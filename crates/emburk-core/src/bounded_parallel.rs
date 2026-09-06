//! Bounded ordered formatter coordination using only scoped std threads.
use std::{
    collections::BTreeMap,
    panic::{self, AssertUnwindSafe},
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
        mpsc::{self, RecvTimeoutError},
    },
    thread,
    time::Duration,
};

const MAX_WORKERS: usize = 8;
const MAX_RESULT: usize = 3 * 1024 * 1024;
pub(crate) fn run<T: Send>(
    workers: usize,
    cancel: &AtomicBool,
    mut next: impl FnMut() -> Result<Option<T>, String>,
    format: impl Fn(T) -> Result<Vec<u8>, String> + Sync,
    mut emit: impl FnMut(Vec<u8>) -> Result<(), String>,
) -> Result<usize, String> {
    if !(1..=MAX_WORKERS).contains(&workers) {
        return Err("workers must be 1 through 8".into());
    }
    if cancel.load(Ordering::Acquire) {
        return Err("cancelled".into());
    }
    let window = workers * 2;
    let (job_tx, job_rx) = mpsc::sync_channel::<(usize, T)>(window);
    let (result_tx, result_rx) = mpsc::sync_channel::<(usize, Result<Vec<u8>, String>)>(window);
    let jobs = Arc::new(Mutex::new(job_rx));
    thread::scope(|scope| {
        let mut handles = Vec::new();
        let mut failure = None;
        for _ in 0..workers {
            let format = &format;
            let jobs = Arc::clone(&jobs);
            let result_tx = result_tx.clone();
            match thread::Builder::new()
                .name("emburk-format".into())
                .spawn_scoped(scope, move || {
                    loop {
                        if cancel.load(Ordering::Acquire) {
                            break;
                        }
                        let job = match jobs
                            .lock()
                            .map_err(|_| ())
                            .and_then(|r| r.recv().map_err(|_| ()))
                        {
                            Ok(v) => v,
                            Err(_) => break,
                        };
                        let (seq, item) = job;
                        if cancel.load(Ordering::Acquire) {
                            break;
                        }
                        let value = panic::catch_unwind(AssertUnwindSafe(|| format(item)))
                            .map_err(|_| "formatter panicked".to_owned())
                            .and_then(|v| v);
                        let value = value.and_then(|v| {
                            if v.len() > MAX_RESULT {
                                Err("formatted record exceeds 3145728 bytes".into())
                            } else {
                                Ok(v)
                            }
                        });
                        if result_tx.send((seq, value)).is_err() {
                            break;
                        }
                    }
                }) {
                Ok(handle) => handles.push(handle),
                Err(error) => {
                    failure = Some(format!("cannot start worker: {error}"));
                    break;
                }
            }
        }
        drop(result_tx);
        let mut admitted = 0usize;
        let mut committed = 0usize;
        let mut done = false;
        let mut pending = BTreeMap::new();
        let coordinator = panic::catch_unwind(AssertUnwindSafe(|| {
            while failure.is_none() && (!done || committed < admitted) {
                if cancel.load(Ordering::Acquire) {
                    failure = Some("cancelled".into());
                    break;
                }
                while !done && admitted - committed < window {
                    if cancel.load(Ordering::Acquire) {
                        failure = Some("cancelled".into());
                        break;
                    }
                    match next() {
                        Ok(Some(v)) => {
                            if job_tx.send((admitted, v)).is_err() {
                                failure = Some("worker channel closed".into());
                                break;
                            }
                            admitted += 1
                        }
                        Ok(None) => {
                            done = true;
                            break;
                        }
                        Err(e) => {
                            failure = Some(e);
                            break;
                        }
                    }
                }
                if failure.is_some() {
                    break;
                }
                if committed == admitted {
                    continue;
                }
                match result_rx.recv_timeout(Duration::from_millis(20)) {
                    Ok((seq, value)) => match value {
                        Ok(v) => {
                            pending.insert(seq, v);
                            while let Some(v) = pending.remove(&committed) {
                                if cancel.load(Ordering::Acquire) {
                                    failure = Some("cancelled".into());
                                    break;
                                }
                                if let Err(e) = emit(v) {
                                    failure = Some(e);
                                    break;
                                }
                                committed += 1
                            }
                        }
                        Err(e) => {
                            failure = Some(e);
                            break;
                        }
                    },
                    Err(RecvTimeoutError::Timeout) => continue,
                    Err(RecvTimeoutError::Disconnected) => {
                        failure = Some("worker channel closed".into());
                        break;
                    }
                }
            }
        }));
        if coordinator.is_err() {
            failure = Some("coordinator callback panicked".into());
        }
        drop(job_tx);
        drop(result_rx);
        for handle in handles {
            if handle.join().is_err() && failure.is_none() {
                failure = Some("worker panicked".into())
            }
        }
        failure.map_or(Ok(committed), Err)
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Barrier, atomic::AtomicUsize};
    #[test]
    fn out_of_order_workers_keep_order_and_bound_entire_uncommitted_window() {
        let admitted = AtomicUsize::new(0);
        let committed = AtomicUsize::new(0);
        let high = AtomicUsize::new(0);
        let mut output = Vec::new();
        let mut sequence = 0usize;
        let count = run(
            2,
            &AtomicBool::new(false),
            || {
                if sequence == 31 {
                    return Ok(None);
                }
                let value = sequence;
                sequence += 1;
                let total = admitted.fetch_add(1, Ordering::SeqCst) + 1;
                let outstanding = total - committed.load(Ordering::SeqCst);
                high.fetch_max(outstanding, Ordering::SeqCst);
                assert!(outstanding <= 4);
                Ok(Some(value))
            },
            |value| {
                if value % 4 == 0 {
                    thread::sleep(Duration::from_millis(5));
                }
                Ok(vec![value as u8])
            },
            |bytes| {
                output.extend(bytes);
                committed.fetch_add(1, Ordering::SeqCst);
                Ok(())
            },
        )
        .unwrap();
        assert_eq!(count, 31);
        assert_eq!(output, (0..31).collect::<Vec<u8>>());
        assert_eq!(high.load(Ordering::SeqCst), 4);
    }
    #[test]
    fn selected_workers_really_execute_concurrently() {
        let barrier = Barrier::new(3);
        let active = AtomicUsize::new(0);
        let peak = AtomicUsize::new(0);
        let mut values = 0..6;
        run(
            3,
            &AtomicBool::new(false),
            || Ok(values.next()),
            |value| {
                let concurrent = active.fetch_add(1, Ordering::SeqCst) + 1;
                peak.fetch_max(concurrent, Ordering::SeqCst);
                barrier.wait();
                active.fetch_sub(1, Ordering::SeqCst);
                Ok(vec![value])
            },
            |_| Ok(()),
        )
        .unwrap();
        assert_eq!(peak.load(Ordering::SeqCst), 3);
        assert_eq!(active.load(Ordering::SeqCst), 0);
    }
    #[test]
    fn callback_failures_and_worker_panic_return_without_blocked_joins() {
        for mode in [
            "source",
            "formatter",
            "writer",
            "panic",
            "oversize",
            "source-panic",
            "writer-panic",
        ] {
            let mut count = 0;
            let result = run(
                2,
                &AtomicBool::new(false),
                || {
                    count += 1;
                    if mode == "source-panic" && count == 3 {
                        panic!("injected source panic");
                    }
                    if mode == "source" && count == 3 {
                        return Err("source failure".into());
                    }
                    Ok((count < 20).then_some(count))
                },
                |_| {
                    if mode == "panic" {
                        panic!("injected formatter panic");
                    }
                    if mode == "formatter" {
                        return Err("formatter failure".into());
                    }
                    if mode == "oversize" {
                        return Ok(vec![0; MAX_RESULT + 1]);
                    }
                    Ok(vec![1])
                },
                |_| {
                    if mode == "writer-panic" {
                        panic!("injected writer panic");
                    }
                    if mode == "writer" {
                        Err("writer failure".into())
                    } else {
                        Ok(())
                    }
                },
            );
            assert!(result.is_err(), "{mode}");
        }
    }
    #[test]
    fn invalid_workers_and_precancellation_do_not_admit_input() {
        for workers in [0, 9] {
            assert!(
                run::<()>(
                    workers,
                    &AtomicBool::new(false),
                    || panic!("admitted"),
                    |_| Ok(vec![]),
                    |_| Ok(())
                )
                .is_err()
            );
        }
        assert_eq!(
            run::<()>(
                1,
                &AtomicBool::new(true),
                || panic!("admitted"),
                |_| Ok(vec![]),
                |_| Ok(())
            )
            .unwrap_err(),
            "cancelled"
        );
    }
    #[test]
    fn cancellation_while_waiting_joins_workers_without_ordered_output() {
        let cancel = AtomicBool::new(false);
        let started = AtomicBool::new(false);
        let mut emitted = 0;
        thread::scope(|scope| {
            scope.spawn(|| {
                while !started.load(Ordering::Acquire) {
                    thread::yield_now();
                }
                cancel.store(true, Ordering::Release);
            });
            let mut values = 0..10;
            let result = run(
                2,
                &cancel,
                || Ok(values.next()),
                |_| {
                    started.store(true, Ordering::Release);
                    thread::sleep(Duration::from_millis(30));
                    Ok(vec![0])
                },
                |_| {
                    emitted += 1;
                    Ok(())
                },
            );
            assert_eq!(result.unwrap_err(), "cancelled");
        });
        assert_eq!(emitted, 0);
    }
}

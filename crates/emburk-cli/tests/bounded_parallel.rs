use std::{
    fs,
    io::Write,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    sync::atomic::{AtomicUsize, Ordering},
    thread,
    time::{Duration, Instant},
};
static NEXT: AtomicUsize = AtomicUsize::new(0);
fn root() -> PathBuf {
    let root = std::env::temp_dir().join(format!(
        "emburk-parallel-cli-{}-{}",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    fs::create_dir(&root).unwrap();
    fs::create_dir(root.join("output")).unwrap();
    root
}
fn config(workers: usize, json: bool, encoder: &str) -> String {
    let parser = if json {
        "    type: json\n"
    } else {
        "    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    skip_header_lines: 1\n"
    };
    format!(
        "in:\n  type: file\n  path_prefix: input\n  parser:\n{parser}    columns:\n    - {{name: id, type: long}}\n    - {{name: name, type: string}}\nfilters:\n- type: rename\n  columns: {{name: label}}\nout:\n  type: file\n  path_prefix: output/result\n  file_ext: csv\n{encoder}  formatter:\n    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    header_line: true\n    quote_policy: MINIMAL\nexec:\n  max_threads: {workers}\n  min_output_tasks: 1\n"
    )
}
fn command(root: &Path) -> Command {
    let mut command = Command::new(env!("CARGO_BIN_EXE_emburk"));
    command.args(["run", "config.yml"]).current_dir(root);
    command
}
#[test]
fn serial_and_parallel_selected_formats_are_byte_deterministic() {
    for json in [false, true] {
        for encoder in [
            "",
            "  encoders:\n  - {type: gzip, level: 6}\n",
            "  encoders:\n  - {type: bzip2, level: 9}\n",
        ] {
            let mut baseline = None;
            for workers in [1, 4, 8] {
                let root = root();
                fs::write(root.join("config.yml"), config(workers, json, encoder)).unwrap();
                let mut input = if json {
                    String::new()
                } else {
                    String::from("id,name\n")
                };
                for id in 0..2000 {
                    if json {
                        input.push_str(&format!("{{\"id\":{id},\"name\":\"row, {id} ☃\"}}\n"));
                    } else {
                        input.push_str(&format!("{id},\"row, {id} ☃\"\n"));
                    }
                }
                fs::write(root.join("input"), input).unwrap();
                let result = command(&root).output().unwrap();
                assert!(
                    result.status.success(),
                    "{}",
                    String::from_utf8_lossy(&result.stderr)
                );
                let bytes = fs::read(root.join("output/result000.00.csv")).unwrap();
                if let Some(expected) = &baseline {
                    assert_eq!(&bytes, expected);
                } else {
                    baseline = Some(bytes);
                }
            }
        }
    }
}
#[test]
fn worker_limits_fail_before_output() {
    for workers in [0, 9] {
        let root = root();
        fs::write(root.join("config.yml"), config(workers, false, "")).unwrap();
        fs::write(root.join("input"), b"id,name\n1,Ada\n").unwrap();
        assert!(!command(&root).status().unwrap().success());
        assert_eq!(fs::read_dir(root.join("output")).unwrap().count(), 0);
    }
}
#[cfg(unix)]
#[test]
fn sigint_cancels_active_transfer_and_reaps_without_publishing() {
    for encoder in [
        "",
        "  encoders:\n  - {type: gzip, level: 6}\n",
        "  encoders:\n  - {type: bzip2, level: 9}\n",
    ] {
        let root = root();
        fs::write(root.join("config.yml"), config(4, false, encoder)).unwrap();
        let mut input = fs::File::create_new(root.join("input")).unwrap();
        input.write_all(b"id,name\n").unwrap();
        let block = b"1,abcdefghijklmnopqrstuvwxyz\n".repeat(4096);
        for _ in 0..256 {
            input.write_all(&block).unwrap();
        }
        drop(input);
        let stderr = fs::File::create_new(root.join("stderr.log")).unwrap();
        let mut child = command(&root)
            .stdout(Stdio::null())
            .stderr(stderr)
            .spawn()
            .unwrap();
        let start = Instant::now();
        let mut active = false;
        while start.elapsed() < Duration::from_secs(5) {
            if fs::read_dir(root.join("output")).unwrap().any(|e| {
                e.unwrap()
                    .file_name()
                    .to_string_lossy()
                    .starts_with(".emburk-output-")
            }) {
                active = true;
                break;
            }
            if child.try_wait().unwrap().is_some() {
                break;
            }
            thread::sleep(Duration::from_millis(1));
        }
        let signalled = active
            && Command::new("/bin/kill")
                .args(["-INT", &child.id().to_string()])
                .status()
                .unwrap()
                .success();
        let wait_start = Instant::now();
        let mut status = None;
        while wait_start.elapsed() < Duration::from_secs(5) {
            status = child.try_wait().unwrap();
            if status.is_some() {
                break;
            }
            thread::sleep(Duration::from_millis(5));
        }
        if status.is_none() {
            let _ = child.kill();
        }
        let status = child.wait().unwrap();
        assert!(signalled, "could not observe and signal an active child");
        assert_eq!(
            status.code(),
            Some(130),
            "{}",
            fs::read_to_string(root.join("stderr.log")).unwrap()
        );
        assert_eq!(fs::read_dir(root.join("output")).unwrap().count(), 0);
    }
}

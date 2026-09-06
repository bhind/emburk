#![cfg(unix)]
use std::{
    fs::{self, File, OpenOptions},
    io::Write,
    os::unix::fs::{MetadataExt, PermissionsExt},
    path::{Path, PathBuf},
    process::{Command, Stdio},
    sync::atomic::{AtomicUsize, Ordering},
    thread,
    time::{Duration, Instant},
};
static NEXT: AtomicUsize = AtomicUsize::new(0);
fn root() -> PathBuf {
    let p = std::env::temp_dir().join(format!(
        "emburk-resume-cli-{}-{}",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    fs::create_dir(&p).unwrap();
    fs::create_dir(p.join("output")).unwrap();
    p
}
fn config(json: bool, codec: &str) -> String {
    let parser = if json {
        "    type: json\n"
    } else {
        "    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    skip_header_lines: 1\n"
    };
    format!(
        "in:\n  type: file\n  path_prefix: input\n  parser:\n{parser}    columns:\n    - {{name: id, type: long}}\n    - {{name: name, type: string}}\nfilters:\n- type: rename\n  columns: {{name: label}}\nout:\n  type: file\n  path_prefix: output/result\n  file_ext: csv\n{codec}  formatter:\n    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    header_line: true\n    quote_policy: MINIMAL\nexec:\n  max_threads: 4\n  min_output_tasks: 1\n"
    )
}
fn command(p: &Path, args: &[&str]) -> Command {
    let mut c = Command::new(env!("CARGO_BIN_EXE_emburk"));
    c.current_dir(p).args(args);
    c
}
fn run(p: &Path, args: &[&str], success: bool) {
    let result = command(p, args).output().unwrap();
    assert_eq!(
        result.status.success(),
        success,
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
}
fn interrupted(json: bool, codec: &str) -> PathBuf {
    let p = root();
    fs::write(p.join("config.yml"), config(json, codec)).unwrap();
    let mut input = File::create_new(p.join("input")).unwrap();
    if !json {
        input.write_all(b"id,name\n").unwrap();
    }
    let row = if json {
        b"{\"id\":1,\"name\":\"abcdefghijklmnopqrstuvwxyz\"}\n".as_slice()
    } else {
        b"1,abcdefghijklmnopqrstuvwxyz\n".as_slice()
    };
    let block = row.repeat(4096);
    for _ in 0..64 {
        input.write_all(&block).unwrap();
    }
    drop(input);
    let log = File::create_new(p.join("interruption.stderr")).unwrap();
    let mut child = command(&p, &["run", "config.yml", "--state", "state"])
        .stderr(log)
        .stdout(Stdio::null())
        .spawn()
        .unwrap();
    let start = Instant::now();
    let mut active = false;
    while start.elapsed() < Duration::from_secs(10) {
        if p.join("state/00000000000000000001.json").exists() {
            active = true;
            break;
        }
        if child.try_wait().unwrap().is_some() {
            break;
        }
        thread::sleep(Duration::from_millis(2));
    }
    if active {
        assert!(
            Command::new("/bin/kill")
                .args(["-INT", &child.id().to_string()])
                .status()
                .unwrap()
                .success()
        );
    } else {
        let _ = child.kill();
    }
    let deadline = Instant::now();
    while child.try_wait().unwrap().is_none() && deadline.elapsed() < Duration::from_secs(10) {
        thread::sleep(Duration::from_millis(5));
    }
    if child.try_wait().unwrap().is_none() {
        child.kill().unwrap();
    }
    let status = child.wait().unwrap();
    assert!(active, "no durable active checkpoint: {}", p.display());
    assert_eq!(status.code(), Some(130));
    assert!(!p.join("output/result000.00.csv").exists());
    p
}
#[test]
fn actual_sigint_resume_matches_plain_run_and_repeated_resume_preserves_inode() {
    for (json, codec) in [
        (false, ""),
        (true, ""),
        (false, "  encoders:\n  - {type: gzip, level: 6}\n"),
        (true, "  encoders:\n  - {type: bzip2, level: 9}\n"),
    ] {
        let p = interrupted(json, codec);
        run(&p, &["resume", "config.yml", "state"], true);
        let output = p.join("output/result000.00.csv");
        let bytes = fs::read(&output).unwrap();
        let ino = fs::metadata(&output).unwrap().ino();
        run(&p, &["resume", "config.yml", "state"], true);
        assert_eq!(fs::metadata(&output).unwrap().ino(), ino);
        let baseline = root();
        fs::copy(p.join("input"), baseline.join("input")).unwrap();
        fs::copy(p.join("config.yml"), baseline.join("config.yml")).unwrap();
        run(&baseline, &["run", "config.yml"], true);
        assert_eq!(
            bytes,
            fs::read(baseline.join("output/result000.00.csv")).unwrap()
        );
    }
}
#[test]
fn tampering_is_rejected_without_truncating_spool_or_touching_output() {
    for kind in [
        "input",
        "config",
        "spool",
        "generation",
        "conflict",
        "permissions",
        "extra-input",
    ] {
        let p = interrupted(false, "");
        let spool = p.join("state/spool");
        OpenOptions::new()
            .append(true)
            .open(&spool)
            .unwrap()
            .write_all(b"uncheckpointed-tail")
            .unwrap();
        match kind {
            "input" => {
                OpenOptions::new()
                    .append(true)
                    .open(p.join("input"))
                    .unwrap()
                    .write_all(b"2,changed\n")
                    .unwrap();
            }
            "config" => {
                OpenOptions::new()
                    .append(true)
                    .open(p.join("config.yml"))
                    .unwrap()
                    .write_all(b"\n# changed\n")
                    .unwrap();
            }
            "spool" => {
                OpenOptions::new()
                    .write(true)
                    .open(&spool)
                    .unwrap()
                    .write_all(b"corrupt")
                    .unwrap();
            }
            "generation" => {
                fs::remove_file(p.join("state/00000000000000000000.json")).unwrap();
            }
            "conflict" => {
                fs::write(p.join("output/result000.00.csv"), b"untouched").unwrap();
            }
            "permissions" => {
                fs::set_permissions(&spool, fs::Permissions::from_mode(0o644)).unwrap();
            }
            "extra-input" => {
                fs::write(p.join("input-extra"), b"id,name\n").unwrap();
            }
            _ => unreachable!(),
        }
        let before = fs::read(&spool).unwrap();
        run(&p, &["resume", "config.yml", "state"], false);
        assert_eq!(before, fs::read(&spool).unwrap());
        if kind == "conflict" {
            assert_eq!(
                fs::read(p.join("output/result000.00.csv")).unwrap(),
                b"untouched"
            );
        } else {
            assert!(!p.join("output/result000.00.csv").exists());
        }
    }
}
#[test]
fn valid_tail_recovery_lock_exclusion_and_missing_state_are_safe() {
    let p = interrupted(false, "");
    let lock = OpenOptions::new()
        .read(true)
        .write(true)
        .open(p.join("state/lock"))
        .unwrap();
    lock.try_lock().unwrap();
    run(&p, &["resume", "config.yml", "state"], false);
    drop(lock);
    OpenOptions::new()
        .append(true)
        .open(p.join("state/spool"))
        .unwrap()
        .write_all(b"partial trailing record")
        .unwrap();
    run(&p, &["resume", "config.yml", "state"], true);
    run(&p, &["resume", "config.yml", "absent"], false);
    assert!(!p.join("absent").exists());
    let target = p.join("output/result000.00.csv");
    let bytes = fs::read(&target).unwrap();
    fs::rename(&target, p.join("original-output")).unwrap();
    fs::write(&target, &bytes).unwrap();
    run(&p, &["resume", "config.yml", "state"], false);
    assert_eq!(fs::read(&target).unwrap(), bytes);
}

#[test]
fn modeled_crashes_before_and_after_output_link_recover() {
    for linked in [true, false] {
        let p = root();
        fs::write(p.join("config.yml"), config(false, "")).unwrap();
        fs::write(p.join("input"), b"id,name\n1,Ada\n").unwrap();
        run(&p, &["run", "config.yml", "--state", "state"], true);
        let output = p.join("output/result000.00.csv");
        let ino = fs::metadata(&output).unwrap().ino();
        let mut generations = fs::read_dir(p.join("state"))
            .unwrap()
            .map(|e| e.unwrap().path())
            .filter(|p| p.extension().is_some_and(|s| s == "json"))
            .collect::<Vec<_>>();
        generations.sort();
        // Removing only the final Published generation reproduces the persisted
        // Publishing state observable after a crash immediately after output link.
        fs::remove_file(generations.last().unwrap()).unwrap();
        if !linked {
            // Retain the original inode away from the destination to model a
            // durable prepared checkpoint whose output was never linked.
            fs::rename(&output, p.join("prepared-not-linked")).unwrap();
        }
        run(&p, &["resume", "config.yml", "state"], true);
        assert_eq!(fs::read(&output).unwrap(), b"id,label\n1,Ada\n");
        if linked {
            assert_eq!(fs::metadata(output).unwrap().ino(), ino);
        } else {
            assert_ne!(fs::metadata(output).unwrap().ino(), ino);
        }
    }
}

use std::{
    fs,
    path::{Path, PathBuf},
    process::Command,
    sync::atomic::{AtomicUsize, Ordering},
};
static NEXT: AtomicUsize = AtomicUsize::new(0);
fn dir(name: &str) -> PathBuf {
    let p = std::env::temp_dir().join(format!(
        "emburk-configured-csv-{}-{}-{}",
        std::process::id(),
        name,
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    fs::create_dir(&p).unwrap();
    fs::create_dir(p.join("output")).unwrap();
    p
}
fn config(extra: &str) -> String {
    format!(
        "in:\n  type: file\n  path_prefix: input.csv\n  parser:\n    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    skip_header_lines: 1\n    columns:\n    - {{name: id, type: long}}\n    - {{name: name, type: string}}\nout:\n  type: file\n  path_prefix: output/result\n  file_ext: csv\n  formatter:\n    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    header_line: true\n    quote_policy: MINIMAL\nexec:\n  max_threads: 1\n  min_output_tasks: 1\n{extra}"
    )
}
fn boolean_config(extra: &str) -> String {
    config(extra).replace(
        "    - {name: id, type: long}\n    - {name: name, type: string}",
        "    - {name: flag, type: boolean}",
    )
}
fn double_config(extra: &str) -> String {
    config(extra).replace(
        "    - {name: id, type: long}\n    - {name: name, type: string}",
        "    - {name: ratio, type: double}",
    )
}
fn run(dir: &Path) -> std::process::Output {
    Command::new(env!("CARGO_BIN_EXE_emburk"))
        .args(["run", "config.yml"])
        .current_dir(dir)
        .output()
        .unwrap()
}
fn write(dir: &Path, text: &str) {
    fs::write(dir.join("config.yml"), text).unwrap();
}
#[test]
fn normal_missing_and_existing_outputs_are_safe() {
    let d = dir("normal");
    write(&d, &config(""));
    fs::write(d.join("input.csv"), b"id,name\n1,Alice\n").unwrap();
    assert!(run(&d).status.success());
    let out = d.join("output/result000.00.csv");
    assert_eq!(fs::read(&out).unwrap(), b"id,name\n1,Alice\n");
    let e = run(&d);
    assert!(!e.status.success());
    assert_eq!(fs::read(&out).unwrap(), b"id,name\n1,Alice\n");
    let m = dir("missing");
    write(&m, &config(""));
    assert!(run(&m).status.success());
    assert!(!m.join("output/result000.00.csv").exists());
}
#[test]
fn selected_boolean_csv_values_preserve_empty_and_quote_state() {
    let d = dir("boolean-selected");
    write(&d, &boolean_config(""));
    fs::write(d.join("input.csv"), b"flag\ntrue\nfalse\ntruthy\n\n\"\"\n").unwrap();
    assert!(run(&d).status.success());
    assert_eq!(
        fs::read(d.join("output/result000.00.csv")).unwrap(),
        b"flag\ntrue\nfalse\nfalse\n\nfalse\n"
    );
}
#[test]
fn unsupported_boolean_literal_rejects_the_csv_run() {
    let d = dir("boolean-unsupported");
    write(&d, &boolean_config(""));
    fs::write(d.join("input.csv"), b"flag\nTRUE\n").unwrap();
    let output = run(&d);
    assert!(!output.status.success());
    assert!(String::from_utf8_lossy(&output.stderr).contains("unsupported Boolean literal"));
    assert!(!d.join("output/result000.00.csv").exists());
}
#[test]
fn selected_float64_csv_values_preserve_signed_zero_and_omit_selected_bad_rows() {
    let d = dir("float64-selected");
    write(&d, &double_config(""));
    fs::write(
        d.join("input.csv"),
        b"ratio\n1.5\n-0.0\n0.0\n\"\"\nnot-a-double\n2.5\n",
    )
    .unwrap();
    assert!(run(&d).status.success());
    assert_eq!(
        fs::read(d.join("output/result000.00.csv")).unwrap(),
        b"ratio\n1.5\n-0.0\n0.0\n2.5\n"
    );
}
#[test]
fn selected_float64_unquoted_empty_is_null() {
    let d = dir("float64-unquoted-empty");
    let profile = double_config("").replace(
        "    - {name: ratio, type: double}",
        "    - {name: label, type: string}\n    - {name: ratio, type: double}",
    );
    write(&d, &profile);
    fs::write(d.join("input.csv"), b"label,ratio\nbare,\nquoted,\"\"\n").unwrap();
    assert!(run(&d).status.success());
    assert_eq!(
        fs::read(d.join("output/result000.00.csv")).unwrap(),
        b"label,ratio\nbare,\n"
    );
}
#[test]
fn out_of_domain_float64_literal_rejects_without_publishing_output() {
    let d = dir("float64-unsupported");
    write(&d, &double_config(""));
    fs::write(d.join("input.csv"), b"ratio\n1e2\n").unwrap();
    let output = run(&d);
    assert!(!output.status.success());
    assert!(String::from_utf8_lossy(&output.stderr).contains("unsupported Float64 literal"));
    assert!(!d.join("output/result000.00.csv").exists());
}
#[test]
fn selected_float64_lexical_values_preserve_quote_state_and_omit_only_3_5x() {
    let d = dir("float64-lexical-selected");
    write(&d, &double_config(""));
    fs::write(
        d.join("input.csv"),
        b"ratio\n3.5\n-12.25\n\"3.5\"\n3.5x\n42.0\n",
    )
    .unwrap();
    assert!(run(&d).status.success());
    assert_eq!(
        fs::read(d.join("output/result000.00.csv")).unwrap(),
        b"ratio\n3.5\n-12.25\n3.5\n42.0\n"
    );
}
#[test]
fn finite_decimal_profile_normalizes_leading_zeroes_and_preserves_negative_zero() {
    let d = dir("float64-finite-decimal");
    write(&d, &double_config(""));
    fs::write(
        d.join("input.csv"),
        b"ratio\n03.5\n3.50\n42\n-0\n-0.00\n999999.99\n",
    )
    .unwrap();
    assert!(run(&d).status.success());
    assert_eq!(
        fs::read(d.join("output/result000.00.csv")).unwrap(),
        b"ratio\n3.5\n3.5\n42.0\n-0.0\n-0.0\n999999.99\n"
    );
}
#[test]
fn invalid_configurations_do_not_open_output() {
    for (name, text) in [
        ("unknown", config("unknown: nope\n")),
        ("raw", String::from("[")),
        ("multi", String::from("---\na: b\n---\na: b\n")),
        (
            "tag",
            config("\n# kept\n").replace("type: file", "type: !x file"),
        ),
        ("anchor", config("").replace("type: file", "type: &x file")),
        ("alias", config("").replace("type: file", "type: *x")),
        ("large", "x".repeat(65537)),
    ] {
        let d = dir(name);
        write(&d, &text);
        assert!(!run(&d).status.success());
        assert!(!d.join("output/result000.00.csv").exists());
    }
    let d = dir("raw-invalid-utf8");
    fs::write(d.join("config.yml"), [0xff]).unwrap();
    assert!(!run(&d).status.success());
    assert!(!d.join("output/result000.00.csv").exists());
}
#[test]
fn two_matching_inputs_are_sorted_and_more_than_two_are_rejected() {
    let d = dir("prefix");
    write(&d, &config(""));
    fs::write(d.join("input.csv-a"), b"id,name\n1,a\n").unwrap();
    fs::write(d.join("input.csv-b"), b"id,name\n2,b\n").unwrap();
    assert!(run(&d).status.success());
    assert_eq!(
        fs::read(d.join("output/result000.00.csv")).unwrap(),
        b"id,name\n1,a\n"
    );
    assert_eq!(
        fs::read(d.join("output/result001.00.csv")).unwrap(),
        b"id,name\n2,b\n"
    );
    fs::write(d.join("input.csv-c"), b"id,name\n3,c\n").unwrap();
    let failed = run(&d);
    assert!(!failed.status.success());
    assert!(String::from_utf8_lossy(&failed.stderr).contains("more than two input files matched"));
}
#[test]
fn bad_csv_does_not_publish_or_leave_temporary_output() {
    for (name, bytes) in [
        ("quote", b"id,name\n1,\"bad\"x\n".as_slice()),
        ("width", b"id,name\n1,a,b\n".as_slice()),
        ("utf8", b"id,name\n1,\xff\n".as_slice()),
    ] {
        let d = dir(name);
        write(&d, &config(""));
        fs::write(d.join("input.csv"), bytes).unwrap();
        assert!(!run(&d).status.success());
        assert!(!d.join("output/result000.00.csv").exists());
        assert_eq!(fs::read_dir(d.join("output")).unwrap().count(), 0);
    }
}
#[test]
fn malformed_second_input_keeps_completed_first_prefix() {
    let d = dir("second-fails");
    write(&d, &config(""));
    fs::write(d.join("input.csv-a"), b"id,name\n1,a\n").unwrap();
    fs::write(d.join("input.csv-b"), b"id,name\n2,b,c\n").unwrap();
    assert!(!run(&d).status.success());
    assert_eq!(
        fs::read(d.join("output/result000.00.csv")).unwrap(),
        b"id,name\n1,a\n"
    );
    assert!(!d.join("output/result001.00.csv").exists());
}
#[test]
fn existing_and_dangling_output_targets_are_rejected_before_processing() {
    for (name, make_target) in [("existing", false), ("dangling", true)] {
        let d = dir(name);
        write(&d, &config(""));
        fs::write(d.join("input.csv-a"), b"id,name\n1,a\n").unwrap();
        fs::write(d.join("input.csv-b"), b"id,name\n2,b\n").unwrap();
        let target = d.join("output/result001.00.csv");
        if make_target {
            #[cfg(unix)]
            std::os::unix::fs::symlink("absent", &target).unwrap();
            #[cfg(not(unix))]
            fs::write(&target, b"sentinel").unwrap();
        } else {
            fs::write(&target, b"sentinel").unwrap();
        }
        assert!(!run(&d).status.success());
        assert!(!d.join("output/result000.00.csv").exists());
    }
}
#[test]
fn prefix_and_bad_csv_regression_marker() {
    // Keeps the old test name's coverage split into focused multi-file cases.
    for (name, bytes) in [
        ("quote", b"id,name\n1,\"bad\"x\n".as_slice()),
        ("width", b"id,name\n1,a,b\n".as_slice()),
        ("utf8", b"id,name\n1,\xff\n".as_slice()),
    ] {
        let d = dir(name);
        write(&d, &config(""));
        fs::write(d.join("input.csv"), bytes).unwrap();
        assert!(!run(&d).status.success());
        assert!(!d.join("output/result000.00.csv").exists());
        assert_eq!(fs::read_dir(d.join("output")).unwrap().count(), 0);
    }
}
#[cfg(unix)]
#[test]
fn generated_file_is_owner_only() {
    use std::os::unix::fs::PermissionsExt;
    let d = dir("mode");
    write(&d, &config(""));
    fs::write(d.join("input.csv"), b"id,name\n").unwrap();
    assert!(run(&d).status.success());
    assert_eq!(
        fs::metadata(d.join("output/result000.00.csv"))
            .unwrap()
            .permissions()
            .mode()
            & 0o777,
        0o600
    );
}

#[cfg(unix)]
#[test]
fn killed_transfer_never_exposes_partial_final_output() {
    use std::{
        io::Write,
        thread,
        time::{Duration, Instant},
    };
    let d = dir("interrupted");
    write(&d, &config(""));
    let mut input = fs::File::create(d.join("input.csv")).unwrap();
    input.write_all(b"id,name\n").unwrap();
    let block = b"1,abcdefghijklmnopqrstuvwxyz\n".repeat(4096);
    for _ in 0..256 {
        input.write_all(&block).unwrap();
    }
    drop(input);
    let mut child = Command::new(env!("CARGO_BIN_EXE_emburk"))
        .args(["run", "config.yml"])
        .current_dir(&d)
        .spawn()
        .unwrap();
    let start = Instant::now();
    let mut saw_temporary = false;
    while start.elapsed() < Duration::from_secs(5) {
        if fs::read_dir(d.join("output")).unwrap().any(|entry| {
            entry
                .unwrap()
                .file_name()
                .to_string_lossy()
                .starts_with(".emburk-output-")
        }) {
            saw_temporary = true;
            break;
        }
        if child.try_wait().unwrap().is_some() {
            break;
        }
        thread::sleep(Duration::from_millis(1));
    }
    // Always reap the child, including a failed synchronization attempt.
    let _ = child.kill();
    let status = child.wait().unwrap();
    assert!(
        saw_temporary,
        "did not observe the staged output before timeout/exit"
    );
    assert!(!status.success());
    assert!(!d.join("output/result000.00.csv").exists());
    // SIGKILL cannot run cleanup. Only a private temporary can remain; recovery
    // of that residue is deliberately not claimed by this publication slice.
    assert!(fs::read_dir(d.join("output")).unwrap().all(|entry| {
        entry
            .unwrap()
            .file_name()
            .to_string_lossy()
            .starts_with(".emburk-output-")
    }));
}

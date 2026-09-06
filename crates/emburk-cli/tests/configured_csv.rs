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
fn prefix_and_bad_csv_fail_before_or_with_explicit_partial_output() {
    let d = dir("prefix");
    write(&d, &config(""));
    fs::write(d.join("input.csv-a"), b"id,name\n1,a\n").unwrap();
    fs::write(d.join("input.csv-b"), b"id,name\n2,b\n").unwrap();
    assert!(!run(&d).status.success());
    assert!(!d.join("output/result000.00.csv").exists());
    for (name, bytes) in [
        ("quote", b"id,name\n1,\"bad\"x\n".as_slice()),
        ("width", b"id,name\n1,a,b\n".as_slice()),
        ("utf8", b"id,name\n1,\xff\n".as_slice()),
    ] {
        let d = dir(name);
        write(&d, &config(""));
        fs::write(d.join("input.csv"), bytes).unwrap();
        assert!(!run(&d).status.success());
        assert!(d.join("output/result000.00.csv").exists());
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

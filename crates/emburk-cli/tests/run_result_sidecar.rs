use std::{
    fs,
    fs::File,
    path::{Path, PathBuf},
    process::{Command, Output, Stdio},
    sync::atomic::{AtomicBool, AtomicUsize, Ordering},
};

static NEXT: AtomicUsize = AtomicUsize::new(0);

fn root(name: &str) -> PathBuf {
    let root = std::env::temp_dir().join(format!(
        "emburk-run-result-{name}-{}-{}",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    fs::create_dir(&root).unwrap();
    fs::create_dir(root.join("output")).unwrap();
    root
}

#[cfg(unix)]
#[test]
fn report_hard_link_to_selected_input_is_rejected_by_open_descriptor_identity() {
    let root = root("report-input-hardlink");
    let input = root.join("input.csv");
    fs::write(&input, b"id,name\n1,Ada\n").unwrap();
    let output_prefix = root.join("output/result");
    fs::write(
        root.join("config.yml"),
        config()
            .replace(
                "path_prefix: input.csv",
                &format!("path_prefix: {}", input.display()),
            )
            .replace(
                "path_prefix: output/result",
                &format!("path_prefix: {}", output_prefix.display()),
            ),
    )
    .unwrap();
    let report = root.join("report-hardlink.json");
    fs::hard_link(&input, &report).unwrap();
    let report_file = File::open(&report).unwrap();
    let error = emburk_core::run_config_with_cancel_and_report(
        &root.join("config.yml"),
        &AtomicBool::new(false),
        Some((&report_file, &report)),
    )
    .unwrap_err();
    assert_eq!(error, "report target aliases input");
    assert_eq!(fs::read(&input).unwrap(), b"id,name\n1,Ada\n");
    assert_eq!(fs::read_dir(root.join("output")).unwrap().count(), 0);
}

fn config() -> &'static str {
    "in:\n  type: file\n  path_prefix: input.csv\n  parser:\n    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    skip_header_lines: 1\n    columns:\n    - {name: id, type: long}\n    - {name: name, type: string}\nout:\n  type: file\n  path_prefix: output/result\n  file_ext: csv\n  formatter:\n    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    header_line: true\n    quote_policy: MINIMAL\nexec:\n  max_threads: 1\n  min_output_tasks: 1\n"
}

fn command(root: &Path, report: &Path) -> Command {
    let mut command = Command::new(env!("CARGO_BIN_EXE_emburk"));
    command
        .args(["run", "config.yml", "--report"])
        .arg(report)
        .current_dir(root);
    command
}

fn report(path: &Path) -> serde_json::Value {
    serde_json::from_slice(&fs::read(path).unwrap()).unwrap()
}

#[test]
fn successful_run_writes_the_exact_v1_result_line() {
    let root = root("success");
    fs::write(root.join("config.yml"), config()).unwrap();
    fs::write(root.join("input.csv"), b"id,name\n1,Ada\n").unwrap();
    let report_path = root.join("result.json");

    let output = command(&root, &report_path).output().unwrap();

    assert!(output.status.success(), "{:?}", output);
    assert_eq!(
        fs::read_to_string(&report_path).unwrap(),
        "{\"schema\":\"emburk.run-result/v1\",\"command\":\"run\",\"outcome\":\"succeeded\",\"exit_code\":0,\"records\":1,\"error\":null}\n"
    );
    assert_eq!(
        fs::read(root.join("output/result000.00.csv")).unwrap(),
        b"id,name\n1,Ada\n"
    );
}

#[test]
fn successful_two_input_run_reports_the_checked_aggregate() {
    let root = root("two-inputs");
    fs::write(root.join("config.yml"), config()).unwrap();
    fs::write(root.join("input.csv-a"), b"id,name\n1,Ada\n").unwrap();
    fs::write(root.join("input.csv-b"), b"id,name\n2,Bea\n3,Cy\n").unwrap();
    let report_path = root.join("result.json");
    let output = command(&root, &report_path).output().unwrap();
    assert!(output.status.success(), "{output:?}");
    assert_eq!(report(&report_path)["records"], 3);
    assert_eq!(
        fs::read(root.join("output/result000.00.csv")).unwrap(),
        b"id,name\n1,Ada\n"
    );
    assert_eq!(
        fs::read(root.join("output/result001.00.csv")).unwrap(),
        b"id,name\n2,Bea\n3,Cy\n"
    );
}

#[test]
fn failed_run_records_the_exact_canonical_stderr_line() {
    let root = root("failure");
    fs::write(
        root.join("config.yml"),
        config().replace("max_threads: 1", "max_threads: 0"),
    )
    .unwrap();
    fs::write(root.join("input.csv"), b"id,name\n1,Ada\n").unwrap();
    let report_path = root.join("result.json");

    let output = command(&root, &report_path).output().unwrap();

    assert_eq!(output.status.code(), Some(1));
    let stderr = String::from_utf8(output.stderr).unwrap();
    assert!(stderr.starts_with("emburk: run failed: "));
    assert_eq!(stderr.matches('\n').count(), 1);
    let result = report(&report_path);
    assert_eq!(result["schema"], "emburk.run-result/v1");
    assert_eq!(result["command"], "run");
    assert_eq!(result["outcome"], "failed");
    assert_eq!(result["exit_code"], 1);
    assert!(result["records"].is_null());
    assert_eq!(result["error"], stderr.trim_end_matches('\n'));
    assert!(!root.join("output/result000.00.csv").exists());
}

#[test]
fn existing_report_is_rejected_before_pipeline_execution() {
    let root = root("existing");
    fs::write(root.join("config.yml"), config()).unwrap();
    fs::write(root.join("input.csv"), b"id,name\n1,Ada\n").unwrap();
    let report_path = root.join("result.json");
    fs::write(&report_path, b"sentinel").unwrap();

    let output = command(&root, &report_path).output().unwrap();

    assert_eq!(output.status.code(), Some(2));
    assert!(
        String::from_utf8_lossy(&output.stderr)
            .starts_with("emburk: cannot create run report exclusively: ")
    );
    assert_eq!(fs::read(&report_path).unwrap(), b"sentinel");
    assert_eq!(fs::read_dir(root.join("output")).unwrap().count(), 0);
}

#[test]
fn report_and_configured_output_collision_keeps_the_reserved_failed_report() {
    let root = root("collision");
    fs::write(root.join("config.yml"), config()).unwrap();
    fs::write(root.join("input.csv"), b"id,name\n1,Ada\n").unwrap();
    let report_path = root.join("output/result000.00.csv");

    let output = command(&root, &report_path).output().unwrap();

    assert_eq!(output.status.code(), Some(1));
    let result = report(&report_path);
    assert_eq!(result["outcome"], "failed");
    assert_eq!(result["exit_code"], 1);
    assert!(result["records"].is_null());
    assert_eq!(
        result["error"],
        String::from_utf8(output.stderr)
            .unwrap()
            .trim_end_matches('\n')
    );
}

#[test]
fn report_output_aliases_are_rejected_before_any_prefix_publication() {
    let root = root("output-aliases");
    std::os::unix::fs::symlink("output", root.join("output-link")).unwrap();
    for report_path in [
        root.join("output/result000.00.csv"),
        root.join("output/../output/result000.00.csv"),
        fs::canonicalize(root.join("output"))
            .unwrap()
            .join("result000.00.csv"),
        root.join("output-link/result000.00.csv"),
    ] {
        fs::write(root.join("config.yml"), config()).unwrap();
        fs::write(root.join("input.csv"), b"id,name\n1,Ada\n").unwrap();
        let output = command(&root, &report_path).output().unwrap();
        assert_eq!(output.status.code(), Some(1));
        assert_eq!(report(&report_path)["outcome"], "failed");
        assert_eq!(fs::read_dir(root.join("output")).unwrap().count(), 1);
        fs::remove_file(&report_path).unwrap();
        assert!(!root.join("output/result000.00.csv").exists());
    }
}

#[test]
fn report_matching_the_input_prefix_fails_explicitly_without_output() {
    let root = root("input-prefix");
    fs::write(root.join("config.yml"), config()).unwrap();
    fs::write(root.join("input.csv"), b"id,name\n1,Ada\n").unwrap();
    let report_path = root.join("input.csv.report.json");

    let output = command(&root, &report_path).output().unwrap();

    assert_eq!(output.status.code(), Some(1));
    let result = report(&report_path);
    assert_eq!(result["outcome"], "failed");
    assert_eq!(result["exit_code"], 1);
    assert!(result["records"].is_null());
    assert_eq!(
        result["error"],
        String::from_utf8(output.stderr)
            .unwrap()
            .trim_end_matches('\n')
    );
    assert_eq!(fs::read_dir(root.join("output")).unwrap().count(), 0);
}

#[cfg(unix)]
#[test]
fn report_is_created_owner_only() {
    use std::os::unix::fs::PermissionsExt;

    let root = root("mode");
    fs::write(root.join("config.yml"), config()).unwrap();
    fs::write(root.join("input.csv"), b"id,name\n").unwrap();
    let report_path = root.join("result.json");

    assert!(command(&root, &report_path).status().unwrap().success());
    assert_eq!(
        fs::metadata(report_path).unwrap().permissions().mode() & 0o777,
        0o600
    );
}

#[cfg(unix)]
#[test]
fn sigint_after_report_reservation_writes_a_cancelled_result() {
    use std::{
        io::Write,
        thread,
        time::{Duration, Instant},
    };

    let root = root("sigint-reserved");
    fs::write(root.join("config.yml"), config()).unwrap();
    let mut input = fs::File::create(root.join("input.csv")).unwrap();
    input.write_all(b"id,name\n").unwrap();
    let block = b"1,abcdefghijklmnopqrstuvwxyz\n".repeat(4096);
    for _ in 0..128 {
        input.write_all(&block).unwrap();
    }
    drop(input);
    let report_path = root.join("result.json");
    let mut child = command(&root, &report_path)
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let start = Instant::now();
    while !report_path.exists() && start.elapsed() < Duration::from_secs(10) {
        assert!(child.try_wait().unwrap().is_none(), "pipeline exited early");
        thread::sleep(Duration::from_millis(1));
    }
    assert!(report_path.exists(), "report was not reserved");
    assert!(
        Command::new("/bin/kill")
            .args(["-INT", &child.id().to_string()])
            .status()
            .unwrap()
            .success()
    );
    let output: Output = child.wait_with_output().unwrap();

    assert_eq!(output.status.code(), Some(130));
    let stderr = String::from_utf8(output.stderr).unwrap();
    let result = report(&report_path);
    assert_eq!(result["outcome"], "cancelled");
    assert_eq!(result["exit_code"], 130);
    assert!(result["records"].is_null());
    assert_eq!(result["error"], stderr.trim_end_matches('\n'));
    assert!(!root.join("output/result000.00.csv").exists());
}

#[cfg(unix)]
#[test]
fn sigint_writes_a_cancelled_result_without_publishing_output() {
    use std::{
        io::Write,
        thread,
        time::{Duration, Instant},
    };

    let root = root("sigint");
    fs::write(root.join("config.yml"), config()).unwrap();
    let mut input = fs::File::create(root.join("input.csv")).unwrap();
    input.write_all(b"id,name\n").unwrap();
    let block = b"1,abcdefghijklmnopqrstuvwxyz\n".repeat(4096);
    for _ in 0..128 {
        input.write_all(&block).unwrap();
    }
    drop(input);
    let report_path = root.join("result.json");
    let mut child = command(&root, &report_path)
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let start = Instant::now();
    let mut active = false;
    while start.elapsed() < Duration::from_secs(10) {
        if fs::read_dir(root.join("output")).unwrap().any(|entry| {
            entry
                .unwrap()
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
        thread::sleep(Duration::from_millis(2));
    }
    assert!(active, "pipeline did not become active");
    assert!(
        Command::new("/bin/kill")
            .args(["-INT", &child.id().to_string()])
            .status()
            .unwrap()
            .success()
    );
    let output: Output = child.wait_with_output().unwrap();

    assert_eq!(output.status.code(), Some(130));
    let stderr = String::from_utf8(output.stderr).unwrap();
    let result = report(&report_path);
    assert_eq!(result["outcome"], "cancelled");
    assert_eq!(result["exit_code"], 130);
    assert!(result["records"].is_null());
    assert_eq!(result["error"], stderr.trim_end_matches('\n'));
    assert!(!root.join("output/result000.00.csv").exists());
}

#[cfg(unix)]
#[test]
fn sigint_after_first_prefix_is_published_keeps_only_that_prefix() {
    use std::{
        io::Write,
        thread,
        time::{Duration, Instant},
    };
    let root = root("sigint-after-first-prefix");
    fs::write(root.join("config.yml"), config()).unwrap();
    fs::write(root.join("input.csv-a"), b"id,name\n1,Ada\n").unwrap();
    let mut second = File::create(root.join("input.csv-b")).unwrap();
    second.write_all(b"id,name\n").unwrap();
    let block = b"2,abcdefghijklmnopqrstuvwxyz\n".repeat(4096);
    for _ in 0..256 {
        second.write_all(&block).unwrap();
    }
    drop(second);
    let report_path = root.join("result.json");
    let mut child = command(&root, &report_path)
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let start = Instant::now();
    while !root.join("output/result000.00.csv").exists()
        && start.elapsed() < Duration::from_secs(10)
    {
        assert!(child.try_wait().unwrap().is_none(), "pipeline exited early");
        thread::sleep(Duration::from_millis(1));
    }
    assert!(
        root.join("output/result000.00.csv").exists(),
        "first prefix was not published"
    );
    assert!(
        Command::new("/bin/kill")
            .args(["-INT", &child.id().to_string()])
            .status()
            .unwrap()
            .success()
    );
    let output = child.wait_with_output().unwrap();
    assert_eq!(output.status.code(), Some(130));
    assert_eq!(report(&report_path)["outcome"], "cancelled");
    assert_eq!(
        fs::read(root.join("output/result000.00.csv")).unwrap(),
        b"id,name\n1,Ada\n"
    );
    assert!(!root.join("output/result001.00.csv").exists());
}

use std::{
    ffi::OsStr,
    fs,
    path::{Path, PathBuf},
    process::Command,
    sync::atomic::{AtomicUsize, Ordering},
};

static NEXT_DIRECTORY: AtomicUsize = AtomicUsize::new(0);

#[cfg(unix)]
#[test]
fn output_is_owner_only_even_with_permissive_umask() {
    use std::os::unix::fs::PermissionsExt;
    let directory = directory("permissions");
    let input = directory.join("input.txt");
    let output = directory.join("output.txt");
    fs::write(&input, b"private\n").unwrap();
    let result = Command::new("/bin/sh")
        .args(["-c", "umask 000; exec \"$@\"", "transfer-test"])
        .arg(env!("CARGO_BIN_EXE_emburk"))
        .arg("transfer-lines")
        .arg(&input)
        .arg(&output)
        .output()
        .unwrap();
    assert!(result.status.success());
    assert_eq!(
        fs::metadata(&output).unwrap().permissions().mode() & 0o777,
        0o600
    );
}

fn directory(name: &str) -> PathBuf {
    let unique = NEXT_DIRECTORY.fetch_add(1, Ordering::Relaxed);
    let path = std::env::temp_dir().join(format!(
        "emburk-file-transfer-{}-{}-{unique}",
        std::process::id(),
        name
    ));
    fs::create_dir(&path).unwrap();
    path
}

fn run(directory: &Path, arguments: &[&OsStr]) -> std::process::Output {
    Command::new(env!("CARGO_BIN_EXE_emburk"))
        .args(arguments)
        .current_dir(directory)
        .output()
        .unwrap()
}

#[test]
fn retains_development_status_and_exposes_help_and_argument_errors() {
    let directory = directory("arguments");
    let status = run(&directory, &[]);
    assert!(status.status.success());
    assert!(
        String::from_utf8_lossy(&status.stdout).contains("experimental text transfer available")
    );
    let help = run(&directory, &[OsStr::new("--help")]);
    assert!(help.status.success());
    assert!(String::from_utf8_lossy(&help.stdout).contains("transfer-lines INPUT OUTPUT"));
    let invalid = run(&directory, &[OsStr::new("transfer-lines")]);
    assert_eq!(invalid.status.code(), Some(2));
    let extra_help = run(&directory, &[OsStr::new("--help"), OsStr::new("extra")]);
    assert_eq!(extra_help.status.code(), Some(2));
}

#[test]
fn transfers_real_utf8_crlf_blank_and_unterminated_lines() {
    let directory = directory("normal");
    let input = directory.join("input.txt");
    let output = directory.join("output.txt");
    fs::write(&input, "hello\r\n🦀\n\nfinal").unwrap();
    let result = run(
        &directory,
        &[
            OsStr::new("transfer-lines"),
            input.as_os_str(),
            output.as_os_str(),
        ],
    );
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    assert_eq!(
        fs::read(&output).unwrap(),
        "hello\n🦀\n\nfinal\n".as_bytes()
    );
    assert!(String::from_utf8_lossy(&result.stdout).contains("4 records"));
}

#[test]
fn empty_input_produces_empty_output() {
    let directory = directory("empty");
    let input = directory.join("input.txt");
    let output = directory.join("output.txt");
    fs::write(&input, []).unwrap();
    let result = run(
        &directory,
        &[
            OsStr::new("transfer-lines"),
            input.as_os_str(),
            output.as_os_str(),
        ],
    );
    assert!(result.status.success());
    assert_eq!(fs::read(&output).unwrap(), b"");
    assert!(String::from_utf8_lossy(&result.stdout).contains("0 records"));
}

#[test]
fn rejects_missing_existing_and_same_targets_without_overwriting() {
    let directory = directory("targets");
    let missing = directory.join("missing.txt");
    let output = directory.join("output.txt");
    assert_eq!(
        run(
            &directory,
            &[
                OsStr::new("transfer-lines"),
                missing.as_os_str(),
                output.as_os_str()
            ]
        )
        .status
        .code(),
        Some(1)
    );
    assert!(!output.exists());
    let input = directory.join("input.txt");
    fs::write(&input, b"input\n").unwrap();
    fs::write(&output, b"original").unwrap();
    let existing = run(
        &directory,
        &[
            OsStr::new("transfer-lines"),
            input.as_os_str(),
            output.as_os_str(),
        ],
    );
    assert_eq!(existing.status.code(), Some(1));
    assert_eq!(fs::read(&output).unwrap(), b"original");
    let same = run(
        &directory,
        &[
            OsStr::new("transfer-lines"),
            input.as_os_str(),
            input.as_os_str(),
        ],
    );
    assert_eq!(same.status.code(), Some(1));
    assert_eq!(fs::read(&input).unwrap(), b"input\n");
    let directory_input = directory.join("directory-input");
    fs::create_dir(&directory_input).unwrap();
    let directory_output = directory.join("directory-output.txt");
    assert_eq!(
        run(
            &directory,
            &[
                OsStr::new("transfer-lines"),
                directory_input.as_os_str(),
                directory_output.as_os_str(),
            ],
        )
        .status
        .code(),
        Some(1)
    );
    assert!(!directory_output.exists());
}

#[cfg(unix)]
#[test]
fn rejects_an_existing_symlink_target() {
    use std::os::unix::fs::symlink;
    let directory = directory("symlink");
    let input = directory.join("input.txt");
    let target = directory.join("target.txt");
    let output = directory.join("output-link.txt");
    fs::write(&input, b"input\n").unwrap();
    fs::write(&target, b"original").unwrap();
    symlink(&target, &output).unwrap();
    let result = run(
        &directory,
        &[
            OsStr::new("transfer-lines"),
            input.as_os_str(),
            output.as_os_str(),
        ],
    );
    assert_eq!(result.status.code(), Some(1));
    assert_eq!(fs::read(&target).unwrap(), b"original");
}

#[test]
fn rejects_invalid_utf8_and_oversized_input() {
    let directory = directory("invalid");
    let invalid = directory.join("invalid.txt");
    let invalid_output = directory.join("invalid-output.txt");
    fs::write(&invalid, [0xff, b'\n']).unwrap();
    let result = run(
        &directory,
        &[
            OsStr::new("transfer-lines"),
            invalid.as_os_str(),
            invalid_output.as_os_str(),
        ],
    );
    assert_eq!(result.status.code(), Some(1));
    assert!(String::from_utf8_lossy(&result.stderr).contains("partially written"));
    let oversized = directory.join("oversized.txt");
    let oversized_output = directory.join("oversized-output.txt");
    fs::write(&oversized, vec![b'x'; 1024 * 1024 + 1]).unwrap();
    assert_eq!(
        run(
            &directory,
            &[
                OsStr::new("transfer-lines"),
                oversized.as_os_str(),
                oversized_output.as_os_str()
            ]
        )
        .status
        .code(),
        Some(1)
    );
}

use std::{
    fs,
    path::PathBuf,
    process::Command,
    sync::atomic::{AtomicUsize, Ordering},
};
static NEXT: AtomicUsize = AtomicUsize::new(0);
fn root() -> PathBuf {
    let p = std::env::temp_dir().join(format!(
        "emburk-guess-cli-{}-{}",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    fs::create_dir(&p).unwrap();
    fs::create_dir(p.join("output")).unwrap();
    p
}
fn seed(parser: &str) -> String {
    format!(
        "in:\n  type: file\n  path_prefix: input\n{parser}out:\n  type: file\n  path_prefix: output/result\n  file_ext: csv\n  formatter:\n    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    header_line: true\n    quote_policy: MINIMAL\nexec:\n  max_threads: 1\n  min_output_tasks: 1\n"
    )
}
fn run(root: &PathBuf, args: &[&str], success: bool) {
    let o = Command::new(env!("CARGO_BIN_EXE_emburk"))
        .args(args)
        .current_dir(root)
        .output()
        .unwrap();
    assert_eq!(
        o.status.success(),
        success,
        "{}",
        String::from_utf8_lossy(&o.stderr)
    );
}
#[test]
fn generated_csv_and_explicit_json_schema_execute() {
    for (data, parser, expected) in [
        (
            "account,label\n71,\n-3,Delta\n",
            "  parser:\n    columns:\n    - {name: account, type: long}\n    - {name: label, type: string}\n",
            "account,label\n71,\n-3,Delta\n",
        ),
        (
            "account,label\n71,Delta\n-3,Echo\n",
            "",
            "account,label\n71,Delta\n-3,Echo\n",
        ),
        (
            "{\"account\":71,\"label\":\"Delta\"}\n",
            "  parser:\n    columns:\n    - {name: account, type: long}\n    - {name: label, type: string}\n",
            "account,label\n71,Delta\n",
        ),
    ] {
        let p = root();
        fs::write(p.join("input"), data).unwrap();
        let seed = seed(parser);
        fs::write(p.join("seed.yml"), &seed).unwrap();
        run(&p, &["guess", "seed.yml", "-o", "config.yml"], true);
        run(&p, &["run", "config.yml"], true);
        assert_eq!(
            fs::read_to_string(p.join("output/result000.00.csv")).unwrap(),
            expected
        );
        assert_eq!(fs::read_to_string(p.join("seed.yml")).unwrap(), seed);
    }
}
#[test]
fn rejection_and_output_no_clobber() {
    for data in ["", "id\tname\n1\tAda\n", "1,Ada\n2,Bob\n"] {
        let p = root();
        fs::write(p.join("input"), data).unwrap();
        fs::write(p.join("seed.yml"), seed("")).unwrap();
        run(&p, &["guess", "seed.yml", "-o", "config.yml"], false);
        assert!(!p.join("config.yml").exists());
    }
    let p = root();
    fs::write(p.join("input"), "id,name\n1,Ada\n").unwrap();
    fs::write(p.join("seed.yml"), seed("")).unwrap();
    fs::write(p.join("config.yml"), "sentinel").unwrap();
    run(&p, &["guess", "seed.yml", "-o", "config.yml"], false);
    assert_eq!(
        fs::read_to_string(p.join("config.yml")).unwrap(),
        "sentinel"
    );
}
#[test]
fn oversize_explicit_conflicts_and_json_missing_schema_are_not_silently_fixed() {
    let p = root();
    fs::write(p.join("seed.yml"), seed("")).unwrap();
    fs::write(p.join("input"), vec![b'x'; 32769]).unwrap();
    run(&p, &["guess", "seed.yml", "-o", "config.yml"], false);
    fs::write(p.join("input"), "{\"id\":1}\n").unwrap();
    run(&p, &["guess", "seed.yml", "-o", "config.yml"], true);
    run(&p, &["run", "config.yml"], false);
    assert!(fs::read_dir(p.join("output")).unwrap().next().is_none());
    fs::write(
        p.join("seed.yml"),
        seed("  parser: {charset: ISO-8859-9}\n"),
    )
    .unwrap();
    run(&p, &["guess", "seed.yml"], false);
}

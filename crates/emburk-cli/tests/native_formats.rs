use std::{
    fs,
    path::PathBuf,
    process::{Command, Output},
    sync::atomic::{AtomicUsize, Ordering},
};
static NEXT: AtomicUsize = AtomicUsize::new(0);

fn config(filters: &str, decoder: &str, encoder: &str) -> String {
    format!(
        "in:\n  type: file\n  path_prefix: input\n{decoder}  parser:\n    type: json\n    columns:\n    - {{name: id, type: long}}\n    - {{name: name, type: string}}\n{filters}out:\n  type: file\n  path_prefix: output/result\n  file_ext: csv\n{encoder}  formatter:\n    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    header_line: true\n    quote_policy: MINIMAL\nexec:\n  max_threads: 1\n  min_output_tasks: 1\n"
    )
}
fn run(config: &str, input: &[u8]) -> (PathBuf, Output) {
    let root = std::env::temp_dir().join(format!(
        "emburk-native-formats-{}-{}",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    fs::create_dir(&root).unwrap();
    fs::create_dir(root.join("output")).unwrap();
    fs::write(root.join("config.yml"), config).unwrap();
    fs::write(root.join("input"), input).unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_emburk"))
        .args(["run", "config.yml"])
        .current_dir(&root)
        .output()
        .unwrap();
    (root, output)
}
#[test]
fn json_multiline_sequence_nulls_and_arbitrary_names_transfer() {
    let cfg = config("", "", "")
        .replace("name: id", "name: sequence")
        .replace("name: name", "name: label");
    let input = "{\n\"label\":\"a, \\\"quote\\\" ☃\",\"sequence\":-9223372036854775808\n}\n{\"sequence\":2,\"label\":\"\"} {\"sequence\":null}";
    let (root, result) = run(&cfg, input.as_bytes());
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    assert_eq!(
        fs::read_to_string(root.join("output/result000.00.csv")).unwrap(),
        "sequence,label\n-9223372036854775808,\"a, \"\"quote\"\" ☃\"\n2,\"\"\n,\n"
    );
}
#[test]
fn ordered_filters_preserve_positional_values_and_validate_before_output() {
    let filters = "filters:\n- type: rename\n  columns: {id: name, name: id}\n- type: remove_columns\n  remove: [name]\n";
    let (root, result) = run(&config(filters, "", ""), b"{\"id\":7,\"name\":\"Ada\"}");
    assert!(result.status.success());
    assert_eq!(
        fs::read(root.join("output/result000.00.csv")).unwrap(),
        b"id\nAda\n"
    );
    let invalid = "filters:\n- type: remove_columns\n  remove: [missing]\n";
    let (root, result) = run(&config(invalid, "", ""), b"not valid input");
    assert!(!result.status.success());
    assert!(String::from_utf8_lossy(&result.stderr).contains("remove column not found"));
    assert_eq!(fs::read_dir(root.join("output")).unwrap().count(), 0);
}
#[test]
fn invalid_json_and_corrupt_codecs_never_publish() {
    for input in [
        b"{\"id\":1}\n{".as_slice(),
        b"{\"id\":\"wrong type\"}",
        b"{\"name\":false}",
        b"{\"name\":\"\xff\"}",
        b"[]",
    ] {
        let (root, result) = run(&config("", "", ""), input);
        assert!(!result.status.success());
        assert_eq!(fs::read_dir(root.join("output")).unwrap().count(), 0);
    }
    for codec in ["gzip", "bzip2"] {
        let decoder = format!("  decoders:\n  - {{type: {codec}}}\n");
        let (root, result) = run(&config("", &decoder, ""), b"corrupted compressed bytes");
        assert!(!result.status.success());
        assert_eq!(fs::read_dir(root.join("output")).unwrap().count(), 0);
    }
}
#[test]
fn unsupported_profile_options_fail_before_output() {
    for cfg in [
        config("", "  decoders:\n  - {type: zip}\n", ""),
        config("", "", "  encoders:\n  - {type: gzip, level: 1}\n"),
        config("filters:\n- type: rename\n  rules: []\n", "", ""),
    ] {
        let (root, result) = run(&cfg, b"{\"id\":1}");
        assert!(!result.status.success());
        assert_eq!(fs::read_dir(root.join("output")).unwrap().count(), 0);
    }
}

#[test]
fn repeated_json_columns_cannot_expand_past_record_budget() {
    let cfg = config("", "", "").replace("{name: id, type: long}", "{name: name, type: string}");
    let input = format!("{{\"name\":\"{}\"}}", "x".repeat(700_000));
    let (root, result) = run(&cfg, input.as_bytes());
    assert!(!result.status.success());
    assert!(String::from_utf8_lossy(&result.stderr).contains("selected record exceeds"));
    assert_eq!(fs::read_dir(root.join("output")).unwrap().count(), 0);
}

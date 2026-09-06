use super::{Float64Bits, LogicalRecord, LogicalRecords, LogicalValue};

const HEADER: &str = "T0012-S10\t1";
const CASES: [(&str, usize); 2] = [("finite-null", 7), ("nonfinite", 5)];
const CAP: usize = 1024;
const MANIFEST_CAP: u64 = 65_536;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ReferenceValue {
    Null,
    Double(u64),
}

type ParsedCase = (String, LogicalRecords, Vec<Vec<ReferenceValue>>);

fn parse_count(text: &str, label: &str) -> Result<usize, String> {
    if text.is_empty()
        || !text.bytes().all(|byte| byte.is_ascii_digit())
        || (text.len() > 1 && text.starts_with('0'))
    {
        return Err(format!("malformed {label}"));
    }
    let value: usize = text.parse().map_err(|_| format!("malformed {label}"))?;
    if value > CAP {
        return Err(format!("{label} exceeds cap"));
    }
    Ok(value)
}

fn parse_cell(tag: &str, payload: &str) -> Result<LogicalValue, String> {
    match tag {
        "N" if payload == "-" => Ok(LogicalValue::Null),
        "N" => Err("null payload must be -".into()),
        "D" if payload.len() == 16
            && payload
                .bytes()
                .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte)) =>
        {
            let bits = u64::from_str_radix(payload, 16)
                .map_err(|_| "malformed double payload".to_owned())?;
            Ok(LogicalValue::Float64(Float64Bits::from_float(
                f64::from_bits(bits),
            )))
        }
        "D" => Err("malformed double payload".into()),
        _ => Err("unknown double value tag".into()),
    }
}

fn parse_reference(tag: &str, payload: &str) -> Result<ReferenceValue, String> {
    match tag {
        "N" if payload == "-" => Ok(ReferenceValue::Null),
        "N" => Err("null payload must be -".into()),
        "D" if payload.len() == 16
            && payload
                .bytes()
                .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte)) =>
        {
            Ok(ReferenceValue::Double(
                u64::from_str_radix(payload, 16)
                    .map_err(|_| "malformed double payload".to_owned())?,
            ))
        }
        "D" => Err("malformed double payload".into()),
        _ => Err("unknown double value tag".into()),
    }
}

fn parse_manifest(manifest: &str) -> Result<Vec<ParsedCase>, String> {
    if manifest.len() as u64 > MANIFEST_CAP {
        return Err("manifest exceeds cap".into());
    }
    if !manifest.ends_with('\n') || manifest.contains('\r') {
        return Err("manifest is not canonical TSV".into());
    }
    let mut lines = manifest.lines();
    if lines.next() != Some(HEADER) {
        return Err("unsupported manifest header".into());
    }
    let mut cases = Vec::new();
    for (expected_name, expected_rows) in CASES {
        let fields: Vec<_> = lines
            .next()
            .ok_or("missing case row")?
            .split('\t')
            .collect();
        if fields.len() != 4 || fields[0] != "CASE" || fields[1] != expected_name {
            return Err("case manifest is not exact and ordered".into());
        }
        let rows = parse_count(fields[2], "row count")?;
        let cells = parse_count(fields[3], "cell count")?;
        if rows != expected_rows || cells != 1 {
            return Err("unsupported selected dimensions".into());
        }
        let mut supplied = Vec::with_capacity(rows);
        let mut reference = Vec::with_capacity(rows);
        for row_index in 0..rows {
            let row: Vec<_> = lines.next().ok_or("truncated row")?.split('\t').collect();
            if row.as_slice() != ["ROW", &row_index.to_string()] {
                return Err("row order or index mismatch".into());
            }
            let cell: Vec<_> = lines.next().ok_or("truncated cell")?.split('\t').collect();
            if cell.len() != 6 || cell[0] != "CELL" || cell[1] != "0" {
                return Err("cell order or index mismatch".into());
            }
            supplied.push(LogicalRecord::new(vec![parse_cell(cell[2], cell[3])?]));
            reference.push(vec![parse_reference(cell[4], cell[5])?]);
        }
        cases.push((
            expected_name.to_owned(),
            LogicalRecords::new(supplied),
            reference,
        ));
    }
    if lines.next().is_some() {
        return Err("trailing manifest records".into());
    }
    Ok(cases)
}

fn compare(cases: &[ParsedCase]) -> Result<(), String> {
    for (name, supplied, reference) in cases {
        let matches = supplied.records().zip(reference).all(|(record, expected)| {
            record.cells().len() == expected.len()
                && record.cells().zip(expected).all(|(actual, wanted)| {
                    matches!((actual, wanted), (LogicalValue::Null, ReferenceValue::Null))
                        || matches!(
                            (actual, wanted),
                            (LogicalValue::Float64(value), ReferenceValue::Double(bits))
                                if value.bits() == *bits && value.to_float().to_bits() == *bits
                        )
                })
        });
        if !matches || supplied.records().len() != reference.len() {
            return Err(format!(
                "reference differs from private double storage for {name}"
            ));
        }
    }
    Ok(())
}

fn valid_manifest() -> String {
    let finite = [
        "7fefffffffffffff",
        "ffefffffffffffff",
        "0000000000000001",
        "8000000000000001",
        "0000000000000000",
        "8000000000000000",
        "-",
    ];
    let nonfinite = [
        "7ff0000000000000",
        "fff0000000000000",
        "7ff8000000000000",
        "7ff8000000000042",
        "fff8000000000042",
    ];
    let mut output = format!("{HEADER}\n");
    for (name, values) in [
        ("finite-null", finite.as_slice()),
        ("nonfinite", nonfinite.as_slice()),
    ] {
        output.push_str(&format!("CASE\t{name}\t{}\t1\n", values.len()));
        for (row, value) in values.iter().enumerate() {
            let tag = if *value == "-" { "N" } else { "D" };
            output.push_str(&format!(
                "ROW\t{row}\nCELL\t0\t{tag}\t{value}\t{tag}\t{value}\n"
            ));
        }
    }
    output
}

#[test]
fn stores_arbitrary_selected_bit_patterns_and_reconstructs_them() {
    let bits = [
        0,
        1,
        0x8000_0000_0000_0001,
        0xffef_ffff_ffff_ffff,
        0x8000_0000_0000_0000,
        0x7ff0_0000_0000_0000,
        0xfff0_0000_0000_0000,
        0x7ff8_0000_0000_0042,
        0xfff8_0000_0000_0042,
        0x7fef_ffff_ffff_ffff,
    ];
    for expected in bits {
        let stored = Float64Bits::from_float(f64::from_bits(expected));
        assert_eq!(stored.bits(), expected);
        assert_eq!(stored.to_float().to_bits(), expected);
    }
}

#[test]
fn structural_identity_is_bitwise_not_numeric_equality() {
    let positive_zero = Float64Bits::from_float(0.0);
    let negative_zero = Float64Bits::from_float(-0.0);
    assert_ne!(positive_zero, negative_zero);
    assert_eq!(positive_zero.to_float(), negative_zero.to_float());
    let nan = Float64Bits::from_float(f64::from_bits(0x7ff8_0000_0000_0042));
    assert_eq!(nan, nan);
    assert_ne!(nan.to_float(), nan.to_float());
}

#[test]
fn null_is_distinct_and_record_order_is_preserved() {
    let records = LogicalRecords::new(vec![
        LogicalRecord::new(vec![
            LogicalValue::Float64(Float64Bits::from_float(-0.0)),
            LogicalValue::Null,
        ]),
        LogicalRecord::new(vec![LogicalValue::Float64(Float64Bits::from_float(
            f64::INFINITY,
        ))]),
    ]);
    let values: Vec<Vec<_>> = records
        .records()
        .map(|record| record.cells().cloned().collect())
        .collect();
    assert_eq!(values.len(), 2);
    assert_eq!(
        values[0][0],
        LogicalValue::Float64(Float64Bits(0x8000_0000_0000_0000))
    );
    assert_eq!(values[0][1], LogicalValue::Null);
    assert_eq!(
        values[1][0],
        LogicalValue::Float64(Float64Bits(0x7ff0_0000_0000_0000))
    );
}

#[test]
fn comparison_rejects_missing_and_extra_actual_cells() {
    let reference = vec![vec![ReferenceValue::Double(0)]];
    for actual in [
        Vec::new(),
        vec![
            LogicalValue::Float64(Float64Bits(0)),
            LogicalValue::Float64(Float64Bits(1)),
        ],
    ] {
        let cases = vec![(
            "shape".to_owned(),
            LogicalRecords::new(vec![LogicalRecord::new(actual)]),
            reference.clone(),
        )];
        assert_eq!(
            compare(&cases),
            Err("reference differs from private double storage for shape".into())
        );
    }
}

#[test]
fn manifest_rejects_transport_and_value_errors() {
    let valid = valid_manifest();
    assert!(compare(&parse_manifest(&valid).unwrap()).is_ok());
    let rejects = |text: &str, diagnostic: &str| {
        assert_eq!(parse_manifest(text), Err(diagnostic.to_owned()));
    };
    rejects(valid.trim_end(), "manifest is not canonical TSV");
    rejects(
        &valid.replacen(HEADER, "T0012-S10\t2", 1),
        "unsupported manifest header",
    );
    rejects(
        &valid.replacen("CASE\tfinite-null", "CASE\tunknown", 1),
        "case manifest is not exact and ordered",
    );
    rejects(
        &valid.replacen("CASE\tnonfinite", "CASE\tfinite-null", 1),
        "case manifest is not exact and ordered",
    );
    rejects(
        &valid.replacen("CASE\tfinite-null", "CASE\tnonfinite", 1),
        "case manifest is not exact and ordered",
    );
    rejects(
        &valid.replacen("CASE\tfinite-null\t7\t1", "CASE\tfinite-null\t8\t1", 1),
        "unsupported selected dimensions",
    );
    rejects(
        &valid.replacen("CASE\tfinite-null\t7\t1", "CASE\tfinite-null\t01\t1", 1),
        "malformed row count",
    );
    rejects(
        &valid.replacen("CASE\tfinite-null\t7\t1", "CASE\tfinite-null\t1025\t1", 1),
        "row count exceeds cap",
    );
    rejects(
        &valid.replacen("ROW\t0", "ROW\t1", 1),
        "row order or index mismatch",
    );
    rejects(
        &valid.replacen("\tD\t7fefffffffffffff", "\tD\t7FEFFFFFFFFFFFFF", 1),
        "malformed double payload",
    );
    rejects(
        &valid.replacen("\tN\t-\tN\t-", "\tN\t0\tN\t-", 1),
        "null payload must be -",
    );
    rejects(
        &valid.replacen("\tD\t7fefffffffffffff", "\tX\t7fefffffffffffff", 1),
        "unknown double value tag",
    );
    rejects(
        &valid.replacen("7fefffffffffffff", "7feffffffffffff", 1),
        "malformed double payload",
    );
    rejects(&format!("{valid}ROW\t0\n"), "trailing manifest records");
    rejects(
        &"x".repeat(MANIFEST_CAP as usize + 1),
        "manifest exceeds cap",
    );
}

#[test]
fn expected_only_mutation_fails_without_changing_supplied_values() {
    let valid = valid_manifest();
    let changed = valid.replacen(
        "CELL\t0\tD\t0000000000000000\tD\t0000000000000000",
        "CELL\t0\tD\t0000000000000000\tD\t8000000000000000",
        1,
    );
    let baseline = parse_manifest(&valid).unwrap();
    let mutated = parse_manifest(&changed).unwrap();
    assert_eq!(mutated[0].1, baseline[0].1);
    assert!(compare(&mutated).is_err());
}

#[test]
#[ignore = "requires the external T-0012/S10 double-value driver"]
fn live_double_value_differential() {
    let path =
        std::env::var("T0012_S10_MANIFEST").expect("T0012_S10_MANIFEST must name driver output");
    let metadata = std::fs::metadata(&path).expect("stat S10 manifest");
    assert!(metadata.is_file() && metadata.len() <= MANIFEST_CAP);
    let manifest = std::fs::read_to_string(path).expect("read S10 manifest");
    compare(&parse_manifest(&manifest).expect("validate S10 manifest"))
        .expect("selected doubles must match private storage");
}

//! Private owned logical record values with no schema or physical encoding policy.

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) struct Float64Bits(u64);

impl Float64Bits {
    pub(super) fn from_float(value: f64) -> Self {
        Self(value.to_bits())
    }

    pub(super) fn to_float(self) -> f64 {
        f64::from_bits(self.0)
    }

    pub(super) fn bits(self) -> u64 {
        self.0
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) enum LogicalValue {
    Null,
    Boolean(bool),
    Signed64(i64),
    Text(String),
    Float64(Float64Bits),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct LogicalRecord {
    cells: Vec<LogicalValue>,
}

impl LogicalRecord {
    pub(super) fn new(cells: Vec<LogicalValue>) -> Self {
        Self { cells }
    }

    pub(super) fn cells(&self) -> impl ExactSizeIterator<Item = &LogicalValue> {
        self.cells.iter()
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct LogicalRecords {
    records: Vec<LogicalRecord>,
}

impl LogicalRecords {
    fn new(records: Vec<LogicalRecord>) -> Self {
        Self { records }
    }

    fn records(&self) -> impl ExactSizeIterator<Item = &LogicalRecord> {
        self.records.iter()
    }
}

#[cfg(test)]
const HEADER: &str = "T0012-S08\t1";
#[cfg(test)]
const CAP: usize = 1024;
#[cfg(test)]
const CASES: [&str; 2] = ["empty", "typed-null"];

#[cfg(test)]
fn parse_count(value: &str, label: &str) -> Result<usize, String> {
    if value.is_empty()
        || !value.bytes().all(|byte| byte.is_ascii_digit())
        || (value.len() > 1 && value.starts_with('0'))
    {
        return Err(format!("malformed {label}"));
    }
    value.parse().map_err(|_| format!("malformed {label}"))
}

#[cfg(test)]
fn parse_value(tag: &str, payload: &str) -> Result<LogicalValue, String> {
    match tag {
        "N" if payload == "-" => Ok(LogicalValue::Null),
        "B" if matches!(payload, "true" | "false") => Ok(LogicalValue::Boolean(payload == "true")),
        "L" => {
            let value: i64 = payload.parse().map_err(|_| "malformed signed64 payload")?;
            if value.to_string() != payload {
                return Err("noncanonical signed64 payload".into());
            }
            Ok(LogicalValue::Signed64(value))
        }
        "S" => Ok(LogicalValue::Text(decode_hex(payload)?)),
        "N" => Err("null payload must be -".into()),
        "B" => Err("malformed boolean payload".into()),
        _ => Err("unknown value tag".into()),
    }
}

#[cfg(test)]
fn decode_hex(value: &str) -> Result<String, String> {
    if !value
        .bytes()
        .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
        || !value.len().is_multiple_of(2)
    {
        return Err("malformed lowercase hex payload".into());
    }
    let mut bytes = Vec::with_capacity(value.len() / 2);
    for pair in value.as_bytes().as_chunks::<2>().0 {
        let nibble = |byte| match byte {
            b'0'..=b'9' => Ok(byte - b'0'),
            b'a'..=b'f' => Ok(byte - b'a' + 10),
            _ => Err("malformed lowercase hex payload"),
        };
        bytes.push(nibble(pair[0])? << 4 | nibble(pair[1])?);
    }
    String::from_utf8(bytes).map_err(|_| "non-UTF-8 text payload".into())
}

#[cfg(test)]
type ParsedCase = (String, LogicalRecords, LogicalRecords);

#[cfg(test)]
fn parse_live_tsv(tsv: &str) -> Result<Vec<ParsedCase>, String> {
    if !tsv.ends_with('\n') || tsv.contains('\r') {
        return Err("manifest is not canonical TSV".into());
    }
    let mut lines = tsv.lines();
    if lines.next() != Some(HEADER) {
        return Err("unsupported manifest header".into());
    }
    let mut cases = Vec::new();
    for expected_case in CASES {
        let fields: Vec<_> = lines
            .next()
            .ok_or("missing case row")?
            .split('\t')
            .collect();
        if fields.len() != 4 || fields[0] != "CASE" || fields[1] != expected_case {
            return Err("case manifest is not exact and ordered".into());
        }
        let row_count = parse_count(fields[2], "row count")?;
        let cells_per_row = parse_count(fields[3], "cells per row")?;
        if row_count > CAP
            || cells_per_row > CAP
            || cells_per_row != 3
            || (expected_case == "empty" && row_count != 0)
            || (expected_case == "typed-null" && row_count != 3)
        {
            return Err("unsupported selected dimensions".into());
        }
        let mut input_records = Vec::with_capacity(row_count);
        let mut expected_records = Vec::with_capacity(row_count);
        for row_index in 0..row_count {
            let row: Vec<_> = lines.next().ok_or("truncated row")?.split('\t').collect();
            if row.len() != 2 || row[0] != "ROW" || row[1] != row_index.to_string() {
                return Err("row order or index mismatch".into());
            }
            let mut input = Vec::with_capacity(cells_per_row);
            let mut expected = Vec::with_capacity(cells_per_row);
            for cell_index in 0..cells_per_row {
                let cell: Vec<_> = lines.next().ok_or("truncated cell")?.split('\t').collect();
                if cell.len() != 6 || cell[0] != "CELL" || cell[1] != cell_index.to_string() {
                    return Err("cell order or index mismatch".into());
                }
                input.push(parse_value(cell[2], cell[3])?);
                expected.push(parse_value(cell[4], cell[5])?);
            }
            input_records.push(LogicalRecord::new(input));
            expected_records.push(LogicalRecord::new(expected));
        }
        cases.push((
            expected_case.to_owned(),
            LogicalRecords::new(input_records),
            LogicalRecords::new(expected_records),
        ));
    }
    if lines.next().is_some() || cases.len() != CASES.len() {
        return Err("trailing or missing case records".into());
    }
    Ok(cases)
}

#[cfg(test)]
fn compare_cases(cases: &[ParsedCase]) -> Result<(), String> {
    for (name, actual, expected) in cases {
        let actual_cells: Vec<_> = actual
            .records()
            .map(|record| record.cells().cloned().collect::<Vec<_>>())
            .collect();
        let expected_cells: Vec<_> = expected
            .records()
            .map(|record| record.cells().cloned().collect::<Vec<_>>())
            .collect();
        if actual_cells != expected_cells {
            return Err(format!(
                "oracle differs from private record storage for {name}"
            ));
        }
    }
    Ok(())
}

#[cfg(test)]
fn assert_live_tsv(tsv: &str) -> Result<(), String> {
    compare_cases(&parse_live_tsv(tsv)?)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cell(
        index: usize,
        input_tag: &str,
        input: &str,
        reference_tag: &str,
        reference: &str,
    ) -> String {
        format!("CELL\t{index}\t{input_tag}\t{input}\t{reference_tag}\t{reference}")
    }

    fn valid_tsv() -> String {
        let rows = [
            vec![
                cell(0, "B", "true", "B", "true"),
                cell(1, "L", "9223372036854775807", "L", "9223372036854775807"),
                cell(2, "S", "", "S", ""),
            ],
            vec![
                cell(0, "B", "false", "B", "false"),
                cell(1, "L", "-9223372036854775808", "L", "-9223372036854775808"),
                cell(2, "S", "417c420acebb", "S", "417c420acebb"),
            ],
            vec![
                cell(0, "N", "-", "N", "-"),
                cell(1, "N", "-", "N", "-"),
                cell(2, "N", "-", "N", "-"),
            ],
        ];
        let mut output = format!("{HEADER}\nCASE\tempty\t0\t3\nCASE\ttyped-null\t3\t3\n");
        for (index, cells) in rows.iter().enumerate() {
            output.push_str(&format!("ROW\t{index}\n{}\n", cells.join("\n")));
        }
        output
    }

    #[test]
    fn preserves_order_nulls_bounds_and_owned_text() {
        let mut text = String::from("crab 🦀\n");
        let records = LogicalRecords::new(vec![LogicalRecord::new(vec![
            LogicalValue::Null,
            LogicalValue::Boolean(false),
            LogicalValue::Signed64(i64::MIN),
            LogicalValue::Text(text.clone()),
            LogicalValue::Signed64(i64::MAX),
            LogicalValue::Signed64(0),
            LogicalValue::Text(String::new()),
        ])]);
        text.push_str("changed outside record");
        assert_eq!(records.records().len(), 1);
        assert_eq!(records.records().next().unwrap().cells().count(), 7);
        assert_eq!(
            records.records().next().unwrap().cells().nth(3),
            Some(&LogicalValue::Text("crab 🦀\n".into()))
        );
        assert_eq!(
            records
                .records()
                .next()
                .unwrap()
                .cells()
                .cloned()
                .collect::<Vec<_>>(),
            vec![
                LogicalValue::Null,
                LogicalValue::Boolean(false),
                LogicalValue::Signed64(i64::MIN),
                LogicalValue::Text("crab 🦀\n".into()),
                LogicalValue::Signed64(i64::MAX),
                LogicalValue::Signed64(0),
                LogicalValue::Text(String::new()),
            ]
        );
    }

    #[test]
    fn preserves_empty_record_and_record_stream() {
        let empty_stream = LogicalRecords::new(Vec::new());
        assert_eq!(empty_stream.records().len(), 0);
        let records = LogicalRecords::new(vec![LogicalRecord::new(Vec::new())]);
        assert_eq!(records.records().len(), 1);
        assert_eq!(records.records().next().unwrap().cells().len(), 0);
    }

    #[test]
    fn live_tsv_bridge_stores_every_selected_row_and_cell() {
        let valid = valid_tsv();
        assert!(assert_live_tsv(&valid).is_ok());
        let cases = parse_live_tsv(&valid).unwrap();
        assert_eq!(cases[0].0, "empty");
        assert_eq!(cases[0].1.records().len(), 0);
        assert_eq!(cases[0].2.records().len(), 0);
        assert_eq!(cases[1].0, "typed-null");
        let actual: Vec<Vec<_>> = cases[1]
            .1
            .records()
            .map(|record| record.cells().cloned().collect())
            .collect();
        assert_eq!(
            actual,
            vec![
                vec![
                    LogicalValue::Boolean(true),
                    LogicalValue::Signed64(i64::MAX),
                    LogicalValue::Text(String::new()),
                ],
                vec![
                    LogicalValue::Boolean(false),
                    LogicalValue::Signed64(i64::MIN),
                    LogicalValue::Text("A|B\nλ".into()),
                ],
                vec![LogicalValue::Null, LogicalValue::Null, LogicalValue::Null],
            ]
        );
    }

    fn rejects(tsv: String, diagnostic: &str) {
        assert_eq!(assert_live_tsv(&tsv), Err(diagnostic.into()), "{tsv}");
    }

    #[test]
    fn live_tsv_bridge_rejects_header_case_dimension_and_order_errors() {
        let valid = valid_tsv();
        rejects(
            valid.replacen(HEADER, "T0012-S08\t2", 1),
            "unsupported manifest header",
        );
        rejects(valid.trim_end().into(), "manifest is not canonical TSV");
        rejects(valid.replace('\n', "\r\n"), "manifest is not canonical TSV");
        rejects(
            valid.replacen("CASE\tempty", "BROKEN\tempty", 1),
            "case manifest is not exact and ordered",
        );
        rejects(
            valid.replacen("CASE\tempty", "CASE\tunknown", 1),
            "case manifest is not exact and ordered",
        );
        rejects(
            valid.replacen("CASE\ttyped-null", "CASE\tempty", 1),
            "case manifest is not exact and ordered",
        );
        rejects(
            valid.replacen("CASE\ttyped-null\t3\t3\n", "", 1),
            "case manifest is not exact and ordered",
        );
        let reordered = valid.replacen(
            "CASE\tempty\t0\t3\nCASE\ttyped-null\t3\t3",
            "CASE\ttyped-null\t0\t3\nCASE\tempty\t3\t3",
            1,
        );
        rejects(reordered, "case manifest is not exact and ordered");
        for replacement in ["01", "x", "1025"] {
            let diagnostic = if replacement == "1025" {
                "unsupported selected dimensions"
            } else {
                "malformed row count"
            };
            rejects(
                valid.replacen(
                    "CASE\tempty\t0\t3",
                    &format!("CASE\tempty\t{replacement}\t3"),
                    1,
                ),
                diagnostic,
            );
        }
        rejects(
            valid.replacen("CASE\tempty\t0\t3", "CASE\tempty\t0\t1025", 1),
            "unsupported selected dimensions",
        );
        rejects(
            valid.replacen("CASE\ttyped-null\t3\t3", "CASE\ttyped-null\t2\t3", 1),
            "unsupported selected dimensions",
        );
        rejects(
            valid.replacen("CASE\ttyped-null\t3\t3", "CASE\ttyped-null\t3\t2", 1),
            "unsupported selected dimensions",
        );
        rejects(
            valid.replacen("ROW\t0", "ROW\t1", 1),
            "row order or index mismatch",
        );
        rejects(
            valid.replacen("ROW\t0", "ROW\t0\textra", 1),
            "row order or index mismatch",
        );
        rejects(
            valid.replacen("CELL\t0", "CELL\t1", 1),
            "cell order or index mismatch",
        );
        rejects(
            valid.replacen("CELL\t0", "CELL\t0\textra", 1),
            "cell order or index mismatch",
        );
        rejects(
            format!("{valid}ROW\t0\n"),
            "trailing or missing case records",
        );
        rejects(
            valid.replacen("CELL\t2\tN\t-\tN\t-\n", "", 1),
            "truncated cell",
        );
    }

    #[test]
    fn live_tsv_bridge_rejects_type_payload_and_text_errors() {
        let valid = valid_tsv();
        rejects(
            valid.replacen("\tB\ttrue\tB\ttrue", "\tB\tTRUE\tB\ttrue", 1),
            "malformed boolean payload",
        );
        rejects(
            valid.replacen("\tB\ttrue\tB\ttrue", "\tX\ttrue\tB\ttrue", 1),
            "unknown value tag",
        );
        rejects(
            valid.replacen("\tB\ttrue\tB\ttrue", "\tB\ttrue\tL\ttrue", 1),
            "malformed signed64 payload",
        );
        rejects(
            valid.replacen("9223372036854775807", "01", 1),
            "noncanonical signed64 payload",
        );
        rejects(
            valid.replacen("9223372036854775807", "9223372036854775808", 1),
            "malformed signed64 payload",
        );
        rejects(
            valid.replacen("417c420acebb", "417C420acebb", 1),
            "malformed lowercase hex payload",
        );
        rejects(
            valid.replacen("417c420acebb", "f", 1),
            "malformed lowercase hex payload",
        );
        rejects(
            valid.replacen("417c420acebb", "ff", 1),
            "non-UTF-8 text payload",
        );
        rejects(
            valid.replacen("\tN\t-\tN\t-", "\tN\tempty\tN\t-", 1),
            "null payload must be -",
        );
        rejects(
            valid.replacen("\tN\t-\tN\t-", "\tS\t-\tN\t-", 1),
            "malformed lowercase hex payload",
        );
    }

    #[test]
    fn expected_only_mutation_fails_comparison_without_changing_inputs() {
        let valid = valid_tsv();
        let changed_reference =
            valid.replacen("CELL\t0\tB\ttrue\tB\ttrue", "CELL\t0\tB\ttrue\tB\tfalse", 1);
        let baseline = parse_live_tsv(&valid).unwrap();
        let cases = parse_live_tsv(&changed_reference).unwrap();
        assert_eq!(cases[1].1, baseline[1].1);
        assert_eq!(
            compare_cases(&cases),
            Err("oracle differs from private record storage for typed-null".into())
        );
    }

    #[test]
    #[ignore = "requires the external T-0012/S08 oracle driver"]
    fn live_page_value_differential() {
        let path = std::env::var("T0012_S08_MANIFEST")
            .expect("T0012_S08_MANIFEST must name driver output");
        assert_live_tsv(&std::fs::read_to_string(path).expect("read manifest"))
            .expect("live manifest must match private records");
    }
}

#[cfg(test)]
mod double_tests;

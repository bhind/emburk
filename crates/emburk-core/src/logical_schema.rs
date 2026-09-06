//! Private, ordered logical schema storage with no physical encoding policy.

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum LogicalType {
    Boolean,
    Signed64,
    Float64,
    Text,
    Timestamp,
    Json,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct LogicalColumn {
    name: String,
    logical_type: LogicalType,
}

impl LogicalColumn {
    pub(super) fn new(name: impl Into<String>, logical_type: LogicalType) -> Self {
        Self {
            name: name.into(),
            logical_type,
        }
    }

    pub(super) fn name(&self) -> &str {
        &self.name
    }

    pub(super) fn logical_type(&self) -> LogicalType {
        self.logical_type
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct LogicalSchema {
    columns: Vec<LogicalColumn>,
}

impl LogicalSchema {
    pub(super) fn new(columns: Vec<LogicalColumn>) -> Self {
        Self { columns }
    }

    pub(super) fn columns(&self) -> impl ExactSizeIterator<Item = &LogicalColumn> {
        self.columns.iter()
    }
}

// The bridge is deliberately test-only. Its driver obtains actual schema rows
// from S05, while this module supplies only the private representation.
#[cfg(test)]
fn assert_live_tsv(tsv: &str) -> Result<(), String> {
    const CASES: [&str; 3] = ["empty", "ordered6types", "duplicate-name-differing-types"];
    let mut lines = tsv.lines();
    if lines.next() != Some("T0012-S06\t1") {
        return Err("unsupported TSV header".into());
    }
    let mut seen = std::collections::BTreeSet::new();
    while let Some(case_line) = lines.next() {
        let fields: Vec<_> = case_line.split('\t').collect();
        if fields.len() != 3 || fields[0] != "CASE" {
            return Err("missing case boundary".into());
        }
        let case = fields[1];
        if !CASES.contains(&case) || !seen.insert(case.to_owned()) {
            return Err("unknown or duplicate case".into());
        }
        let count: usize = fields[2].parse().map_err(|_| "malformed case count")?;
        if count > lines.clone().count() {
            return Err("case count exceeds remaining rows".into());
        }
        let mut input = Vec::with_capacity(count);
        let mut expected = Vec::with_capacity(count);
        for index in 0..count {
            let row = lines.next().ok_or("truncated case rows")?;
            let row: Vec<_> = row.split('\t').collect();
            if row.len() != 6 || row[0] != "FIELD" || row[1] != index.to_string() {
                return Err("malformed field row".into());
            }
            input.push(LogicalColumn::new(
                decode_hex_string(row[2])?,
                parse_type(row[3])?,
            ));
            expected.push(LogicalColumn::new(
                decode_hex_string(row[4])?,
                parse_type(row[5])?,
            ));
        }
        let schema = LogicalSchema::new(input.clone());
        let actual: Vec<_> = schema.columns().cloned().collect();
        if actual != input {
            return Err("private schema did not preserve input columns".into());
        }
        if actual != expected {
            return Err(format!("oracle differs from private schema for {case}"));
        }
    }
    if seen.len() != CASES.len() || !CASES.iter().all(|case| seen.contains(*case)) {
        return Err("TSV case manifest is not exact".into());
    }
    Ok(())
}

#[cfg(test)]
fn parse_type(value: &str) -> Result<LogicalType, String> {
    match value {
        "boolean" => Ok(LogicalType::Boolean),
        "signed64" => Ok(LogicalType::Signed64),
        "float64" => Ok(LogicalType::Float64),
        "text" => Ok(LogicalType::Text),
        "timestamp" => Ok(LogicalType::Timestamp),
        "json" => Ok(LogicalType::Json),
        _ => Err("unknown logical type".into()),
    }
}

#[cfg(test)]
fn decode_hex_string(value: &str) -> Result<String, String> {
    let bytes = value.as_bytes();
    if !bytes.len().is_multiple_of(2) {
        return Err("malformed hex".into());
    }
    let (pairs, remainder) = bytes.as_chunks::<2>();
    debug_assert!(remainder.is_empty());
    let mut decoded = Vec::with_capacity(pairs.len());
    for pair in pairs {
        decoded.push(hex_nibble(pair[0])? << 4 | hex_nibble(pair[1])?);
    }
    String::from_utf8(decoded).map_err(|_| "non-UTF-8 hex string".into())
}

#[cfg(test)]
fn hex_nibble(value: u8) -> Result<u8, String> {
    match value {
        b'0'..=b'9' => Ok(value - b'0'),
        b'a'..=b'f' => Ok(value - b'a' + 10),
        b'A'..=b'F' => Ok(value - b'A' + 10),
        _ => Err("malformed hex".into()),
    }
}

#[cfg(test)]
mod tests {
    use super::{LogicalColumn, LogicalSchema, LogicalType};

    #[test]
    fn preserves_empty_schema() {
        assert_eq!(LogicalSchema::new(vec![]).columns().len(), 0);
    }

    #[test]
    fn preserves_six_ordered_logical_types() {
        let columns = vec![
            LogicalColumn::new("boolean_column", LogicalType::Boolean),
            LogicalColumn::new("long_column", LogicalType::Signed64),
            LogicalColumn::new("double_column", LogicalType::Float64),
            LogicalColumn::new("string_column", LogicalType::Text),
            LogicalColumn::new("timestamp_column", LogicalType::Timestamp),
            LogicalColumn::new("json_column", LogicalType::Json),
        ];
        assert_eq!(
            LogicalSchema::new(columns.clone())
                .columns()
                .cloned()
                .collect::<Vec<_>>(),
            columns
        );
    }

    #[test]
    fn preserves_duplicate_names_at_distinct_positions() {
        let columns = vec![
            LogicalColumn::new("duplicate", LogicalType::Boolean),
            LogicalColumn::new("duplicate", LogicalType::Text),
        ];
        assert_eq!(
            LogicalSchema::new(columns.clone())
                .columns()
                .cloned()
                .collect::<Vec<_>>(),
            columns
        );
    }

    #[test]
    fn owns_arbitrary_utf8_names() {
        let mut name = String::from("crab 🦀\n");
        let schema = LogicalSchema::new(vec![LogicalColumn::new(name.clone(), LogicalType::Json)]);
        name.push_str("changed outside schema");
        assert_eq!(schema.columns().next().unwrap().name, "crab 🦀\n");
    }

    fn field(
        index: usize,
        input_name: &str,
        input_type: &str,
        expected_name: &str,
        expected_type: &str,
    ) -> String {
        format!(
            "FIELD\t{index}\t{}\t{input_type}\t{}\t{expected_type}",
            input_name
                .as_bytes()
                .iter()
                .map(|byte| format!("{byte:02x}"))
                .collect::<String>(),
            expected_name
                .as_bytes()
                .iter()
                .map(|byte| format!("{byte:02x}"))
                .collect::<String>()
        )
    }

    fn valid_tsv() -> String {
        let empty = "CASE\tempty\t0".to_owned();
        let ordered = [
            ("boolean_column", "boolean"),
            ("long_column", "signed64"),
            ("double_column", "float64"),
            ("string_column", "text"),
            ("timestamp_column", "timestamp"),
            ("json_column", "json"),
        ];
        let duplicate = [("duplicate", "boolean"), ("duplicate", "text")];
        let ordered_rows = ordered
            .iter()
            .enumerate()
            .map(|(i, (name, kind))| field(i, name, kind, name, kind))
            .collect::<Vec<_>>();
        let duplicate_rows = duplicate
            .iter()
            .enumerate()
            .map(|(i, (name, kind))| field(i, name, kind, name, kind))
            .collect::<Vec<_>>();
        format!(
            "T0012-S06\t1\n{empty}\nCASE\tordered6types\t6\n{}\nCASE\tduplicate-name-differing-types\t2\n{}\n",
            ordered_rows.join("\n"),
            duplicate_rows.join("\n")
        )
    }

    #[test]
    fn live_tsv_bridge_rejects_invalid_or_mutated_evidence() {
        let valid = valid_tsv();
        assert!(super::assert_live_tsv(&valid).is_ok());
        for bad in [
            valid.replacen("CASE\tempty\t0", "CASE\tempty\t1", 1),
            valid.replacen("CASE\tempty\t0", "CASE\tunknown\t0", 1),
            valid.replacen(
                "\tboolean\t626f6f6c65616e5f636f6c756d6e\tboolean",
                "\tunknown\t626f6f6c65616e5f636f6c756d6e\tboolean",
                1,
            ),
            valid.replacen("626f6f6c65616e5f636f6c756d6e", "zz", 1),
            valid.replacen("FIELD\t0", "FIELD\t1", 1),
            valid.replacen("CASE\tempty\t0\n", "", 1),
            valid.replacen("CASE\tordered6types\t6", "CASE\tordered6types\t5", 1),
            valid.replacen("CASE\tempty\t0", "CASE\tempty\t999999999", 1),
            format!("{valid}CASE\tempty\t0\n"),
            valid.replacen("626f6f6c65616e5f636f6c756d6e", "ff", 1),
            valid.replacen(
                "\t626f6f6c65616e5f636f6c756d6e\tboolean\n",
                "\t626f6f6c65616e5f636f6c756d6e\tunknown\n",
                1,
            ),
        ] {
            assert!(super::assert_live_tsv(&bad).is_err(), "{bad}");
        }
        let original_field = valid
            .lines()
            .find(|line| line.starts_with("FIELD\t0\t"))
            .unwrap();
        let original_parts: Vec<_> = original_field.split('\t').collect();
        let input_before = (original_parts[2], original_parts[3]);
        let mutated_expected = valid
            .lines()
            .map(|line| {
                if line == original_field {
                    let mut parts: Vec<_> = line.split('\t').collect();
                    parts[4] = "6368616e676564";
                    parts.join("\t")
                } else {
                    line.to_owned()
                }
            })
            .collect::<Vec<_>>()
            .join("\n")
            + "\n";
        let mutated_field = mutated_expected
            .lines()
            .find(|line| line.starts_with("FIELD\t0\t"))
            .unwrap();
        let mutated_parts: Vec<_> = mutated_field.split('\t').collect();
        assert_eq!(input_before, (mutated_parts[2], mutated_parts[3]));
        assert!(super::assert_live_tsv(&mutated_expected).is_err());
        assert!(
            super::assert_live_tsv(&valid).is_ok(),
            "expected-only mutation changed input state"
        );
    }

    #[test]
    #[ignore = "requires the external T-0012/S05 oracle driver"]
    fn live_schema_differential() {
        let path = std::env::var("T0012_S06_TSV").expect("T0012_S06_TSV must name driver output");
        let tsv = std::fs::read_to_string(path).expect("read driver TSV");
        super::assert_live_tsv(&tsv).expect("validate and compare live schema TSV");
    }
}

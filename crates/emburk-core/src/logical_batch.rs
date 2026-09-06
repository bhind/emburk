//! Private positional admission of accepted logical schema and record values.
//!
//! This has no physical encoding, source policy, public API, or lifecycle role.

use crate::{
    logical_record::{LogicalRecord, LogicalValue},
    logical_schema::{LogicalSchema, LogicalType},
};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum LogicalValueCategory {
    Null,
    Boolean,
    Signed64,
    Float64,
    Text,
}

impl LogicalValue {
    fn category(&self) -> LogicalValueCategory {
        match self {
            Self::Null => LogicalValueCategory::Null,
            Self::Boolean(_) => LogicalValueCategory::Boolean,
            Self::Signed64(_) => LogicalValueCategory::Signed64,
            Self::Float64(_) => LogicalValueCategory::Float64,
            Self::Text(_) => LogicalValueCategory::Text,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum LogicalBatchError {
    UnsupportedSchemaType {
        column_index: usize,
        actual: LogicalType,
    },
    RowWidth {
        row_index: usize,
        expected: usize,
        actual: usize,
    },
    CellType {
        row_index: usize,
        column_index: usize,
        expected: LogicalType,
        actual: LogicalValueCategory,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct LogicalBatch {
    schema: LogicalSchema,
    rows: Vec<LogicalRecord>,
}

impl LogicalBatch {
    fn try_new(schema: LogicalSchema, rows: Vec<LogicalRecord>) -> Result<Self, LogicalBatchError> {
        for (column_index, column) in schema.columns().enumerate() {
            if matches!(
                column.logical_type(),
                LogicalType::Timestamp | LogicalType::Json
            ) {
                return Err(LogicalBatchError::UnsupportedSchemaType {
                    column_index,
                    actual: column.logical_type(),
                });
            }
        }

        let expected = schema.columns().len();
        for (row_index, row) in rows.iter().enumerate() {
            let actual = row.cells().len();
            if actual != expected {
                return Err(LogicalBatchError::RowWidth {
                    row_index,
                    expected,
                    actual,
                });
            }
        }

        for (row_index, row) in rows.iter().enumerate() {
            for (column_index, (column, cell)) in schema.columns().zip(row.cells()).enumerate() {
                let actual = cell.category();
                if actual != LogicalValueCategory::Null
                    && !matches_type(column.logical_type(), actual)
                {
                    return Err(LogicalBatchError::CellType {
                        row_index,
                        column_index,
                        expected: column.logical_type(),
                        actual,
                    });
                }
            }
        }

        Ok(Self { schema, rows })
    }

    fn schema(&self) -> &LogicalSchema {
        &self.schema
    }

    fn rows(&self) -> impl ExactSizeIterator<Item = &LogicalRecord> {
        self.rows.iter()
    }
}

fn matches_type(expected: LogicalType, actual: LogicalValueCategory) -> bool {
    matches!(
        (expected, actual),
        (LogicalType::Boolean, LogicalValueCategory::Boolean)
            | (LogicalType::Signed64, LogicalValueCategory::Signed64)
            | (LogicalType::Float64, LogicalValueCategory::Float64)
            | (LogicalType::Text, LogicalValueCategory::Text)
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        logical_record::Float64Bits,
        logical_schema::{LogicalColumn, LogicalType},
    };

    fn schema(types: &[LogicalType]) -> LogicalSchema {
        LogicalSchema::new(
            types
                .iter()
                .enumerate()
                .map(|(index, kind)| LogicalColumn::new(format!("column-{index}"), *kind))
                .collect(),
        )
    }

    fn row(cells: Vec<LogicalValue>) -> LogicalRecord {
        LogicalRecord::new(cells)
    }

    fn sample(kind: LogicalType) -> LogicalValue {
        match kind {
            LogicalType::Boolean => LogicalValue::Boolean(true),
            LogicalType::Signed64 => LogicalValue::Signed64(37),
            LogicalType::Float64 => LogicalValue::Float64(Float64Bits::from_float(-0.0)),
            LogicalType::Text => LogicalValue::Text("owned 🦀 text".to_owned()),
            LogicalType::Timestamp | LogicalType::Json => LogicalValue::Null,
        }
    }

    #[test]
    fn admits_exact_selected_matching_and_null_rows_without_reencoding() {
        let mut source_text = "A|B".to_owned();
        let schema = LogicalSchema::new(vec![
            LogicalColumn::new("flag", LogicalType::Boolean),
            LogicalColumn::new("number", LogicalType::Signed64),
            LogicalColumn::new("ratio", LogicalType::Float64),
            LogicalColumn::new("text", LogicalType::Text),
        ]);
        let batch = LogicalBatch::try_new(
            schema,
            vec![
                row(vec![
                    LogicalValue::Boolean(true),
                    LogicalValue::Signed64(37),
                    LogicalValue::Float64(Float64Bits::from_float(-0.0)),
                    LogicalValue::Text(source_text.clone()),
                ]),
                row(vec![
                    LogicalValue::Null,
                    LogicalValue::Null,
                    LogicalValue::Null,
                    LogicalValue::Null,
                ]),
            ],
        )
        .expect("selected schema/value rows admit");
        source_text.clear();

        let columns: Vec<_> = batch.schema().columns().collect();
        assert_eq!(
            columns
                .iter()
                .map(|column| (column.name(), column.logical_type()))
                .collect::<Vec<_>>(),
            vec![
                ("flag", LogicalType::Boolean),
                ("number", LogicalType::Signed64),
                ("ratio", LogicalType::Float64),
                ("text", LogicalType::Text),
            ]
        );
        let rows: Vec<_> = batch.rows().collect();
        assert_eq!(
            rows.iter()
                .map(|row| row.cells().cloned().collect::<Vec<_>>())
                .collect::<Vec<_>>(),
            vec![
                vec![
                    LogicalValue::Boolean(true),
                    LogicalValue::Signed64(37),
                    LogicalValue::Float64(Float64Bits::from_float(-0.0)),
                    LogicalValue::Text("A|B".to_owned()),
                ],
                vec![
                    LogicalValue::Null,
                    LogicalValue::Null,
                    LogicalValue::Null,
                    LogicalValue::Null,
                ],
            ]
        );
        match rows[0].cells().nth(2) {
            Some(LogicalValue::Float64(value)) => assert_eq!(value.bits(), 0x8000_0000_0000_0000),
            other => panic!("expected Float64, got {other:?}"),
        }
    }

    #[test]
    fn admits_exact_selected_duplicate_name_positions() {
        let batch = LogicalBatch::try_new(
            LogicalSchema::new(vec![
                LogicalColumn::new("shared", LogicalType::Signed64),
                LogicalColumn::new("shared", LogicalType::Text),
            ]),
            vec![row(vec![
                LogicalValue::Signed64(37),
                LogicalValue::Text("right".to_owned()),
            ])],
        )
        .expect("duplicate names remain positional");
        assert_eq!(
            batch
                .schema()
                .columns()
                .map(|column| (column.name(), column.logical_type()))
                .collect::<Vec<_>>(),
            vec![
                ("shared", LogicalType::Signed64),
                ("shared", LogicalType::Text),
            ]
        );
        assert_eq!(
            batch
                .rows()
                .next()
                .expect("one row")
                .cells()
                .cloned()
                .collect::<Vec<_>>(),
            vec![
                LogicalValue::Signed64(37),
                LogicalValue::Text("right".to_owned())
            ]
        );
        assert_eq!(batch.rows().len(), 1);
    }

    #[test]
    fn admits_empty_schema_with_zero_or_one_empty_row() {
        assert!(LogicalBatch::try_new(schema(&[]), vec![]).is_ok());
        let batch =
            LogicalBatch::try_new(schema(&[]), vec![row(vec![])]).expect("empty row admits");
        assert_eq!(batch.rows().len(), 1);
        assert_eq!(batch.rows().next().expect("row").cells().len(), 0);
    }

    #[test]
    fn rejects_timestamp_and_json_before_width_or_values_even_when_null() {
        for (types, expected_index, expected_type) in [
            (
                [LogicalType::Timestamp, LogicalType::Json],
                0,
                LogicalType::Timestamp,
            ),
            (
                [LogicalType::Boolean, LogicalType::Json],
                1,
                LogicalType::Json,
            ),
        ] {
            assert_eq!(
                LogicalBatch::try_new(
                    schema(&types),
                    vec![row(vec![LogicalValue::Null; types.len()])]
                ),
                Err(LogicalBatchError::UnsupportedSchemaType {
                    column_index: expected_index,
                    actual: expected_type,
                })
            );
        }
        assert_eq!(
            LogicalBatch::try_new(schema(&[LogicalType::Timestamp]), vec![]),
            Err(LogicalBatchError::UnsupportedSchemaType {
                column_index: 0,
                actual: LogicalType::Timestamp,
            })
        );
        assert_eq!(
            LogicalBatch::try_new(schema(&[LogicalType::Timestamp]), vec![row(vec![])]),
            Err(LogicalBatchError::UnsupportedSchemaType {
                column_index: 0,
                actual: LogicalType::Timestamp,
            })
        );
    }

    #[test]
    fn rejects_widths_before_any_value_type_check() {
        let expected = 2;
        assert_eq!(
            LogicalBatch::try_new(
                schema(&[LogicalType::Boolean, LogicalType::Text]),
                vec![
                    row(vec![]),
                    row(vec![
                        LogicalValue::Signed64(9),
                        LogicalValue::Text("ok".into())
                    ])
                ],
            ),
            Err(LogicalBatchError::RowWidth {
                row_index: 0,
                expected,
                actual: 0
            })
        );
        assert_eq!(
            LogicalBatch::try_new(
                schema(&[LogicalType::Boolean, LogicalType::Text]),
                vec![
                    row(vec![
                        LogicalValue::Signed64(9),
                        LogicalValue::Text("wrong first".into())
                    ]),
                    row(vec![LogicalValue::Boolean(true)]),
                ],
            ),
            Err(LogicalBatchError::RowWidth {
                row_index: 1,
                expected,
                actual: 1,
            })
        );
        assert_eq!(
            LogicalBatch::try_new(
                schema(&[LogicalType::Boolean, LogicalType::Text]),
                vec![
                    row(vec![LogicalValue::Boolean(true)]),
                    row(vec![
                        LogicalValue::Boolean(true),
                        LogicalValue::Text("ok".into()),
                        LogicalValue::Null
                    ])
                ],
            ),
            Err(LogicalBatchError::RowWidth {
                row_index: 0,
                expected,
                actual: 1
            })
        );
        assert_eq!(
            LogicalBatch::try_new(
                schema(&[LogicalType::Boolean]),
                vec![
                    row(vec![LogicalValue::Boolean(true)]),
                    row(vec![LogicalValue::Boolean(false), LogicalValue::Null])
                ],
            ),
            Err(LogicalBatchError::RowWidth {
                row_index: 1,
                expected: 1,
                actual: 2
            })
        );
    }

    #[test]
    fn rejects_all_twelve_cross_type_pairings() {
        let categories = [
            LogicalType::Boolean,
            LogicalType::Signed64,
            LogicalType::Float64,
            LogicalType::Text,
        ];
        for expected in categories {
            for actual_type in categories {
                if expected == actual_type {
                    continue;
                }
                let actual = sample(actual_type);
                assert_eq!(
                    LogicalBatch::try_new(schema(&[expected]), vec![row(vec![actual])]),
                    Err(LogicalBatchError::CellType {
                        row_index: 0,
                        column_index: 0,
                        expected,
                        actual: match actual_type {
                            LogicalType::Boolean => LogicalValueCategory::Boolean,
                            LogicalType::Signed64 => LogicalValueCategory::Signed64,
                            LogicalType::Float64 => LogicalValueCategory::Float64,
                            LogicalType::Text => LogicalValueCategory::Text,
                            LogicalType::Timestamp | LogicalType::Json => unreachable!(),
                        },
                    })
                );
            }
        }
    }

    #[test]
    fn reports_the_first_row_major_value_error_after_all_widths_pass() {
        assert_eq!(
            LogicalBatch::try_new(
                schema(&[LogicalType::Boolean, LogicalType::Signed64]),
                vec![
                    row(vec![
                        LogicalValue::Boolean(true),
                        LogicalValue::Text("row zero column one".into())
                    ]),
                    row(vec![
                        LogicalValue::Text("later".into()),
                        LogicalValue::Boolean(false)
                    ]),
                ],
            ),
            Err(LogicalBatchError::CellType {
                row_index: 0,
                column_index: 1,
                expected: LogicalType::Signed64,
                actual: LogicalValueCategory::Text,
            })
        );
        assert_eq!(
            LogicalBatch::try_new(
                schema(&[LogicalType::Boolean]),
                vec![
                    row(vec![LogicalValue::Boolean(true)]),
                    row(vec![LogicalValue::Signed64(1)]),
                    row(vec![LogicalValue::Text("later".into())]),
                ],
            ),
            Err(LogicalBatchError::CellType {
                row_index: 1,
                column_index: 0,
                expected: LogicalType::Boolean,
                actual: LogicalValueCategory::Signed64,
            })
        );
    }
}

#[cfg(test)]
mod differential_tests {
    use super::*;
    use crate::{logical_record::Float64Bits, logical_schema::LogicalColumn};
    use std::io::Read;

    const CAP: usize = 65_536;
    const CASES: [(&str, usize); 3] =
        [("matching", 4), ("explicit-null", 4), ("duplicate-name", 2)];

    #[derive(Clone, Debug, PartialEq, Eq)]
    enum Reference {
        Null,
        Boolean(bool),
        Long(i64),
        Double(u64),
        Text(String),
    }

    #[derive(Clone, Debug, PartialEq, Eq)]
    struct Case {
        schema: Vec<LogicalColumn>,
        rows: Vec<LogicalRecord>,
        reference_schema: Vec<(String, String)>,
        reference: Vec<Vec<Reference>>,
    }

    fn hex(text: &str) -> Result<String, String> {
        if !text.len().is_multiple_of(2) {
            return Err("hex".into());
        }
        let mut bytes = Vec::with_capacity(text.len() / 2);
        for pair in text.as_bytes().as_chunks::<2>().0 {
            let nibble = |b| match b {
                b'0'..=b'9' => Ok(b - b'0'),
                b'a'..=b'f' => Ok(b - b'a' + 10),
                _ => Err("hex"),
            };
            bytes.push(nibble(pair[0])? << 4 | nibble(pair[1])?);
        }
        String::from_utf8(bytes).map_err(|_| "utf8".into())
    }

    fn kind(text: &str) -> Result<LogicalType, String> {
        match text {
            "boolean" => Ok(LogicalType::Boolean),
            "signed64" => Ok(LogicalType::Signed64),
            "float64" => Ok(LogicalType::Float64),
            "text" => Ok(LogicalType::Text),
            _ => Err("type".into()),
        }
    }

    fn long(text: &str) -> Result<i64, String> {
        let n = text.parse::<i64>().map_err(|_| "long")?;
        if n.to_string() != text {
            return Err("long".into());
        }
        Ok(n)
    }

    fn bits(text: &str) -> Result<u64, String> {
        if text.len() != 16
            || !text
                .bytes()
                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        {
            return Err("bits".into());
        }
        u64::from_str_radix(text, 16).map_err(|_| "bits".into())
    }

    fn input(tag: &str, text: &str) -> Result<LogicalValue, String> {
        match tag {
            "N" if text == "-" => Ok(LogicalValue::Null),
            "B" if matches!(text, "true" | "false") => Ok(LogicalValue::Boolean(text == "true")),
            "L" => Ok(LogicalValue::Signed64(long(text)?)),
            "D" => Ok(LogicalValue::Float64(Float64Bits::from_float(
                f64::from_bits(bits(text)?),
            ))),
            "S" => Ok(LogicalValue::Text(hex(text)?)),
            _ => Err("value".into()),
        }
    }

    // Expected values never pass through native record or floating storage.
    fn reference(tag: &str, text: &str) -> Result<Reference, String> {
        match tag {
            "N" if text == "-" => Ok(Reference::Null),
            "B" if matches!(text, "true" | "false") => Ok(Reference::Boolean(text == "true")),
            "L" => Ok(Reference::Long(long(text)?)),
            "D" => Ok(Reference::Double(bits(text)?)),
            "S" => Ok(Reference::Text(hex(text)?)),
            _ => Err("value".into()),
        }
    }

    fn parse(text: &str) -> Result<Vec<Case>, String> {
        if text.len() > CAP {
            return Err("cap".into());
        }
        if !text.ends_with('\n') || text.contains('\r') {
            return Err("transport".into());
        }
        let mut lines = text.lines();
        if lines.next() != Some("T0023-S02\t1") {
            return Err("header".into());
        }
        let mut cases = Vec::new();
        for (wanted, width) in CASES {
            let f: Vec<_> = lines.next().ok_or("case")?.split('\t').collect();
            if f.len() != 4 || f[0] != "CASE" || f[1] != wanted {
                return Err("case".into());
            }
            if f[2] != width.to_string() || f[3] != "1" {
                return Err("dimensions".into());
            }
            let mut case = Case {
                schema: vec![],
                rows: vec![],
                reference_schema: vec![],
                reference: vec![],
            };
            for index in 0..width {
                let f: Vec<_> = lines.next().ok_or("field")?.split('\t').collect();
                if f.len() != 6 || f[0] != "FIELD" || f[1] != index.to_string() {
                    return Err("field".into());
                }
                case.schema
                    .push(LogicalColumn::new(hex(f[2])?, kind(f[3])?));
                kind(f[5])?;
                case.reference_schema.push((hex(f[4])?, f[5].into()));
            }
            if lines.next() != Some("ROW\t0") {
                return Err("row".into());
            }
            let mut supplied = Vec::new();
            let mut expected = Vec::new();
            for index in 0..width {
                let f: Vec<_> = lines.next().ok_or("cell")?.split('\t').collect();
                if f.len() != 6 || f[0] != "CELL" || f[1] != index.to_string() {
                    return Err("cell".into());
                }
                supplied.push(input(f[2], f[3])?);
                expected.push(reference(f[4], f[5])?);
            }
            case.rows.push(LogicalRecord::new(supplied));
            case.reference.push(expected);
            cases.push(case);
        }
        if lines.next().is_some() {
            return Err("trailing".into());
        }
        Ok(cases)
    }

    fn compare(cases: &[Case]) -> Result<(), String> {
        for case in cases {
            let batch =
                LogicalBatch::try_new(LogicalSchema::new(case.schema.clone()), case.rows.clone())
                    .map_err(|_| "actual-admission")?;
            let columns: Vec<_> = batch
                .schema()
                .columns()
                .map(|c| {
                    let tag = match c.logical_type() {
                        LogicalType::Boolean => "boolean",
                        LogicalType::Signed64 => "signed64",
                        LogicalType::Float64 => "float64",
                        LogicalType::Text => "text",
                        _ => "unsupported",
                    };
                    (c.name().to_owned(), tag.to_owned())
                })
                .collect();
            if columns != case.reference_schema {
                return Err("comparison-schema".into());
            }
            let values: Vec<Vec<_>> = batch
                .rows()
                .map(|r| {
                    r.cells()
                        .map(|v| match v {
                            LogicalValue::Null => Reference::Null,
                            LogicalValue::Boolean(v) => Reference::Boolean(*v),
                            LogicalValue::Signed64(v) => Reference::Long(*v),
                            LogicalValue::Float64(v) => Reference::Double(v.bits()),
                            LogicalValue::Text(v) => Reference::Text(v.clone()),
                        })
                        .collect()
                })
                .collect();
            if values != case.reference {
                return Err("comparison-values".into());
            }
        }
        Ok(())
    }

    fn validate(text: &str) -> Result<(), String> {
        compare(&parse(text)?)
    }

    fn valid() -> String {
        let fields = [
            ("666c6167", "boolean", "B", "true"),
            ("6e756d626572", "signed64", "L", "37"),
            ("726174696f", "float64", "D", "8000000000000000"),
            ("74657874", "text", "S", "417c42"),
        ];
        let mut text = String::from("T0023-S02\t1\n");
        for (case, width) in CASES {
            let selected = if case == "duplicate-name" {
                vec![
                    ("736861726564", "signed64", "L", "37"),
                    ("736861726564", "text", "S", "7269676874"),
                ]
            } else {
                fields.to_vec()
            };
            text.push_str(&format!("CASE\t{case}\t{width}\t1\n"));
            for (i, (name, kind, _, _)) in selected.iter().enumerate() {
                text.push_str(&format!("FIELD\t{i}\t{name}\t{kind}\t{name}\t{kind}\n"));
            }
            text.push_str("ROW\t0\n");
            for (i, (_, _, tag, payload)) in selected.iter().enumerate() {
                let (tag, payload) = if case == "explicit-null" {
                    ("N", "-")
                } else {
                    (*tag, *payload)
                };
                text.push_str(&format!("CELL\t{i}\t{tag}\t{payload}\t{tag}\t{payload}\n"));
            }
        }
        text
    }

    fn changed(from: &str, to: &str) -> String {
        let original = valid();
        assert!(original.contains(from));
        let modified = original.replacen(from, to, 1);
        assert_ne!(original, modified);
        modified
    }

    #[test]
    fn complete_selected_projection_passes_and_retains_all_cells() {
        let cases = parse(&valid()).unwrap();
        assert_eq!(cases.len(), 3);
        assert_eq!(
            cases
                .iter()
                .map(|c| c.rows[0].cells().len())
                .collect::<Vec<_>>(),
            vec![4, 4, 2]
        );
        assert_eq!(
            cases[0].reference,
            vec![vec![
                Reference::Boolean(true),
                Reference::Long(37),
                Reference::Double(0x8000_0000_0000_0000),
                Reference::Text("A|B".into())
            ]]
        );
        assert_eq!(cases[1].reference, vec![vec![Reference::Null; 4]]);
        assert_eq!(
            cases[2].reference,
            vec![vec![Reference::Long(37), Reference::Text("right".into())]]
        );
        assert_eq!(validate(&valid()), Ok(()));
    }

    #[test]
    fn expected_only_mutations_preserve_inputs_and_fail_comparison() {
        let baseline = parse(&valid()).unwrap();
        for (from, to, diagnostic) in [
            (
                "CELL\t1\tL\t37\tL\t37",
                "CELL\t1\tL\t37\tL\t38",
                "comparison-values",
            ),
            (
                "FIELD\t0\t666c6167\tboolean\t666c6167\tboolean",
                "FIELD\t0\t666c6167\tboolean\t78\tboolean",
                "comparison-schema",
            ),
            (
                "FIELD\t0\t666c6167\tboolean\t666c6167\tboolean",
                "FIELD\t0\t666c6167\tboolean\t666c6167\ttext",
                "comparison-schema",
            ),
            (
                "CELL\t2\tD\t8000000000000000\tD\t8000000000000000",
                "CELL\t2\tD\t8000000000000000\tD\t0000000000000000",
                "comparison-values",
            ),
            (
                "CELL\t0\tN\t-\tN\t-",
                "CELL\t0\tN\t-\tB\tfalse",
                "comparison-values",
            ),
        ] {
            let cases = parse(&changed(from, to)).unwrap();
            for (a, b) in cases.iter().zip(&baseline) {
                assert_eq!(a.schema, b.schema);
                assert_eq!(a.rows, b.rows);
            }
            assert_eq!(compare(&cases), Err(diagnostic.into()));
        }
    }

    #[test]
    fn rejects_structure_and_canonical_transport() {
        for (from, to, diagnostic) in [
            ("T0023-S02\t1", "T0023-S02\t2", "header"),
            ("CASE\tmatching\t4\t1", "CASE\tunknown\t4\t1", "case"),
            ("CASE\texplicit-null\t4\t1", "CASE\tmatching\t4\t1", "case"),
            ("CASE\tmatching\t4\t1", "CASE\texplicit-null\t4\t1", "case"),
            ("CASE\tmatching\t4\t1\n", "", "case"),
            (
                "CASE\tmatching\t4\t1",
                "CASE\tmatching\t4\t1\textra",
                "case",
            ),
            (
                "CASE\tmatching\t4\t1",
                "CASE\tmatching\t04\t1",
                "dimensions",
            ),
            ("CASE\tmatching\t4\t1", "CASE\tmatching\t3\t1", "dimensions"),
            ("CASE\tmatching\t4\t1", "CASE\tmatching\t4\t0", "dimensions"),
            ("CASE\tmatching\t4\t1", "CASE\tmatching\t4\t2", "dimensions"),
            ("FIELD\t0", "FIELD\t1", "field"),
            ("FIELD\t1", "FIELD\t0", "field"),
            ("FIELD\t0", "FIELD\t00", "field"),
            ("FIELD\t0", "FIELD\t0\textra", "field"),
            (
                "FIELD\t0\t666c6167\tboolean\t666c6167\tboolean\n",
                "",
                "field",
            ),
            ("ROW\t0", "ROW\t1", "row"),
            ("ROW\t0\n", "", "row"),
            ("CELL\t0", "CELL\t1", "cell"),
            ("CELL\t1", "CELL\t0", "cell"),
            ("CELL\t0", "CELL\t0\textra", "cell"),
            ("CELL\t0\tB\ttrue\tB\ttrue\n", "", "cell"),
        ] {
            assert_eq!(validate(&changed(from, to)), Err(diagnostic.into()));
        }
        assert_eq!(validate(valid().trim_end()), Err("transport".into()));
        assert_eq!(
            validate(&valid().replace('\n', "\r\n")),
            Err("transport".into())
        );
        assert_eq!(validate(&(valid() + "extra\n")), Err("trailing".into()));
        assert_eq!(validate(&"x".repeat(CAP + 1)), Err("cap".into()));
    }

    #[test]
    fn rejects_malformed_values_and_schema_fields() {
        for (from, to, diagnostic) in [
            ("666c6167", "ff", "utf8"),
            ("666c6167", "Ff", "hex"),
            ("666c6167", "f", "hex"),
            ("boolean", "json", "type"),
            ("CELL\t0\tB\ttrue", "CELL\t0\tX\ttrue", "value"),
            ("CELL\t0\tB\ttrue", "CELL\t0\tB\tTRUE", "value"),
            ("CELL\t1\tL\t37", "CELL\t1\tL\t037", "long"),
            ("CELL\t1\tL\t37", "CELL\t1\tL\t+37", "long"),
            ("CELL\t1\tL\t37", "CELL\t1\tL\t9223372036854775808", "long"),
            ("8000000000000000", "800000000000000A", "bits"),
            ("8000000000000000", "800000000000000", "bits"),
            ("417c42", "ff", "utf8"),
            ("417c42", "417C42", "hex"),
            ("CELL\t0\tN\t-", "CELL\t0\tN\tempty", "value"),
            (
                "CELL\t0\tB\ttrue\tB\ttrue",
                "CELL\t0\tL\t37\tB\ttrue",
                "actual-admission",
            ),
        ] {
            assert_eq!(validate(&changed(from, to)), Err(diagnostic.into()));
        }
    }

    #[test]
    #[ignore = "requires strict S11 evidence projected by the S02 wrapper"]
    fn live_logical_batch_differential() {
        let path = std::env::var("T0023_S02_MANIFEST").expect("T0023_S02_MANIFEST");
        let file = std::fs::File::open(path).expect("manifest readable");
        let mut text = String::new();
        file.take((CAP + 1) as u64)
            .read_to_string(&mut text)
            .expect("UTF-8 manifest");
        validate(&text).expect("selected actual and reference batch projections match");
    }
}

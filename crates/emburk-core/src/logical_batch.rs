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

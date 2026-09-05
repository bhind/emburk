//! Private, dependency-free resolution for project-constructed scalar values.
//!
//! This module intentionally has no parser or public API. It models only the
//! native values and policies admitted by T-0012/S03.

#[derive(Clone, Debug, PartialEq, Eq)]
enum RawScalar {
    Missing,
    Null,
    String(String),
    Boolean(bool),
    I64(i64),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum RawScalarKind {
    Missing,
    Null,
    String,
    Boolean,
    I64,
}

impl RawScalar {
    fn kind(&self) -> RawScalarKind {
        match self {
            Self::Missing => RawScalarKind::Missing,
            Self::Null => RawScalarKind::Null,
            Self::String(_) => RawScalarKind::String,
            Self::Boolean(_) => RawScalarKind::Boolean,
            Self::I64(_) => RawScalarKind::I64,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum ScalarRequest {
    RequiredString,
    DefaultString { value: String },
    OptionalStringNullDefault,
    Boolean,
    I64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ScalarRequestKind {
    RequiredString,
    DefaultString,
    OptionalStringNullDefault,
    Boolean,
    I64,
}

impl ScalarRequest {
    fn kind(&self) -> ScalarRequestKind {
        match self {
            Self::RequiredString => ScalarRequestKind::RequiredString,
            Self::DefaultString { .. } => ScalarRequestKind::DefaultString,
            Self::OptionalStringNullDefault => ScalarRequestKind::OptionalStringNullDefault,
            Self::Boolean => ScalarRequestKind::Boolean,
            Self::I64 => ScalarRequestKind::I64,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum ScalarResolution {
    String(String),
    OptionalString(Option<String>),
    Boolean(bool),
    I64(i64),
    MissingRequired,
    NullNotAllowed,
    Unsupported {
        raw: RawScalarKind,
        requested: ScalarRequestKind,
    },
}

fn resolve(raw: RawScalar, request: ScalarRequest) -> ScalarResolution {
    match (raw, request) {
        (RawScalar::Missing, ScalarRequest::RequiredString) => ScalarResolution::MissingRequired,
        (RawScalar::Null, ScalarRequest::RequiredString) => ScalarResolution::NullNotAllowed,
        (RawScalar::String(value), ScalarRequest::RequiredString) => {
            ScalarResolution::String(value)
        }
        (RawScalar::Missing, ScalarRequest::DefaultString { value }) => {
            ScalarResolution::String(value)
        }
        (RawScalar::String(value), ScalarRequest::DefaultString { .. }) => {
            ScalarResolution::String(value)
        }
        (RawScalar::Null, ScalarRequest::DefaultString { .. }) => ScalarResolution::NullNotAllowed,
        (RawScalar::Missing | RawScalar::Null, ScalarRequest::OptionalStringNullDefault) => {
            ScalarResolution::OptionalString(None)
        }
        (RawScalar::String(value), ScalarRequest::OptionalStringNullDefault) => {
            ScalarResolution::OptionalString(Some(value))
        }
        (RawScalar::Boolean(value), ScalarRequest::Boolean) => ScalarResolution::Boolean(value),
        (RawScalar::I64(value), ScalarRequest::I64) => ScalarResolution::I64(value),
        (raw, request) => ScalarResolution::Unsupported {
            raw: raw.kind(),
            requested: request.kind(),
        },
    }
}

// The bridge is deliberately test-only.  The TSV is produced by the S04
// stdlib driver; production code neither reads it nor knows its fixture IDs.
#[cfg(test)]
fn assert_live_tsv(tsv: &str) -> Result<(), String> {
    const MANIFEST: [&str; 13] = [
        "required-absent",
        "required-null",
        "required-value",
        "defaulted-absent",
        "defaulted-null",
        "defaulted-value",
        "optional-absent",
        "optional-null",
        "optional-value",
        "boolean-true",
        "boolean-false",
        "long-37",
        "long-max",
    ];
    let mut lines = tsv.lines();
    if lines.next() != Some("T0012-S04\t1") {
        return Err("unsupported TSV header".into());
    }
    let mut seen = std::collections::BTreeSet::new();
    for line in lines {
        let columns: Vec<_> = line.split('\t').collect();
        if columns.len() != 7 {
            return Err("truncated TSV row".into());
        }
        let id = decode_hex(columns[0])?;
        let id = std::str::from_utf8(&id).map_err(|_| "non-UTF-8 fixture id")?;
        if !MANIFEST.contains(&id) {
            return Err("unknown fixture id".into());
        }
        if !seen.insert(id.to_owned()) {
            return Err("duplicate fixture id".into());
        }
        let raw = parse_raw(columns[1], columns[2])?;
        let request = parse_request(columns[3], columns[4])?;
        let actual = resolve(raw, request);
        let expected = parse_resolution(columns[5], columns[6])?;
        if actual != expected {
            return Err(format!("mutated outcome for {id}"));
        }
    }
    if seen.len() != MANIFEST.len() || !MANIFEST.iter().all(|id| seen.contains(*id)) {
        return Err("missing fixture id".into());
    }
    Ok(())
}

#[cfg(test)]
fn decode_hex(value: &str) -> Result<Vec<u8>, String> {
    let bytes = value.as_bytes();
    if !bytes.len().is_multiple_of(2) {
        return Err("malformed hex".into());
    }
    let (pairs, remainder) = bytes.as_chunks::<2>();
    debug_assert!(remainder.is_empty());
    pairs
        .iter()
        .map(|[high, low]| Ok(hex_nibble(*high)? << 4 | hex_nibble(*low)?))
        .collect()
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
fn hex_string(value: &str) -> Result<String, String> {
    String::from_utf8(decode_hex(value)?).map_err(|_| "non-UTF-8 string".into())
}

#[cfg(test)]
fn parse_raw(tag: &str, value: &str) -> Result<RawScalar, String> {
    match tag {
        "missing" if value.is_empty() => Ok(RawScalar::Missing),
        "null" if value.is_empty() => Ok(RawScalar::Null),
        "string" => Ok(RawScalar::String(hex_string(value)?)),
        "bool" if value == "true" => Ok(RawScalar::Boolean(true)),
        "bool" if value == "false" => Ok(RawScalar::Boolean(false)),
        "i64" => value
            .parse()
            .map(RawScalar::I64)
            .map_err(|_| "malformed i64".into()),
        _ => Err("malformed raw tag".into()),
    }
}

#[cfg(test)]
fn parse_request(tag: &str, value: &str) -> Result<ScalarRequest, String> {
    match tag {
        "required-string" if value.is_empty() => Ok(ScalarRequest::RequiredString),
        "default-string" => Ok(ScalarRequest::DefaultString {
            value: hex_string(value)?,
        }),
        "optional-string-null-default" if value.is_empty() => {
            Ok(ScalarRequest::OptionalStringNullDefault)
        }
        "bool" if value.is_empty() => Ok(ScalarRequest::Boolean),
        "i64" if value.is_empty() => Ok(ScalarRequest::I64),
        _ => Err("malformed request tag".into()),
    }
}

#[cfg(test)]
fn parse_resolution(tag: &str, value: &str) -> Result<ScalarResolution, String> {
    match tag {
        "string" => Ok(ScalarResolution::String(hex_string(value)?)),
        "optional-none" if value.is_empty() => Ok(ScalarResolution::OptionalString(None)),
        "optional-some" => Ok(ScalarResolution::OptionalString(Some(hex_string(value)?))),
        "bool" if value == "true" => Ok(ScalarResolution::Boolean(true)),
        "bool" if value == "false" => Ok(ScalarResolution::Boolean(false)),
        "i64" => value
            .parse()
            .map(ScalarResolution::I64)
            .map_err(|_| "malformed i64".into()),
        "missing-required" if value.is_empty() => Ok(ScalarResolution::MissingRequired),
        "null-not-allowed" if value.is_empty() => Ok(ScalarResolution::NullNotAllowed),
        _ => Err("malformed outcome tag".into()),
    }
}

#[cfg(test)]
mod tests {
    use super::{
        RawScalar, RawScalarKind, ScalarRequest, ScalarRequestKind, ScalarResolution, resolve,
    };

    #[test]
    fn strings_preserve_arbitrary_contents() {
        let required = "emoji: \u{1f980}\nleading and trailing ".to_owned();
        let defaulted = "different\0string".to_owned();

        assert_eq!(
            resolve(
                RawScalar::String(required.clone()),
                ScalarRequest::RequiredString
            ),
            ScalarResolution::String(required)
        );
        assert_eq!(
            resolve(
                RawScalar::String(defaulted.clone()),
                ScalarRequest::DefaultString {
                    value: "unused fallback".to_owned(),
                },
            ),
            ScalarResolution::String(defaulted)
        );
        assert_eq!(
            resolve(
                RawScalar::String(String::new()),
                ScalarRequest::RequiredString
            ),
            ScalarResolution::String(String::new())
        );
        assert_eq!(
            resolve(
                RawScalar::String(String::new()),
                ScalarRequest::DefaultString {
                    value: "fallback".to_owned(),
                },
            ),
            ScalarResolution::String(String::new())
        );
        assert_eq!(
            resolve(
                RawScalar::String(String::new()),
                ScalarRequest::OptionalStringNullDefault,
            ),
            ScalarResolution::OptionalString(Some(String::new()))
        );
    }

    #[test]
    fn string_default_applies_only_to_missing() {
        let request = ScalarRequest::DefaultString {
            value: "fallback".to_owned(),
        };

        assert_eq!(
            resolve(RawScalar::Missing, request.clone()),
            ScalarResolution::String("fallback".to_owned())
        );
        assert_eq!(
            resolve(RawScalar::Null, request),
            ScalarResolution::NullNotAllowed
        );
    }

    #[test]
    fn optional_string_null_default_maps_missing_and_null_to_none() {
        let request = ScalarRequest::OptionalStringNullDefault;

        assert_eq!(
            resolve(RawScalar::Missing, request.clone()),
            ScalarResolution::OptionalString(None)
        );
        assert_eq!(
            resolve(RawScalar::Null, request.clone()),
            ScalarResolution::OptionalString(None)
        );
        assert_eq!(
            resolve(RawScalar::String("present".to_owned()), request),
            ScalarResolution::OptionalString(Some("present".to_owned()))
        );
    }

    #[test]
    fn required_string_preserves_observed_missing_and_null_outcomes() {
        assert_eq!(
            resolve(RawScalar::Missing, ScalarRequest::RequiredString),
            ScalarResolution::MissingRequired
        );
        assert_eq!(
            resolve(RawScalar::Null, ScalarRequest::RequiredString),
            ScalarResolution::NullNotAllowed
        );
    }

    #[test]
    fn booleans_preserve_both_native_values() {
        assert_eq!(
            resolve(RawScalar::Boolean(true), ScalarRequest::Boolean),
            ScalarResolution::Boolean(true)
        );
        assert_eq!(
            resolve(RawScalar::Boolean(false), ScalarRequest::Boolean),
            ScalarResolution::Boolean(false)
        );
    }

    #[test]
    fn signed_64_bit_integers_preserve_both_bounds() {
        assert_eq!(
            resolve(RawScalar::I64(i64::MIN), ScalarRequest::I64),
            ScalarResolution::I64(i64::MIN)
        );
        assert_eq!(
            resolve(RawScalar::I64(i64::MAX), ScalarRequest::I64),
            ScalarResolution::I64(i64::MAX)
        );
    }

    #[test]
    fn unsupported_combinations_are_not_errors_or_coercions() {
        assert_eq!(
            resolve(RawScalar::String("true".to_owned()), ScalarRequest::Boolean),
            ScalarResolution::Unsupported {
                raw: RawScalarKind::String,
                requested: ScalarRequestKind::Boolean,
            }
        );
        assert_eq!(
            resolve(
                RawScalar::I64(42),
                ScalarRequest::DefaultString {
                    value: "fallback".to_owned(),
                }
            ),
            ScalarResolution::Unsupported {
                raw: RawScalarKind::I64,
                requested: ScalarRequestKind::DefaultString,
            }
        );
    }

    fn row(
        id: &str,
        raw_tag: &str,
        raw: &str,
        request_tag: &str,
        request: &str,
        outcome_tag: &str,
        outcome: &str,
    ) -> String {
        format!(
            "{}\t{raw_tag}\t{raw}\t{request_tag}\t{request}\t{outcome_tag}\t{outcome}",
            id.as_bytes()
                .iter()
                .map(|byte| format!("{byte:02x}"))
                .collect::<String>()
        )
    }

    fn valid_tsv() -> String {
        let rows = [
            row(
                "required-absent",
                "missing",
                "",
                "required-string",
                "",
                "missing-required",
                "",
            ),
            row(
                "required-null",
                "null",
                "",
                "required-string",
                "",
                "null-not-allowed",
                "",
            ),
            row(
                "required-value",
                "string",
                "6f627365727665642d76616c7565",
                "required-string",
                "",
                "string",
                "6f627365727665642d76616c7565",
            ),
            row(
                "defaulted-absent",
                "missing",
                "",
                "default-string",
                "66616c6c6261636b",
                "string",
                "66616c6c6261636b",
            ),
            row(
                "defaulted-null",
                "null",
                "",
                "default-string",
                "66616c6c6261636b",
                "null-not-allowed",
                "",
            ),
            row(
                "defaulted-value",
                "string",
                "6f627365727665642d76616c7565",
                "default-string",
                "66616c6c6261636b",
                "string",
                "6f627365727665642d76616c7565",
            ),
            row(
                "optional-absent",
                "missing",
                "",
                "optional-string-null-default",
                "",
                "optional-none",
                "",
            ),
            row(
                "optional-null",
                "null",
                "",
                "optional-string-null-default",
                "",
                "optional-none",
                "",
            ),
            row(
                "optional-value",
                "string",
                "6f627365727665642d76616c7565",
                "optional-string-null-default",
                "",
                "optional-some",
                "6f627365727665642d76616c7565",
            ),
            row("boolean-true", "bool", "true", "bool", "", "bool", "true"),
            row(
                "boolean-false",
                "bool",
                "false",
                "bool",
                "",
                "bool",
                "false",
            ),
            row("long-37", "i64", "37", "i64", "", "i64", "37"),
            row(
                "long-max",
                "i64",
                "9223372036854775807",
                "i64",
                "",
                "i64",
                "9223372036854775807",
            ),
        ];
        format!("T0012-S04\t1\n{}\n", rows.join("\n"))
    }

    #[test]
    fn live_tsv_bridge_rejects_invalid_manifests_and_rows() {
        let valid = valid_tsv();
        assert!(super::assert_live_tsv(&valid).is_ok());
        for bad in [
            valid.replacen("72657175697265642d616273656e74", "756e6b6e6f776e", 1),
            valid.replacen("\n72657175697265642d616273656e74", "\n", 1),
            valid.replacen(
                "\n72657175697265642d616273656e74",
                "\n72657175697265642d6e756c6c",
                1,
            ),
            valid.replacen("\tstring\t6f627365727665642d76616c7565", "\tstring\tzz", 1),
            valid.replacen("\tmissing\t\t", "\tunknown\t\t", 1),
            valid.replacen("\tmissing-required\t", "\tunknown-exception\t", 1),
            valid.replacen("\tbool\ttrue\n", "\tbool\tfalse\n", 1),
            valid.replacen("T0012-S04\t1", "T0012-S04\t1\ntruncated", 1),
        ] {
            assert!(super::assert_live_tsv(&bad).is_err(), "{bad}");
        }
        assert!(super::assert_live_tsv("T0012-S04\t1\n").is_err());
        assert!(super::decode_hex("💥").is_err());
    }

    #[test]
    #[ignore = "requires the external T-0012/S04 oracle driver"]
    fn live_scalar_differential() {
        let path = std::env::var("T0012_S04_TSV").expect("T0012_S04_TSV must name driver output");
        let tsv = std::fs::read_to_string(path).expect("read driver TSV");
        super::assert_live_tsv(&tsv).expect("validate and compare live scalar TSV");
    }
}

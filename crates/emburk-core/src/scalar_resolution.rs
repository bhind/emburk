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
}

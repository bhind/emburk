#![forbid(unsafe_code)]

// This is deliberately private until a later packet authorizes an API consumer.
#[allow(
    dead_code,
    reason = "T-0012/S03 is an internal resolver without a public consumer"
)]
mod scalar_resolution;

// This is deliberately private until a later packet authorizes an API consumer.
#[allow(
    dead_code,
    reason = "T-0012/S06 is an internal ordered schema without a public consumer"
)]
mod logical_schema;

// This is deliberately private until a later packet authorizes a record API.
#[allow(
    dead_code,
    reason = "T-0012/S08 is private values-only storage without a public consumer"
)]
mod logical_record;

// This is deliberately private: it is a bounded fake-fixture coordinator, not
// a public plugin API or a production lifecycle contract.
#[allow(
    dead_code,
    reason = "T-0021/S03 is an internal empty-task coordinator without a public consumer"
)]
mod empty_lifecycle;

pub const DEVELOPMENT_STATUS: &str =
    "emburk: development environment ready (data transfer not implemented yet)";

#[cfg(test)]
mod tests {
    use super::DEVELOPMENT_STATUS;

    #[test]
    fn development_status_does_not_claim_a_working_loader() {
        assert!(DEVELOPMENT_STATUS.contains("data transfer not implemented yet"));
    }
}

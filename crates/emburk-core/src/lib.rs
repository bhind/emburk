#![forbid(unsafe_code)]

// This is deliberately private until a later packet authorizes an API consumer.
#[allow(
    dead_code,
    reason = "T-0012/S03 is an internal resolver without a public consumer"
)]
mod scalar_resolution;

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

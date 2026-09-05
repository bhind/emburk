#![forbid(unsafe_code)]

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

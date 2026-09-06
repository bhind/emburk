#![forbid(unsafe_code)]

#[cfg(unix)]
mod checkpoint;

#[cfg(unix)]
#[doc(hidden)]
pub use configured_csv::run_config_resumable;

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

// This is deliberately private: it validates only the selected internal
// schema/value categories before any physical batch representation exists.
#[allow(
    dead_code,
    reason = "T-0023/S01 is a private positional admission boundary without a consumer"
)]
mod logical_batch;

// This remains a private ownership experiment, not a plugin or lifecycle API.
#[allow(
    dead_code,
    reason = "T-0021/S06 is an internal synchronous owned-record handoff seam"
)]
mod record_handoff;

// This is an unstable std-I/O bridge for the experimental CLI command, not a
// plugin API or a general record-transfer interface.
mod text_transfer;

mod bounded_parallel;
mod configured_csv;
mod guess;
#[doc(hidden)]
pub use guess::{guess_config, guess_config_to_file};
mod csv_stream;
mod native_formats;
mod publication;
mod yaml_profile;

#[doc(hidden)]
pub use configured_csv::run_config;
#[doc(hidden)]
pub use configured_csv::run_config_with_cancel;
#[doc(hidden)]
pub use text_transfer::transfer_lines;

// This is deliberately private: it is a bounded fake-fixture coordinator, not
// a public plugin API or a production lifecycle contract.
#[allow(
    dead_code,
    reason = "T-0021/S03 is an internal empty-task coordinator without a public consumer"
)]
mod empty_lifecycle;

pub const DEVELOPMENT_STATUS: &str =
    "emburk: experimental text transfer available (full ETL not implemented)";

#[cfg(test)]
mod tests {
    use super::DEVELOPMENT_STATUS;

    #[test]
    fn development_status_describes_the_available_experimental_transfer() {
        assert!(DEVELOPMENT_STATUS.contains("experimental text transfer available"));
        assert!(DEVELOPMENT_STATUS.contains("full ETL not implemented"));
    }
}

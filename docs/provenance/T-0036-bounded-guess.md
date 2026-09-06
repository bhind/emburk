# T-0036/S02 bounded native guessing

Issue #29. Done through PR #124; accepted 5 SP. S01 accepted 3 SP through PR #123
(cdb0fdc), after primary/independent three tests and ten reviewed projections at
1d577dd. Parent Current becomes 8, Initial remains 5. S03/T-0037 acceptance
remains separate; this packet does not complete full guessing compatibility.

## Branch and allowlist

Branch feat/t-0036-bounded-guess. Plugin Implementer owns only
crates/emburk-core/src/guess.rs and its inline unit tests. After that returns,
PM serially owns integration/fixes in that file, lib.rs, configured_csv.rs,
crates/emburk-cli/src/main.rs and tests/guess.rs. PM owns this packet, prior
S01 closeout, STATUS/TODO/ROADMAP/COMPATIBILITY/ARCHITECTURE, ADR-0022 and indexes,
and the native guide. No concurrent source writers or new dependencies.
The implementer returned an unregistered incomplete module; PM took serial
source ownership, replaced the unbounded raw read, implemented actual seed
preservation/codec output, and added compiled unit/CLI tests before acceptance.

## Accepted bounded design

Original behavioral implementation informed only by S01 observations and public
documentation, not upstream source translation. Use already admitted YAML,
JSON, CSV and codec adapters. Emit JSON syntax (valid YAML) with preserved seed
fields; compare semantic keys/scalars rather than YAML formatting. Never
replace explicit configuration values or invent JSON columns. An incomplete
JSON configuration stays incomplete and cannot silently run with guessed types.

Initially admit UTF-8/LF/comma CSV, JSON objects, and one gzip/bzip2 layer.
Read at most 1 MiB raw compressed bytes and 32 KiB decoded sample, rejecting
larger files in this initial whole-sample profile rather than pretending partial
EOF proves the schema. Configuration/output remain <=64 KiB, <=256 columns;
sampling of larger inputs is future work. CSV headers are unique identifier
names with numeric evidence below; headerless numeric columns require explicit
UTF-8 in the seed because the observed charset heuristic differs. Single-column
prose is a string c0. Infer only uniform signed64/string columns; reject
unsupported delimiters, inconsistent rows and uncertain numeric coercions.

TSV and unseeded headerless charset guessing remain explicit unsupported gaps,
not accepted deviations or matching comparisons. UTF-8 byte validity alone is
not a claim to reproduce upstream ICU charset detection. Keep these reference
cases in the gap inventory. Broader header/type/charset behavior is unverified.

CLI: guess SEED [-o CONFIG]. Write stdout only without -o; with -o use existing
no-clobber publication, never overwrite a destination or mutate input/seed.
Configured CSV accepts only observed false trim/extra/optional policies; JSON
accepts only explicit UTF-8/LF. True policies and other encodings stay rejected.

## Demo Command

`cargo fmt --all -- --check && cargo clippy --locked --workspace --all-targets -- -D warnings && cargo test --locked --workspace && git diff --check`

Use the existing offline Cargo cache if needed. Tests include arbitrary names,
compression, explicit configuration preservation, empty/invalid/oversized input,
no-clobber output and executing generated supported configurations. Final
cross-runtime guess/transfer/resume comparisons belong to T-0037/S01.

## Evidence class, stop rule and non-claims

Integrated as 54d2cc1abd8b849063859e9f57eaf0ea6b6a4bc9 after exact primary and
independent Demo at 421500e5b46ff38a00bc8186956acb0d70d71e62: 125 tests passed,
eight existing intentional ignores. Primary /private/tmp/t0036-s02-primary.Zjyjsw
stdout SHA256 c2ededb2c3d50599c3318d78d1e6b89375d882c28ef51eb6fbb84e34c05585cd;
stderr 79aa25dbb413f70aaa50cea73145107fdbe4f336e4a5d03f92f6eac204e8b910.
Independent /private/tmp/t0036-s02-independent.ARslvI stdout SHA256
e31c833095e60be3b8fb6388b049f0d6c2a9a20a781488e1b1b72bbb746e8064;
stderr b2470955a79f16e6a9f67d2cf07186878f26a99f64f1d60f63c9bba27cc156a5.
Both exits 0; independent revision/status unchanged. Review found explicit
CSV schema was overlaid after unwanted inference; fixed and regression-tested
before the accepted revision. Parent #29 remains Backlog, accepted total 8 SP,
Current8/Initial5, broader guessing unaccepted.

Unit/Contract and native Integration. Stop on unbounded read, seed loss,
unsafe write, dependency/provenance gap or mismatch hidden as a normalization.
No full guess/plugin or charset/type inference parity, no automatic JSON schema,
no large-input sampling claim. S01 artifact/license/IP non-claims remain.

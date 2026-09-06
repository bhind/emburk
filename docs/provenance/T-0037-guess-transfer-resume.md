# T-0037/S01 guess/transfer/native-resume acceptance

Issue #30. In Progress; forecast 5 SP. Depends on independently accepted
T-0036/S01 (#123), S02 (#124, 54d2cc1), configured format/publication/worker/
resume slices (#116–#121). Broader parent tasks are not presumed complete.

## Branch and allowlist

Branch test/t-0037-guess-transfer-resume. PM owns tests/t0037_guess_pipeline.py,
tests/t0037_guess_pipeline_test.sh, this packet, prior S02 closeout and canonical
STATUS/TODO/ROADMAP/COMPATIBILITY/ARCHITECTURE, native guide and ADR-0022/index.
No Rust implementation or dependency changes. Independent reviewers are
read-only. Maximum one active implementation/acceptance Project lane.

## Acceptance matrix

Re-run all ten pinned reference guess fixtures. Compare all keys, scalar text
and ordered arrays of seven supported successful generated configurations;
compare empty-input rejection separately. Retain two unsupported reference
cases (TSV and unseeded headerless charset) as gaps, not successful matches.
Use installed Ruby 2.6.10/Psych 3.1.0 only to parse both YAML documents to raw
scalar trees; preserve keys and array order, reject aliases/duplicates. No
schema/value coercion or broad YAML equivalence claim. Runtime API usage only;
no Ruby/Psych source or library is redistributed/adopted by the Rust binary.

Run six complete generated profiles through both actual Embulk and native
transfer and compare full output filenames/bytes. Unseeded JSON has no columns
and is not included as a runnable profile; no schema is silently inserted.
For CSV, explicit-schema JSON, gzip and bzip2, first guess from a small sample,
then create a larger same-schema job input BEFORE either execution. Record
both input versions. Interrupt the actual native stateful job after a durable
checkpoint, resume it, and compare final output with actual reference normal
execution. Repeat resume and verify no target replacement. This compares final
data after native recovery, NOT Embulk resume-file/lifecycle/transaction parity.

Retain all commands/logs/exits/input/config/output hashes and exact native
revision/binary/reference identities. Explicitly fail on mismatch or timeout;
keep incomplete summary on failure. Forced mismatch is a required negative
control. Existing CSV/formats comparisons and runtime tests remain unchanged.

## Demo Command

`cargo fmt --all -- --check && cargo clippy --locked --workspace --all-targets -- -D warnings && cargo test --locked --workspace && bash tests/t0032_configured_csv_differential_test.sh && bash tests/t0033_native_formats_differential_test.sh && bash tests/t0037_guess_pipeline_test.sh && git diff --check`

Requires pinned reference JAR/Java17, installed Ruby/Psych and offline Cargo
cache where necessary. Reference packet S01 records exact artifacts/licenses.

## Evidence class, stop rule and non-claims

Pre-acceptance controls: forced configuration mismatch under PYTHONOPTIMIZE
returned 1 with incomplete summary in
/var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T/emburk-t0037-pipeline-f19397by.
Forced timeout returned 1; owned child exit -9 and timeout=true were retained
in /var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T/emburk-t0037-pipeline-havrgy_6.
Read-only PID probe confirmed that child was reaped. Review findings about
missing failure records and vacuous rejection classification were fixed before
acceptance: owned process groups are reaped, records are written in finally,
rejected configurations must be absent with the intended diagnostic, and
sample/job schema and expected output filenames are checked explicitly.

Selected Differential plus native recovery Integration. Stop on unexplained
mismatch, hidden gap, source drift, unsafe output or orphaned subprocess.
No full T-0037 parent completion, generic guess/schema/charset support,
Embulk recovery parity, benchmark, production or legal-clearance claim.

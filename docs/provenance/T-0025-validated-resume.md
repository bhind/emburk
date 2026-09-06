# T-0025/S02 validated native resume

Issue: [#22](https://github.com/bhind/emburk/issues/22). State: In Progress.
Forecast: 8 SP; accepted S01 is 5 SP. Parent Current becomes 13, Initial stays 8.

## Authority and dependencies

Owner authorized the seven-stage sequence and routine integration. S01 safe
publication is integrated in PR #117; bounded workers/cancellation in PR #120
(24b99fab7763f4417e20422ec8a1e239d1b4069f). This completes the bounded native
stage-seven profile, not the full Embulk transaction or scheduler contracts.

## Branch and allowlist

Branch: feat/t-0025-validated-resume. Implementation owner: Rust Core
Implementer, serial ownership of crates/emburk-core/src/checkpoint.rs,
configured_csv.rs, publication.rs, lib.rs, crates/emburk-cli/src/main.rs,
crates/emburk-cli/tests/validated_resume.rs, crates/emburk-core/Cargo.toml and
Cargo.lock. PM owns this packet and canonical documentation only. Reviewers
do not mutate tracked files. No other worktree may be changed.

PM also owns README.md, docs/NATIVE_PIPELINE.md and documentation indexes.
PM owns docs/THIRD_PARTY_NOTICES.md for the new hash dependency attribution.
After the initial checkpoint scaffold, the implementer is restricted to
publication.rs for the prepared hook and unit tests; PM takes serial source
ownership for the remaining checkpoint/configuration/CLI integration after
that sub-step returns. There are no concurrent tracked-source writers.

## Acceptance contract

Expose an explicit state-directory run and resume command. Preserve ordinary
run behavior. Checkpoint the uncompressed formatted spool; restart encoding
from that spool, never append an uncertain compressed stream. Bound manifest,
record, spool and generation sizes. Exclusively create private state; hold a
kernel file lock for the entire operation, rejecting concurrent writers.

Validate exact configuration and input identity/content, output destination,
profile version, checkpoint chain, spool identity/length/hash and actual
reformatted prefix before mutating resume state. Never blindly skip N records.
Only validated owned uncheckpointed tails may be truncated. Recheck source
identity/content before publication. Retain state for inspection.

Persist the prepared output identity after file synchronization and before
no-clobber publication. Recovery may recognize an already-linked output only
by matching the prepared identity and content, never by filename alone. A
conflicting output remains untouched. Cancellation preserves a usable durable
checkpoint. Repeated successful resume must not republish or overwrite.

Tests cover actual interrupted CLI/resume, input/config/spool tampering,
concurrent lock rejection, incomplete tails, publication crash windows and
repeat resume. Existing 106 tests and thirteen reference comparisons remain.

Protocol v1 bounds: 64 KiB manifest, 8 GiB spool, 65,536 generations; checkpoint
each 1,024 valid records or 4 MiB, plus header and completion. Generations use
20-digit sequence names, exact version/sequence/previous-hash/run identity,
configuration hash, canonical input identity/hash, canonical target, spool
identity/length/hash, record count, phase and optional prepared output identity.
Exclusive synchronized temporary records become immutable through hard links.
Recognized incomplete temporaries are not authoritative generations. Reject
unknown entries, gaps, unsafe file types/modes and mismatched chain identities.

The initial dependency network retry was denied. No network bypass was used:
seven exact archives already retained in the provenance inventory were hashed
against Cargo.lock, then copied into a temporary offline Cargo cache at
/private/tmp/emburk-resume-cargo.FrbGlD. The original user cache was unchanged.
All subsequent builds can use this CARGO_HOME with --offline --locked.
The seven new exact archives (sha2, block-buffer, cpufeatures, crypto-common,
digest, hybrid-array and typenum) contain no build.rs scripts. Their exact
versions and archive checksums are retained in Cargo.lock; no source bodies
were copied into Emburk.

## Dependency and provenance boundary

Only sha2=0.11.0 (default-features=false) may be newly admitted, after exact
lock graph verification against the already inspected prospective archive
inventory. Official archive: https://static.crates.io/crates/sha2/sha2-0.11.0.crate
SHA256: 446ba717509524cb3f22f17ecc096f10f4822d76ab5c0b9822c5f9c284e825f4.
Accessed 2026-09-06. MIT/Apache-2.0; no implementation copied. Unreviewed
dependency security, release SBOM and patent/FTO are not cleared.

The std File::try_lock API documentation was inspected at
https://doc.rust-lang.org/std/fs/struct.File.html#method.try_lock on 2026-09-06,
Rust 1.98.1 commit 48a229ceaefd4985c50990b14116b6d856af0985 (MIT/Apache-2.0).
Kernel lock release on handle closure avoids stale PID guessing. API usage
only, not copied implementation; locks do not prevent unrelated file writes.

## Demo Command

`cargo fmt --all -- --check && cargo clippy --locked --workspace --all-targets -- -D warnings && cargo test --locked --workspace && bash tests/t0032_configured_csv_differential_test.sh && bash tests/t0033_native_formats_differential_test.sh && git diff --check`

Use the pinned local reference JAR and Java 17. Retain primary and independent
final-revision logs, hashes and numeric exits before PR integration.

## Evidence class, stop rule and non-claims

Native Unit/Contract and Integration; differential regressions only. Stop on
data loss, unsafe recovery, unbounded state, dependency mismatch or unexplained
reference mismatch. Trusted same-UID stable local Unix filesystem only. No
hostile path-race, hardware power-loss, fast seek, generic resume-file format,
distributed transaction, exactly-once or full Embulk resume parity claim.

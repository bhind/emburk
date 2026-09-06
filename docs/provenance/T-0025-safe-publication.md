# T-0025/S01 safe single-file publication

Issue: [#22](https://github.com/bhind/emburk/issues/22). State: Done through PR #117.
Forecast: 5 SP. Stage 5 of the authorized execution sequence.

## Authority

The owner authorized stages 1–7, routine commits, pushes and merges absent
incidents. PM owns this packet and acceptance. No new dependency is admitted.

## Dependencies

T-0032/S01 integrated through PR #116 (66c6125), with 81 passing tests and
eight selected independent Embulk comparisons at 59a7cca. This slice handles
one local output only; the complete T-0013/T-0024 contracts are not prerequisites
for this limited publication primitive and remain open.

## Branch and allowlist

Branch feat/t-0025-safe-publication. Rust Core Implementer owns only
crates/emburk-core/src/publication.rs, crates/emburk-core/src/lib.rs,
crates/emburk-core/src/configured_csv.rs and
crates/emburk-cli/tests/configured_csv.rs. One mutation owner, read-only reviewers.
PM owns this packet, ADR-0018, STATUS/TODO/ROADMAP/COMPATIBILITY/ARCHITECTURE,
IMPLEMENTATION_SEQUENCE, provenance index, T-0032 closeout, ADR-0017 status,
and the daily log. No dependency, old line consumer, or oracle changes.

The initial implementer returned an incomplete scaffold and stopped mutation.
PM then took serial ownership of the same source allowlist, replacing the
scaffold with a closure-owned writer, actual typed failure states and operation
fault tests. The implementer subsequently reviews read-only.

## Artifacts and acceptance

Original std-only Rust, Unix local same-filesystem sibling temporary output.
Exclusive 0600 temporary creation; stream, flush, file sync, hard-link to the
final path without replacement, parent sync, remove only the owned temporary
name, parent sync again. Do not precheck then replace a destination. Existing
files and symlinks must remain unchanged. Unsupported platforms/filesystems
return an explicit error; there is no fallback to overwriting rename.

Model NotPublished, PublishedDurabilityUnknown, and Published outcomes with
phase and temporary cleanup disposition. Before link success, failures cannot
create the final target and cleanup may remove only the owned temporary file.
After link success, never delete the target. First directory sync failure
reports uncertain durability; later unlink or directory sync failure reports
published output with incomplete cleanup. Errors include retained paths.

Wire configured CSV through this primitive. Transfer/header/read/write/flush
failures do not publish partial final output. Existing eight successful byte
projections and older CLI commands remain unchanged. Temporary crash residue is
not claimed recoverable in this slice. A later slice owns cancellation/resume.

Tests inject create/write/flush/file-sync/link/first-directory-sync/unlink/
second-directory-sync failures through a private original test seam. Cover
actual existing regular/symlink targets, successful mode 0600/no residue,
invalid CSV/read failure unpublished, every post-link error preserving target,
and cleanup failure retaining an explicit owned path. No environment-driven
production fault switches. Trusted filesystem and same-UID process boundary;
hostile directory substitution and power-loss simulation are non-claims.

## Demo Command

The CLI interruption regression observes an actual owned temporary during a
large transfer, kills and reaps the child, and verifies no partial final output.
Abrupt termination may leave that private temporary; no resume claim follows.

`cargo fmt --all -- --check && cargo clippy --locked --workspace --all-targets -- -D warnings && cargo test --locked --workspace && bash tests/t0032_configured_csv_differential_test.sh && git diff --check`

Set EMBURK_REFERENCE_JAR and JAVA_HOME as in T-0032/S01. Retain exact-head
primary/independent logs, exit values and hashes before integration.

## Evidence class

Unit/Contract and local Integration; selected CSV Differential regression only.
Publication policy is a native safety contract, not measured Embulk parity.

## Acceptance evidence

Accepted 5 SP; integrated aac00039d9d60c218750125d274400be4b8e135e.
Exact Demo passed in primary and independent runs at
725dd7e9ff25f2abf0e055dae08cfc789fa00d6c: 87 tests (72 core, 5 configured CLI,
10 old CLI) passed, eight existing intentional ignores; eight selected CSV
comparisons matched. Actual kill regression and five publication fault tests
passed. Fmt, strict locked Clippy and diff-check passed; no concrete defect
found by read-only peer review. macOS arm64, Rust/Cargo 1.98.1, Java17.

Primary /private/tmp/t0025-s01-primary.t2cXuE: stdout SHA256
6cd62b5d1f648c98860e4b90a22ee79ac2f5035915a66c102b38c38ce8d81ecc;
stderr 52bf09dc42db1ccdf0b71e7e4af82af86354684e493786791b4161461f9931fd.
Independent /private/tmp/emburk-t0025-acceptance.6RzodA/demo.log SHA256
c5ed2e4f0e6e6d5d3552530b9419f4aebf973b7401180e8b2b1fd73add478bda.
Both numeric exit 0, exit-file SHA256
9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa.
Parent #22 remains open in Backlog for resume and broader transaction scope.

## Stop rule and non-claims

Stop on overwritten/unowned deletion, unexplained differential mismatch, new
dependencies, source/IP uncertainty or unsafe cleanup. No full distributed
transaction, replacement semantics, hardware durability, cancellation, resume,
multi-output atomicity, hostile same-UID defense, or patent/FTO clearance claim.

No external implementation was consulted or copied for this original state
machine; existing provenance remains applicable to CSV reference behavior.

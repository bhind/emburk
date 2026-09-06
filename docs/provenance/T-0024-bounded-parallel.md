# T-0024/S01 bounded formatting and cancellation

Issue: [#21](https://github.com/bhind/emburk/issues/21). State: Done via PR #120.
Accepted: 5 SP. First independently acceptable part of stage 7; resume follows.

## Authority and dependencies

Owner authorized stages 1–7 and routine testing/integration absent incidents.
T-0033/S01 integrated through PR #119 (95b5592), with 97 tests and thirteen
selected comparisons at 39c97d8. Existing publication states remain unchanged.
No Embulk scheduling/performance parity is inferred from native unit evidence.

## Branch and allowlist

Branch feat/t-0024-bounded-parallel. PM owns initial dependency metadata changes
to Cargo.lock and crates/emburk-cli/Cargo.toml. Rust Core Implementer then owns
only core/src/bounded_parallel.rs under crates/emburk-core; after that adapter
returns, PM serially owns integration in core/src/lib.rs and configured_csv.rs,
CLI src/main.rs and tests/bounded_parallel.rs, plus adapter review fixes.
No concurrent source mutation. PM owns this packet, ADR-0020, STATUS/TODO/
ROADMAP/COMPATIBILITY/ARCHITECTURE, implementation sequence, provenance index,
T-0033 closeout, ADR-0019 status, third-party notices and daily log.
Reviewers are read-only. PM additionally owns publication.rs only for a borrowed
cancel flag check immediately before linking and its regression test. This is
required to cover cancellation during flush/sync; publication states and
no-clobber behavior remain unchanged. Do not mutate old regression sources.

The adapter returned uncompiled without tests; PM then took serial ownership
of the same source allowlist for compilation, integration and acceptance tests.

## Dependency admission

Add ctrlc=3.5.2 to the CLI only, default features (no termination feature).
Official exact archive accessed 2026-09-06:
https://static.crates.io/crates/ctrlc/ctrlc-3.5.2.crate, SHA256
e0b1fab2ae45819af2d0731d60f2afe17227ebb1a1538a236da84c93e9a60162.
Compare all new lock entries with the previously verified prospective archive
inventory before building. Selected platform graph: Unix nix/libc; macOS
dispatch2/block2/objc2; Windows entries are lock-only here. Licenses are MIT or
Apache-2.0 except dispatch2 (Zlib/Apache/MIT) and block2/objc2/objc2-encode (MIT).
No new unsafe code in Emburk. Dependency unsafe/platform code is not audited
by forbid(unsafe_code). Only API usage and manifest/build/license metadata
influences this original adapter. Full security/SBOM/patent/FTO remains
unreviewed; no redistribution or legal clearance claim. Stop on graph change
or tool approval denial. sha2 is not admitted by this slice.

The resolved registry lock contains 34 entries, all matching the prior exact
archive inventory or integrated graph. Inspected new build.rs in nix 0.31.3,
objc2 0.6.4 and libc 0.2.189: platform cfg generation, compiler/version probes
(including optional emcc/freebsd-version probes), not an installer. Their
package archive checksums/versions are fixed in Cargo.lock. No source bodies
from Embulk were read or copied for this original scheduler.

## Acceptance

Configured exec.max_threads accepts 1–8 with min_output_tasks=1. Source parsing
remains serial; worker threads format independent owned records, and only the
coordinator writes results in source order. Admission counts the entire
uncommitted window (queued, executing and out-of-order completed), at most
2 * workers <=16 records. A worker count alone is not the memory bound.
Selected record payload is <=1 MiB (existing CSV/JSON limits); formatted result
is <=3 MiB including escaping/column overhead. Bound queues and reordering by
the same window. Report worker panic/error instead of silently losing a row.
No all-file collection, unbounded reorder map or blocked-join failure path.

CLI SIGINT sets an AtomicBool through ctrlc; core only sees that borrowed
cancellation flag. Check before admission, while waiting, before ordered write,
and before encoder finalization. Pre-publication cancellation returns nonzero
(CLI 130) and does not publish; cancel after irreversible publication cannot
delete or roll back a target. Drop senders/receivers and join every worker on
error/cancel. No hard interrupt latency promise for blocking filesystem I/O.

Tests force out-of-order completion, admission high-water limit, source/worker/
writer failure, panic, pre-cancellation and cancellation while waiting. Actual
CLI tests compare serial/parallel bytes across selected CSV/JSON/codecs/filters,
reject 0/>8 workers before output, and signal an active child with SIGINT then
reap it, verifying unpublished output and cleanup. Keep all existing tests and
both selected real-reference drivers. No benchmark/speedup claim is accepted.

## Demo Command

`cargo fmt --all -- --check && cargo clippy --locked --workspace --all-targets -- -D warnings && cargo test --locked --workspace && bash tests/t0032_configured_csv_differential_test.sh && bash tests/t0033_native_formats_differential_test.sh && git diff --check`

Pinned local EMBURK_REFERENCE_JAR and Java17 JAVA_HOME are required. Retain
final-head primary/independent command logs, hashes and numeric exits.

## Evidence class, stop rule and non-claims

Integrated as 24b99fab7763f4417e20422ec8a1e239d1b4069f after primary and
independent exact Demo at 4970e46a5cae9891743e78a07ef9cd418f0559ba: 106 passes,
eight existing intentional ignores, eight CSV and five format/filter matches.
Primary logs: /private/tmp/t0024-s01-primary.R6aQam; stdout SHA256
ea7dc931f9605d9686297a8b1171e50dd4a60a25ad2382f0d045e482d14b7dec,
stderr 8bedbdde19abc64b5c6efd222d3ecb7c25da1984681604a334b9ee63e5a3b002.
Independent logs: /private/tmp/t0024-s01-independent.IZVa9s; stdout SHA256
323ca5ca237d94366e97fdd81c6717915be364383471f13af85b99595ea3fdba,
stderr 5a4892be096f2141486beb3202ac6341bb695d22524a7e9d7c86215717fbe982.
Both exits 0; exit-file SHA256
9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa.
Independent pre/post revision and tracked status were unchanged. Project audits
passed with one active item before integration. Parent remains open in Backlog.

Unit/Contract and local Integration, selected differential regressions only.
Stop on unbounded admission, ordering mismatch, deadlock, unjoined worker,
unsafe output, dependency/IP issue or unexplained reference mismatch. No full
scheduler/plugin parity, speedup/RSS benchmark, multi-input/output scheduling,
hard real-time cancellation, checkpoint or resume acceptance follows yet.

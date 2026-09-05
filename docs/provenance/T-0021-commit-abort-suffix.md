# T-0021/S05 private commit abort suffix

- Tracking issue: [T-0021, #18](https://github.com/bhind/emburk/issues/18)
- State: In Progress; independent planning review passed
- Priority: P1; parent T-0020
- Slice estimate: 3 SP (implementation 1, uncertainty 1, verification 1,
  environment 0). Parent Current SP is refined 8 to 13; Initial remains 5.
  S01–S04 account for 8 accepted SP; this new 3 SP slice and remaining runtime
  contract uncertainty exceed that forecast. No parent completion or duplicate
  earned points is implied.

## Authority

PM owns ADR-0010, scope, canonical records, acceptance and integration. One
Rust Core Implementer owns the exact source file below. Tester remains read-only.
Standing owner authority permits this bounded implementation and accepted PR
integration. Preserve the user's checkout and other worktrees.

## Dependencies

T-0021/S04 private last-commit handling (PR #76, `b5cfb87`), T-0013/S06 live
normal/last comparisons (PR #77, `3b16aaf`), and T-0013/S07 independently
accepted first/middle observations (PR #78, `14cc2a6`) are integrated.
ADR-0010 accepts the bounded policy change. Requeue T-0013 to Backlog with its
parent open; T-0012 stays Backlog. Use one serial active work item.

## Branch and allowlist

Branch: `feat/t-0021-commit-abort-suffix`.
Mutation owner: Rust Core Implementer, exactly
`crates/emburk-core/src/empty_lifecycle.rs` (private algorithm, comments and
original local tests only).

PM owns STATUS, TODO, ROADMAP, COMPATIBILITY, ARCHITECTURE, runtime design,
ADR-0010/decision index, provenance/index, S07 integration closeout and dated log.
Existing differential child files, shell/Python/Java tools, Cargo/dependencies,
public APIs, CLI, schema/scalar files and external artifacts stay unchanged.

## Artifacts

Replace failed-handle-only abort with failed/unattempted suffix abort after an
actual commit Result error. Preserve committed prefix report tokens, stop later
commits, close all handles, propagate the same output error through four scopes,
drop handles and invoke separate cleanup with actual input/output reports.
Do not change normal/zero-task/input-run-failure paths or fake error text.
Do not pass fixture selection into the coordinator or replay expected events.

Add first failure N=8/k=0 and middle N=8/k=4 and N=3/k=1 local tests. Assert
the full ordered typed trace, exact error and actual token contents, exactly one
cleanup per component, matching plan, no live handles at cleanup, no abort on
committed prefix and no commit after failure. Existing last failure 1/1 and 1/8
tests remain unchanged. Update private comments to the exact approved boundary.

## Acceptance criteria

- Actual fake callbacks exercise all three new supplied plans/positions.
- Complete trace and token assertions establish retained prefix, abort suffix,
  all-close, original typed error propagation and separate cleanup.
- Existing local normal, last-failure, input-failure, invalid-plan and handle
  lifetime tests pass unchanged.
- Unchanged S04 and S06 full live gates pass, including their raw controls.
- Source stays in the one-file allowlist; no public or bridge types change.
- Primary and independent Tester reproduce frozen-source Demo; final PR-head
  Demo passes before integration. Parent #18 remains open.

## Demo Command

`cargo test -p emburk-core empty_lifecycle::tests -- --nocapture && bash tests/t0013_empty_lifecycle_differential_test.sh && bash tests/t0013_output_commit_differential_test.sh`

Also require workspace tests, `cargo fmt --check`, strict workspace/all-target
Clippy, explicit Rust 2024 format checks for the two included differential child
files and `git diff --check`. Retain stdout/stderr and nonzero test counts,
source revision/hash and live evidence directories. No ignored live test may be
substituted for actual selected execution.

## Evidence class

Unit/Contract for new first/middle native behavior; regression of four existing
S04/S06 Differential projections only. No new first/middle Differential claim.

Independent read-only planning review at `a4093f1` found no blocking ambiguity.
It confirmed the one-file boundary, all three new local cases, full typed trace/
token/cleanup assertions, unchanged last-failure behavior and preserved S04/S06
live gates. This is Planning only, not implementation acceptance.

## Reference and provenance

Use only the already integrated S07 observed behavior and original local fakes.
Its packet records pinned Embulk 0.11.5 artifact/source identity, API provenance,
license/notice retention and independently reviewed raw per-index traces.
No additional upstream implementation, protocol, artifact or plugin adoption is
authorized. Copyright/license permission is not patent/FTO clearance; existing
patent, standards, redistribution/SBOM and jurisdiction gaps remain unreviewed.

## Stop rule

Repair ordinary build/test/network issues in scope. Return to PM before widening
callback fallibility, source files, public/API/bridge types, upstream-source use
or material security/IP exposure. Never discard unrelated edits or weaken a
failing regression to manufacture acceptance.

## Non-claims

No arbitrary-index/concurrent compatibility, rollback, durable publication,
retry/resume, exactly-once, cancellation, real plugin/host, values/Pages/data
transfer, default fan-out, performance or release readiness. Reports remain
opaque callback values; abort remains an infallible fake notification.

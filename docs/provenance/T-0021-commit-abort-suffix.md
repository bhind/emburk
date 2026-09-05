# T-0021/S05 private commit abort suffix

- Tracking issue: [T-0021, #18](https://github.com/bhind/emburk/issues/18)
- State: Done (bounded slice only); PR #79 integrated as `d36cf28`
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

### Primary frozen-source acceptance

Source revision: `f2d9755cc47f2451e41559f0c13719b92118fb09`.
Only the allowed core file changed; SHA-256:
`489ab3301b3b5f73747c269bd4e45ff2c3f61df88322470117c71737f57050fd`.
PM reviewed the complete diff: actual commit errors select the abort suffix,
prior reports remain intact, all handles close and no public/bridge type or
existing test changes. Three new tests compare complete typed event vectors,
actual tokens, identical plans and one separate cleanup per component; the
existing cleanup fake verifies handles have been dropped.

Primary exact combined Demo at this revision exited 0: 12 local tests passed,
two live tests intentionally ignored in the local phase and then separately
executed through their wrappers. S04 compared two cases with 13 raw controls;
S06 compared two cases with 31 raw controls plus its separate bridge tests and
unchanged S05 gate. Workspace tests passed 26 with four intentional ignores.
Format, explicit included-child Rust 2024 checks, strict workspace/all-target
Clippy and diff checks all exited 0.

Primary logs: `/private/tmp/t0021-s05-primary-acceptance.oAdVUk`.
S04 evidence: `${TMPDIR}/t0013-s04.eWPSwK`;
S06 evidence: `${TMPDIR}/t0013-s06.D2FaJt`.
Combined stdout/stderr SHA-256:
`570c2c8f9b9570bd5f3a529e81eb7c64424b0ed57367d714a5e1586000d11090` /
`2d6d1578c0228a8b196565b8452c011b0f83880e64fbbc4c546b8ffe187acae5`.

Accounting correction: prior S06 records said 30 raw controls. PM counted 31
calls and 31 markers in the unchanged wrapper, independently confirmed by the
implementer. The two Rust bridge tests are separate, not the extra raw control.
Correct STATUS/TODO/S06 provenance/log to 31; no test or acceptance gate changes.

The implementer's early external-gate attempt exited 4 with only the driver
diagnostic `S03 full probe exited 1` and empty nested stdout/stderr at
`${TMPDIR}/t0013-s04.7yUVAQ`. Its detailed cause is not established. Retain that
attempt, not a success claim. A later persistent combined invocation and the
post-commit invocation both passed; final implementer logs remain at
`/private/tmp/t0021-s05-primary.shZx2H/final-combined.stdout.log` and its stderr
peer. Primary frozen-source acceptance above passed without weakening any gate.

Independent read-only Tester reproduced the exact persistent combined Demo at
`f2d9755`: exit 0, 12 local passes/two intentional ignores, S04 two projections/
13 raw controls and S06 two projections/31 raw controls plus separate bridge
execution. Workspace 26 passed/four intentionally ignored, formatting, explicit
child formatting, strict Clippy and diff checks passed. No source finding remains.
Retained S04/S06 evidence: `${TMPDIR}/t0013-s04.qLpg8l` and
`${TMPDIR}/t0013-s06.3TVLjw`. Final output fragment logs reside at
`/private/tmp/t0021-s05-independent.6LtwAh`; fragment stdout SHA-256
`aa343e2b32ceca5642111022edea5e28383a8c82331a733a85bddb9c2994bdf2`
is not represented as the complete combined output hash.

Evidence is Unit/Contract for the new cases and existing Differential regression
only. Final-head exact Demo passed at
`02673ba295fe095eb71bf6e27b6d5d6f16a1f282`: 12 local passes/two intentional
ignores, then actual S04/S06 live gates with two cases each and 13/31 raw
controls. Retained logs: `/private/tmp/t0021-s05-final-head.fe2mVZ`;
S04/S06 evidence: `${TMPDIR}/t0013-s04.kqNcRk` and
`${TMPDIR}/t0013-s06.Vr2ryv`. Final source hash and unchanged bridge hashes,
diff boundary and Project audits passed. PR #79 integrated as
`d36cf286795011a5389699864c7c156644a92dbf`. The bounded slice is complete;
parent #18 stays open and returns to Backlog.

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

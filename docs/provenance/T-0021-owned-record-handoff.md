# T-0021/S06 private synchronous owned-record handoff

- Issue: [T-0021, #18](https://github.com/bhind/emburk/issues/18)
- State: Ready; independent packet review passed, planning PR integration pending
- Priority: P1; owner Rust Core Implementer; PM owns records and integration
- Estimate: 2 SP (implementation 1, verification 1), within Current 13 / Initial 5
- Prior accepted S01–S05: 11 SP. No parent completion or new points yet.

## Authority

Standing owner authority permits bounded implementation after readiness review
and integration after verified acceptance. Preserve user worktrees. One source
owner and one active Project item; independent Tester remains read-only.

## Dependencies

T-0012/S08/S10 private values and T-0021/S01 workspace are integrated. ADR-0013
must pass readiness review before activation. Parent T-0012/T-0013 contracts
remain open; this structural experiment does not depend on inventing their
missing reference behavior or complete parent T-0021.

## Branch and allowlist

Implementation branch: `feat/t-0021-owned-record-handoff`.
Mutation owner: one Rust Core Implementer, exactly:

- `crates/emburk-core/src/lib.rs`: register one private module only.
- `crates/emburk-core/src/logical_record.rs`: minimum pub(super) visibility for
  existing value/record types and constructors/accessors needed by sibling
  handoff tests; preserve storage semantics and all existing tests unchanged.
- `crates/emburk-core/src/record_handoff.rs`: new private seam and local tests.

PM owns this packet, ADR-0013/index, STATUS/TODO/ROADMAP/ARCHITECTURE/
COMPATIBILITY, runtime design, provenance index and dated log. No schema,
empty-lifecycle, existing child tests, external tools, Cargo or CLI edits.

## Artifacts

Follow ADR-0013's private synchronous handoff. Use typed source/sink error
variants retaining the original payload. Return accepted count on exhaustion,
never success on error. The coordinator must be fixture-independent, use real
callback results, move each record directly without cloning or queuing and stop
immediately on source or sink failure. No lifecycle callbacks or schema policy.

## Acceptance criteria

- Zero records: one terminating source call and no sink call; result 0.
- Multiple records: exact ordered source/accept trace and final exhaustion;
  result equals the number actually accepted.
- Preserve existing selected values, owned text, integer bounds, null, signed
  zeros, infinity and selected NaN bits through the real handoff path.
- Source and sink failures at first and later positions preserve typed payloads,
  accepted prefixes and exact full traces, with no post-failure calls or retry.
- Fakes cannot manufacture coordinator results or expected output; tests inspect
  actual sink contents and callback traces. Code inspection confirms no queue
  or clone in the loop. No global memory/backpressure guarantee follows.
- Primary and independent Tester run the exact Demo at frozen source; retain
  complete stdout/stderr/exit externally, resolve findings, reconcile records,
  rerun final PR-head Demo and confirm integration before completion.

## Demo Command

`cargo test -p emburk-core record_handoff::tests -- --nocapture && cargo test --workspace && cargo fmt --all -- --check && cargo clippy --workspace --all-targets -- -D warnings && git diff --check`

Require named handoff tests and a nonzero pass count; an empty filter is failure.
Existing S08/S10 storage tests must remain unchanged and pass in the workspace.

## Evidence class

Unit/Contract only. Readiness is Planning, not runtime evidence.

## Stop rule

Return to PM before lifecycle callbacks, schema/type mismatch policy, public
API/plugin traits, filesystem/config/parser/codec work, Arrow/batches, async,
concurrency, cancellation, memory-budget policy, dependencies or upstream use.
Fix ordinary local build/test failures without widening scope or weakening tests.

## Non-claims

No Embulk Differential, production transfer, File-to-File, exactly-once,
publication/durability, retry/resume, global resource bound, public value/schema
contract, numeric equality, performance, release or parent completion claim.
No new external artifact or source inspection; this is original composition
using already accepted local storage. Existing legal/provenance gaps remain
unreviewed, not cleared.

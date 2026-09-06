# T-0021/S06 private synchronous owned-record handoff

- Issue: [T-0021, #18](https://github.com/bhind/emburk/issues/18)
- State: Done; final acceptance passed and PR #96 integrated as `56ef9e9`
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

## Source review and acceptance

Final acceptance: exact Demo at PR head `8cb13ff` passed with exit 0,
five named handoff passes and 46 workspace passes/seven intentional live ignores,
format, strict Clippy and diff check. Complete logs:
`/private/tmp/t0021-s06-pr-head.wIz6Iv`; stdout SHA-256
`aead2a95367c2331c2f5151e6b93351adba5b07322f92d4aa92ae58d3ac0478a`;
stderr SHA-256
`8155d84bc729b7c8ae06883b51b04f9e7d378269a85d1eb850fb251b4c9b41cf`.
PR #96 integrated as `56ef9e9058c3751b5afdf797200e870109535f40`.
S06's 2 SP are accepted; S01–S06 total 13 SP. Parent #18 remains open and
returns to Backlog. The following chronology retains earlier pending gates;
final acceptance and integration now satisfy them. All non-claims remain.

Frozen source `8fe820bceadf62db89a5b7850abe1b9c9192be1f` follows initial
implementation `f3b0e9f`. Review removed unused sibling visibility and made
the selected-value test verify all eleven S10 double bit patterns against raw
expected integers at the sink, plus null, both booleans, integer bounds and
owned/empty text. Both first/later source and sink failures use complete ordered
traces and typed original payload assertions. Primary inspection confirms one
direct ownership move, no queue/clone, and no lifecycle/schema additions.

The exact Demo passed with exit 0 for implementer, primary and independent
Tester at the frozen source. Complete stdout/stderr/exit are retained at:

- implementer: `/private/tmp/t0021-s06-demo.CSu34r`;
- primary: `/private/tmp/t0021-s06-primary.9Ludl9`;
- independent: `/private/tmp/t0021-s06-independent.4m3s3N`.

Each ran five named handoff tests, 46 workspace passes/seven intentional live
ignores, format, strict all-target Clippy and diff check. No live Differential
test is claimed by this local Demo. Independent stdout SHA-256:
`7d5bf1fed893a82aa0c46237445d9456fc2304c3ac6eb1662c5cedc0201f4ba8`;
stderr (normal Cargo progress) SHA-256:
`738f634ac47effc5b59c390d61aa96f3b9f77f05ebde075cad0da64f0156c1be`.
Environment: macOS ARM64, Rust/Cargo 1.98.1. Local temporary logs must be
reproduced if removed; their paths are not a durable published artifact store.

Source SHA-256:

- lib: `5213b2c72a317725f9eb52a108664838bee347db9bcd798f55a48f0e031f8f8c`;
- logical record: `9398928aa5862a2b370729571b2b86ad0e6b388f43768a746eab7f46c12c3f3e`;
- handoff: `6c8a9994455e110dffd5183cadfcee754ac4733a77d0f6e26e935facc45eb4fd`.

Only the three authorized source paths changed. PM-owned documentation was
separately unstaged during source acceptance and was not reverted by agents.
Final-head Demo, record reconciliation and integration remain required.

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

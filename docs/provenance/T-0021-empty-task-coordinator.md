# T-0021/S03 private empty-task coordinator

- Tracking issue: [T-0021, #18](https://github.com/bhind/emburk/issues/18)
- State: In Progress; acceptance pending
- Priority: P1; parent T-0020
- Slice estimate: 3 SP within unchanged parent Current/Initial SP 5
- Refinement: implementation 1, uncertainty 1, verification 1, environment 0;
  raw 3 maps to 3 SP. No parent completion or duplicate velocity is implied.

## Authority

PM owns scope, accepted decision, canonical records and integration. Rust Core
Implementer owns the exact source allowlist. Tester independently reproduces
the frozen revision; PM reviews orchestration and non-claims. Standing owner
authority permits scoped implementation and integration after acceptance.

## Dependencies

T-0021/S01/S02 workspace/design and accepted ADR-0008. T-0013/S01–S03 reference
observations integrated through PR #70 (`e8b5726`), #71 (`d474b7b`) and #72
(`8e43948`). T-0012/S06's private schema remains unchanged. T-0013 returns to
Backlog for its remaining comparison/failure/recovery contracts while this
bounded prerequisite is implemented. This is not a Blocked or Done transition;
combined WIP stays one. Both parent semantic dependency gates remain open.

## Branch and allowlist

Branch: `feat/t-0021-empty-task-coordinator`.
Rust Core Implementer owns exactly:

- `crates/emburk-core/src/empty_lifecycle.rs` (new module and its unit tests)
- `crates/emburk-core/src/lib.rs` (private module registration only)

PM owns STATUS, TODO, ROADMAP, COMPATIBILITY, ARCHITECTURE, runtime design,
ADR-0008/index, provenance/index and dated log. No scalar/schema implementation,
Cargo manifests, dependencies, CLI, existing probes/comparators, public exports,
external artifacts or upstream implementation changes/inspection.

## Artifacts

Implement an original synchronous coordinator behind private typed interfaces,
following ADR-0008. An explicit validated plan distinguishes input/output task
counts and includes an output-task count cap. Permit 0/0 and 1/N with positive
N within the supplied cap; reject other plans before invoking any plugin
callback. Unsupported plan errors are internal scope/resource rejections, not
claims about Embulk validation. Counts alone do not bound memory in bytes.

Original fake input/output plugins must actually execute callbacks, produce
reports and record typed events during those calls. The coordinator receives
objects/capabilities and must not dispatch on a fixture ID, consume Java traces,
or return a predetermined expected trace. Keep job-level control scopes and
owned mutable output handles separate; use straightforward private interfaces
that permit nested control calls without unsafe aliasing. Shared job views plus
owned task handles are one option; no public Rust API is being frozen.

For the supported normal path, nest input/output transaction-control scopes,
open task-local outputs, run the single empty input callback, let its actual
finish call finish the opened outputs, collect reports via output commit,
close handles, unwind successful job/control scopes, then clean up input and
output jobs with their separate report collections. Zero input tasks invoke
job/control/cleanup scopes without opening or running task handles.

For the supported input-run error before finish, execute the same callback
path until the fake input returns its typed failure. Abort and close already
opened output handles, propagate that same failure through job/control scopes,
then invoke cleanup with available separate input/output reports. Do not call
input finish or fabricate a report/commit success. The core responds to an
actual callback Result, not a fixture flag or expected outcome table.

Cleanup must be a separate job-level capability using plan/report information,
not a requirement to retain live task handles or the transaction instance's
mutable fields. Demonstrate a fresh cleanup context on failure. Report values
are opaque internal tokens: preserve them without claiming upstream fields,
identity, serialization, atomicity or durability.

This slice supports only fake empty jobs and the selected input failure.
Setup/open/finish/commit/abort/close/cleanup fallibility and panics are outside
this private boundary; an infallible fixture interface must state that limit
explicitly and never masquerade as a complete production plugin trait.
No retry, resume, worker threads, async runtime, Pages, values, YAML, Arrow,
state persistence, real plugin execution or public loader/API is added.

## Acceptance criteria

Unit tests must inspect actual callback execution and report preservation:

- 0/0 plan, no input run or output handles, job/control/cleanup still execute;
- 1/1 and 1/8 normal plans, with distinct input/output counts and typed traces;
- selected input failure with 1/1 and 1/8 plans, same error propagated,
  abort/close rather than commit, and empty report collections to cleanup;
- fresh cleanup context objects work without live transaction/task state;
- independent input/output report collections preserve produced opaque tokens;
- invalid/multi-input/mismatched-zero/over-cap plans reject before side effects;
- no fixture-ID branching or hardcoded factor eight inside the coordinator.

One/eight cases are local contract tests, not claims of reference coverage for
arbitrary task counts. Test normal and failure callback ordering for this
selected model; do not infer cross-task parallel ordering, default planning,
delivery or general lifecycle compatibility. Unit tests must not merely compare
two manually authored event lists without invoking the coordinator and plugins.

## Demo Command

`cargo test -p emburk-core empty_lifecycle::tests -- --nocapture`

Verify a nonzero selected test count and all passing; also run
`cargo test --workspace`, `cargo fmt --check`,
`cargo clippy --workspace --all-targets -- -D warnings` and `git diff --check`.
Existing live tests may retain their explicit ignored markers; no JVM/network
execution is required or claimed by this Rust Unit/Contract slice. Tester
independently reproduces the frozen source and PM verifies the final PR head.

## Evidence class

Unit/Contract only. Reference observations motivate the candidate, but this
slice does not perform Differential comparison. A later T-0013 packet must
define and execute that comparison without silently broadening its projection.

## Reference and reuse record

Access/review date 2026-09-06. Implementation is independently authored from
repository-owned design and the bounded observed callbacks in T-0013/S01–S03.
Exact executable/source pins and public API locators remain in those records:
Embulk 0.11.5 executable SHA-256
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`, core
`c5ac2d471edac465b45088669d376a7e2a525f8f`, SPI 0.11
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`. No upstream implementation/test
code is copied or mechanically translated. Core/SPI source classification is
Apache-2.0; notices and exact locators remain in T-0011 and the actual probes.
No new external dependency/plugin is admitted or JAR redistributed. Transitive
SBOM/notices, redistribution, patent/standards/trademark, jurisdiction and FTO
remain unreviewed; these observations do not provide legal clearance.

## Source acceptance

PM reviewed and ran the exact Demo at source revision
`84edf00dc91a5f046dd9ab27998bfb82c430ec45` on 2026-09-06. The five selected
tests passed (nonzero, no ignored selected tests). `cargo test --workspace`
passed 19 tests with two explicitly ignored external live comparisons.
`cargo fmt --check`, strict workspace/all-target Clippy and `git diff --check`
all exited 0. Environment: macOS arm64, rustc 1.98.1
(`48a229cea`), cargo 1.98.1 (`797e8a9bc`). No JVM or network evidence is claimed.

The review corrected cleanup that initially remained coupled to job objects,
failure operation ordering and scope outcome propagation. Separate cleanup
receivers now assert zero live task handles through Drop counters. Typed event
traces are generated by actual callback calls; full distinct report values,
not just counts, are asserted. The core receives the returned failure and
passes the same outcome through all four scope-completion callbacks.

Frozen source SHA-256:

- `crates/emburk-core/src/lib.rs`:
  `e1617bbeee789c3933950354c2ffc80c8f1e9fee7b990335b13054d675101c48`
- `crates/emburk-core/src/empty_lifecycle.rs`:
  `dd73ec198040596c3fb7ceaed81b3212341195b6de302ec7e201ae0996471128`

Independent Tester reproduced all commands at the frozen source (all exit 0),
including five selected and 19 workspace passes with two intentional ignores.
Read-only source audit confirmed both files match the frozen commit. No
acceptance finding remains. Raw logs are local-only at
`/private/tmp/emburk-t0021-s03-acceptance.qVK6vU`; Demo log SHA-256 is
`c9eca34fc1357c827c10ac65b846960f3c9f8a4bd249c56f74c068de340741c8`, workspace
log SHA-256 is
`943c519ade34e436258f9fcdf6ffae3c82c72e21e3d6f8ce2fac18c5860b9cb3`.
Final-head acceptance and integration remain pending.
Evidence is Unit/Contract only; the parent Issue and live comparison gate stay
open. This is not an integration or completion declaration.

## Stop rule

Repair ordinary compile/test issues in scope. Stop expansion for unobserved
callback failures, public APIs, multi-input scheduling, value/host/persistence
work, new artifacts/upstream implementation inspection or material IP/security
uncertainty. Preserve unsupported boundaries; do not weaken acceptance to
obtain a passing test or silently change the user checkout.

## Non-claims

No Differential result, full lifecycle or plugin compatibility, default output
mapping, global memory bound, throughput, data transfer, rollback, durability,
cleanup guarantee, retries/resume, exactly-once, security or release claim.
Parent #18 stays open after bounded slice acceptance.

# T-0013/S08 selected commit-position differential

- Tracking issue: [T-0013, #16](https://github.com/bhind/emburk/issues/16)
- State: Prepared; implementation waits for Ready and activation
- Priority: P0; parent T-0010
- Slice estimate: 3 SP (implementation 1, uncertainty 1, verification 1,
  environment 0). Parent Current 34 / Initial 8 remain unchanged. S01–S07
  account for 21 accepted SP; this independently acceptable slice fits within
  that forecast. No parent completion or duplicated earned points is implied.

## Authority

PM owns scope, records, acceptance and integration. One Compatibility Host
Implementer owns the four test-infrastructure paths below. Tester remains
read-only. Standing owner authority permits bounded implementation and accepted
PR integration; preserve the user's checkout and unrelated worktrees.

## Dependencies

T-0013/S07 original first/middle reference observations are independently
accepted and integrated through PR #78 (`14cc2a6`). ADR-0010 and T-0021/S05
private native abort-suffix behavior are integrated through PR #79 (`d36cf28`)
after independent and final-head acceptance. S04/S06 comparison tools remain
accepted regressions. Requeue T-0021 to Backlog with parent #18 open; T-0012
stays Backlog. Use one serial active item and a separate read-only acceptance
lane. No new runtime policy or ADR is needed for this test-only comparison.

## Branch and allowlist

Branch: `test/t-0013-commit-position-differential`.
One implementer owns exactly:

- `tools/t0013-output-commit-position-differential` (new Python driver);
- `tests/t0013_output_commit_position_differential_test.sh` (new wrapper);
- `crates/emburk-core/src/empty_lifecycle/output_commit_position_differential_tests.rs`
  (new private child test module);
- `crates/emburk-core/src/empty_lifecycle.rs` (registration-only inclusion of
  that child; no algorithm, type, fake, existing test or comment changes).

PM owns STATUS, TODO, ROADMAP, COMPATIBILITY, ARCHITECTURE, runtime design,
provenance/index, S05 integration closeout and dated log. Existing S04/S06/S07
tools, fixtures and child tests, Cargo/dependencies, public exports, CLI, scalar,
schema and runtime behavior stay unchanged. Original repository-owned S06/S07
validation/test patterns may be adapted; no upstream implementation copying.

## Artifacts and comparison boundary

Invoke exactly `bash tests/t0013_output_commit_position_probe_test.sh`. Require
successful exit and exactly one `T0013_POSITION_FULL_PROBE=passed|evidence=...`
marker; retain its stdout/stderr, three cases, raw logs/traces and identities.
Never substitute capture-only or artifact-only output. Preserve executable URL/
SHA, input/output source identities, local artifact hashes, coordinates and raw
hashes. The unchanged S07 gate includes its 57 semantic controls, two artifact
controls and the full S05 regression.

The new driver independently validates raw evidence before projection and in a
`--validate-only` mode used by mutated-copy controls. Preserve S07's envelope,
canonical Base64, UUID/sequence, raw-log/digest, exact callback manifests,
per-index pairs, scope/physical order, fresh failure cleanup and report checks.
Reject missing/duplicate/unknown cases, empty evidence, extra callbacks and
malformed or contradictory transport. Require exactly normal, commit-first,
commit-middle in that order; input count 1, zero-column schema, observed N >= 3,
and explicit cap 1024 checked before allocating per-index structures.

Derive selection from validated output markers: normal N-1 without injection,
first 0, middle floor(N/2). Validate both mode and index. Use header
`T0013-S08\t1` and a documented strict owned manifest with actual N, selected
index/scenario, actual result/report counts and ordered projected events.
No hard-coded observed N=8 or k=4 may drive either execution or acceptance.

Validate exact Java error class
`T0013CommitPositionOutputPlugin$InjectedCommitFailure` and message
`t0013-output-commit-position-failure` at the selected terminal and both outer
transaction exceptions. Selection, injection, entry/pair and capture metadata
may be excluded only after their own strict validation, with explicit named
projection exclusions. Preserve observable physical order in compared events.

The Rust child executes the actual private coordinator with supplied plan and
original fakes. The fake chooses the selected index; the coordinator still
receives no fixture identifier/index policy. Validate the actual Rust result,
report tokens/counts, exact `OutputFailure("selected last commit failure")`,
one selected failed-commit event and exactly one of each of the four typed
failed scopes before category/index normalization. No input failure substitution,
missing scope or payload may disappear in filtering. Only the two Rust control
failure completions absent from Java instrumentation may be excluded after
validation, as in S06. Reject unknown/unexpected events rather than dropping them.

Compare exactly three selected projections:

- normal: all successful commits, no abort, all closes, reports input 1/output N;
- first/middle failure at k: successful prefix [0,k), failed k, no later commit,
  abort suffix [k,N), all closes, reports input 1/output k, same typed category.

Compare actual ordered event vectors, not just totals or a synthesized expected
trace. Equal failure marker totals cannot identify which handles committed or
aborted. Report presence remains a callback fact, not a durability assertion.

## Acceptance criteria

- All three live projected fixtures compare actual reference and Rust execution.
- Strict raw controls repair sequence, digest and raw-log transport before
  testing semantic rejection and assert the intended diagnostic.
- Controls cover case/event grammar/identity, counts/schema/cap, mode/index,
  exact terminal/outer payloads, later commit fabrication, missing suffix abort,
  abort of committed prefix, missing close, scope/phase/cleanup order and reports.
  Exercise position-specific failures in both first and middle cases.
- Local manifest controls reject missing/duplicate/unknown cases, invalid counts/
  selection/scenario/result/report fields and mutated ordered events. Repair
  event counts so semantic controls do not fail at incidental envelope checks.
- Direct mutated Rust-result/trace controls reject payload/category/index,
  missing/extra/substituted failed scopes, later commit, wrong abort suffix or
  committed-prefix abort, missing close, wrong reports/order and normal failure.
- Include valid local N=3 and N=8 contracts, clearly Unit/Contract only; live N
  is read from the actual reference, never assumed.
- Existing S04 and S06 full live gates remain unchanged and pass separately.
- Primary and independent Tester reproduce frozen-source Demo; final PR-head
  Demo passes before integration. Parent #16 remains open.

## Demo Command

`bash tests/t0013_output_commit_position_differential_test.sh && bash tests/t0013_empty_lifecycle_differential_test.sh && bash tests/t0013_output_commit_differential_test.sh`

Require exactly three new compared cases and actual selected Rust live-test
execution with a nonzero passing count. Require S07's unique full marker, both
existing regressions and all negative gates. Also run workspace tests, format,
strict workspace/all-target Clippy, explicit Rust 2024 formatting of all three
included child files, separate shell syntax checks, Python syntax with external
cache, source hashes and both ordinary/staged diff checks. Retain stdout/stderr,
raw evidence and normalized manifest hashes at the reviewed revision.

## Evidence class

Unit/Contract for strict adapters/negative controls, plus Differential (Embulk)
only for the three selected empty-fixture projections after acceptance. No new
runtime policy, arbitrary-index/concurrent equivalence or parent completion.

## Provenance and non-claims

Use original repository-owned S06/S07 patterns and their pinned Embulk 0.11.5
reference provenance. No new artifact, protocol, dependency, plugin admission
or upstream implementation inspection/copying is authorized. Existing license/
notice identity checks remain. Redistribution/transitive SBOM, patent/standards,
trademark, jurisdiction and freedom-to-operate gaps remain unreviewed, not cleared.

No real plugin/host/API, Pages/data transfer, default fan-out, rollback/durable
publication, retry/resume, exactly-once, cancellation, performance or release claim.
UUID captures are instrumentation, not recoverable session identifiers.

## Stop rule

Fix ordinary build/test/network issues in scope and retain failed attempts.
Return to PM before any runtime change, source allowlist expansion, different
fixture/artifact, public API, new normalization exclusion or material IP/security
uncertainty. Never weaken a guard, invent observed success or alter the user's
checkout to complete the gate.

# T-0013/S08 selected commit-position differential

- Tracking issue: [T-0013, #16](https://github.com/bhind/emburk/issues/16)
- State: In Progress; independent packet readiness review passed
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

Independent read-only planning review at `f51e535` found no material ambiguity.
It confirmed the exact four-file boundary, immutable S07 full gate, dynamic
three-case projection, raw validation before exclusion, separate runtime-local
error checks and unchanged S04/S06 regressions. This is Planning only, not a
new observed match or source acceptance.

### PM manifest and projection decision

The reviewed owned format has header `T0013-S08\t1` and exactly 11 CASE fields:
`CASE`, fixture, input_tasks, actual_N, cap, selected_index, scenario, result,
input_reports, output_reports, event_count. EVENT rows retain actual projected
physical order. Fixtures are normal/commit-first/commit-middle; scenarios are
normal-output/fail-first-commit/fail-middle-commit. Results are success or
selected-output-commit-failure. Mode/index formulas and counts must agree with
the validated raw reference, never a missing-field fallback.

After full raw validation, Java projection excludes only input finish-before,
run-normal-return and cleanup-entry; output commit-selection,
commit-injection-before and cleanup-entry; and output open/finish/commit/abort/
close entry instrumentation. Their matching returns, normal scopes, failed
transaction outcomes and cleanup returns remain represented. Rust excludes only
the two validated failed control completions absent from that instrumentation;
failed job/commit outcomes normalize category/index only after exact payload
checks. All event mapping remains exhaustive. No further exclusion is approved.

Artifact identity validation belongs to the mandatory unchanged full S07 live
gate; the driver retains those complete identity records alongside its raw
hashes. `--validate-only` validates raw envelopes, capture identity, log/digest
consistency and semantics of control copies. It is not artifact admission or a
substitute for the live gate and cannot establish a live comparison by itself.
Independent moving-draft review found no additional raw/projection gap beyond
the PM's requested cap-before-allocation, ordinary validator function, exact
Bash invocation and complete identity-retention corrections. Final source and
actual acceptance remain required.

### Primary frozen-source acceptance

Source revision: `4c591a064b3196b243db9f9b5befd885749b9628`.
Exactly the four owned paths changed; the coordinator edit only registers the
new child. SHA-256 (driver, wrapper, Rust child, registration file):

- `f1ba46d6f581bf51abfaaccaa0325532c6ae35cbd1e9283dafc461cc29c47389`
- `3a7faa157c590dd23c4ab231feb7a0ce4e9e26bc07ad4b49bb61ffefd5b9cec0`
- `9dab02e74d1d63c1e4c96c10d8df6fb36974518454e1684585744b1fb6ed8769`
- `61d24e7a4d74826db1ea732e4c42cc9518a1d6ae4cba3f18c13b2dca1b356878`

PM reviewed the complete adapter/bridge/wrapper. Before freezing, review moved
the cap before allocation, replaced dynamic execution with an ordinary validator,
made exclusions exhaustive, removed an unapproved cross-case equal-N assumption,
and added mixed N=3/8 local validity. Direct negative tests now start from fresh
execution contexts and assert the intended diagnostic; a draft had accidentally
left a mutated plan that could mask later trace defects. Failed control closure
order is checked before those otherwise unobserved events are excluded.
All findings were resolved before the frozen-source acceptance below.

Primary exact three-script Demo at this revision exited 0. S08 compared three
live projections with 57 repaired raw controls, three local Rust contract tests
and one actually executed ignored-live test. The unique full S07 gate passed,
including its 57 controls, two artifact controls and unchanged full S05 gate.
Unchanged S04 and S06 regressions compared two cases each with 13/31 raw controls.
Workspace tests passed 29 with five intentional live-test ignores; format,
strict workspace/all-target Clippy, explicit Rust 2024 child formatting, separate
shell syntax, external-cache Python syntax and diff checks all passed.

Primary combined logs: `/private/tmp/t0013-s08-primary-acceptance.eTcg45`.
S08/S04/S06 evidence: `${TMPDIR}/t0013-s08.f4vL9U`,
`${TMPDIR}/t0013-s04.3mC8zx`, `${TMPDIR}/t0013-s06.F6dYCx`.
Reference evidence: `${TMPDIR}/t0013-output-commit-position.YiBPe0/evidence`.
Combined stdout SHA-256:
`45a218333b2028c5227ce94e63e4cae0ac3b5fc3743ff89018a86e00556fe3ba`;
stderr is empty. Normalized manifest SHA-256:
`29421eae3f2d625b8f4f9576644c3d9b3648df70c6d9a05792351f1faff8ec06`.
Raw cases/traces SHA-256:
`093a3679990378fa3a756d80ff2d99f88781478ac9e20387ebbc0d3ee091a386` /
`f5ff0dd583128b49343b380472e08e3e988beaccbd51cb99b4642be1767f71d2`.

Observed N=8 in this run: normal compares 44 events and reports 1/8; first k=0
and middle k=4 each compare 43 events with reports 1/0 and 1/4. Complete event
equality, not those equal failure totals, establishes the different committed
prefix and aborted suffix for each selected case. Exact runtime-local errors
were validated before normalization. Local N=3 and mixed N tests are
Unit/Contract, not additional reference observations. Independent reproduction,
final-head acceptance and integration remain required; no wider claim follows.

### Independent frozen-source acceptance

The read-only Tester independently reproduced the exact three-script Demo at
`4c591a064b3196b243db9f9b5befd885749b9628`, with actual tool exit 0 and
`CHILD_EXIT=0`. All four source hashes and the registration-only boundary match.
Combined logs: `/private/tmp/t0013-s08-independent-persistent`; stdout SHA-256
`20ffdb8a76b575c39faf4a065ab36003315c9bf29dbb7bb5e21691ab87438db`;
stderr is empty. S08/S04/S06 roots are `${TMPDIR}/t0013-s08.mrgCcv`,
`${TMPDIR}/t0013-s04.fklU8w`, `${TMPDIR}/t0013-s06.MZXU4h`.
The normalized manifest hash matches the primary run. Three selected live
projections, 57 new raw controls, three local Rust controls, actual ignored-live
execution, full S07 gate and unchanged S04/S06 regressions passed. Workspace
29 passed/five intentional ignores, formatting, strict Clippy, explicit child
formatting, shell/Python syntax and diff checks passed independently.

Retained non-passing attempts remain distinct: the sandbox run under
`/private/tmp/t0013-s08-independent.TC9pWu` encountered an artifact-control
download failure; early nonpersistent network yields were not child exits.
Two incorrect explicit-rustfmt filename attempts were harness errors, corrected
in the final successful command. No source guard was weakened. Evidence remains
Unit/Contract plus the three selected Differential projections only. Final-head
acceptance and PR integration remain required.

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

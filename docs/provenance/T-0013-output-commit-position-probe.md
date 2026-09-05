# T-0013/S07 output commit position observation

- Tracking issue: [T-0013, #16](https://github.com/bhind/emburk/issues/16)
- State: In Progress; Stage A fixture preparation, initial capture and acceptance pending
- Priority: P0; parent T-0010
- Slice estimate: 3 SP (implementation 1, uncertainty 1, verification 1,
  environment 0). Parent Current SP is refined 21 to 34; Initial SP remains 8.
  S01–S06 account for 18 accepted SP. This observation consumes 3 further SP;
  native policy/comparison and remaining cleanup/recovery uncertainty require
  forecast capacity beyond the previous 21. This is forecast refinement, not
  parent completion, automatic child allocation or duplicated earned points.

## Authority

PM owns scope, the observation-to-expectation decision, canonical records,
acceptance and integration. One Compatibility Host Implementer owns the three
source/test paths serially. Tester is read-only. Standing owner authority permits
bounded implementation and integration after acceptance. A source observation
must not silently become a Rust policy or compatibility exception.

## Dependencies

S05 selected last-index reference (PR #75, `2901c31`), T-0021/S04 private
implementation (PR #76, `b5cfb87`) and S06 two-case comparison (PR #77,
`3b16aaf`) are integrated. S06 final-head acceptance passed at `7d90f5d`.
T-0012 and T-0021 remain Backlog; one serial T-0013 mutation lane remains.

## Branch and allowlist

Branch: `research/t-0013-output-commit-position-probe`.
One implementer owns exactly three new files:

- `tools/t0013-output-commit-position-probe/src/T0013CommitPositionOutputPlugin.java`
- `tools/t0013-output-commit-position-probe/run.sh`
- `tests/t0013_output_commit_position_probe_test.sh`

PM owns STATUS, TODO, ROADMAP, COMPATIBILITY, ARCHITECTURE, runtime design,
provenance/index and dated log. Existing S03 input, S05/S06 tools, Java fixtures,
all Rust, public APIs, dependencies, CLI, schema and scalar files stay unchanged.
Generated Java artifacts and downloaded executable remain outside the repository.

## Artifacts

Use the unchanged repository-owned S03 input fixture under distinct local-only
S07 Maven coordinates. New output is an independently maintained adaptation of
the original local S05 instrumentation, not upstream implementation. Preserve
callback entry/return capture and UUIDv4/per-capture sequencing. Record exact
source paths/hashes and a diff against S05, pinned executable URL/SHA/license/
notice/Java version, local jar hashes/coordinates, three raw logs, cases/traces,
digests, process exits and counts. No new external artifact is needed.

Fixtures are exactly `normal`, `commit-first`, `commit-middle`, avoiding the
input fixture's special `failure` identifier. Require observed output N >= 3
to distinguish first/middle/last positions. Select 0 for `commit-first`, N/2
(integer floor) for `commit-middle`, and N-1 for the normal control without
injection. Reject unknown modes and unusable counts; never substitute another
fixture or assume N=8. Emit `commit-selection` fields count, mode, index before
control execution. For selected failure fixtures, throw an original
`T0013CommitPositionOutputPlugin$InjectedCommitFailure` with message
`t0013-output-commit-position-failure` only from the chosen handle's commit,
before creating its TaskReport. Other callbacks remain the original empty fakes.

Use `POSITIONOUTTRACE` output markers, unchanged `FAILTRACE` input markers,
`POSITIONCASE` case envelopes, `T0013_POSITION_EVIDENCE_DIR` evidence marker and
`T0013_POSITION_NEGATIVE` artifact-control selector. Keep evidence/artifacts
separate from S05/S06; capture UUIDs are instrumentation only.

### Stage A: capture before choosing post-failure expectations

PM reviews fixture/runner source and pinned-artifact controls before the first
live capture. Run the new runner to retain normal/first/middle raw observations.
The initial wrapper may offer `--capture-only` to check envelopes/grammar,
canonical Base64/UUID/sequence, log/hash/count consistency, empty schema,
N >= 3, selection formulas and exact locally injected commit exception. Check
that input failure, add/guess/resume were not activated. It must emit a distinct
capture-only marker, never `T0013_POSITION_FULL_PROBE=passed`.

Do not assert which later handles commit, abort or close, which reports survive,
or which outer scopes return/throw until the raw capture has been reviewed.
Initial capture is evidence collection, not task acceptance or a Rust contract.

### Stage B: PM freezes only observed acceptance expectations

PM inspects both failure traces in full and records, for every output index,
whether commit was entered/returned/threw, abort occurred and close occurred.
Also record input completion, exact outer exception propagation, physical
cross-component order, scope completion, fresh cleanup captures and separate
report counts. Distinguish committed, selected-failed and not-attempted handles
without assuming a shared cleanup policy.

Only after that recorded decision may the implementer add strict acceptance
expectations and targeted semantic controls. Surprising behavior is a new
observation to classify, not an incident by itself or permission to change Rust.
No broader policy is adopted in this slice; a later packet/ADR must decide it.

## Acceptance criteria

- Stage A source review, initial raw capture and PM expectation decision exist.
- Exact normal/first/middle fixtures execute; N and selection are read from
  traces, never hard-coded. Require nonzero marker counts and all three cases.
- Validate raw envelope, source/artifact identity, exact callback manifests,
  per-index pairs, error payloads, physical phases/scopes/cleanup and report
  counts against the independently recorded Stage B expectations.
- Corrupt-copy and unavailable-executable controls fail at their intended gate.
- Missing/duplicate/unknown/malformed events/cases, selection/count/schema/index
  errors, wrong exception/payload, missing commit terminal/abort/close, altered
  later-handle behavior, invalid scope/cleanup order and report counts reject.
  Semantic mutations must repair sequence, hashes and raw-log envelopes first
  and assert the intended diagnostic rather than incidental transport failure.
- The unchanged full S05 gate is a required regression within the new wrapper;
  its unique final marker and both cases/23 controls must pass.
- Primary and read-only Tester reproduce frozen-source Demo; final PR-head Demo
  passes before integration. Parent #16 remains open.

## Demo Command

`bash tests/t0013_output_commit_position_probe_test.sh`

This is an acceptance command only after Stage B. It must emit exactly one
`T0013_POSITION_FULL_PROBE=passed|evidence=...` marker after all three cases,
negative controls and unchanged S05 regression pass. Also run separate `bash -n`
on runner and wrapper, `git diff --check`, and verify source allowlist/hashes.
Keep captured stdout/stderr and raw artifacts for primary and independent runs.

## Evidence class

Planning only until capture. Intended acceptance: Reference Observation /
Integration using the pinned executable and original local fixture only.
No new Rust Differential result follows. Read-only planning review recommended
the three-file, two-stage scope and dynamic first/middle selection; PM owns the
forecast refinement and the later raw-to-expectation decision.

## Reference and reuse record

Review date: 2026-09-06. Official executable:
`https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar`;
SHA-256 `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`.
Embulk core `c5ac2d471edac465b45088669d376a7e2a525f8f`, SPI 0.11
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`; exact API/license locators and
Apache-2.0 classification remain in T-0011/S05. Unchanged input source SHA-256:
`d45f0b6e83d39458331a2cf1be27a01d1b6863017bd87807f0e49d160c96d252`;
owned S05 output SHA-256:
`6889081e838e19052ba7ea34193a8ad7bf64ec5b7339e4d825e1ad09adfb65d3`.
No upstream implementation/test inspection or copying, new protocol mechanism,
external dependency or plugin admission is authorized. Preserve existing pinned
artifact notices. Redistribution/transitive SBOM, patent/standards/trademark,
jurisdiction and freedom to operate remain unreviewed, not cleared.

## Stop rule

Repair ordinary test/build/network issues in scope. Return to PM before widening
artifacts, callback fallibility, fixture boundary, upstream-source use, public
API or materially uncertain security/IP exposure. Pause only the transition
from initial capture to post-failure assertions until PM records the evidence
decision; other safe in-scope checks may continue. Never manufacture a passing
capture, infer later-handle behavior or alter the user's checkout.

## Non-claims

No Rust first/middle policy, arbitrary-index equivalence, concurrency/default
fan-out contract, rollback/durable publication, retry/resume, exactly-once,
real plugin host/API, values/Pages/data transfer, performance or release claim.
Callback success and TaskReport presence are not durability acknowledgements.

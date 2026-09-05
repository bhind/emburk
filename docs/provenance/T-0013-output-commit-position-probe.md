# T-0013/S07 output commit position observation

- Tracking issue: [T-0013, #16](https://github.com/bhind/emburk/issues/16)
- State: In Progress; Stage A captured, PM Stage B expectations recorded; acceptance pending
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
Independent read-only planning review at
`415c6977a0e4b23e63bbade93f3bc74e82c9faa6` found no material ambiguity.
It confirmed distinct first/middle/last indices even at N=3, the exact three-file
allowlist, fixed marker/error names and the capture-only-to-expectation gate.
The review ran no fixture and provides no observed post-failure behavior.
The Project's active-slice evidence field is `Integration`, reflecting the
intended reference-fixture acceptance class, not a completed result. The parent
Differential gate remains open. Replace its stale bootstrap Demo placeholder
with the exact Stage B command; capture-only execution cannot satisfy it.

### Pre-capture source review

PM and read-only Tester reviewed Stage A before any positive fixture ran.
Java SHA-256 is
`fd82c85966b90190a82e8a29d4a2b4145bf82c8776045d362116ddd7ef6bbb64`;
runner SHA-256 is
`20ec0c780a243412ffbc20f4ad700bddeccd29fb4c8a12c4e2c448c02ba7c423`;
capture wrapper SHA-256 is
`993596195dab55b116ace71fc317cb83acfde2e91f3bee585d86ac8246bffc5e`.
Both reviewers confirmed the three-file boundary, exact artifact/source identity,
selection instrumentation and throw-before-TaskReport construction. Separate
shell syntax, Python AST parsing, default-wrapper refusal (exit 2) and diff
checks passed. Artifact-only controls rejected corrupt-copy at exit 3 and
unavailable executable at exit 56; they did not execute the fixtures.
Staging exposed one extra blank EOF line in each new Java/runner file that an
unstaged diff check could not see. PM verified their removal was byte-for-byte
whitespace-only by reconstructing both prior hashes; cached diff checks passed
before approving the final hashes above. No fixture semantics changed.

Review removed a premature failure-process-exit assertion. Stage A now records
that exit without judging it, and checks each local injected error pair without
assuming one commit invocation. Its singleton transaction/selection qualification
only identifies an unambiguous supplied plan. Unexpected multiplicity still
retains complete runner logs before capture validation rejects; PM must inspect
and classify it rather than infer that host repetition is impossible.

Tester recommended additional callback completeness checks. PM defers semantic
completeness/per-index callback assertions to Stage B: capture-only is collection,
not acceptance, and cannot qualify a truncated or unusual trace as compatible.
PM will inspect all initial raw callbacks and process exits before freezing any
expectation. The source is approved for the first capture only; neither review
establishes post-failure behavior or task completion.

### Initial capture and PM Stage B decision

Stage A source revision: `fb26813b09cd0416d93cc171253c96931b3b32fe`.
Command: `bash tests/t0013_output_commit_position_probe_test.sh --capture-only`.
The capture wrapper exited 0 and emitted only its collection marker. Evidence:
`${TMPDIR}/t0013-output-commit-position.vSfSxA/evidence`; retained wrapper output:
`/private/tmp/t0013-s07-initial-capture.u5ITuQ`.

The implementer's outer shell chain subsequently exited 1 because it incorrectly
required empty stderr. PM inspected all 829 stderr bytes: the known pinned-JAR
7451-byte ZIP-prefix warnings and Java deprecation notes, not a failed fixture
or empty capture. Retain this result; do not claim the whole outer chain passed.
The exact Stage B Demo will independently rerun the actual acceptance gate.
Wrapper stdout/stderr SHA-256:
`fe37e0463b44aaf1836ae202fe74c89998e1f4e0ecf81dd90fb0fc42776fec65` /
`bccc90b82673e2c3d11d6d2e444c9b716ee1a328208d393a60ac1165055ed09b`.
Raw cases/traces SHA-256:
`ac6b0e6a4ccba08015e0256e1fa7535f8f28fb417048c856cd0e8cad2fdd404f` /
`37e4cef7eac821f5393f9196f0da1dc32e3148c0548ed1842e40461e137f8148`.

PM decoded and inspected all 245 raw markers before choosing expectations.
Each fixture requested one input task; output transaction observed N=8, schema
count 0. Selection modes were normal/7, first/0 and middle/4. The normal process
exited 0 with 81 markers (input 10/output 71); each failure exited 1 with 82
markers (input 9/output 73). Those marker totals alone do not distinguish which
handles committed or aborted.

| Fixture | Commit normal returns | Selected commit exception | No commit entry | Abort entry/return | Close entry/return | Cleanup reports input/output |
|---|---|---|---|---|---|---|
| normal | 0–7 | none | none | none | 0–7 | 1/8 |
| commit-first | none | 0 | 1–7 | 0–7 | 0–7 | 1/0 |
| commit-middle | 0–3 | 4 | 5–7 | 4–7 | 0–7 | 1/4 |

In every fixture all outputs open before input run; input finish encloses all
output finish pairs, and input finish/run return before the first commit entry.
For each failure, every earlier successful commit returns before the selected
commit entry/injection/exact exception. No selected normal return or later
commit entry occurs. Abort applies to the selected and not-yet-attempted handles,
not earlier committed handles. All abort returns precede all close entries;
every handle closes before output then input transaction exceptions. Each
exception is the exact original position-injection class/message. Neither
component emits normal control/transaction completion on failure.

Normal execution closes all handles after all commits, then returns from output
control/transaction followed by input control/transaction. Cleanup follows outer
scope completion: input entry/return then output entry/return. Failure cleanup
uses fresh captures distinct from the corresponding original transaction
captures and receives the observed input report plus prior successful output
reports. No add, guess, resume or input-run injection occurred.

PM now authorizes Stage B validation and negative controls for these recorded
fixtures only. Derive N and selected k from observed transaction/selection
markers, with k=0 or floor(N/2), not a fixed 8 or 4. Validate exact per-index
manifests and callback pairs: successful commits [0,k), one selected exception
at k, no commit beyond k, aborts [k,N), all closes [0,N), output report count k
and input report count 1. Freeze the recorded physical phase/scope order and
error propagation; distinguish absence from a successful callback with no report.
Normal control retains [0,N) successful commits, no abort and N output reports.
These bounded fixture expectations do not establish every index, arbitrary
fan-out/concurrency or a general host recovery rule.

Add diagnostic-specific mutations for both first and middle cases, including a
fabricated later commit, missing later abort, abort of an earlier successful
handle, altered retained reports, incomplete pairs, and reordered scope/cleanup.
Repair transport envelopes before testing semantic mutations. Preserve Stage A
mode and original Java/runner sources; default wrapper may now expose full
acceptance only after all checks and the unchanged S05 regression pass.

This observation motivates a later Rust decision to track the committed prefix
separately from failed/unattempted outputs. It does not authorize that runtime
change here. Existing last-index-only Rust behavior remains explicitly bounded
and is not being presented as compatible at first/middle positions. New source
acceptance, independent reproduction, final-head Demo and integration remain.
Independent read-only review of the same initial capture confirmed all three
case envelopes, per-index callbacks, exact error propagation, physical phases,
fresh cleanup captures, report counts and retained hashes. It ran no new
fixture and made no edits. This corroborates the input to PM's Stage B decision,
not acceptance of the forthcoming validator or a Rust policy.

### Stage B source acceptance

Frozen source revision: `76dbab0e9276f83e9b245d6e6147a8d1ef9760ae`.
Only the wrapper changes after Stage A. Its SHA-256 is
`4c67c8ac36ec6364e7ecf56127f24b91f6fd759977db12e879f832a5c4467807`;
Java and runner retain the pre-capture hashes above. PM reviewed exact per-index
pairs, error payloads, report counts, physical phases, main capture chains and
fresh failure cleanup captures. The validator bounds declared output count by
available raw rows before allocating per-index expectations.

Primary ran the exact Demo at that revision: exit 0, three live cases,
57 diagnostic-specific mutated-evidence controls, two artifact controls and the
unchanged S05 full regression (two cases and 23 controls). Exactly one S07 full
marker and one retained S05 full marker were present. Semantic mutations repair
sequence, hashes and raw logs before expecting their named rejection. Separate
runner/wrapper shell syntax, source identity and diff checks passed.

Primary evidence: `${TMPDIR}/t0013-output-commit-position.FKYCgj/evidence`;
wrapper stdout/stderr retained in `/private/tmp/t0013-s07-primary.VXA85k`.
Cases/traces SHA-256:
`cd4beef69d2e5512d039616419724795ec7ff99ab8cf36f0dbaed8f19afdaaac` /
`359916e690604180b8ba7e93ffd85746cbb1aea6b909d95410de20e2b3c9a4a2`.
Wrapper stdout/stderr SHA-256:
`925af29495a79b07c4bbdd4446a320aec98ebb2933f53ceb3812eeba77aaca40` /
`16bb7c78d42058fa75f028e32e115e6c416a3a6059e502ec093ed6199b1fd2cb`.
Normal records 81 markers and exit 0; first/middle each record 82 and exit 1.
Observed N=8, selected failures 0/4 and cleanup reports 1/0 and 1/4 agree with
the independently reviewed initial matrix. Known artifact/deprecation warnings
remain retained rather than requiring empty stderr. Evidence is Reference
Observation / Integration only.

Independent read-only Tester reproduced the exact Demo at the same revision:
exit 0, all three cases, 57 semantic controls, two artifact controls and the
unchanged S05 full gate; separate shell syntax, diff and source hashes passed.
Evidence: `${TMPDIR}/t0013-output-commit-position.rQhaTC/evidence`;
logs: `/private/tmp/t0013-s07-independent.q6IP8P`.
Cases/traces SHA-256:
`2114daf1b13791ef37827398216756d0ea38daf632066517bc6aa1cb98433389` /
`652ec31a8948dfd87a596b5cdfe10b8f9e3f7267a91f6644629c338b6d0ffb99`.
Stdout/stderr SHA-256:
`034b6734dbe07637bbcf43d2ded83f178c7290e3debf961a109d74a8e9df0eb4` /
`4502b13c20c87f60fdeb96eaf54a0c2d63ad505cb7d0601dfc3f866e3a0b13e0`.
No source finding remains. Final-head acceptance and integration are still
required; the parent remains open.

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

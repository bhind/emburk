# T-0013/S05 output commit failure observation

- Tracking issue: [T-0013, #16](https://github.com/bhind/emburk/issues/16)
- State: Review; PR #75, final-head acceptance and integration pending
- Priority: P0; parent T-0010
- Slice estimate: 3 SP (implementation 1, uncertainty 1, verification 1,
  environment 0; raw 3 maps to 3 SP)
- Parent Current SP: 21, refined from 13; Initial SP remains 8. Four accepted
  3-SP slices already represent 12 SP, while output-failure observation and
  remaining lifecycle/recovery contracts are not complete. The former estimate
  underrepresented verification and failure uncertainty. This is a forecast
  refinement, not earned parent points or parent completion.

## Authority

PM owns scope, first-observation interpretation, canonical records, acceptance
and integration. One Compatibility Host implementation lane owns the three
source/test paths below; Tester is read-only. Standing owner authority permits
bounded implementation and PR integration after acceptance.

## Dependencies

Pinned T-0011 executable/API provenance, original T-0013/S03 input/output fixtures
and capture grammar (PR #72, `8e43948`), and T-0013/S04's accepted two selected
input-failure projections (PR #74, `68d848c`). T-0021/S03 remains unchanged.
No parent dependency is declared complete; combined WIP remains one.

## Branch and allowlist

Branch: `research/t-0013-output-commit-failure`.
One implementer owns exactly:

- `tools/t0013-output-commit-failure/run.sh` (new)
- `tools/t0013-output-commit-failure/src/T0013CommitFailureOutputPlugin.java` (new)
- `tests/t0013_output_commit_failure_probe_test.sh` (new)

Compile the existing `tools/t0013-input-failure/src/T0013FailureInputPlugin.java`
read-only under a distinct local-only Maven coordinate. Preserve its hash and
source location in evidence. Do not change S03/S04, Rust code, manifests,
dependencies, CLI, public API, other probes or upstream sources. PM owns STATUS,
TODO, ROADMAP, COMPATIBILITY, ARCHITECTURE, runtime design, provenance and dated log.

## Artifacts

Use the same pinned official Embulk 0.11.5 executable and a new original local
output fixture, independently packaged from the unchanged input fixture. Retain
executable/source/JAR hashes, URL, coordinates, LICENSE/NOTICE, Java version,
raw process logs, raw cases/traces and callback capture identities. No generated
JAR or downloaded executable is published. Prefix the new output trace distinctly
and validate the existing input trace independently; never merge their counters.

Run two separate processes: `normal` and `commit-failure`, each requesting one
empty input task. These names leave the unchanged input fixture's `failure`
branch inactive. Preserve a same-runtime positive control before interpreting
the selected failure. No Pages, add, resume or guess execution is introduced.

In the output transaction, require a positive actual task count and select
`taskCount - 1`; record the count and selected index. A fixture-local volatile
selection initialized to an invalid sentinel may transfer this instrumentation
to handles in the same capture. Do not infer shared class state if it is not
observed: a missing selection or unreached injection is a failed observation,
not permission to invent a state transport. Cleanup may use a fresh capture and
must not depend on retained transaction selection. No fixed fan-out is allowed.

At the selected handle's commit in `commit-failure`, emit commit entry and one
injection-before marker, construct an original fixture exception, record its
actual class/message, and throw before `Exec.newTaskReport()` or a commit normal
return. Use an exact fixture-owned class such as
`T0013CommitFailureOutputPlugin$InjectedCommitFailure` with message
`t0013-output-commit-failure`. Other output callback bodies retain S03 behavior;
all their actual entry/return markers remain recorded. Trace I/O failures must
not be confused with the injected operation exception.

Selecting the last numerical index does not guarantee previous commits occurred
first. Observe physical order; do not sort the raw trace or infer concurrency
ordering. Record every actual open/finish/commit/abort/close callback, input run
and finish, both transaction/control outcomes and both cleanup/report paths.
Preserve outer exception class/messages exactly, including wrappers; do not
assume they equal the injection before the first run has been interpreted.

### Observation before policy

The first live failure trace must be sent to PM with raw paths and actual counts
before adding lifecycle-outcome assertions to acceptance. Injection reachability,
typed grammar, callback pair integrity and artifact identity can be validated
in advance. Abort/close cardinality, successful commits, cleanup presence/counts,
report availability and outer propagation are observations, not predetermined
success expectations. PM records the actual boundary before Rust fallibility or
any new Differential comparison is considered.

Validate canonical UUIDv4 captures and per-capture contiguous sequences, exact
event arities, Base64/UTF-8, null-message positions, task indices/counts, zero
schema columns, same-capture callback pairs and prior matching opens. A thrown
selected commit has a distinct exception terminal, never a fabricated normal
return. Capture IDs remain instrumentation, not recovery or process identities.
Retain independent cleanup report counts; do not make them equal an earlier
control report count or the number of successful commit callbacks by assumption.

## Acceptance criteria

- Normal process exits 0 and exposes complete original input/output callbacks.
- Failure reaches the selected injection exactly once at observed `N - 1`,
  records its exact exception, has no normal return for that invocation and
  exits nonzero for that reached operation, not an unrelated startup failure.
- Actual failure lifecycle outcomes are reviewed by PM and retained, with no
  rollback, durability or general partial-publication inference.
- Strict artifact/hash/raw-log/capture/grammar checks pass; malformed and
  contradictory evidence fails closed with targeted diagnostics.
- Negative controls cover unavailable/corrupt executable, missing/duplicate
  injection, wrong selection, altered injected class/message, fabricated commit
  normal return, missing operation terminal, sequence/capture errors, malformed
  fields, stale hashes/logs, unknown/add/resume callbacks and contradictory
  transaction outcomes. Repair unrelated sequence/hash/log metadata when testing
  semantic missing/contradictory markers so the intended validator is exercised.
- Unchanged input source hash and narrowly changed original output behavior
  are reviewed; no upstream implementation inspection or production Rust edit.

## Demo Command

`bash tests/t0013_output_commit_failure_probe_test.sh`

Run each shell syntax check separately and `git diff --check`. Tester reproduces
the frozen source and PM reruns the exact Demo at final PR head. Retain failures
and retry safe pinned-network execution as needed; ordinary tooling problems are
not an incident or permission to stop unrelated authorized work.

## Evidence class

Reference Observation / Integration only if acceptance passes. No Rust behavior
or Differential result is added by this observation. Planning is not evidence
that the injection has been reached or that cleanup/rollback works.

Independent read-only Planning review at `45839d5` found no material ambiguity
or overclaim. It confirmed the unchanged-input/new-output boundary, dynamic
capture-local selection, first-trace interpretation gate and explicit absence
of rollback/publication or Rust-policy claims. Source acceptance remains pending.

## Initial observation and PM interpretation

Before failure-outcome assertions were added, the original runner produced
local-only evidence at `${TMPDIR}/t0013-output-commit-failure.Whvtnv/evidence`.
PM read the full decoded failure trace on 2026-09-06. Normal process exit was 0
with 81 markers (10 input, 71 output); failure exit was 1 with 82 (9 input,
73 output). Both observed output counts were 8, schema count 0, selected index 7.

All eight output handles opened and finished, and the input finish/run returned
normally before commit. Failure commits at indexes 0–6 returned normally;
index 7 reached the injection and recorded the exact original exception without
a commit normal return. Only index 7 received abort; all eight received close.
Output transaction then input transaction recorded the same original exception,
not normal control/transaction returns. Fresh input cleanup capture received
task count 1/report count 1; fresh output cleanup capture received task count
8/schema count 0/report count 7. These are distinct from S03 input-run failure's
all-output abort and empty report collections.

PM authorizes assertions for that selected fixture pattern using observed N and
selected N - 1, retaining physical event order and independent cleanup counts.
This is not a universal equality between successful commits and cleanup reports,
an arbitrary failing-index observation, or evidence of durable publication or
rollback. Numerical last-index selection does not establish a concurrent order.
No Rust output-failure policy is implemented or accepted by this interpretation.

Initial raw SHA-256 (per-run evidence, not golden values):

- `cases.raw`:
  `57f4a36145ac0336cd2b6318bc68d0ca86130d923a41e9eb65be999e08e875d6`
- `traces.raw`:
  `095a51068f1273a6d573e9c3e71ddc0002faf4d84a2cbd9e58c724a939d1eec0`
- `normal.raw.log`:
  `3ccb2c5b34a27a45efc37fb042c26c8b5d18501b6e755cc7fb0318206d54ba28`
- `commit-failure.raw.log`:
  `91a429bb8594250edff725be4e20b8a5f5a25c62bb7f2c862272894fe645599b`

This initial capture preceded strict source acceptance; later evidence follows.

## Source acceptance

Primary acceptance at `876e861853e723391347f2473e9da630c2dfb033` on 2026-09-06
passed the exact Demo (exit 0): normal exit 0 with 81 markers (10 input/71
output), selected commit failure exit 1 with 82 (9/73), matching the interpreted
boundary above. Actual N was 8 and selected index 7; those are observations,
not constants inside selection or validation. Both executable controls and all
21 targeted semantic/envelope controls passed. Missing, duplicate, contradictory
and reordered semantic markers have repaired sequence/hash/raw-log metadata and
must fail with their specific diagnostic. A one-output plan no longer crashes
the parser's zero-prior-commit ordering check; this is parser robustness, not a
new live observation of N = 1.

Both shell syntax checks were run separately and passed; `git diff --check`
exited 0. Environment remains macOS arm64, Temurin 17.0.20+8, Python 3.14.6 and
Bash 3.2.57. The pinned self-executable's known 7451-byte zip prefix warning and
public-API deprecation notes are retained, not suppressed or new artifacts.
No Rust or existing probe source changed. PM reviewed the output/S03 source diff:
changes are confined to fixture identity, selection and the original injection.

Primary local-only evidence:
`${TMPDIR}/t0013-output-commit-failure.tQ5LZR/evidence`.

- `cases.raw` SHA-256:
  `55e3794bffd144418edce00386214c14151846e47436c47c8121495e1c80ff8c`
- `traces.raw` SHA-256:
  `a9c4ddac0cca23f796118269f2cb784a70cd76dbf8057b7af236404124d81b4a`
- Runner SHA-256:
  `a49aa3869677fa1db7ad7e989697fd59d78fbd9bad64d895ff71ed7468b1acb3`
- New output Java SHA-256:
  `6889081e838e19052ba7ea34193a8ad7bf64ec5b7339e4d825e1ad09adfb65d3`
- Acceptance wrapper SHA-256:
  `2c5c7e20cc515836459d4d15b52f1dde4ed1bc4fbd0bdf3cf9a7ba53752275b6`
- Unchanged S03 input Java SHA-256:
  `d45f0b6e83d39458331a2cf1be27a01d1b6863017bd87807f0e49d160c96d252`

Independent Tester reproduced the frozen source: exact Demo exit 0 with both
fixtures and all 23 controls, separate shell syntax and diff checks passing.
The initial sandbox attempt exited 1 without evidence; the approved exact
pinned-network rerun passed. No acceptance finding remains. Logs are local-only
at `/private/tmp/emburk-t0013-s05-acceptance.X684fr`; `demo-escalated.log` SHA-256:
`a129739e86bab0d7328dfe76b04f922631f21363cf47e01936374456ac3995b9`.
Independent reference root is
`${TMPDIR}/t0013-output-commit-failure.z9E3Nq/evidence`; `cases.raw` SHA-256:
`38acff4e916c0fbd18d193390b652f4c3e9d423242986c15b66a785721c714e8`;
`traces.raw` SHA-256:
`1b4048b0b32450e0b910fdc7bdeb1fc08776037cf8c1193299e6fa6b84f28114`.
Final-head acceptance and integration remain pending.
Evidence is Reference Observation / Integration only. Other commit positions,
general output-error semantics, publication and rollback remain unverified.

## Reference and reuse record

Access/review date: 2026-09-06. Uses the exact official executable URL recorded
in T-0011 and T-0013/S03:
`https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar`,
SHA-256 `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`.
Core `c5ac2d471edac465b45088669d376a7e2a525f8f`, SPI 0.11
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`, Apache-2.0 classification and exact
public API locators remain in T-0011/S03 records. This slice reuses only original
repository-owned fixture/runner ideas, not upstream implementation/test code.
No new artifact, dependency or external plugin is admitted. Transitive SBOM and
notices, redistribution, patent/standards/trademark, jurisdiction and freedom to
operate remain unreviewed, not cleared.

## Stop rule

Repair ordinary compilation/test issues within the allowlist. Send the first
failure trace to PM before policy assertions. Return to PM for unreachable
injection/class-state gaps, new artifact/API/state transport, changed scope or
material IP/security uncertainty. Do not silently edit accepted probes, weaken
controls or assume a failed operation was rolled back.

## Non-claims

No Rust output-failure handling, full lifecycle/plugin compatibility, general
commit ordering, durable publication, rollback, lost acknowledgement, retry,
resume, atomicity, exactly-once, performance, isolation, production loader or
parent #16 completion. A normal empty commit return proves only that the fixture
returned its TaskReport, not that external data was durably committed.

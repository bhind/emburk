# T-0013/S05 output commit failure observation

- Tracking issue: [T-0013, #16](https://github.com/bhind/emburk/issues/16)
- State: In Progress; acceptance pending
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

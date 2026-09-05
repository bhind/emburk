# T-0013/S02 output lifecycle reference observation

- Tracking issue: [T-0013, #16](https://github.com/bhind/emburk/issues/16)
- State: Review; primary and independent acceptance passed, integration pending
- Parent: T-0010; priority P0
- Slice estimate: 3 SP within unchanged parent Current/Initial SP 8
- Refinement: implementation 1, uncertainty 1, verification 1, environment 1;
  raw 4 maps to 3 SP. No parent completion or duplicate velocity is implied.

## Authority

Repository owner retains final authority. Project Manager owns lifecycle,
scope, records and integration. Compatibility Host Implementer owns the exact
source allowlist below. Librarian supplies the public-interface/provenance gate;
Tester independently reproduces the frozen revision. Standing owner authority
permits implementation and integration after acceptance without treating
ordinary harness or retrieval failures as incidents.

## Dependencies

T-0011's existing official executable pin and T-0013/S01, integrated through
PR #70 as `e8b5726`. Reuse the unchanged original S01 empty input probe source;
do not edit its source, runner or test. T-0012 and T-0021 remain Backlog.
Combined WIP stays one of two. This slice precedes choosing Rust lifecycle
traits; it does not complete the parent Differential gate.

## Branch and allowlist

Branch: `research/t-0013-output-lifecycle`.
Compatibility Host Implementer owns exactly these three new files:

- `tools/t0013-output-lifecycle/run.sh`
- `tools/t0013-output-lifecycle/src/T0013OutputPlugin.java`
- `tests/t0013_output_lifecycle_probe_test.sh`

PM owns canonical STATUS, TODO, ROADMAP, COMPATIBILITY, runtime design,
provenance/index and dated log reconciliation. No other mutation, dependency,
Rust code, production host, public API, input probe or existing test changes.

## Artifacts

Author an original local-only output plugin, runner and full acceptance test.
Execute exactly two isolated fixtures using S01's unchanged empty input source:
zero requested tasks and one empty task/schema, no Pages or values. Compile
input and output into separately identified local Maven-style plugin JARs and
coordinates with the correct category. Do not assume a shared classloader or
static counter between input and output. Retain both source and JAR hashes.

The output fixture returns newly created TaskSource/ConfigDiff/TaskReport
objects at its applicable return sites, without durability or report semantics.
Log actual entry and normal-return markers for transaction, open, cleanup,
resume, and the returned object's add/finish/commit/abort/close methods. An
unexpected add must remain visible and fail this no-Page fixture acceptance.
Record actual task count/index, schema count and report count where applicable;
do not invent callback invocation, ordering or missing return markers.
Surround the actual output Control.run call with before/normal-return markers;
retain returned report count. Catch RuntimeExceptions only from the operation
being observed, preserve exact class and nullable message and rethrow. Keep
trace I/O outside caught operations; instrumentation and setup Errors are not
semantic outcomes. No fault injection, Pages, retries or resume scenarios.

Keep S01 input TRACE lines and distinct output markers in physical raw-log
order, with component-local sequence counters and canonical encoded fields.
Do not assert a shared numeric sequence across components. Retain per-case
raw logs, process exits, requested counts, extracted traces, event counts and
digests, executable identity, Java version/settings, generated coordinates and
source/JAR hashes, executable LICENSE/NOTICE in unique external directories.
No hardcoded output snapshot hash or fixture-ID-derived outcome.

## Acceptance criteria

Both fixtures must reach the actual input transaction/control and output
transaction/control boundaries; startup/loading failure cannot be an accepted
result. One-task positive control must exit 0, reach input run/normal finish
and actual output open/finish normal return plus normal transaction/control
return. Other actual output callbacks (commit, abort, close, cleanup, resume)
are observations for PM interpretation, not preselected expected counts/order.
Zero may succeed or reject; rejection requires an actual output transaction
exception, propagated input transaction exception, and nonzero process exit.
No unexpected add, instrumentation/setup failure or unaccounted process failure.

Validate exactly two complete case envelopes, known events and exact arity,
canonical UTF-8/Base64 including null versus empty exception messages, typed
count/index fields, contiguous component-local sequences, required positive
markers, normal/exception consistency, raw-log correspondence and recomputed
counts/digests. Unknown, missing, truncated, duplicate sequence, malformed,
contradictory and unrelated-exception evidence must fail closed. Rehashed
mutated copies must reach intended exact diagnostic labels, not merely stale
checksum failures. Include valid synthetic null/empty message controls; these
are format controls, not live fault observations.

Input requested count and output transaction count are separate observed
quantities. Validate output fields against the actual output transaction
context, not against requested input count. Do not force executor settings to
make the quantities equal or assert a portable fan-out factor.

Run actual corrupt-executable-copy rejection (exit 3) and unavailable official
asset rejection (exit 56); never skip a missing runtime or substitute a pin.
Tester independently reproduces the exact full Demo at a frozen revision.

## Demo Command

`tests/t0013_output_lifecycle_probe_test.sh`

Run from outside the repository. It executes both live fixtures, artifact
negative controls and strict trace validation controls, exiting 0 only on full
completion. Run per-file `bash -n` and `git diff --check`. No unchanged Rust
regression suite is claimed or required for this separate test-only slice.

## Evidence class

Reference Observation / Integration only. No Rust comparator is implemented.

## Reference and reuse record

Access/review date 2026-09-06. Librarian gate and PM inspection used public
`javap -public` signatures from the already admitted official
[Embulk 0.11.5 executable](https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar),
SHA-256 `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`.
Core commit `c5ac2d471edac465b45088669d376a7e2a525f8f`; SPI 0.11 commit
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`. API locators:
`org/embulk/spi/OutputPlugin.class`, `OutputPlugin$Control.class`,
`TransactionalPageOutput.class`, `PageOutput.class`,
`org/embulk/config/TaskReport.class`. Transaction/resume return ConfigDiff;
Control.run returns List<TaskReport>; commit returns TaskReport. Public
signatures permit original fixture calls, not conclusions about lifecycle.

Core/SPI source license classification is Apache-2.0. Exact source LICENSE and
core NOTICE-executable locators remain in the T-0011 inventory; embedded
META-INF/LICENSE and META-INF/NOTICE are retained per run. No upstream
implementation/tests/text are copied or translated. S01 probe/runner reuse is
project-owned original code. Executable and generated JARs remain local-only;
original probe source is published. No new external plugin or artifact admitted.
Transitive SBOM/notices, redistribution, patent/standards/trademark,
jurisdiction and freedom-to-operate remain unreviewed; this is not legal
clearance.

## Stop rule

Repair ordinary compilation, harness and authorized retrieval issues within the
packet. Escalate unexpected trace interpretation to PM before choosing policy.
Stop expansion for new artifacts, upstream implementation inspection, injected
failures, resume/retry scenarios, production traits, redistribution or material
IP/security uncertainty. Do not hide negative evidence or silently weaken gates.

## Acceptance evidence (2026-09-06)

Primary acceptance at `57390529daeb0d3f937f455f4e02f98d3cb742d6` ran the
exact Demo from `/private/tmp`, exit 0. Per-file `bash -n` and
`git diff --check` passed. No Rust code changed or new Rust test run is claimed.
Evidence: `${TMPDIR}/t0013-output-lifecycle.3Tto9c/evidence`.

| Fixture | Requested input tasks | Observed output tasks | Process exit | Input/output markers |
|---|---:|---:|---:|---:|
| Zero | 0 | 0 | 0 | 6 / 6 |
| One empty input task | 1 | 8 | 0 | 10 / 70 |

In the one-input case, the actual output trace records open, finish, commit
and close entry/normal-return pairs for indices 0 through 7. All opens precede
the input run marker; output finishes occur inside the input finish markers;
commits then closes occur after input run normal return. Output control and
transaction return normally, followed by input control/transaction return,
input cleanup, then output cleanup. Both zero-task transactions return normally
and input cleanup precedes output cleanup. Output cleanup report counts were
zero/eight respectively. No add, abort or resume marker occurred.

These are actual sequences for the two original empty fixtures, not universal
callback ordering or report semantics. Runtime logging reported `max_threads=16`
and output tasks `8 = input tasks 1 * 8`. PM accepted the differing task counts
as evidence, not an incident, and explicitly rejected equating input/output
counts or treating eight as a portable constant. The default mapping algorithm
and executor configuration remain unverified.

Evidence SHA-256:

- `cases.raw`: `9c08408c10f8fd1a50c63eb9dc09f3ed8401fb65b9069965acb13625b8f9c3ca`
- `traces.raw`: `06cc4542e428511062bfd575546471d1acd2dba2af64cc9e79ef468ee302b453`
- Zero mixed trace: `12263d6c29045e10311b5e053b46c86c1f85d8189ce0dec1b0cd0479b1d4f2ec`
- One mixed trace: `e6b18edff2a49aba53bb1ad7e5df2b9194e61427b8c7c4e5e7db39b1d81aa001`

Corrupt-copy control exited 3 (`t0013-output-lifecycle.UJAZuL`); unavailable
asset control exited 56 (`t0013-output-lifecycle.nKkXIn`). Thirty mutated
invalid-evidence controls reached their exact intended diagnostics; null/empty
synthetic transaction-exception messages remained valid transport forms.
Checks include source-local marker ordering and a prior matching open before
handle methods, without prescribing ordering among output tasks. Cleanup's
received report count is not equated to the earlier control result. No fixed
outcome hash, output task count or absent callback is an acceptance constant.

Both separately identified local JAR/source hashes, executable hash, notices
and Java settings remain in the evidence directory. Java is Temurin 17.0.20
on macOS arm64, with Bash 3.2.57 and Python 3.14.6. This does not demonstrate
sink durability or Rust lifecycle behavior.

Independent Tester reproduced the exact Demo and per-file syntax/diff checks
at `5739052`, all exit 0, with identical case/trace hashes and no findings.
Evidence: `${TMPDIR}/t0013-output-lifecycle.UA5fzd/evidence`; full log
`/private/tmp/t0013-s02-independent.HGLtLk/full-probe.log`, SHA-256
`27fc9215c7ae3c9de88f4382341e74832e13bd045c3490fc3c2cec28bf3b0d6c`.
Integration remains pending; parent #16 remains open.

## Non-claims

No Rust lifecycle, full callback ordering/count guarantee, data transfer,
durability, cleanup guarantee, retry/resume behavior, report semantics,
transaction atomicity, exactly-once, plugin compatibility, performance,
security or release claim. Parent T-0013 remains open after bounded acceptance.

# T-0013/S01 input lifecycle reference observation

- Tracking issue: [T-0013, #16](https://github.com/bhind/emburk/issues/16)
- State: In Progress; acceptance pending
- Parent: T-0010; priority P0
- Slice estimate: 3 SP within unchanged parent Current/Initial SP 8
- Refinement: implementation 1, uncertainty 1, verification 1, environment 1;
  raw 4 maps to 3 SP. No parent completion or duplicate velocity is implied.

## Authority

Repository owner retains final authority. Lifecycle owner: Project Manager;
mutation owner: Compatibility Host Implementer. Required reviewers: Librarian
(public-interface/provenance gate), Tester (independent reproduction), PM
(scope and acceptance). Standing owner authorization permits implementation
and integration after acceptance; ordinary build/retrieval problems are not
incidents or grounds to abandon unaffected work.

## Dependencies

T-0011's pinned reference inventory and the established T-0012 official
executable/local input-plugin route. No T-0012 source file changes are needed.
T-0012/S01–S06 and T-0021/S01–S02 are integrated; their still-incomplete parent
tasks return to Backlog while this dependency-clearing lifecycle slice runs.
This is reprioritization, not a Blocked or Done transition. WIP becomes one.

## Branch and allowlist

Branch: `research/t-0013-input-lifecycle`.
Implementer owns exactly three new files:

- `tools/t0013-input-lifecycle/run.sh`
- `tools/t0013-input-lifecycle/src/T0013InputPlugin.java`
- `tests/t0013_input_lifecycle_probe_test.sh`

No changes to T-0012 probes/comparators, Rust code, Cargo manifests, production
dependencies, credentials, plugin APIs or public traits. PM separately owns
STATUS, TODO, ROADMAP, COMPATIBILITY, ARCHITECTURE, RUST_RUNTIME_DESIGN,
provenance/index and the dated log. Records and implementation remain serial
or disjoint.

## Artifacts

Independently author a local-only input plugin and runner for exactly two
isolated fixtures: requested task count zero and one, both with empty schema,
no input records, no Page creation/addition and the bundled null output.
Use the established official executable route with a distinct local plugin
coordinate and isolated external runtime directories.

Emit actual entry/normal-return markers in input transaction, run and cleanup;
also instrument resume/guess if invoked, without requiring that they occur.
Emit markers immediately before Control.run and after its normal return. In
the positive-control run callback, emit markers immediately before
PageOutput.finish() and after its normal return, then return a new TaskReport.
These are probe markers, not direct observations of OutputPlugin callbacks or
delivery guarantees. Include actual task index/count where available.

Use an unambiguous trace envelope with fixture ID, monotonically recorded
sequence, event and encoded fields. Preserve raw exception class/message with
null distinct from empty and rethrow observed RuntimeExceptions so the original
process failure remains visible. Do not catch linkage/setup Errors as semantic
outcomes. Keep observation I/O outside the caught operation; I/O failure is not
a lifecycle result. Do not fabricate uncalled callbacks, sort away event order,
deduplicate repeats or infer cleanup from object destruction.

Retain each requested task count, raw process log, extracted event sequence,
process exit, event count/digest and pinned executable/plugin/source hashes in
external evidence. Record actual outcomes, not expected traces keyed by ID.

## Acceptance criteria

One-task positive control must reach transaction, Control.run and an actual run
callback with normal finish/run/transaction return and process exit 0. Record
the zero-task result without presupposing success or rejection; a rejection is
acceptable observation only after reaching the instrumented transaction/control
operation, with raw exception and nonzero process exit. Setup failure is never
an accepted fixture. Any surprising callbacks remain evidence for PM review,
not permission to infer a Rust lifecycle policy.

Validate exactly two complete fixture envelopes, sequence/field grammar,
required positive-control markers and consistency of raw traces, counts,
digests and process exits. Reject unknown/truncated/missing/duplicate records;
test corrupted copies, not just static source structure. No output snapshot
hash is a hardcoded acceptance gate. Preserve errors and evidence paths.

Require actual corrupt-executable-copy rejection (exit 3) and unavailable
official asset rejection (exit 56) before observations. Never skip an unavailable
runtime or substitute a different version. The independent Tester must reproduce
the full Demo at a frozen source revision before integration.

## Demo Command

`tests/t0013_input_lifecycle_probe_test.sh`

It must execute both live fixtures, negative artifact controls and malformed
trace tests; final exit 0 proves the whole script completed, not merely that
some live rows were printed. Run per-file shell syntax and `git diff --check`.
New Java must compile/run against the same pinned Java 17/executable route.

## Evidence class

Reference Observation / Integration only. A future independently implemented
Rust lifecycle comparator is needed for the parent Differential (Embulk) gate.

## Reference and reuse record

Access/review date: 2026-09-06. Librarian read-only gate used `javap -public`
against the already admitted official
[Embulk 0.11.5 executable](https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar),
SHA-256 `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`.
Core pin `c5ac2d471edac465b45088669d376a7e2a525f8f`; SPI 0.11 pin
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`.
Artifact API locators: `org/embulk/spi/InputPlugin.class`,
`InputPlugin$Control.class`, `Exec.class`, `PageOutput.class`, and
`org/embulk/config/TaskSource.class`, `TaskReport.class`.
Public signatures establish available calls only, not callback semantics.
PageOutput.finish(): void permits an original empty positive-control call;
the marker around it is not an output-delivery observation.

Core/SPI source license classification is Apache-2.0; exact LICENSE and core
NOTICE-executable locators remain in [T-0011](T-0011-embulk-reference-inventory.md).
The runner retains executable `META-INF/LICENSE` and `META-INF/NOTICE` externally.
No upstream implementation, test, fixture or text is copied/translated. Reusing
project-owned test-runner boilerplate is not new upstream adoption. Original
test source is published, while executable and generated probe JARs remain
local-only. No new plugin or dependency is admitted. Runtime SBOM/transitives,
redistribution, patent/standards/trademark, jurisdiction and freedom-to-operate
review remain unreviewed; this interface triage is not legal clearance.

## Stop rule

Repair ordinary compile, harness and authorized retrieval failures within this
packet. Stop expansion for injected failure/retry/resume scenarios, new upstream
implementation inspection, new artifacts, production traits, redistribution or
material IP/security uncertainty requiring PM/legal review. Do not hide an
unexpected trace; retain it and obtain PM interpretation before policy work.

## Non-claims

No Rust lifecycle, full callback-order/count contract, output callback/delivery,
cleanup guarantee, retry, resume, task-report semantics, transaction atomicity,
exactly-once, plugin compatibility, performance, security or release claim.
No fault injection in this slice. Parent T-0013 remains open after bounded
observation acceptance.

# T-0013/S03 input-run failure reference observation

- Tracking issue: [T-0013, #16](https://github.com/bhind/emburk/issues/16)
- State: In Progress; acceptance pending
- Parent: T-0010; priority P0
- Slice estimate: 3 SP within parent Current SP 13; Initial SP remains 8
- Refinement: implementation 1, uncertainty 1, verification 1, environment 1;
  raw 4 maps to 3 SP. No parent completion or duplicate velocity is implied.

## Authority

Repository owner retains final authority. PM owns scope, records, estimates,
acceptance and integration. Compatibility Host Implementer owns the exact
source allowlist. Librarian reviewed the existing public-API/adoption boundary;
Tester independently reproduces the frozen source. Standing owner authority
permits implementation and integration after acceptance; ordinary harness or
retrieval failures are repairable work, not incidents.

## Dependencies

T-0011's pinned executable and S01/S02, integrated through PR #70 (`e8b5726`)
and PR #71 (`d474b7b`). Reuse S02's unchanged original output source in a
separately identified local output JAR. Input and output tasks are distinct;
do not equate counts or hardcode the observed factor eight. T-0012 and T-0021
remain Backlog; combined WIP is one of two.

Current parent estimate changes from 8 to 13, preserving Initial SP 8. Separate
input/output task contexts and failure-evidence validation were underrepresented
in the initial lifecycle estimate. S01/S02/S03 are refined slices of the same
parent scope; their observations do not complete the remaining Rust comparison,
retry/resume, cleanup-error or partial-publication contracts.

## Branch and allowlist

Branch: `research/t-0013-input-failure`.
Compatibility Host Implementer owns exactly three new files:

- `tools/t0013-input-failure/run.sh`
- `tools/t0013-input-failure/src/T0013FailureInputPlugin.java`
- `tests/t0013_input_failure_probe_test.sh`

No existing S01/S02 source/runner/test mutation, Rust code, production host,
dependency or public API changes. PM separately owns STATUS, TODO, ROADMAP,
COMPATIBILITY, runtime design, provenance/index and dated log reconciliation.

## Artifacts

An original local input fixture and standalone runner/test execute exactly two
isolated cases, each requesting one empty input task/schema and no Pages or
values: normal positive control, and an input-run failure before the input's
own PageOutput.finish call. Output source remains the original S02 fixture.
Reuse project-owned probe structure only, not upstream implementation/tests.
Use distinct local input/output Maven-style coordinates, categories and JARs;
retain both source/JAR hashes and never assume shared static marker state.

The failure fixture emits an explicit injection-before marker, throws a distinct
original RuntimeException class with a fixed non-secret message inside run,
records the actual caught class/message and rethrows. Keep marker I/O outside
the caught operation. The positive path actually calls finish and returns a
new TaskReport, as S01 does. Record actual input transaction/control, run,
cleanup and any resume/guess callbacks, including normal/exception returns;
do not fabricate callbacks after the throw. Preserve S02's actual output
markers, physical cross-component order and component-local sequences.

Retain all actual callbacks, including any repeated calls or attempts; do not
sort or deduplicate. Capture exact exception classes/messages (null distinct
from empty), actual requested/input/output counts, indices, schema/report
counts, raw process exit, raw logs, extracted traces, total/component counts
and recomputed digests. Preserve notices and executable/source/JAR identities
and Java environment in unique external evidence directories. Never derive
outcomes from fixture IDs or compare against a hardcoded trace digest.

## Acceptance criteria

Positive control must exit 0, reach actual input run/finish normal return and
output open/finish plus normal input/output control and transaction returns.
The failure case must demonstrably reach the injection and record/rethrow its
distinct actual run exception before any input finish call. A startup/loading
failure is not an observation. Retain actual outer propagation and process
exit; nonzero exit requires actual transaction-exception evidence. If the
runtime suppresses the injected failure or exposes unexpected propagation,
retain it for PM interpretation before accepting or imposing a Rust policy.

Observe output abort/close/commit/cleanup and input cleanup without requiring
that any of them occur or preselecting their counts/order. Calling the injection
"pre-publication" would be unjustified: a real output could have side effects
in transaction or open. This local empty sink establishes no durability boundary.

Validate exactly two complete fixture envelopes, marker grammar and exact
arity, canonical UTF-8/Base64 and typed numerical fields, raw-log correspondence,
component-local sequence continuity, source-local entry/return/exception
consistency, required positive/injected markers and count/digest consistency.
Track per-invocation structure where needed; repeated genuine invocations are
not duplicate transport records. Output fields use their own observed context;
cleanup report counts are not equated to control reports. Any unexpected add,
instrumentation/setup error or unsupported trace interpretation fails acceptance.

Use mutated evidence copies to reject missing/unknown/truncated/duplicate-
sequence records, malformed fields, stale counts/hashes/logs, fake injected
exception class, missing injection, normal-return contradictions and unrelated
nonzero failures. Rehash semantic mutations and check exact diagnostic labels.
Include null/empty exception-message format controls without presenting them
as live failures. Actual corrupt-copy rejection exits 3 and unavailable official
asset rejection exits 56; never skip or replace the pinned runtime.

## Demo Command

`tests/t0013_input_failure_probe_test.sh`

Run from outside the worktree: both live fixtures, artifact rejection and
malformed-evidence controls must complete with final exit 0. Also run per-file
`bash -n` and `git diff --check`. Tester independently reproduces the frozen
source; no unchanged Rust regression suite is required or claimed.

## Evidence class

Reference Observation / Integration only. No Rust comparator or runtime policy.

## Reference and reuse record

Access/review date 2026-09-06. Librarian reviewed only existing admitted public
API/provenance and original fixtures; no upstream implementation or new artifact
was inspected. Official [Embulk 0.11.5 executable](https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar)
SHA-256 `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`;
core `c5ac2d471edac465b45088669d376a7e2a525f8f`, SPI 0.11
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`. Public locators remain
InputPlugin, InputPlugin$Control, OutputPlugin, OutputPlugin$Control,
TransactionalPageOutput and PageOutput classes under `org/embulk/spi`, plus
TaskSource/TaskReport under `org/embulk/config`, as recorded by S01/S02.
The original injected exception is not an upstream error class or contract.

Core/SPI source classification is Apache-2.0; exact LICENSE/core
NOTICE-executable locators remain in T-0011. Embedded META-INF/LICENSE and
META-INF/NOTICE are retained per run. No upstream code/tests/text copied or
translated. Project-owned fixture reuse is not new upstream adoption. Original
source is published; executable/generated JARs remain local-only. No new
external plugin admitted. Transitive SBOM/notices, redistribution,
patent/standards/trademark, jurisdiction and FTO remain unreviewed; not legal
clearance.

## Stop rule

Repair ordinary compile/harness/retrieval issues within scope. Send first live
failure traces to PM for interpretation before finalizing acceptance gates.
Stop expansion for other injection sites, explicit retry/resume scenarios,
Pages, durable effects, new artifacts/upstream implementation inspection,
production traits, redistribution or material IP/security uncertainty.

## Non-claims

No Rust lifecycle, executor mapping, general callback count/order, durable
publication, rollback, cleanup guarantee, retry/resume behavior, report
semantics, transaction atomicity, exactly-once, plugin compatibility,
performance, security or release claim. Parent #16 remains open after acceptance.

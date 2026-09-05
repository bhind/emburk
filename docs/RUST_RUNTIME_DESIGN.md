# Rust runtime design proposal

Status: Proposed; not a verified Embulk contract or stable Rust API.
Task: [T-0021/S02](https://github.com/bhind/emburk/issues/18).
Related contracts: T-0012 and T-0013. Evidence class: Planning.

## Objective and compatibility rule

Reproduce observable behavior of the pinned Embulk core and separately pinned
plugins as strictly as practical. This includes defaults, validation timing,
values, outputs, exit behavior, lifecycle effects, cleanup, and resume. A staged
delivery schedule does not authorize permanent semantic simplification.

Java/Rust implementation differences do not by themselves justify observable
differences. A proposed exception must identify the reference behavior,
reproducer, technical constraint or disproportionate effort estimate,
alternatives, migration impact, and owner decision. Unimplemented behavior is
pending work, not an approved exception. No exception is approved here.

This proposal derives from repository decisions and owner requirements. It
does not add upstream observations to the existing T-0011 provenance inventory.
Every reference-dependent answer below needs a pinned-source observation and
a differential fixture before it becomes a compatibility contract.

## Physical boundaries and dependency direction

PR #58 supplies the first two crates, CLI and core. Expand only when a real
consumer requires the new boundary; do not create empty crates in advance.

| Component | Owns | Permitted direct dependencies within Emburk |
|---|---|---|
| `emburk-api` | Logical data contracts, task descriptors/reports, plugin interfaces, error categories | None |
| `emburk-compat` | Versioned configuration/default/coercion rules and compatibility diagnostics | api |
| `emburk-core` | Planning, task admission, scheduling, cancellation, recovery coordination | api |
| Native plugin crates | Parsing, formatting, filtering, source/sink behavior | api; compat only where a shared compatibility helper is needed |
| `emburk-protocol` | Wire envelopes, negotiation, transport-independent message definitions | None; no runtime or plugin implementation |
| `emburk-host-client` | Process supervision, protocol-to-API conversion, remote plugin adapter | api, protocol |
| `emburk-cli` | Commands, exit behavior, composition and plugin registration | core, compat, native plugins, host-client |
| `emburk-testkit` | Fixtures, trace capture, fake plugins and fault injection | api; test runners may depend on core and adapters |

Initially api and compat can be core modules. Extract api before separately
compiled plugins need it. Core receives a registry of factories through the
API; it never imports concrete plugins. CLI registers factories. This avoids
the cycle core -> plugin -> core. Wire-to-logical conversion belongs in the
host adapter, so neither api nor protocol must depend on the other.

The CLI injects a compatibility resolver implementing an interface declared in
api. Core invokes that resolver at the phase established by reference traces;
the CLI must not eagerly apply all validation. Resolved configuration is
immutable for each planned task/attempt. This keeps defaulting and validation
timing observable in one coordinator trace without a core-to-compat dependency.

The logical contract in api is the sole semantic authority for record values.
Protocol envelopes carry version-tagged payloads; any concrete schema/batch
encoding must have an explicit mapping version tied to that logical contract.
The adapter validates that mapping and its lossless round-trip fixtures. A
wire representation is not an independently evolving second logical model.

Provider SDKs, artifact resolution, YAML parsing, Arrow implementation types,
and transport/runtime handles must not become requirements of the public
plugin trait merely because one implementation uses them. Exact library
choices and a stable external Rust API remain undecided.

## Configuration and value contract worksheet

Keep raw configuration separate from resolved plugin configuration. Preserve
source locations and missing-versus-present information until the observed
defaulting and validation rules have been applied. Typed getters must not
silently inherit the chosen Rust parser's coercion policy.

| Surface | Proposed internal responsibility | Required reference cases before acceptance |
|---|---|---|
| Configuration syntax | compat loader and source diagnostics | Quoted/unquoted scalars, duplicate keys, aliases, malformed syntax, encoding, templates and environment expansion |
| Presence/defaults | Missing, explicit null and concrete value remain distinguishable | Missing/null/empty values, nested defaults, unknown keys, validation order |
| Boolean | Logical boolean; explicit compatibility conversions | True/false, numeric/string inputs, invalid coercion and error timing |
| Integer | Signed 64-bit logical domain where the baseline requires it | Bounds, overflow, negative zero spelling, string/float coercion |
| Float | 64-bit value with deliberate conversion/equality rules | NaN, infinities, signed zero, overflow, formatting and rounding |
| String | Text plus explicit encoding policy | Invalid byte sequences, Unicode, escaping, empty text, null |
| Timestamp | Logical time retaining all baseline-observable precision | Pre-epoch fractions, timezone parsing, DST edges, precision and range |
| JSON | Representation chosen only after observing required preservation | Large numbers, key order/duplicates, null, nested values and formatting |
| Schema | Ordered fields with explicit type/metadata | Duplicate names, renaming, column order, null handling, mismatch timing |

Do not implement the unresolved cells as guessed defaults. T-0012 must assign
each a fixture ID, pinned source locator, expected result and normalization
rule. Normalization may remove only demonstrated nondeterminism; it must not
erase a mismatch in precision, ordering, coercion, or externally visible error.

T-0012/S05's [bounded reference record](provenance/T-0012-schema-boundary-probe.md)
now observes empty, ordered six-type and duplicate-name schema handoff. These
observations motivate preserving order and duplicate names in a future private
representation; a name-keyed map alone would lose the observed duplicate case.
They do not settle lookup, renaming, null handling, mismatch timing or physical
value encodings, and do not establish a Rust schema API.

S06 now implements the private ordered-vector boundary under ADR-0007. Its
three-case live comparison has primary and independent acceptance and integrated
through PR #69. This storage-only model does not resolve the remaining
worksheet cells or authorize physical encoding/public API choices.

## Logical records and physical batches

Keep the logical compatibility contract independent of physical Arrow storage.
ADR-0004 selects an Arrow-compatible direction, not permission to discard
information. Round-trip timestamp, JSON, null and numeric edge cases before
selecting encodings. If lossless representation is infeasible, propose an ADR
revision instead of changing observable values silently.

File plugins need a byte-stream boundary as well as a record-batch boundary:

```text
byte source -> decoder -> parser -> logical batches -> filters
logical batches -> formatter -> encoder -> byte sink
record source -> logical batches -> record sink
```

These are proposed responsibilities, not a claim about Embulk callback order.
Parsing, formatting and codecs must remain independently testable. A database
connector should not need to pretend its records are a CSV byte stream.

Batch ownership transfers with its memory permit. Account for retained buffers,
parser/codec workspace and queued batches; a bounded item count alone does not
bound memory. A single oversized value needs an explicit compatibility and
resource policy. Splitting at row boundaries, spilling, and rejecting the job
are alternatives to evaluate; truncation is not an acceptable fallback.

## Lifecycle responsibilities and trace worksheet

The following sequence is an Emburk orchestration proposal. Exact upstream
callbacks, nesting, retry rules and call counts are unverified until T-0013.
No public trait signatures should be frozen from this sequence alone.

T-0013/S01's bounded input probe now records successful zero/one empty task
executions, including input cleanup and the normal return of the one-task
probe's `PageOutput.finish()` call. This is reference observation only. It does
not reveal output commit/abort/close behavior; observe that boundary directly
before making those responsibilities part of the private Rust execution model.

S02's primary reference acceptance at `5739052` shows why the distinction
matters: one requested input task reached an output transaction with eight
tasks. Its runtime log explicitly reported `max_threads=16` and eight output
tasks. A future coordinator must not collapse input task identity and output
task identity into one counter. The factor eight is a local observation, not a
portable constant or an accepted scheduling algorithm. Mapping rules, executor
options and concurrency need separate fixtures before implementation.

S03's primary failure acceptance at `f35cb49` also records plugin
loading again during cleanup and reset static probe counters. Do not design
cleanup around a requirement that the original in-memory plugin instance or
task handle survives. The probe now assigns explicit capture-context IDs so
reload-like observations are distinguishable from duplicate transport records.
Those IDs are instrumentation only, not a proposed resume/task identity format.
The empty TaskSource fixture does not establish a general reconstruction or
serialization contract.

| Phase | Coordinator responsibility | Plugin/adapter responsibility | Trace evidence required |
|---|---|---|---|
| Resolve and validate | Select pinned factories, resolve configuration | Validate plugin options at the compatible stage | First error, defaults applied, side effects before failure |
| Prepare job | Establish task plan and recovery identity | Discover splits and prepare source/sink state | Callback nesting, zero tasks, schema discovery, partial preparation |
| Open task | Allocate attempt and bounded resources | Open task-local readers/writers/filters | Partial-open failure and which resources need cleanup |
| Execute task | Dispatch, apply backpressure and cancellation | Consume/produce bytes or batches | Empty input, order guarantees, malformed records, task failure |
| Finish task | Collect attempt reports | Flush/finalize task resources as contracted | Distinguish task completion from job-wide durable publication |
| Finalize job | Decide whether prerequisites permit publication | Perform source/sink-specific finalization | Partial success, lost replies, exceptions and repeated calls |
| Cleanup/recovery | Retain evidence and classify recoverability | Release resources or reconcile external state | Cleanup errors, process loss, retry/resume traces |

A task descriptor is immutable; task-local mutable state belongs to its attempt.
Reports identify the task and attempt so late replies cannot advance another
attempt. These identities are internal initially and do not assert upstream
resume-file compatibility. Explicit fallible cleanup is required: destructors
alone cannot report a remote cleanup failure or reliably perform async work.

## Failure and recovery states

Use explicit uncertainty rather than treating every exception as an abort.
The state names below are candidates for the internal coordinator, not pinned
upstream states or a finalized serialization format.

| Event | Candidate state | Permitted recovery |
|---|---|---|
| Failure before any publication request | Failed before commit | Cleanup and retry only under the source/sink contract |
| All required task reports collected | Prepared | Persist validated recovery information before publication when required |
| Publication request sent | Commit in flight | Await acknowledgement or reconcile the sink |
| Durable sink success established | Committed | Preserve receipt; cleanup failure must not turn success into a retry |
| Reply lost or host dies during publication | Outcome unknown | Query/reconcile or use proven idempotency; never blindly abort/replay |
| Rollback positively established | Aborted | Retain failure evidence; resume only under a validated policy |
| Some effects published and no global rollback | Partial publication | Expose the partial outcome and connector-specific recovery path |

A source/core/sink combination may lack a global transaction. Do not introduce
one as a compatibility promise. Record separately whether the sink supports
idempotent publication, outcome queries and rollback, and whether the source
can reproduce the same input. Capabilities require evidence, not declarations
alone. Process isolation limits some failures but cannot undo external effects.

Recovery records need a format version, configuration/artifact identities,
task/attempt identity, phase and validated plugin payloads. Decide durability,
atomic replacement, corruption handling and secret exclusion before writing
the format. Reading an Embulk resume file is a separate compatibility question
from resuming an Emburk job; neither is established by this proposal.

## Scheduling and process boundaries

Start with bounded task-level parallelism. Evaluate a synchronous plugin task
interface with bounded blocking workers, while process I/O and cancellation
may use an async supervisor. Do not expose a particular async runtime through
the plugin API before a vertical slice demonstrates the need.

Cancellation stops admission, propagates a signal, and drains or discards work
according to the contract. Arbitrary native code inside a thread cannot be
assumed to stop cooperatively. Strong termination requires an external process;
statically linked built-ins remain within the coordinator's failure boundary.

The external protocol needs version negotiation, message/buffer size limits,
request/task/attempt correlation, cancellation, failure reporting and explicit
end-of-stream. Control traffic must not deadlock behind full data queues. Define
resource accounting at both sides of a process boundary. Arrow IPC is a data
transport candidate, not the control protocol or a complete lifecycle adapter.

## Decisions and implementation gates

| ID | Recommended direction | Evidence that decides it | Owner/task |
|---|---|---|---|
| D1 | Compatibility by default, explicit reviewed exceptions | Reproducer, constraint/effort comparison, migration impact | PM; T-0012/T-0013 |
| D2 | Extract api before separate plugin crates | A fake source/filter/sink compiles without core internals or dependency cycles | Rust Core Implementer; T-0021 |
| D3 | Logical types precede physical Arrow encodings | Lossless edge-case round trips and differential fixtures | Compatibility Host Implementer; T-0012/T-0023 |
| D4 | Separate job coordination from task-local resources | Pinned callback traces for success, failure, zero tasks and resume | Compatibility Host Implementer; T-0013 |
| D5 | Explicit unknown/partial commit outcomes | Faults immediately before/after publication and before acknowledgement | Rust Core Implementer; T-0025 |
| D6 | Bounded workers; runtime choice remains open | Tiny native vertical slice, cancellation and memory-pressure measurements | Rust Core Implementer; T-0024 |
| D7 | Versioned process protocol with separate control/data concerns | Fake-host disconnect, queue saturation, stale replies and version mismatch | Compatibility Host Implementer; T-0041 |

Next work is to produce the T-0012 and T-0013 reference fixtures and callback
traces, then implement API contracts with fake plugins. Defer actual Java/Ruby
hosts and provider integrations until those boundaries are evidenced. This
document can be reviewed independently; parent task completion still requires
its original semantic dependencies and executable acceptance evidence.

### Bounded path from observation to private execution

The immediate goal is a testable private empty-task coordinator, not completion
of every compatibility cell before any execution code. ADR-0008 and the
T-0021/S03 packet implements that bounded candidate with explicit plans,
separate report collections and fresh cleanup capability receivers. Task
handles are dropped before scope completion and cleanup; the selected failure
aborts all opened handles before closing all of them. Five local lifecycle
tests pass at `84edf00` under primary and independent acceptance; final-head
acceptance passed and PR #73 integrated as `14d5fb5`.
Other callback
fallibility remains outside the initial fake-plugin boundary; public traits
and a complete lifecycle contract are not approved by this internal slice.

| Decision point | Required evidence | What it permits, and what it does not |
|---|---|---|
| Empty successful orchestration | Accepted S01 input and S02 output observations with actual component traces | A bounded normal-path candidate; not inferred failure handling |
| Failure before the input's finish call | Same-runtime positive control and an original input-run exception fixture, retaining propagation and all actual output callbacks | A candidate for that exact failure boundary; not pre-publication, rollback, retry or recovery guarantees |
| Private coordinator acceptance | Independently authored fake plugins and explicit input/output plans (T-0021/S03 Unit); two live declared projections pass T-0013/S04 primary and independent acceptance at `98b6cac`, integrated by PR #74 (`68d848c`) | Private execution of those supplied plans; not default executor fan-out, identical instrumentation or a public plugin API |
| Output commit callback exception | S05 original normal control plus one selected output commit exception; actual outcomes pending | Evidence to review before output fallibility; not durable publication, rollback or recovery guarantees |
| Expansion beyond empty tasks | New fixtures for values, output mapping, concurrency and resource bounds | A separately reviewed execution slice; not a silent extension of empty-task evidence |

The proposed failure fixture should throw inside input `run` before its own
`finish` call. Calling this "before publication" would be unjustified: output
transaction/open could already have effects in a real plugin. Commit durability
and lost acknowledgements remain separate D5 gates, even if the empty local
fixture later records abort and close callbacks.

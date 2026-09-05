# Architecture

Status: target architecture unless explicitly identified as implemented below.
The current runtime remains the two-crate bootstrap, not a working loader.

## Principles

Emburk keeps the core compact. The core owns stable orchestration contracts; plugins own integration behavior and dependencies. Installation and dependency resolution are separate from job execution.

The [Rust runtime design proposal](RUST_RUNTIME_DESIGN.md) details candidate
crate dependencies, configuration/value worksheets, lifecycle responsibilities,
and failure states for T-0021. Those API and scheduling choices remain proposed
until T-0012/T-0013 reference evidence is available.

## Initial Rust Workspace Boundary

The first structural slice contains only two crates:

- `emburk-core` is a dependency-light library for Emburk-owned coordination
  primitives. It must not depend on the CLI or contain provider-specific code.
- `emburk-cli` is the composition root and binary. It may depend on
  `emburk-core`; the reverse dependency is forbidden.

The initial dependency direction is therefore `emburk-cli -> emburk-core`.
Public plugin/configuration/schema/value APIs, production runtime scheduling,
transactions, resume state, and process protocols remain
deferred until their compatibility contracts are accepted. ADR-0006 permits a
private, dependency-free raw-scalar resolver inside `emburk-core`; it is neither
a YAML loader nor a stable public API. Creating crate directories does not make
their eventual Rust API stable.

ADR-0007 permits a private ordered logical schema before any physical encoding
or public exposure. S06 implements it as an owned ordered vector in the core,
with no name lookup or deduplication. Its three-case live comparison passed
primary and independent Tester acceptance and integrated through PR #69.
Logical type tags alone do not establish value or Arrow representations.

ADR-0008 permits a private synchronous empty-task coordinator with explicit
input/output task plans, separate report collections and owned output handles.
T-0021/S03 implements this candidate with original fake plugins and separate
cleanup capability receivers after dropping task handles. Five local lifecycle
tests pass at `84edf00` under primary and independent acceptance; final-head
acceptance passed at `264a12f` and PR #73 integrated as `14d5fb5`.
Its limited callback fallibility is not a public production plugin
contract, and it does not choose default fan-out or a parallel scheduler.

T-0013/S04 adds a test-only driver and private child test bridge, leaving the
coordinator and fake behavior unchanged. It compares two live declared event
projections and separate cleanup counts using the reference output count as a
supplied Rust plan. Primary and independent acceptance pass at `98b6cac`;
final-head acceptance passed and PR #74 integrated as `68d848c`. The test adapter
is not a host API.

ADR-0009 permits a private typed output-commit error and common input/output
scope outcome, preserving actual reports on the observed last-index failure.
T-0021/S04 implements this candidate; primary and independent Unit/Contract
acceptance pass at `b8dbc77`; final-head acceptance passed at `d885ba2` and
PR #76 integrated as `b5cfb87`. Its private
fallible signature does not establish arbitrary-index recovery, publication or
rollback semantics or authorize a public plugin boundary.

T-0013/S06 adds a separate test-only bridge for normal and selected last-commit
failure, preserving S04 and the coordinator algorithm. Strict raw validation
precedes physical-order projection; exact errors are validated within each
runtime before comparing category/index. Each failed Rust scope is checked
individually before excluding the two uninstrumented control failures. Primary
and independent acceptance pass at `a284f8b`; final-head acceptance passed at
`7d90f5d` and PR #77 integrated as `3b16aaf`.
S07 prepares first/middle reference observations only. Unattempted-handle policy
must follow raw evidence and a later decision, not extension by analogy.
The S07 initial first/middle capture now observes aborts on the failed and
unattempted suffix, with earlier reports retained and all handles closed. This
motivates an explicit committed-prefix boundary in a future decision; current
Rust behavior is unchanged and remains supported only for its declared fixtures.
Primary and independent full source acceptance at `76dbab0` corroborate the
three reference fixtures; final-head acceptance at `133cddb` passed and PR #78
integrated as `14cc2a6`. ADR-0010 and the T-0021/S05 packet now permit a private
committed-prefix/uncommitted-suffix boundary. No new public/bridge type or
production plugin boundary is introduced. The private implementation at
`f2d9755` now aborts `handles[index..]` after an actual commit failure while
preserving prior report tokens, all-close and separate cleanup. Primary and
independent acceptance pass; final-head acceptance passed at `02673ba` and
PR #79 integrated as `d36cf28`. S08 prepares a separate test-only position
comparison child and strict raw adapter. Registration is its only permitted
edit to the coordinator file; no runtime policy/type change is authorized.

S08 primary and independent source acceptance now passes at `4c591a0`, including
three selected live projections and unchanged S04/S06 regressions. This is a
test-only Differential boundary; no runtime policy, public type or phase gate
changes. Final-head acceptance and integration remain required.

S08 final-head exact Demo passed at `ff8dec0`; PR #80 integrated as `de38a44`.
Its three selected Differential projections are accepted, not a general recovery
contract. Parent T-0013 returns to Backlog and remains open. T-0012/S07 now
prepares two isolated PageBuilder/test-local collector/PageReader observations
under its [packet](provenance/T-0012-page-value-probe.md), before selecting any
Rust value representation. Only Boolean/Long/String and explicit null inputs
are selected. No runtime, public API, Page encoding or transfer claim follows.

S07 initial capture at `66ef66a` returned two successful reference executions:
empty had zero Pages/rows; typed-null had one Page and three ordered rows with
true/MAX/empty text, false/MIN/newline-and-lambda text, then three explicit nulls.
Primary reviewed the complete raw capture before authorizing semantic guards
at `ec558d1`. This is initial observation, not source acceptance or a selected
Rust representation. Full negative gates, independent reproduction and final
integration remain required.

S07 primary and independent source acceptance pass at `1e7d5c9`: two fresh
Page observations, 39 diagnostic-specific repaired raw controls, two artifact
negatives and unchanged S06 three-schema comparison. Workspace 29 passed/five
intentional ignores, formatting, strict Clippy and Bash syntax pass. Evidence
is selected Reference Observation / Integration plus validator Unit/Contract;
no Rust values, production transfer or new Differential result. Final-head
acceptance and integration remain required; parent and phase gates stay open.


T-0012 reference probes and S04's ignored live comparison are test-only tools
outside the Emburk runtime. Their local executable retrieval and generated probe
plugin do not create an Emburk Java host, admitted plugin, runtime dependency,
public API, or protocol boundary.

## Runtime Layers

### Rust Execution Core

The target core owns configuration assembly, schema validation, planning, bounded scheduling, backpressure, cancellation, transaction state, resume state, structured errors, metrics, and plugin lifecycle coordination. These runtime responsibilities are not implemented yet.

It must not accumulate provider-specific clients or convenience libraries that can live in plugin crates.

### Native Plugins

The intended standard plugins are Rust crates linked into the distribution.
Third-party plugins are planned to communicate through a separately versioned
process protocol, avoiding reliance on a stable Rust dynamic ABI. Process
isolation is a design boundary to validate, not a proven security guarantee.

### Legacy Compatibility Hosts

The planned Java host will load pinned Maven-style plugins against Embulk SPI
0.11. A later JRuby layer targets selected gem-style plugins. Both are optional
and intended to run outside the Rust coordinator initially; neither exists yet.

Hosted execution is a migration capability, not evidence that a plugin has been reimplemented in Rust.

## Data Plane

The target internal representation is an Arrow-compatible columnar batch with
explicit Emburk logical metadata. Boolean, signed 64-bit integer, 64-bit float,
string, timestamp, JSON and null behavior require compatibility evidence before
logical or physical representations are accepted. No batch encoding exists yet.

The planned public protocol will be versioned independently from internal crate
layout and will not expose Embulk's raw `Page` representation.

## Execution Lifecycle

The proposed coordinator separates configuration, validation, planning,
transaction, task execution, publication and cleanup. Actual callback ordering,
abort and resume rules await T-0013 reference traces. A failure during publication
may leave an unknown or partial outcome: do not blindly abort or replay it.
Only validated recovery state may be persisted once its contract is accepted.

Exactly-once requires evidence for the complete source/core/sink combination;
a transactional output alone is insufficient. No delivery guarantee is
implemented or verified yet. Reconciliation, replay and idempotency requirements
must be established per combination before labeling its delivery semantics.

## Dependency and Plugin Resolution

- Resolve and lock dependencies during installation or packaging.
- Do not download code implicitly during `run`.
- Record artifact checksums, origin, license, and compatibility status.
- Isolate incompatible plugin dependency graphs.

## Trust Boundaries

The Rust core, native built-ins, external native processes, JVM host, JRuby host, and user plugins are distinct trust boundaries. Protocol input, resume state, plugin output, and artifact metadata must be validated at each boundary.

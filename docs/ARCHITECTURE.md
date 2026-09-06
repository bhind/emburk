# Architecture

Status: target architecture unless explicitly identified as implemented below.
The runtime uses two crates. T-0031/S01 adds an experimental text File-to-File
consumer, not an Embulk-compatible configuration/plugin loader.

ADR-0015 permits CLI-owned regular-file opening and exclusive output creation,
with a doc-hidden unstable std-I/O core function adapting line payloads to
private Text records through the existing synchronous handoff. No record or
plugin types become public, and the empty lifecycle coordinator stays separate.

## Principles

ADR-0016 extends only CLI composition with stdout locking and std::io::sink
adapters. Both use the same core transfer entry point; no new public core or
plugin API is introduced. Stdout data and stderr summaries remain separate.

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

S07 final-head Demo passed at `3b95ecd`; PR #81 integrated as `203d7da`.
Its two bounded reference observations are accepted. T-0012/S08 implements
private owned Null/Boolean/Signed64/Text records under ADR-0011. At frozen source
`914ad2e`, primary and independent acceptance pass two selected getter-result comparisons,
18 raw controls, six local storage/transport tests and the unchanged three-schema
regression. Workspace 35 passed/six intentionally ignored, formatting and strict
Clippy pass. Final-head Demo passed at `332c721`; PR #82 integrated as `b428305`.
Schema coupling, physical encoding, public API and production transfer remain
outside this slice; parent and phase delivery gates stay open. S09 prepares a
separate reference-only double-value observation, with a capture-before-
expectations gate and no Rust Float64 or equality-policy change.
S09 primary and independent source acceptance pass at `3f18966`: two selected
reference double fixtures (114/93 events), 45 diagnostic-specific raw controls,
two artifact controls, unchanged S08/S06 regressions and strict quality checks.
Selected finite/subnormal/signed-zero/null/infinity/NaN bits are preserved in
these observations. Evidence is Reference Observation / Integration plus
validator Unit/Contract, not a native Float64 or numeric equality decision.
PR #91 is in Review; final-head acceptance and integration remain required.

S09 final-head Demo passed at `59f1b2e`; PR #91 integrated as `34757c8`.
Its selected reference observations are accepted; parent T-0012 remains open.
S10 implements the private bit-preserving representation permitted by ADR-0012.
Frozen source `3df2a88` passed implementer and independent Tester acceptance:
12 selected double/null cells, five bridge controls and unchanged S09/S08/S06
regressions. Its private equality is storage identity, not numeric equality.
Primary and final-head acceptance passed; PR #93 integrated as `742274f`.
The S10 slice is Done with Unit/Contract and the two selected Differential
projections. No public value, schema coupling, physical encoding, whole-domain
or production claim follows; parent and delivery gates remain open.

T-0021/S06 implements the private synchronous owned-record handoff permitted by
ADR-0013. Frozen source `8fe820b` passes primary and independent exact Demo:
five handoff tests, 46 workspace passes/seven intentionally ignored live tests,
format and strict Clippy. It moves records directly, preserves selected bits and
typed errors, and stops callbacks on the first failure. Final PR-head acceptance
passed at `8cb13ff`; PR #96 integrated as `56ef9e9`. S06 is Done.
Evidence is Unit/Contract only, not a public
API, schema/lifecycle policy, resource guarantee or Embulk compatibility claim.

T-0012/S11 Stage A at `a95e350` captured five outcomes and 289 events,
independently reproduced and fully reviewed by PM. Matching/null/duplicate-name
cases read selected values; fresh unset text fails at addRecord and string-to-long
misuse fails at the setter. Stage B automation passes at `b556ce0`: five exact vectors, 39 repaired-copy
controls and two artifact controls. Primary and separate reproduction pass;
final-head Demo passed at `da7e50f`; PR #99 integrated as `413f837`.
The bounded observation slice is Done; parent contracts remain open.
These diagnostic observations do not select native defaults or validation.
A separate reviewed decision must precede schema-bound record implementation.

T-0023/S01 is Done through PR #101 (`d0eebf8`). It implements one
private owned logical batch with positional admission over selected Boolean,
Signed64, Float64 and Text categories; primary and independent final-head acceptance passed. No
Arrow/Page, lifecycle, public API or transfer boundary exists.

T-0023/S02 is Done through PR #103 (`5d72866`) after primary and independent
final-head comparison against three selected S11 outcomes. Its test-only bridge does
not make `LogicalBatch` a consumer, physical batch, public contract or transfer
boundary.




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

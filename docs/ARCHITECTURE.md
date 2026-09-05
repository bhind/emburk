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
Plugin traits, public configuration types, schema and value representations,
runtime scheduling, transactions, resume state, and process protocols remain
deferred until their compatibility contracts are accepted. ADR-0006 permits a
private, dependency-free raw-scalar resolver inside `emburk-core`; it is neither
a YAML loader nor a stable public API. Creating crate directories does not make
their eventual Rust API stable.

ADR-0007 permits a private ordered logical schema before any physical encoding
or public exposure. S06 implements it as an owned ordered vector in the core,
with no name lookup or deduplication. Its three-case live comparison passed
primary and independent Tester acceptance and integrated through PR #69.
Logical type tags alone do not establish value or Arrow representations.

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

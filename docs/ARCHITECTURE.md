# Architecture

## Principles

Emburk keeps the core compact. The core owns stable orchestration contracts; plugins own integration behavior and dependencies. Installation and dependency resolution are separate from job execution.

## Runtime Layers

### Rust Execution Core

The core owns configuration assembly, schema validation, planning, bounded scheduling, backpressure, cancellation, transaction state, resume state, structured errors, metrics, and plugin lifecycle coordination.

It must not accumulate provider-specific clients or convenience libraries that can live in plugin crates.

### Native Plugins

Standard plugins are Rust crates linked into the distribution. Third-party plugins communicate through a separately versioned process protocol. This avoids treating Rust's dynamic ABI as stable and prevents one plugin's dependency graph or crash from silently corrupting another.

### Legacy Compatibility Hosts

The Java host loads pinned Maven-style plugins against Embulk SPI 0.11. A later JRuby layer supports selected gem-style plugins. Both are optional and run outside the Rust coordinator initially.

Hosted execution is a migration capability, not evidence that a plugin has been reimplemented in Rust.

## Data Plane

The internal representation is an Arrow-compatible columnar batch with explicit Emburk logical metadata for boolean, signed 64-bit integer, 64-bit floating point, UTF-8 string, timestamp, JSON, and nullability.

The public protocol is versioned independently from internal crate layout. It does not expose Embulk's raw `Page` representation.

## Execution Lifecycle

A job proceeds through configuration, validation, planning, transaction, task execution, commit, and cleanup. Failure invokes abort and persists only validated resume state.

Exactly-once is a capability of the complete source/core/sink combination. Emburk promises it only when the selected output contract can commit transactionally; other combinations are documented as at-least-once or best-effort.

## Dependency and Plugin Resolution

- Resolve and lock dependencies during installation or packaging.
- Do not download code implicitly during `run`.
- Record artifact checksums, origin, license, and compatibility status.
- Isolate incompatible plugin dependency graphs.

## Trust Boundaries

The Rust core, native built-ins, external native processes, JVM host, JRuby host, and user plugins are distinct trust boundaries. Protocol input, resume state, plugin output, and artifact metadata must be validated at each boundary.

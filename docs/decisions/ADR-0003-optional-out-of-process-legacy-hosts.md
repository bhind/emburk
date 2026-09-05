# ADR-0003: Optional Out-of-Process Legacy Hosts

- Status: Accepted
- Date: 2026-09-05

## Context

Unmodified Java bytecode requires a JVM, and existing Ruby plugins may depend on JRuby and Java integration. Reimplementing those runtimes in Rust is outside the product objective.

## Decision

Legacy plugins run in optional out-of-process JVM and JRuby hosts behind an Emburk-owned versioned protocol. Native packages have no JVM/JRuby dependency. Execution never downloads dependencies implicitly. Installation records immutable coordinates, checksums, license metadata, and compatibility status.

## Consequences

Class loaders, dependencies, and crashes are isolated from the Rust coordinator. Host failure cannot commit partial output. Hosted does not mean Native or Verified. Bundled hosts and artifacts require separate license and NOTICE review.

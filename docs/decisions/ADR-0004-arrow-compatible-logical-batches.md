# ADR-0004: Arrow-Compatible Logical Batches

- Status: Accepted
- Date: 2026-09-05

## Context

The data plane needs bounded, efficient transfer within Rust and across process boundaries without exposing Embulk's page layout or Rust crate internals.

## Decision

Use an Arrow-compatible columnar batch with Emburk-owned metadata for timestamp, JSON, nullability, and protocol versioning. The external contract is versioned independently of the internal implementation.

## Consequences

Native execution can use established columnar primitives and process hosts can use Arrow IPC. Compatibility tests must define conversions precisely, especially for timestamps, JSON, and nulls.

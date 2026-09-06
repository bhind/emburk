# ADR-0013: Private Owned-Record Handoff Before Plugin APIs

- Status: Accepted; independent packet readiness review passed
- Date: 2026-09-06

## Context

Private scalar, schema, record and empty-lifecycle modules have no data-bearing
consumer. T-0012/S10 integrated through PR #93 and supplies private Float64 bit
storage alongside existing null, Boolean, signed integer and text values.
Runtime design D2 calls for a concrete consumer before extracting public APIs.
More reference coverage alone does not connect these private components.

## Decision

Propose a private synchronous owned-record handoff seam under T-0021/S06.
An original source returns Result<Option<LogicalRecord>, SourceError>; an
original sink accepts ownership and returns Result<(), SinkError>. Pull one
record, move it to the sink, then pull again. Return the accepted count only on
normal exhaustion. Stop at the first returned error, preserving its component
and payload; do not retry or issue subsequent callbacks.

This is an internal composition experiment, not an Embulk lifecycle decision.
Do not add commit, finish, abort, close, cleanup or schema validation. The
existing empty-task coordinator stays unchanged and disconnected until a later
reference-backed integration decision. Do not silently generalize its behavior.

The loop retains no record queue and does not clone records. This says nothing
about source/sink allocations, global memory bounds or backpressure equivalence.
Use private sibling visibility only where needed; expose no public types and
extract no new crate. All tests use original local fakes and existing values.

## Alternatives and limits

A full transfer coordinator would require new schema mismatch, callback and
resource policies; those are not established by existing fixtures. Public
plugin traits and Arrow batches are premature without a real consumer. The
smaller handoff seam gives subsequent design work an executable ownership path
without accepting those policies. File-to-File, API extraction and all remaining
T-0012/T-0013 gates remain pending, not approved compatibility exceptions.

No external implementation or new dependency is adopted. Existing provenance,
license and unreviewed patent/FTO boundaries remain unchanged.

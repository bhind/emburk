# ADR-0023: Scoped threads for the local File-to-File MVP

- Status: Accepted for T-0071/S01; integration pending
- Date: 2026-09-09

## Context

The bounded native pipeline reads one local regular file, parses records in
source order, formats independent owned records, and publishes through one
ordered writer. T-0024/S01 already fixed a maximum of eight workers and an
entire uncommitted window of at most twice the worker count. T-0071 requires
measured performance without weakening those safety and determinism bounds.

Tokio is optimized for coordinating many tasks that spend time waiting on
async-capable resources. Adding it does not by itself parallelize CPU-bound
formatting, and portable regular-file access commonly remains blocking. Rayon
could schedule CPU work but would introduce another dependency and a less
direct fit for the existing bounded admission and ordered commit protocol.

## Decision

Keep scoped `std::thread` workers and bounded standard-library channels for the
local File-to-File profile. Improve the serial CSV reader by processing each
`BufRead` buffer in place, and move owned logical cells into the formatter so
text fields are escaped directly into the output buffer without cloning the
record or constructing an intermediate row.

Retain one parser, ordered coordinator, encoder, and publisher. Preserve the
existing worker/window/result bounds, cancellation checks, panic conversion,
join behavior, and no-clobber publication. Do not add a runtime dependency.

Use the T-0071 runner to compare 1/4/8-worker native execution, optionally
against the pinned Embulk 0.11.5 executable, with byte equality as a mandatory
gate. Treat short smoke runs as correctness checks, not speed evidence.

## Consequences

The selected quoted-CSV evidence workload scales to 1.92× at eight workers and
reaches 148.0 MiB/s on the recorded eight-logical-CPU arm64 machine. The JSON
workload scales to 1.30× and exposes its larger serial parsing share. These
results justify the current bounded CPU parallelism only for the recorded
profile; they do not establish general scheduling or performance parity.

Tokio remains a candidate for future network plugins and control-plane work.
Its admission requires a concrete async workload, dependency review, resource
bounds, cancellation semantics, and benchmark evidence. This ADR does not
authorize async file wrappers, unbounded task spawning, or a public runtime API.

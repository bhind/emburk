# ADR-0019: Bounded native formats in the configured pipeline

- Status: Accepted; T-0033/S01 integrated through PR #119
- Date: 2026-09-06

Extend the existing private configured pipeline rather than expose a premature
generic plugin API. Keep dependency types inside a native_formats adapter.
JSON object framing bounds bytes and nesting before parsing; codec readers
stream into the same row boundary and codec writers finish before publication.
Ordered schema projections implement selected rename/remove behavior without
losing alignment with row values. Validate options before creating output.

Use the exact reviewed serde_json/flate2/bzip2 graph in the T-0033/S01 packet.
No C backend, optional arbitrary precision or unbounded JSON depth is admitted.
Existing YAML, CSV, logical values, old line consumers and publication states
remain separate. Reference-only T-0014/S02 establishes the selected five real
cases; native acceptance must compare actual exits and plain/decoded output.
Different valid compression bitstreams do not imply different record content,
but cannot be called bitstream parity. No broader Embulk behavior is inferred.

This decision expands ADR-0017's supported formats only within the accepted
future evidence scope; it does not complete any full parent plugin contract.
Stage 7 must separately establish bounded parallelism and validated recovery.

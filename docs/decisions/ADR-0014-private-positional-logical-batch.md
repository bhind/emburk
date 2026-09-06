# ADR-0014: Private Positional Logical Batch Admission Before Physical Encoding

- Status: Accepted; owner approved the bounded internal design after reviewing differences
- Date: 2026-09-06
- Implementation: T-0023/S01 source is frozen under Review in PR #101 at
  `9f842509`; no implementation has been accepted or integrated.

## Context

ADR-0007/S06 supplies a private ordered schema that preserves names, types,
order, and duplicate names. ADR-0011/S08 and ADR-0012/S10 supply private
owned logical values, including bit-preserving Float64 storage. They remain
separate representations. T-0012/S11 observes selected positional matching,
explicit-null, and duplicate-name value outcomes, while its unset and
wrong-setter cases are diagnostics only. T-0021/S06 supplies a separate
record-by-record ownership experiment, not a schema-aware consumer.

## Decision

Permit one original, private, dependency-free `LogicalBatch` containing one
owned `LogicalSchema` and zero or more owned `LogicalRecord` rows. Its only
constructor consumes the schema and rows and returns either a batch or a
private admission error; rejected inputs are not recoverable through this
constructor. This is deliberately not a retry, allocation, or resource policy.

Admission is positional. First scan schema columns from left to right and
reject Timestamp or Json categories, including rows whose corresponding cell
is Null. Then validate every row width from first row to last. Only after all
widths pass, validate non-null cells in row-major order: Boolean, Signed64,
Float64, and Text values must match the category at that exact position. Null
is admitted only for those four selected supported categories. This precedence
is a local testable invariant, not an Embulk error-timing or diagnostic claim.

The batch preserves column order, duplicate names, row order, cell order,
owned text, and Float64 storage bits. It exposes only private read-only
iteration. `record_handoff` remains unchanged.

## Consequences and limits

Owner approval follows the explicit Embulk comparison: internal representation
differences are permitted, not permanent compatibility exceptions. Timestamp,
JSON, unset values, and externally observable failure behavior remain pending
reimplementation and differential verification before public exposure. No
language constraint or prohibitive implementation cost has been established.
Internal width rejection must not dictate parser behavior: any supported
source-level missing/extra-column policy belongs in the parser/adapter before
batch admission. This decision does not approve a parser policy.

This permits original private composition of the already accepted selected
schema/value evidence. It does not select Embulk nullability, defaults,
misuse behavior, coercion, lookup, metadata, timestamp/JSON values, external
error text, public APIs, Arrow/Page encoding, batching/resource bounds,
lifecycle, plugin behavior, transfer, or compatibility completion. T-0012/S11
unset-text and wrong-setter outcomes must not be translated into native rules.

A later private batch consumer or physical representation needs its own packet
and decision. No external code, artifact, dependency, or source observation is
adopted; existing provenance and unreviewed license, redistribution, patent,
standards, and FTO boundaries remain unchanged.

The frozen S01 source implements only this private decision and has seven local
tests. Final-head Demo, independent Tester reproduction and integration remain
open; no compatibility or completion evidence follows from source freeze.

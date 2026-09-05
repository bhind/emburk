# ADR-0011: Private Logical Record Values Before Schema Coupling

- Status: Accepted
- Date: 2026-09-06

## Context

T-0012/S07 is integrated through PR #81 (`203d7da`) after primary,
independent and final-head acceptance. Its original test-local Page collector
observed empty records and three ordered Boolean/Long/String/null rows. This
does not establish Page encoding, general ownership, schema mismatch timing
or other value types. ADR-0007's ordered schema remains a separate private
storage boundary; ADR-0004 remains a physical-batch target, not an encoding
selected by these observations.

## Decision

Permit T-0012/S08 to add only private, dependency-free, owned logical values:
Null, Boolean(bool), Signed64(i64), Text(String). Preserve ordered cells in
records and ordered records without coercion, default substitution, truncation,
name lookup or deduplication. Text ownership must not depend on caller buffers.

Do not couple this representation to LogicalSchema or Column yet. No constructor
validation or schema/type mismatch policy is selected. The reference adapter
validates the exact observed schema before projecting only supplied cells and
actual getter/null outcomes. A test-only comparison constructs real private
records from supplied inputs and compares their actual read-only contents with
those outcomes. Fixture labels cannot manufacture expected values.

No new crate, public export, plugin trait, production data path, Arrow/Page
encoding or wire format is authorized. The owned test transport is not a public
record format. Float64, timestamp and JSON values remain unsupported, not
represented by guessed defaults.

## Consequences

This is a values-only storage/reconstruction boundary, not a general record or
schema API. Local arbitrary storage tests are Unit/Contract; only the two selected
S07 getter-result projections may gain Differential evidence. Typed-null getter
behavior, malformed external record validation, schema coupling, batching,
transfer, resource permits and public exposure require later packets. Existing
schema, scalar, lifecycle and S07 source remain unchanged.


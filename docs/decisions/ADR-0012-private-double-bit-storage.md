# ADR-0012: Private Double Bit Storage Without Numeric Equality Policy

- Status: Accepted
- Date: 2026-09-06

## Context

T-0012/S09 integrated through PR #91 as `34757c8`. Primary, independent and
final-head verification observed exact selected finite/subnormal values, signed
zeros, infinities and quiet-NaN signs/payloads, with null separate from all of
them. These are selected getter-result observations, not a general arithmetic,
coercion, NaN normalization or numerical equality contract.

The existing private logical values derive structural `PartialEq` and `Eq`.
Adding a plain `f64` field would require changing that policy. Numeric comparison
also cannot stand in for bit-preserving storage acceptance: two signed zeros
must remain distinguishable in the selected storage observations.

## Decision

Permit only a private, dependency-free `Float64Bits(u64)` representation and a
`LogicalValue::Float64(Float64Bits)` variant. Conversion from an actual `f64`
uses `to_bits`; reconstruction uses `f64::from_bits`. Preserve the supplied
bits with no arithmetic, formatting, canonicalization or default substitution.
Null stays its existing separate variant. Keep owned row/cell order unchanged.

Derived equality on this private wrapper is explicitly **storage identity**:
same 64 bits. It does not specify Embulk numeric equality. It distinguishes
signed zeros and NaN payloads/signs; an identical stored NaN is structurally
equal to itself. Do not implement ordering, numeric comparison, arithmetic,
coercion or public hash/serialization policies in this slice.

The live bridge constructs real private records from the observed supplied
values, reads those records back and compares the actual bit/null contents with
the separately observed reference getter results. Fixture names cannot generate
expected payloads. Only S09's two selected projections may receive Differential
evidence after fresh comparison; arbitrary local bit cases remain Unit/Contract.

## Alternatives and limits

- Plain `f64` plus ordinary numeric equality would lose the intended distinction
  between equality of stored representations and equality of numbers.
- Canonicalizing NaNs or zero signs would discard information observed in S09.
- Exposing a public floating-value API now would prematurely settle conversion,
  equality, schema and physical-format contracts not covered by these fixtures.

No new crate, dependency, public export, schema coupling, Arrow/Page encoding,
plugin trait, production transfer, timestamp/JSON behavior or benchmark claim.
Existing S08 tests and S09 reference sources remain unchanged. This is an
original local representation decision using standard-library interfaces, not
a translation of upstream implementation. Existing provenance and unreviewed
patent/FTO/redistribution boundaries remain unchanged.

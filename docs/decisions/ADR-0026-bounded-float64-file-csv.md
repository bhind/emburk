# ADR-0026: Bounded Float64 File/CSV physical values

Status: Accepted through PR #148

## Context

The configured File/CSV consumer already carries private Float64 bits but does
not admit a `double` configuration column or define its CSV physical behavior.
T-0032/S03 Stage A used the already admitted pinned Embulk 0.11.5 executable
as a local black box. Its primary and independent raw manifests were validated
at the exact driver revision; no upstream implementation source was consulted.

## Decision

For the three reviewed Stage A configurations only, permit a private CSV
`double` column that enters the existing configured File-to-File profile and
uses the existing private Float64 value boundary. The selected reference
effects are:

- input `1.5`, `-0.0`, and `0.0` produces those three output fields in that
  order, preserving the signed-zero spelling;
- an unquoted empty `double` field is null and formats as an empty CSV field,
  while the selected quoted empty field omits that input row; and
- the selected `not-a-double` row is omitted while surrounding `1.5` and `2.5`
  rows are emitted.

The implementation must use the observed row-level outcomes, preserve the
existing null distinction, and add no dependency, public API, physical-batch
format, or plugin surface. The differential harness must validate raw Stage A
evidence before projecting it into native expectations.

Source `3cb9c32` implements this decision and rejects any other Float64 literal
before final publication rather than silently omitting it. Primary and
independent exact-Demo evidence preceded integration through PR #148.

## Limits

This decision selects no general Float64 lexical grammar, exponent/non-finite
handling, locale, rounding, arbitrary formatter policy, generic malformed-row
recovery, JSON `double`, multi-file Float64 behavior, transaction/resume
semantics, performance result, security clearance, patent/FTO conclusion, or
parent completion. Behavior outside the three observed configurations remains
unverified and is not an accepted compatibility exception.

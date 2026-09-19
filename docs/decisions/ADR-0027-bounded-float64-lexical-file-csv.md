# ADR-0027: Bounded Float64 lexical File/CSV values

Status: Accepted for T-0032/S04 Stage B only

## Context

ADR-0026 accepts three selected Float64 File/CSV physical-value outcomes and
requires a native safety refusal for every other unobserved literal. T-0032/S04
Stage A used the already admitted pinned Embulk 0.11.5 executable as a local
black box. Two independently validated, complete raw captures at source
`2dc3b46` select three additional lexical configurations. No upstream
implementation source was consulted or adopted.

## Decision

Within the existing private configured File/CSV `double` profile, Stage B may
implement only these additional observed outcomes:

- plain `3.5` and `-12.25` retain their fields and order;
- quoted and unquoted `3.5` each retain `3.5`;
- a `3.5x` middle row is omitted while surrounding `3.5` and `42.0` rows
  retain their order.

ADR-0026's already accepted outcomes remain unchanged. Any lexical value not
selected by ADR-0026 or this decision must reject before final publication;
Stage B must not silently omit it. The implementation stays private, uses no
new dependency or public API, and must validate raw oracle evidence before
projecting native expectations.

## Limits

This decision does not select a general Float64 grammar, integer or exponent
handling, non-finite values, locale, rounding, arbitrary formatting, generic
malformed-row recovery, JSON `double`, multi-file Float64 behavior,
transaction/resume semantics, performance result, security clearance,
patent/FTO conclusion, or parent completion. The bounded rejection rule is a
native safety refusal, not a permanent compatibility exception or reference
parity claim.

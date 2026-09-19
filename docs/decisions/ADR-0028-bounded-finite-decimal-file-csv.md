# ADR-0028: Bounded finite-decimal File/CSV values

Status: Accepted for T-0032/S05 Stage B only

## Context

ADR-0026 and ADR-0027 admitted selected physical and lexical Float64 outcomes
through exact literal mappings. That safe boundary cannot economically provide a
useful decimal profile: adding a normal value would require another literal and
another formatter entry.

T-0032/S05 Stage A used the already admitted pinned Embulk 0.11.5 executable
and Java 17 only as a local black box. At source `cb47c8c`, primary and
independent complete captures validated the same frozen, original corpus and
64-value deterministic holdout. No upstream implementation source, dependency,
or artifact was consulted or adopted.

The reference accepts broader forms, including leading `+`, leading zeroes,
leading/trailing-dot forms, exponent syntax, non-finite values, three fractional
digits, and values outside the selected magnitude. Those observations are
retained as compatibility gaps; they do not compel native admission.

## Decision

Within the existing private configured File/CSV `double` profile, Stage B may
replace the finite positive-literal and formatter tables from ADR-0026 and
ADR-0027 with this bounded native grammar:

```text
-?[0-9]{1,6}(\.[0-9]{1,2})?
```

Leading zeroes are deliberately admitted within the six-digit bound because
the reviewed `03.5` reference observation normalizes to `3.5`; this decision
does not claim that every such input is Embulk-compatible. The grammar is ASCII
only and parsing must produce a finite existing private Float64 value.

For values admitted by this grammar, formatting is canonical: shortest finite
decimal spelling, a `.0` suffix for an integral finite value, and a preserved
negative-zero spelling of `-0.0`. Thus the selected observations include
`0 -> 0.0`, `-0`/`-0.00 -> -0.0`, `1.00 -> 1.0`, `3.50 -> 3.5`, and
`42 -> 42.0`. Quoted and unquoted accepted finite fields use the same grammar.

The previously observed quoted-empty, `not-a-double`, and `3.5x` row-omission
sentinels remain unchanged. Other lexical values outside the grammar, including
`+3.5`, `.5`, `1.`, `1e2`, `NaN`, `Infinity`, `3.141`, and more than six
integral digits, reject before final publication. These explicit native
refusals are not assertions that the reference rejects them.

This supersedes the finite literal tables and corresponding safety refusals in
ADR-0026 and ADR-0027. It preserves their empty-field and malformed-sentinel
outcomes. The implementation stays private and adds no dependency or public
surface.

## Limits

This decision is a bounded native domain, not a general Float64 or Embulk CSV
grammar. It does not admit exponent, plus sign, locale, whitespace, non-finite,
unbounded precision/magnitude, generic malformed-row recovery, JSON `double`,
multi-file Float64, transaction/resume semantics, performance, security,
patent/FTO, release, or parent-completion claims.

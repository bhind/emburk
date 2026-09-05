# ADR-0006: Private Raw Scalar Resolution Before Parser Adoption

- Status: Proposed
- Date: 2026-09-05

## Context

T-0012/S01 and S02 recorded bounded reference observations for selected
presence, string, Boolean, and Long values. Emburk has no configuration parser
or public configuration API yet. Adopting a YAML dependency or exposing an API
would exceed those observations and couple later compatibility work prematurely.

## Decision

If accepted, allow T-0012/S03 to add a dependency-free, private raw-scalar
resolver in `emburk-core`. Its inputs are constructed by project-owned tests,
not parsed YAML. It resolves complete native domains only: Missing/Null and
String identity/presence, Boolean identity, and signed-64-bit integer identity.
No CLI wiring, parser, public API, plugin interface, schema, lexical Boolean or
Long conversion, decimal conversion, or default Boolean/Long policy is adopted.

## Consequences

The slice supplies original Rust code and Unit/Contract regression tests traced
to S01/S02 without treating observed tokens as a general lexical algorithm. It
is not a live differential harness or an Emburk compatibility claim. Lexical
spellings, decimal conversion, a parser, defaults, or public exposure require
a new packet and evidence.

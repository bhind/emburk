# ADR-0006: Private Raw Scalar Resolution Before Parser Adoption

- Status: Accepted
- Date: 2026-09-05

## Context

T-0012/S01 and S02 recorded bounded reference observations for selected
presence, string, Boolean, and Long values. Emburk has no configuration parser
or public configuration API yet. Adopting a YAML dependency or exposing an API
would exceed those observations and couple later compatibility work prematurely.

## Decision

Allow T-0012/S03 to add a dependency-free, private raw-scalar resolver in
`emburk-core`. Its inputs are constructed by project-owned tests, not parsed
YAML. It may resolve only the explicitly observed Missing/Null/String/Boolean/
Long cases and named decimal token cases. No CLI wiring, parser, public API,
plugin interface, schema, or default Boolean/Long policy is adopted.

## Consequences

The slice supplies original Rust code and Unit/Contract regression tests traced
to S01/S02. It is not a live differential harness or an Emburk compatibility
claim. New input spellings, a parser, defaults, or public exposure require a
new packet and evidence.

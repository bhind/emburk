# ADR-0025: Bounded Boolean File/CSV physical values

Status: Proposed for T-0032/S02

## Context

The configured File/CSV consumer accepts physical `long` and `string` columns.
The private value layer can retain Boolean values, but no reference observation
yet selects CSV lexical/null behavior or authorizes that value in the runnable
pipeline.

## Proposed decision process

T-0032/S02 first captures three bounded Boolean cases through the checksum-
pinned Embulk 0.11.5 executable. Only after the first raw capture is reviewed
may this ADR lock the admitted literals, null/invalid outcomes, and formatter
projection. Native implementation must use existing private values and add no
dependency or public API.

## Limits

This proposal does not select generic coercion, case folding, arbitrary CSV
syntax, Float64/timestamp/JSON values, multi-file Boolean compatibility,
state/resume parity, transaction behavior, or performance policy.

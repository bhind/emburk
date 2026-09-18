# ADR-0025: Bounded Boolean File/CSV physical values

Status: Proposed for T-0032/S02

## Context

The configured File/CSV consumer accepts physical `long` and `string` columns.
The private value layer can retain Boolean values, but no reference observation
yet selects CSV lexical/null behavior or authorizes that value in the runnable
pipeline.

## Selected candidate decision

The reviewed Stage A capture locks only this candidate mapping: exact `true`
becomes Boolean true, exact `false` becomes Boolean false, and the selected
noncanonical `truthy` becomes false. An unquoted empty Boolean cell remains
null and formats as an empty CSV field; a quoted empty cell becomes false.

The native implementation must distinguish quoted from unquoted empty input,
use existing private values, and add no dependency or public API. It must not
infer that every non-`true` string becomes false. Other spellings remain
outside the selected profile and receive no compatibility claim.

## Limits

This decision does not select generic coercion, case folding, arbitrary CSV
syntax, Float64/timestamp/JSON values, multi-file Boolean compatibility,
state/resume parity, transaction behavior, or performance policy.

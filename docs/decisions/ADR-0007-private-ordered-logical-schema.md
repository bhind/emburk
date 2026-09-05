# ADR-0007: Private Ordered Logical Schema Before Physical Encoding

- Status: Accepted
- Date: 2026-09-06

## Context

T-0012/S05 observed empty, six-type ordered and duplicate-name schemas against
the pinned Embulk executable. Each reached run with the same ordered columns.
Names alone cannot identify a column: the duplicate fixture retains two
different positions and types. No name lookup, nullability or Page/value
encoding behavior was established.

## Decision

Permit T-0012/S06 to add a private, dependency-free ordered schema in
`emburk-core`. Store owned names and an original six-variant logical type tag in
an ordered vector. Construction and read-only iteration preserve supplied
order, names and duplicates. Position is the sequence index, not a name-keyed
identity. Do not add uniqueness checks, name lookup or deduplication.

The logical tags represent Boolean, signed 64-bit, 64-bit float, text, timestamp
and JSON categories only. They do not choose representations for values,
precision, encoding, nullability or Arrow. No new crate, public API, parser,
plugin trait or serialization is authorized. A test-only live comparator must
compare the three supported outcomes with actual S05 oracle data.

## Consequences

This preserves the observed duplicate/order cases without prematurely binding
the logical model to Arrow or a plugin interface. ADR-0004 remains a target
direction; physical batch representation still needs separate value round-trip
evidence. Arbitrary owned-name preservation is an internal storage invariant,
not a claim that all possible names passed Embulk validation. Public exposure,
schema transformations and unsupported semantics require another packet.

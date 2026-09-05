# T-0012/S06 private ordered schema and live comparison

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- Branch: `feat/t-0012-ordered-logical-schema`
- State: In Progress; acceptance pending
- Owner: Rust Core Implementer; canonical records/integration: Project Manager
- Dependencies: T-0011 and S05, integrated through PR #68 as
  `68559dc8b81d45c2b236db3d1e5266f70ab589a9`
- Authority: owner implementation request and accepted ADR-0007
- Estimate: 3 SP within unchanged Current SP 8 / Initial SP 5. Raw score:
  implementation 1, uncertainty 0 (bounded accepted observations), verification
  2 (live plus negative comparison), environment 1 (established Java route).
  No parent completion, additional estimate or duplicate velocity is implied.

## Mutation packet

Implementer owns exactly:

- `crates/emburk-core/src/lib.rs`: private module declaration and narrowly
  scoped unused-code rationale only;
- `crates/emburk-core/src/logical_schema.rs`: original ordered representation,
  unit tests and test-only live transport bridge;
- `tools/t0012-schema-differential`: new Python-standard-library driver;
- `tests/t0012_schema_differential_test.sh`: new Demo and negative checks.

Do not change S05's runner, Java probe or tests, the scalar resolver, Cargo
manifests, production dependencies or public APIs. PM separately owns STATUS,
TODO, ROADMAP, ARCHITECTURE, COMPATIBILITY, relevant ADRs, provenance/index and
the dated log. Implementation and canonical records remain disjoint.

Use a private LogicalSchema containing ordered LogicalColumns, each with owned
UTF-8 name and logical type (Boolean, Signed64, Float64, Text, Timestamp, Json).
Construction and ordered iteration preserve the supplied vector exactly;
duplicate names remain separate positions. No name lookup, uniqueness policy,
renaming, nullability, concrete values, Pages, Arrow or serialization is added.
Unit tests include empty, six ordered types and same-name/different-type pairs;
additional arbitrary-name tests establish only internal storage invariants.

## Live comparison and acceptance

The new driver invokes the unchanged S05 schema mode. Retain its actual raw
evidence paths and results before normalization; retrieval or missing evidence
cannot become an offline skip. Independently check the exact three-case set,
canonical Base64/UTF-8 fields, unique contiguous indices, count/fingerprints,
phase equality, known type names and successful actual run outcomes. Never
select outputs by fixture ID; IDs constrain membership/count only. Input columns
are test-owned, while expected columns come from actual oracle run-phase rows.
Reject unknown output types rather than guessing a fallback.

Transport is a versioned UTF-8 TSV with explicit case boundaries/counts and
hex-encoded names, preserving empty schemas, names and duplicate positions.
The Rust bridge is test-only and invokes the real private representation. Do
not embed upstream expected columns as a live fallback. Test missing/duplicate/
truncated/malformed evidence, unknown types, broken encodings, phase mismatch
and expected-only mutation; the latter must leave input columns unchanged.

Demo Command: `tests/t0012_schema_differential_test.sh`. It runs offline negative
checks, the actual S05 oracle and exactly one fully qualified ignored Rust test
covering all three live cases. Prove the selected test ran (zero filtered matches
must fail); normal offline tests explicitly ignore live tests. Run workspace
format, strict Clippy, tests and diff checks, plus S04 live regression. Independent
Tester reproduction at a frozen revision and record reconciliation precede PR
integration. Retain all raw artifacts/logs outside the repository.

Evidence target: Unit/Contract for internal storage, Differential for exactly
three selected ordered schema outcomes. No full schema/API, name lookup,
nullability, values, Arrow, lifecycle, plugin, transfer or general compatibility
claim; parent T-0012 remains open.

## Provenance and stop boundary

Access date: 2026-09-06. Only S05's accepted runtime observations influence this
slice; see its [exact reference and license record](T-0012-schema-boundary-probe.md).
Official Embulk 0.11.5 executable SHA-256:
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`;
core commit `c5ac2d471edac465b45088669d376a7e2a525f8f`, SPI 0.11 commit
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`. S05's six observed type-name strings
map only to the corresponding internal category; observed names are data, not
reused upstream implementation. No new source or tests are inspected, copied
or translated. Apache-2.0 source classification is not patent/FTO clearance.
Executable LICENSE/NOTICE stay in external oracle evidence; no JAR, dependency
or plugin is newly admitted or redistributed. SBOM, redistribution, patent,
standards and freedom-to-operate review remain unreviewed.

Repair ordinary harness/build/retrieval problems within this packet. Stop scope
expansion for unknown semantic mappings, new dependencies/APIs/encodings,
source translation, redistribution or material IP/security uncertainty. If the
accepted oracle format cannot be consumed without changing S05, repacket rather
than modifying its files silently.

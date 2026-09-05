# T-0012/S06 private ordered schema and live comparison

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- Branch: `feat/t-0012-ordered-logical-schema`
- State: In Progress; independent acceptance passed, integration pending
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
the dated log; RUST_RUNTIME_DESIGN may be reconciled to accepted observations.
Implementation and canonical records remain disjoint.

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

## Primary acceptance

At source revision `c7c7872`, the primary agent ran the exact Demo by absolute
path from `/private/tmp`: exit 0, three live schema comparisons in exactly one
selected ignored Rust test (one passed, zero ignored). The new negative-control
test also selected exactly one test. Offline workspace tests passed 14 with two
intentional live-test ignores; format, strict workspace/all-target Clippy and
diff checks exited 0.

External evidence: `${TMPDIR}/t0012-s06.J9p9ak`. Its `live.tsv` has 12 lines:
one version header, three CASE rows and eight ordered FIELD rows. SHA-256:
`053c68f737661786f709e488a57ef9075092294fa6c0ca673a2ae5651293a66b`.
Recorded actual raw evidence hashes are the S05 hashes; they are computed
observations, not hardcoded outcome acceptance gates. The manifest retains the
live oracle evidence directory before normalization.

Review removed a draft outcome-hash gate and corrected an initially input-side
mutation into an explicitly verified expected-only mutation. Driver negative
controls re-fingerprint mutated phases so unknown-type and phase-mismatch tests
exercise their intended rejection paths rather than merely checksum rejection.
A positive synthetic test preserves changed actual output through TSV while
leaving the test-owned input unchanged. Huge row counts reject before capacity
allocation. None of these synthetic checks adds an upstream observation.

Evidence: Unit/Contract internal storage plus Differential for the three selected
ordered schema outcomes. Primary scalar live regression also passed 13 cases
with exit 0 (`${TMPDIR}/t0012-s04.dNquvT`).

Independent Tester reproduced the exact S06 Demo and S04 regression at full
revision `c7c787202ce3c5321191773f94a2680617cba705`, each with final exit 0.
Normal and `PYTHONOPTIMIZE=1` driver self-tests passed; format, strict Clippy,
offline workspace tests (14 passed, 2 intentional live ignores) and diff checks
passed. No implementation or acceptance finding remains open.

Tester logs: `/private/tmp/emburk-t0012-s06-acceptance-20260906T011105/`.
`s06-demo.log` SHA-256:
`3dae1763ddd9195f3ce447bee56c7ac16283feb89cd85a4bfa61fc56229851d6`.
Tester live evidence `${TMPDIR}/t0012-s06.dpJVxD` has the same TSV hash as primary
acceptance. Its raw-record hash file SHA-256 is
`9946b294746847657f31dca792953d09163d923f2fb9a3bb96f1c52bc5428476`.
Platform: macOS 26.5.1 arm64, Bash 3.2.57, Python 3.14.6, Rust/Cargo 1.98.1,
Temurin JDK 17.0.20. PR integration remains pending; parent T-0012 is not complete.

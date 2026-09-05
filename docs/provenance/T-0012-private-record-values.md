# T-0012/S08 private record values and selected comparison

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: Ready; independent packet review passed with transport clarifications
- Branch: `feat/t-0012-private-record-values`
- Owner: Rust Core Implementer; canonical decisions/integration: PM
- Priority: P0; parent T-0010
- Estimate: 5 SP (implementation 2, uncertainty 0, verification 2, environment 1;
  raw 5). Within unchanged Current 34 / Initial 5. Known accepted S03–S07
  slice estimates total 15 SP; S01/S02 receive no retroactive points. Do not
  combine parent forecast and slice velocity or claim parent completion.

## Authority and dependencies

Standing owner authority permits bounded implementation and independently
accepted PR integration. ADR-0011 permits the private values-only boundary.
S07 is integrated through PR #81 as `203d7daa9fe27f7421e06ea0a0eca91cc1dc1ff8`
after frozen-source acceptance at `1e7d5c9` and final-head Demo at `3b95ecd`.
Existing schema/scalar/lifecycle slices remain accepted regressions.

Use one serial active Project item and a separate read-only Tester. T-0013
and T-0021 stay Backlog; all three parents remain open. Preserve the user's
checkout and unrelated worktrees.

## Mutation owner and exact allowlist

One Rust Core Implementer owns exactly:

- `crates/emburk-core/src/logical_record.rs`: new private types and tests;
- `crates/emburk-core/src/lib.rs`: private module registration with narrowly
  scoped unused-code explanation only; preserve existing declarations/tests;
- `tools/t0012-page-value-differential`: new Python-standard-library driver;
- `tests/t0012_page_value_differential_test.sh`: new wrapper and controls.

PM owns ADR-0011/index, this packet/provenance index, STATUS, TODO, ROADMAP,
ARCHITECTURE, COMPATIBILITY, runtime design, S07 closeout and dated log.
Existing logical_schema/scalar/lifecycle files, S07 Java/runner/wrapper, Cargo,
dependencies, CLI and public API remain unchanged. Implementers do not edit
canonical records or integrate PRs. Testers/reviewers remain read-only.

## Private storage decision

Implement only an original private value enum with Null, Boolean(bool),
Signed64(i64), Text(String), and ordered record/cell storage. Constructors take
already typed values; read-only iteration returns actual stored contents.
Own text and record collections. Preserve null separately from false, zero and
empty text. No source parser, coercion, lookup, schema coupling, shape/type
validation timing, additional types or physical representation policy.

Local tests cover empty records/sequences, ordered selected cells/rows, exact
i64 bounds, Unicode/newline/empty text, null versus false/zero/empty text and
caller-string mutation after construction. Extra local values establish only
storage invariants, not additional Embulk observations.

## Reference adapter and validation reuse

Invoke exactly `["bash", "tests/t0012_page_value_probe_test.sh"]` with repository
root as cwd. Require successful exit and exactly one
`T0012_PAGE_FULL_PROBE=passed|evidence=...` marker. Preserve complete runtime,
source, local artifact/coordinate, stage, raw-log and hash identities. S07's
full gate includes two fresh live fixtures, 39 raw controls and two artifact
controls; capture-only/validate-only cannot substitute for it.

PM explicitly permits reuse of the unchanged S07 raw validator instead of
duplicating its complete callback model: before any projection, invoke its
runner with T0012_PAGE_MODE=validate and the selected evidence directory, require
exit 0 and stdout exactly `T0012_PAGE_VALIDATE_ONLY=passed` followed by one
newline, with empty stderr; no duplicate/noisy marker or exit-only acceptance.
This raw validator is not artifact
admission. Full live mode still requires the full wrapper above. In the new
driver's raw-copy validate-only mode, call this same raw gate before independent
projection checks; never emit the full live comparison marker from raw copies.

Independently verify exact cases, canonical capture/sequence, count caps, raw-log/
trace/digest consistency, exact ordered schema and exhaustive input/read cell
extraction. Unknown or unpaired records cannot disappear in projection: complete
S07 validation precedes any exclusion. Retain original input-cell records
separately from actual isNull/typed-getter records, including row/cell positions.
Do not derive reference results from fixture names, supplied values or totals.

Only after validation, project supplied inputs and actual null/getter results
into the owned manifest below. Schema, setters, callbacks and instrumentation
are not native comparison events in this values-only slice; they must pass S07
raw validation first. No ignored field becomes an unreviewed normalization rule.

## Owned test manifest

UTF-8 TSV header: `T0012-S08\t1`.
For exactly empty then typed-null:

- `CASE\tfixture\trow_count\tcells_per_row`
- For each ordered row: `ROW\trow_index`
- For each ordered cell:
  `CELL\tcell_index\tinput_tag\tinput_payload\treference_tag\treference_payload`

The selected schema has three cells per row (never total cells); empty has zero rows and typed-null has
three. Tags: N for null with payload `-`; B for canonical true/false; L for
canonical signed-64 decimal; S for lowercase hex UTF-8 bytes, including empty
payload for empty text. Null is never encoded as false, zero or empty text.
Require exact header, arity, case membership/order, row/cell indices, counts and
payloads, no trailing records. Cap row/cell counts at 1024 before allocation and
also require the selected fixture dimensions. Reject unknown tags, malformed/
noncanonical numbers/hex/UTF-8 and null/payload contradictions. These are test
transport constraints, not a production parser or native constructor policy.

Rust constructs real private records from input fields, observes their actual
stored contents and compares to reference fields. No cloned-reference-as-actual
shortcut. An expected-only mutation must leave inputs unchanged and cause the
actual comparison to fail. Keep live tests explicitly ignored in offline runs;
the wrapper proves exactly one named live test actually passed.

## Artifacts, acceptance and Demo Command

All generated manifests, builds, raw-copy controls and logs remain external
temporary/ignored artifacts. Retain complete stdout/stderr, source revision/
hashes, raw evidence paths and normalized manifest hash.

Demo Command:
`bash tests/t0012_page_value_differential_test.sh && bash tests/t0012_schema_differential_test.sh`

Require two actual live record projections, mandatory full S07 gate and its
controls, exactly one named Rust live test executed, local transport/storage
controls and unchanged S06 three-schema regression. Negative tests include:

- missing/duplicate/unknown/reordered cases and malformed header/rows/cells;
- bounded counts before allocation, wrong dimensions/indices and extra records;
- type/payload mismatch, malformed bool/i64/text, null/payload contradictions;
- row/cell order, cross-typed cells, changed values and reference-only mutation;
- fresh repaired raw copies testing case/capture/sequence/digest/log/schema,
  input-versus-getter/null contradiction, missing row/exhaustion and callback
  order, with intended diagnostic checks proving the raw gate was not bypassed.

Use ordinary validation functions; no giant embedded-code exec/argv mutation.
Primary and read-only Tester reproduce the exact Demo at frozen source, plus
workspace tests, formatting, strict all-target Clippy, separate shell syntax,
external-cache Python syntax and diff/source hash checks. Final PR-head Demo
passes before integration. No zero-match live test or missing-runtime skip.

## Evidence class, provenance and non-claims

Unit/Contract for private storage/transport controls; Differential (Embulk) only
for the exact two selected S07 getter-result projections after acceptance.
See [S07 provenance](T-0012-page-value-probe.md): admitted Embulk 0.11.5 SHA-256
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`,
core `c5ac2d471edac465b45088669d376a7e2a525f8f`, SPI 0.11
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`; access date 2026-09-06.
Only original repository tests and accepted black-box observations influence
implementation. No new external source/API, artifact, dependency or plugin
admission; no upstream implementation copying/translation or JAR redistribution.
Apache-2.0 notices stay in retained evidence. SBOM/redistribution, patent,
standards, trademark and freedom-to-operate gaps remain unreviewed.

No general record/schema API, schema mismatch/nullable-field policy, typed-null
getter behavior, Float64/time/JSON, Page bytes/ownership, Arrow, batching,
plugin/host, production transfer, durability/resume/performance/release or parent
completion claim. Extra synthetic fixtures are never counted as live matches.

Independent read-only packet review found no scope leak. PM accepted its two
transport clarifications: cells_per_row is explicitly three, not nine total
cells, and raw-validator success is exact unique output with empty stderr.
This is readiness evidence only; no implementation or live match is established.

## Stop rule

Fix ordinary build/test/retrieval issues in scope and retain unsuccessful attempts.
Return to PM before source allowlist expansion, public/schema/physical coupling,
different fixtures/artifacts, new normalization exclusions or material IP/security
uncertainty. Do not edit S07 to make the driver pass, weaken a gate, invent live
outputs or mutate the user's checkout.

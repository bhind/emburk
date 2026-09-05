# T-0012/S08 private record values and selected comparison

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: Done as a bounded slice; [PR #82](https://github.com/bhind/emburk/pull/82) integrated as `b428305`; parent remains open
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

## Frozen source and primary acceptance

Source commit: `914ad2e9f63fffecddcde988cea4caf778270e37`.
Only the four source/test allowlist paths changed. Existing schema, scalar,
lifecycle, S07, Cargo and CLI sources are unchanged.

| Source | SHA-256 |
| --- | --- |
| `crates/emburk-core/src/logical_record.rs` | `5c8702affa7af6b4c6a669370c2220c1e612d79ecc37be7f246b08928950402d` |
| `crates/emburk-core/src/lib.rs` | `a81ca1807e5f7570a8268b92dc0e8d95f317f72d3dd9ccde2e8ae3682d0f85bc` |
| `tools/t0012-page-value-differential` | `e6dbc57428c3c5681d04e604c286c25a030a36851a1ce93b04901fe416407714` |
| `tests/t0012_page_value_differential_test.sh` | `4d892b0b694618b84a4dc6dce296788451fb5b96e731f3f2b9fb8cebb915ee52` |

Primary reviewed the complete four-file change independently of the source
implementers. Input cells construct actual private storage; expected-only
mutation preserves those inputs and fails with the comparison-specific error.
The raw-only path uses the same complete validation and projection as live mode,
but emits no live marker. Exact six-file hash identities are checked before
opening manifest-selected files. No upstream implementation was copied.

The exact two-script Demo exited 0 at the frozen source. Primary logs:
`/private/tmp/t0012-s08-primary.2S6x04/demo.stdout.log` and `demo.stderr.log`.
Stdout SHA-256:
`b56546c8242c79aedfbd3a0b716b0896d258c85b81d533e771fa045a075571e2`;
stderr is empty. Temporary evidence root is
`/var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T`:

- S08 `t0012-s08.HnvBfO`, including manifest, source revision/hashes, native
  control/live logs, full driver stdout/stderr and original raw-evidence path;
- reference `t0012-page-value-probe/run.9AMos8/evidence`, retaining complete
  runtime/artifact/source/coordinate/stage identities and raw logs;
- unchanged S06 `t0012-s06.n6bXJI`.

Both actual reference processes exited 0: empty has 32 raw events and zero rows;
typed-null has 110 events and three rows. The native live test executed exactly
once and passed. Eighteen diagnostic-specific S08 raw controls passed, alongside
the mandatory full S07 gate (39 raw and two artifact controls), six local Rust
storage/transport tests and unchanged S06's three live schema comparisons.
The normalized manifest SHA-256 is
`94b949ebeb6ba7b136323605fcf9307422c05d7d6d328cc1ef82529848d657ae`.

Primary quality logs are in `/private/tmp/t0012-s08-primary-quality.gUJHr1`.
Workspace tests passed 35 with six intentionally ignored live tests; workspace
formatting, strict all-target Clippy, separate Bash syntax, external-cache
Python compilation and diff checks all exited 0. Implementer frozen Demo also
exited 0 in `t0012-s08-combined-frozen.hAXq4j` under the temporary root above.

Retained non-acceptance attempts include the initial incomplete draft runs,
`t0012-s08-full-draft.XbnCJd` (pinned retrieval exited 56 before the unchanged
artifact checksum control could execute), and an initial Clippy rejection of
constant-size `chunks_exact`, corrected before freezing. Contributor reproduction
in `t0012-s08-repro.IxwN3W` has no confirmed final exit and is not acceptance.
Temporary agent-slot exhaustion was resolved by starting a fresh read-only
Tester after implementation finished; no independence gate was waived.

Evidence is Unit/Contract plus the two selected Differential projections only.

## Independent reproduction

The fresh read-only Tester reproduced the exact compound Demo with exit 0 at
unchanged source hashes (`b493925` adds PM documentation only). Retained run:
`/private/tmp/t0012-s08-final.wqfBnG/exact-demo.exit`; native evidence is its
`evidence/` subdirectory, with the same normalized manifest hash as primary.
The tool exposed incomplete outer output for that attempt, so it is not used
as the complete-log acceptance run. The subsequent redirected exact rerun
exited 0 and retained complete logs in `/private/tmp/t0012-s08-retained.M3hmoK`:
`demo.stdout.log`, `demo.stderr.log` (empty), and `demo.exit` (0).
Stdout SHA-256:
`1b979f9c917a6acdc389f41cdca04f9b0922666e8fc66f067c636638bc14f8c5`.
Independent S08/S06 evidence directories under the temporary root above are
`t0012-s08.jtj0rs` and `t0012-s06.NBFA5H`. The normalized manifest matches primary.
Primary inspected the retained logs and actual named live-test success.

The earlier independent attempt in `/private/tmp/emburk-t0012-s08-acceptance`
exited 4 before S06. Its nested artifact attempt `t0012-page-artifact.S4uiIP`
records `curl: (6) Could not resolve host: github.com` and runner exit 56.
The EXIT trap did emit the evidence directory. PM corrected the initial Tester
inference that a missing trap/marker caused failure: retrieval failed before the
corrupt-copy control could be prepared. This was a network-environment failure,
not a source defect or an accepted corrupted artifact. No gate was weakened.

Independent workspace tests, formatting, strict Clippy, separate Bash syntax,
external-cache Python compilation, source hashes and diff checks passed.
Complete-log independent retention passed. Final PR-head Demo/integration
remain required; parent and delivery gates stay open.

Environment remains macOS/Darwin arm64, Rust/Cargo 1.98.1, Python 3.14.6,
Temurin 17 and Bash 3.2, using only the admitted Embulk 0.11.5 reference.
No MSRV, alternate platform or Java-version compatibility claim follows.

## Final-head acceptance and integration

Final PR-head `332c721326cafa7951ff8da436c36916138457c3` passed the exact
Demo with exit 0. Complete logs: `/private/tmp/t0012-s08-final-head.igAcXl`,
stdout SHA-256 `b500373792e48f4cd3164b9b045e8564a566c89bcd1a76dda7dc2da9a4497af8`;
stderr empty. S08/S06 evidence under the temporary root above:
`t0012-s08.KTmsRV` and `t0012-s06.JZODUB`. Manifest hash matches primary and
independent runs; all four source hashes are unchanged. Independent four-file
source review found no unresolved correctness or packet-scope finding.

Project delivery and governance audits passed (52 items, WIP 1/2), private
visibility and main protection were verified, and exact-head guarded squash
merge integrated PR #82 as `b428305d6f2441dc62ea04736b631cf16389f9fb`.
The 5 SP slice is accepted; known S03–S08 slice estimates total 20 SP.
Parent #15 remains open and returns to Backlog during preparation of S09.
No full configuration/value contract or phase-delivery completion follows.

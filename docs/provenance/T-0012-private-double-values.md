# T-0012/S10 private double-value storage and selected comparison

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: Done; accepted and integrated through PR #93 as `742274f`
- Branch: `feat/t-0012-private-double-values`
- Owner: Rust Core Implementer; PM owns decisions, records and integration
- Priority: P0; parent task T-0012; parent epic T-0010
- Estimate: 5 SP (implementation 2, uncertainty 1, verification 1, environment 1)
  within unchanged parent Current 34 / Initial 5. Accepted known S03–S09 slices
  total 25 SP; no retroactive S01/S02 points or parent completion is awarded.

## Authority

Standing owner authority permits bounded implementation and integration after
verification.

## Dependencies

S09 integrated through PR #91 (`34757c8`) after frozen source
acceptance at `3f18966` and exact final-head acceptance at `59f1b2e`. S08 is
integrated through PR #82. ADR-0012 is accepted after independent readiness
review found the four-path scope, actual storage comparison and non-claims
coherent. No runtime evidence follows from readiness.
The decision and packet integrated through PR #92 as `74ac118`; implementation
now uses a fresh dedicated worktree from that accepted revision.
One active Project item and one serial source owner; preserve user worktrees.

## Branch and allowlist

One Rust Core Implementer owns exactly four paths:

- `crates/emburk-core/src/logical_record.rs`: add only the private bit wrapper,
  Float64 variant, conversions/accessors and registration of the new child test
  module; preserve existing S08 storage and tests unchanged.
- `crates/emburk-core/src/logical_record/double_tests.rs`: new child tests and
  bounded live manifest consumer; access real parent-private record types.
- `tools/t0012-double-value-differential`: new original test-only driver.
- `tests/t0012_double_value_differential_test.sh`: new full acceptance wrapper.

PM owns this packet, ADR-0012/index, STATUS/TODO/ROADMAP/ARCHITECTURE/
COMPATIBILITY, runtime design, provenance index and dated log. Reviewers and
Testers are read-only. No Cargo, CLI, S07/S08/S09 reference/driver/wrapper changes,
public API, dependencies or general schema/value-policy edits are authorized.

## Artifacts

Follow ADR-0012: a private `Float64Bits(u64)` stores actual `f64::to_bits` and
reconstructs with `f64::from_bits`. Equality is bitwise storage identity only.
Keep explicit null and ordered owned records. Add local tests for finite bounds,
subnormals, both zero signs, infinities, selected quiet NaNs, null distinction,
ordered reconstruction and structural identity versus numeric equality.
Do not claim signaling-NaN or whole-domain compatibility.

The driver must first run the unchanged full S09 wrapper successfully, retaining
complete stdout/stderr/exit and all fresh raw artifacts. Require its unique full
marker, then invoke the unchanged strict validate-only gate before projecting
physical-order supplied cells and actual getter/null results. Validate-only
does not admit a runtime or emit a live-success marker.

Use a separate bounded, versioned original test manifest, not a public format.
Exactly ordered `finite-null` / `nonfinite` cases have 7 / 5 rows and one cell.
Each cell carries independent supplied and reference tags/payloads: `D` with
16 canonical lowercase hexadecimal digits or `N` with a separate null token.
Validate canonical counts, rows, cells, tags, payloads, membership, exhaustion,
caps before allocation, no trailing records and raw source/capture identities.
Reject unknown, duplicate, missing, reordered or malformed inputs.

Rust must build actual private values from supplied cells using the real float
constructor, store/read records and compare actual bits/nulls with reference
cells. Never copy expected payloads into actual values. Include an expected-only
manifest mutation that fails comparison while leaving all supplied cells intact.
Fixture labels may constrain selected dimensions, not supply expected values.

All generated artifacts and caches stay in canonical external temporary paths.
Retain complete raw data, manifest, runtime/source identities and per-negative
stdout/stderr/exit records, including failed attempts. Fresh copies must test
raw case/capture/hash/source/projection guards and independent manifest semantic
guards. Do not duplicate every S09 control: its unchanged full wrapper already
must pass all 45 raw and two artifact controls. No missing-runtime skips.

## Acceptance criteria

Freeze source before live capture. Primary and separate read-only Tester must
run that exact Demo at the reviewed source; additionally run workspace format,
tests, strict all-target Clippy, separate Bash syntax/Python compile checks with
external caches, diff and source hashes. Retain actual exits and full logs.
Resolve findings, reconcile records, run final PR-head Demo, integrate and then
record acceptance. No conversation or marker alone completes the slice.

## Demo Command

`bash tests/t0012_double_value_differential_test.sh && bash tests/t0012_page_value_differential_test.sh && bash tests/t0012_schema_differential_test.sh`

## Evidence class

Target: Unit/Contract plus Differential for the two selected S09 getter-result
projections only.

## Non-claims

Keep prior S08/S06 evidence unchanged. No general arithmetic,
numeric equality, normalization, schema validation, coercion, public API,
physical encoding, Arrow, ownership, batching, transfer, recovery, performance,
release or parent completion claim.

## Provenance

The accepted S09 packet supplies exact reference artifact/version/API/license
locators and observed bits. No additional upstream implementation inspection,
copying, translation or artifact admission is required. Standard-library public
conversion interfaces are used in original Rust code; no external algorithm is
adopted. License permission is not patent/FTO clearance; existing unreviewed
legal, redistribution and production supply-chain limits remain unreviewed.

## Stop rule

Return to PM before changing fixtures, equality meaning, schema/public scope,
allowlist, APIs/artifacts/dependencies or source-reuse boundaries, or on material
security/IP uncertainty. Routine retrieval/test failures are fixed in scope.

## Source review and verification

Final acceptance: the exact Demo at PR head
`994c68cf398f7c5c511ed2fccae58d539e6d7d18` passed with exit 0 and empty
stderr. Complete logs: `/private/tmp/t0012-s10-pr-head.wHcZGL`; stdout SHA-256:
`87efd49777f47ca2422062aa3cf2abe73e5b012f2e2671142a3e6e3f5ff3dcc0`.
[PR #93](https://github.com/bhind/emburk/pull/93) integrated as
`742274f23234b7f02f8be70a9e97f5bce86f14b3`. The source hashes below are
unchanged. This completes S10's 5 SP, not parent #15. Parent returns to Backlog;
known accepted S03–S10 estimates total 30 SP, Current 34 / Initial 5 unchanged.
The following source-review chronology preserves the earlier pending gates;
final-head acceptance and integration now satisfy them. All non-claims remain.

Frozen source: `3df2a888bf37d9871769a291436df4bcabe56cb6`, following
implementation `0aca08c`. Only the four authorized source paths changed.
Review corrected the independent expected-value representation, manifest size
caps, exact negative diagnostics, missing/extra cell rejection and exact ordered
bit/null assertions. Expected values are raw reference bits, never passed through
the candidate storage constructor. The local wrapper requires all six named
passing tests and one intentionally ignored live test.

The implementer ran the exact Demo successfully at the frozen source, retaining
complete stdout/stderr/exit in `/private/tmp/t0012-s10-demo.yptvkV`.
Independent Tester reproduction passed at the same source, retaining complete
logs in `/private/tmp/t0012-s10-independent.sSUB2B`; stdout SHA-256 is
`98997be62b80183a0116efd2dadd805e2e1e397f30dfbd22b410ce697a257019` and
stderr is empty. Both compared 12 selected double/null cells, rejected five
bridge mutations, reran all 45 S09 raw and two artifact controls, and passed
the unchanged S08/S06 regressions.

Independent quality logs: `/private/tmp/t0012-s10-quality.YjVnNB`.
Format, workspace tests (41 passed, seven intentionally ignored live tests),
strict all-target Clippy, Bash syntax, external-cache Python compilation and
diff checks passed. Implementer quality logs are separately retained in
`/private/tmp/t0012-s10-quality.RAzbKw`, including 19 Project Python tests.
Environment: macOS ARM64, Temurin 17.0.20, Rust/Cargo 1.98.1, Python 3.14.6,
Bash 3.2.57. These are test harness results, not runtime isolation evidence.

Source SHA-256 in allowlist order:

- `logical_record.rs`: `3ac865360e2a89fba0c15a8f4d8e72da08ebd869eb6f66b5a61b23fe1d19fbe3`
- `double_tests.rs`: `c099422d00b3c2d4757aa0b54bd250d47b6bd431e26903453f860add4741af19`
- driver: `f19e71fc15ce54de9a84a54d84411c48911bd8cfc72b3fec13470856cbc9a34d`
- wrapper: `eb7b4ef68ccf404ecef3c93a63e121e045e810ec4e525cfeea01e4f9dc607aa2`

The earlier successful Demo at `0aca08c` is superseded and retained at
`/private/tmp/t0012-s10-demo.AnDoic`; it is not corrected-source acceptance.
Temporary evidence is local and must be reproduced if removed. Final PR-head
acceptance and integration are still required before slice completion.

Primary exact Demo at the same frozen source passed with exit 0, retaining
complete logs at `/private/tmp/t0012-s10-primary.zigMIH`; stdout SHA-256 is
`7d49dacd73891711ddda7ce205b978e11cb36fa386c9741808c1abe98b4a9b8e`
and stderr is empty. Primary inspection confirmed independent reference bits,
exact record/cell shape checks and unchanged prior storage tests. Primary
format, workspace tests (41 passed/seven ignored), strict Clippy and diff checks
also passed. Evidence is Unit/Contract plus Differential for the two selected
projections only, pending integration; the parent remains open.

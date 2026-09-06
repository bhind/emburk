# T-0012/S10 private double-value storage and selected comparison

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: Ready; independent readiness review passed, implementation not started
- Branch: `feat/t-0012-private-double-values` (implementation, not yet created)
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

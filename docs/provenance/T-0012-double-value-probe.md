# T-0012/S09 bounded double-value observation

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: Prepared; independent readiness review passed with parent clarification
- Branch: `research/t-0012-double-value-probe`
- Owner: Compatibility Host Implementer; decisions, records and integration: PM
- Priority: P0; parent task T-0012; parent epic T-0010
- Estimate: 5 SP (implementation 2, uncertainty 1, verification 1, environment 1;
  raw 5). Within unchanged parent Current 34 / Initial 5. Known accepted
  S03–S08 slice estimates total 20 SP; S01/S02 have no retroactive points.
  No parent completion or duplicate parent/slice velocity is awarded.

## Authority and dependencies

Standing owner authority permits bounded implementation and independently
accepted PR integration. S08 integrated through PR #82 as
`b428305d6f2441dc62ea04736b631cf16389f9fb` after source acceptance at `914ad2e`
and final-head Demo at `332c721`. Its Null/Boolean/Signed64/Text representation
stays unchanged. Float64 is the next missing logical value boundary; schema
coupling and production transfer are not prerequisites for this isolated probe.
Use one active Project item and one serial source owner. Preserve user worktrees.

## Mutation owner and allowlist

One Compatibility Host Implementer owns exactly three new files:

- `tools/t0012-double-value-probe/src/T0012DoubleValueInputPlugin.java`
- `tools/t0012-double-value-probe/run.sh`
- `tests/t0012_double_value_probe_test.sh`

PM owns this packet, provenance index, STATUS, TODO, ROADMAP, ARCHITECTURE,
COMPATIBILITY, runtime design, S08 closeout and dated log. Testers and Librarian
remain read-only. Existing Rust, Cargo, CLI, S07/S08 and all other accepted
sources/tests remain unchanged. Original local instrumentation may be adapted;
upstream source, implementation or tests must not be copied or translated.

## Public-interface provenance and adoption

Access date: 2026-09-06. Librarian and PM independently inspected only public
signatures (`javap -public`) in the already admitted
[Embulk 0.11.5 executable](https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar).
Artifact SHA-256:
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`,
size 11109700 bytes. Core pin `c5ac2d471edac465b45088669d376a7e2a525f8f`;
SPI 0.11 pin `576e98033a14ba8ac994ed581d3c9d8fcdda2749`.

Exact artifact locators: `org/embulk/spi/PageBuilder.class` (`setDouble` by
index/Column), `PageReader.class` (`getDouble`, `isNull`),
`org/embulk/spi/type/Types.class` (`DOUBLE`). Existing S07 construction and
collection signatures remain the only supporting API route. PM permits these
signatures solely for independently authored reference instrumentation.

Verified retained artifact:
`/var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T/t0012-page-value-probe/run.9AMos8/embulk.jar`.
PM extracted its `META-INF/LICENSE` and `META-INF/NOTICE` and matched them to
that run's retained files, resolving the Librarian's evidence-path question:
SHA-256 respectively
`cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` and
`27f0e45afdf10e406ee8bf478bfce38279e9087338a7981942a4a2762bcd5be8`.
Known executable ZIP-prefix warnings were retained. Apache-2.0 classification
and immutable source license locators remain in T-0011 provenance.

The existing Temurin 17 runtime's `java.lang.Double` public interface provides
`doubleToRawLongBits(double)` and `longBitsToDouble(long)`; PM inspected these
signatures only, not JDK implementation. Use them as test observation transport,
not as an adopted production algorithm or an assertion about Embulk Page bytes.
No JDK source/constants copied from external tests, new artifact/dependency,
redistribution or external plugin admission. Existing license obligations are
not patent/FTO clearance. SBOM, redistribution, patent, standards, jurisdiction,
trademark and freedom-to-operate gaps remain unreviewed.

## Stage A: original fixtures and complete raw capture

Use one column `number:double`, identical ordered transaction/run schemas.
Exactly two fresh fixtures, in this order:

1. `finite-null`: seven fully assigned rows: `Double.MAX_VALUE`, its negative,
   `Double.MIN_VALUE`, its negative, positive zero, negative zero, explicit null.
2. `nonfinite`: five fully assigned rows: positive infinity, negative infinity,
   `Double.NaN`, and `Double.longBitsToDouble` of original selected bit inputs
   `0x7ff8000000000042L` and `0xfff8000000000042L`.

These inputs do not predict acceptance, getter results or NaN canonicalization.
Record actual supplied runtime bits separately from actual read-result bits,
using exactly 16 lowercase hexadecimal digits. Null is an explicit separate
tag, never zero or NaN. No decimal formatting normalization, arithmetic,
coercion, signaling-NaN or whole-domain equality claim is in scope.

Use the established isolated InputPlugin/local Maven route and a test-local
PageOutput collector. PageBuilder writes only to that collector, not the runtime
output. During each add(Page), synchronously call PageReader.setPage and read
all rows through nextRecord, including the final false. Read isNull before
getDouble and never call the getter for a null field. Capture page/row/cell
positions, exact null flags and actual getter bits. Retain no separate Page,
perform no asynchronous or post-add reads, and close the one fixture-local
reader in collector close. Reader internal retention and Page ownership remain
unobserved. Do not assume a fixed Page count or batching rule before capture.

Capture every supplied setter/null assignment and addRecord operation,
builder/collector/reader finish/close entry/return or exact exception,
transaction/run/control/cleanup boundaries, actual reports and terminal outcome.
Use capture UUIDs, contiguous canonical sequences, strict tagged arities,
Base64 UTF-8 exception transport (null distinct from empty), physical-order
raw logs, per-case exit/count/digest and complete combined traces. Record exact
exception class/message for semantic RuntimeExceptions. Setup/linkage Errors
and evidence-write failures must not become supported semantic outcomes;
check output errors explicitly and retain unsuccessful logs.

Runner modes: `capture`, `full`, and `validate`. Capture mode validates bounded
transport/completeness only and emits a distinct capture-only marker. It must
not assume successful operations, particular getter bits or canonicalized NaNs.
Stop after the first complete Stage A capture and send PM the frozen source,
all actual raw events and exits. Do not implement Stage B expected vectors
before PM reviews capture and records the decision in this packet.

## Required PM decisions after capture

| Question | Evidence required | Decision boundary |
| --- | --- | --- |
| Are finite values, signed zero and null distinguishable? | Separate actual inputs, null flags, getter bits and positions | Record exact selected outcomes; do not infer schema or conversion rules |
| Are nonfinite values admitted? | Actual operation results/exceptions and process exits | A rejected fixture is an observation, not grounds to replace inputs silently |
| What happens to selected NaN payloads/signs? | Actual getter bits, not numeric equality or expected input constants | Record preservation/canonicalization precisely; no unobserved normalization |
| Which Rust representation/equality is justified? | Accepted reference gate followed by a later explicit decision | No Float64 enum variant or Eq-policy change in S09 |

## Stage B and acceptance

After PM freezes the exact observed outcome matrix, validate complete ordered
events and all per-cell values, not counts alone. Canonical case membership,
capture/sequence, caps before allocation, raw-log extraction, trace copies,
hashes and schema must be checked independently of semantic expectations.
Reject unknown, missing, duplicate, reordered or unpaired events. Full mode
requires two fresh runs plus strict raw gates; validate-only cannot substitute
for artifact admission or emit the full marker.

Every negative starts with a fresh raw copy. Repair sequence, case counts,
digests and logs when testing a deeper semantic invariant. Assert exact intended
diagnostics and actual nonzero exits. Cover case/capture/sequence/log/digest,
schema, malformed/noncanonical hex and null tags, changed finite bits, zero
sign, infinity sign, selected NaN bits, input-versus-getter contradiction,
missing/reordered rows, getter/null pairing, reader exhaustion, setters,
finish/close and terminal/cleanup. Artifact corrupt-hash and unavailable-runtime
controls remain separate, with pinned retrieval identity preserved.

All generated artifacts stay in external temporary directories, with resolved
paths outside the repository. Retain runtime/source/JAR/coordinate/stage
identities, LICENSE/NOTICE, source revision/hashes, complete stdout/stderr and
raw evidence including failed attempts. No missing-runtime skip or fabricated
success marker. Ordinary retrieval and tool-output issues are fixed in scope.

Stage A Demo Command:
`T0012_DOUBLE_MODE=capture bash tests/t0012_double_value_probe_test.sh`

Final Demo Command:
`bash tests/t0012_double_value_probe_test.sh && bash tests/t0012_page_value_differential_test.sh && bash tests/t0012_schema_differential_test.sh`

Primary and a separate read-only Tester must review frozen source and reproduce
the exact final Demo with complete outer stdout/stderr and actual exit records.
Run workspace tests, format, strict all-target Clippy, separate Bash syntax,
diff/source-hash checks. Final PR-head Demo and integration are required before
the slice is accepted. Prior S08/S06 claims stay limited and unchanged.

## Evidence class, non-claims and stop rule

Target evidence: Reference Observation / Integration for exactly these two
original reference fixtures; Unit/Contract for validator controls. No new
Differential or native Float64 result, public API, schema coupling, physical
encoding, Arrow, Page ownership, batching, plugin host, production transfer,
recovery, performance, release or parent completion claim.

Return to PM for changes to fixtures, APIs/artifacts, exact source allowlist,
capture transport exclusions, new dependencies, source-reuse policy or material
security/IP uncertainty. Never alter accepted S07/S08 or Rust to pass this probe.
Stage A-to-B and any later Rust value/equality decision remain explicit gates.

Independent read-only readiness review passed after clarifying the parent task
versus parent epic. No runtime evidence or Float64 policy follows from readiness.

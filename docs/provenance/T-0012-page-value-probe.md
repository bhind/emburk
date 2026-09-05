# T-0012/S07 bounded Page value observation

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: Ready; independent packet review passed with capture clarification
- Branch: `research/t-0012-page-value-probe`
- Priority: P0; parent T-0010
- Owner: Compatibility Host Implementer; records/decisions/integration: PM
- Slice estimate: 3 SP (implementation 1, uncertainty 1, verification 1,
  environment 1; raw 4). Parent Current refines 8 to 34; Initial stays 5.
  Known S03–S06 slice estimates already total 12 accepted SP. S01/S02 are not
  retroactively assigned points. This observation, later native value/comparison
  work and remaining configuration/Float64/time/JSON uncertainty exceed the old
  forecast. The refinement is not earned velocity or parent completion.

## Authority and dependencies

Standing owner authority permits bounded implementation and independently
accepted PR integration. PM owns decisions and canonical records; one source
implementer and a separate read-only Tester operate serially at frozen source.
Preserve the user's checkout and all unrelated worktrees.

T-0011 artifact provenance and T-0012/S05–S06 ordered schema observations are
integrated. T-0013/S08 integrated through PR #80 as `de38a44`; return T-0013
to Backlog, with cleanup/recovery gaps and parent #16 open. T-0021 remains
Backlog. Use one active Project item of the two-item limit.

Prioritize the missing value/record boundary because it directly precedes
meaningful native File-to-File data movement. Further cleanup-failure observation
still gates production recovery, but need not block this isolated test fixture.
No public API extraction is justified by this observation.

## Mutation owner and exact allowlist

One Compatibility Host Implementer owns only these new files:

- `tools/t0012-page-value-probe/src/T0012PageValueInputPlugin.java`
- `tools/t0012-page-value-probe/run.sh`
- `tests/t0012_page_value_probe_test.sh`

PM owns this packet, provenance index, STATUS, TODO, ROADMAP, COMPATIBILITY,
ARCHITECTURE, RUST_RUNTIME_DESIGN and dated log, including S08 closeout.
Existing config/schema/lifecycle tools, Rust source/tests, Cargo, dependencies,
CLI and public APIs remain unchanged. Original repository-owned instrumentation
patterns may be adapted, not upstream implementation or fixtures.

## Public-interface provenance and adoption decision

Access date: 2026-09-06. Librarian triaged and primary independently verified
`javap -public` only against the admitted official
[Embulk 0.11.5 executable](https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar).
SHA-256: `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`;
size 11109700 bytes. Core pin: `c5ac2d471edac465b45088669d376a7e2a525f8f`;
SPI 0.11 pin: `576e98033a14ba8ac994ed581d3c9d8fcdda2749`.
Artifact locators: `org/embulk/spi/PageBuilder.class`, `PageReader.class`,
`PageOutput.class`, `Exec.class`, `Schema.class`, `Column.class`,
`BufferAllocator.class` under that same package.

Confirmed public signatures allow PageBuilder(BufferAllocator, Schema,
PageOutput), setNull/setBoolean/setLong/setString by index or Column, addRecord,
finish/close; PageReader(Schema), setPage, nextRecord, isNull, getBoolean,
getLong, getString and close; Exec.getBufferAllocator/getPageBuilder/getPageReader;
PageOutput.add(Page), finish and close. PM adopts these signatures solely to
author the original fixture. They do not establish encoding, null getter values,
callback timing, lifetime or buffer ownership semantics.

Verified artifact retained at
`/private/var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T/t0013-output-commit-position.0oDdCD/embulk.jar`.
Its retained META-INF/LICENSE/NOTICE are nonempty (11358/18251 bytes).
An earlier unverified cache candidate is not adopted. Apache-2.0 source
classification and exact source locators remain in T-0011 provenance.
No implementation decompilation, source copying/translation, new dependency
or external plugin is admitted. Original probe source may be published;
downloaded executable/generated JARs stay external and local-only.
Redistribution/SBOM, patent/standards/trademark, jurisdiction and freedom-to-operate
gaps remain unreviewed, not legally cleared.

## Stage A: capture before expectations

Construct exactly two original fixtures with one three-column schema:
`flag:boolean`, `number:long`, `text:string`, in that order.

- `empty`: zero records.
- `typed-null`: three fully assigned records, in order:
  (true, signed-64 maximum, empty String);
  (false, signed-64 minimum, String `A|B\n\u03bb`, where newline and lambda are
  literal characters);
  (explicit null, explicit null, explicit null).

These are supplied inputs, not assumed successful read results. Every column is
explicitly set for every row; no default/reset/unset behavior is inferred.
InputPlugin uses the established local-only Maven runner route, but PageBuilder
writes to an original test-local PageOutput collector, not the runtime's output.
The collector synchronously reads the supplied Page through PageReader during
add(Page). Read each null flag before its matching typed getter; never call a
typed getter for null. Record actual values and row order, not input constants.
Do not retain, forward or reread Pages after the collector returns; do not
inspect physical bytes/layout. Use one explicit fixture-local reader lifetime
and record close/finish operations and exceptions. Do not claim that chosen
fixture ownership is a general plugin handoff contract.

Capture complete physical-order operation/callback entry/return records,
transaction/run schema indices/names/type names, capture UUID and contiguous
sequence, per-page/total row counts, per-cell null flags and typed results,
terminal outcome and exact exception class/message (null distinct from empty),
actual process exit and raw logs. String output is Java getter text encoded as
UTF-8/Base64 for transport, not Page-byte encoding. Emit input provenance
separately from read outcomes. No guessed fixed Page count or batching policy.

For every collector add(Page), capture PageReader.setPage entry/return and every
nextRecord boolean result, including terminating false, with page ordinal and
physical order. Capture entry/return or exact exception for collector add,
builder addRecord/finish/close, collector finish/close and reader close under the
explicit reader lifetime. This independent readiness-review clarification proves
capture completeness without predicting outcomes or page counts. PM accepts it;
the read-only review found no other material packet ambiguity.

Keep setup/linkage Errors and evidence-write failures distinct from semantic
operation exceptions; do not catch them as supported behavior. All raw evidence
must survive unsuccessful runs. A capture-only command may validate transport
completeness but MUST NOT emit the full acceptance marker or assume successes.
Stop after initial capture and provide source revision, raw evidence and actual
outcomes to PM before adding fixture-specific semantic expectations.

## Stage B: reviewed expectations and controls

After PM records the initial raw outcome matrix, validate exactly those bounded
observations. Require fresh complete captures, canonical Base64/UTF-8 transport,
exact fixtures/schema/sequence and raw-log/hash consistency, explicit cell-null
versus value tags, complete row/page boundaries and actual terminal outcomes.
Bound counts before allocation. Reject missing/duplicate/unknown cases/events/
columns, truncation, contradictory counts/schema/null/value records and altered
ordered values. Preserve instrumentation order without guessing general API
behavior. Use repaired raw copies for semantic controls, with fresh copies and
intended diagnostic assertions. Exercise changed Boolean/Long/String values,
null contradictions, missing/reordered rows/callbacks and transport corruption.

Retain runtime URL/hash/manifest/license/notice, source path/hash, generated local
coordinate/JAR hash, Java/platform versions, per-case raw logs/digests and exits.
Require the pinned artifact; unavailable-runtime and corrupted-copy controls
must fail with their expected setup diagnostics before fixture execution.
No missing-runtime skip, synthetic-only success or zero-observation pass.

## Artifacts and Demo Command

All generated runtime/config/plugin/log/evidence files live in validated external
temporary directories, never tracked or published.
Stage A command: `T0012_PAGE_MODE=capture bash tools/t0012-page-value-probe/run.sh`.
The implementer reports its actual capture-only outcome, not task acceptance.

Final Demo Command:
`bash tests/t0012_page_value_probe_test.sh && bash tests/t0012_schema_differential_test.sh`

The first script must exercise exactly two fresh live fixtures, semantic/
transport controls and both artifact controls, then emit exactly one
`T0012_PAGE_FULL_PROBE=passed|evidence=...` marker only after all pass.
The unchanged S06 regression must still compare its three actual schema outcomes.
Also run separate Bash syntax checks, source/diff hashes and workspace tests,
format and strict Clippy. Primary and read-only Tester reproduce the exact Demo
at frozen source; final PR-head Demo passes before integration.

## Evidence class and non-claims

Planning until capture; Reference Observation / Integration only after accepted
live reference execution, Unit/Contract for synthetic validator controls.
No Rust values, Differential comparison, Arrow/Page encoding, general nullability,
conversion, Float64/time/JSON behavior, production data transfer, plugin/host/API,
arbitrary Page ownership, batching, durability, resume, performance or release
claim. Parent #15 and phase delivery gates remain open.

## Stop rule

Repair ordinary build, retrieval and harness failures and retain failed attempts.
Return to PM before semantic expectations (Stage A gate), any source allowlist
expansion, new artifact/dependency/API, upstream implementation inspection,
ownership/encoding policy adoption or material IP/security uncertainty.
Never weaken a guard or fabricate observations to pass.

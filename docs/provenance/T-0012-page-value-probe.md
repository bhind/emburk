# T-0012/S07 bounded Page value observation

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: Done as a bounded slice; PR #81 integrated as `203d7da`; parent remains open
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
Do not retain a separate Page reference, forward it, read asynchronously or
reread it after the collector returns; do not inspect physical bytes/layout.
The PageReader object itself has one explicit fixture-local lifetime ending
at collector close. Its internal retention/ownership is neither inspected nor
claimed. Use that one explicit fixture-local reader lifetime
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

## Initial capture and PM Stage B decision

Stage A source revision: `66ef66a66b9624d3072728656fb2d7bb8aee4e11`.
Exact capture command exited 0. External evidence:
`${TMPDIR}/t0012-page-value-probe/run.Ysvo8G/evidence`; outer logs:
`/private/tmp/t0012-s07-stage-a.nJKQh7/capture.stdout.log` and
`capture.stderr.log`. The latter retains known executable ZIP-prefix warnings
and the Java deprecation note; it is not empty. No full acceptance marker was
emitted. Primary read every decoded raw event and reviewed the original Java,
runner and wrapper; the trace writer now raises a dedicated Error on output
failure, outside the semantic RuntimeException boundary.

Source SHA-256 (Java, runner, wrapper):

- `bb49b204003b3d021d78f0a7113136471f4f0ab70ea9a3df971414a7a8f66836`
- `dcfdb42aa36f00adcb82fea52eab543d8c91e7d5c8dea9894dfd5c87611cb5ee`
- `65b38880328f1538d2eaa851313249b18833e49a5005a9357380561b00750a57`

Cases/traces SHA-256:
`8b546716e8cd9624e36f1f1a9c24a3e0427d5c7fff9eab80f0604c30c57b782e` /
`5881d1ade93cccb6c81429b32415135fd3d9b87793e5f5834439a2aa8fba5b32`.

| Fixture | Process / events | Actual local collector observation |
|---|---|---|
| empty | Exit 0 / 32 | No Page add, zero rows; collector finish then close |
| typed-null | Exit 0 / 110 | One Page add; three ordered rows; nextRecord true, true, true, false |

Both transaction/run schemas were exactly the selected three ordered columns.
Typed getters returned true/MAX/empty text, then false/MIN/literal newline and
lambda text as supplied; all three cells of the final row had isNull=true and
no typed getter. For both fixtures, builder finish enclosed collector finish;
the nonempty Page add/read sequence occurred before that collector finish.
Builder close enclosed collector close, which enclosed reader close. Runtime
output finish followed; run/control/transaction returned normally, then one
success terminal and cleanup with one report. These are selected fixture facts,
not a general delegation, batching or cleanup policy.

PM clarified the no-retention wording to match the actual fixture boundary:
the fixture keeps no separate Page reference and performs no reads after add
returns; the PageReader object remains alive until collector close. This does
not assert that PageReader internally drops or retains a Page at any point.
No source change or production ownership decision follows from this correction.

PM authorizes Stage B semantic guards for these exact observations, with all
input assignments kept separate from actual getter records. Validate complete
physical order and event arities, including setter/addRecord pairs, every
null check, matching typed getter or cell-null, final nextRecord=false, nested
finish/close and terminal/cleanup. The observed 0/1 Pages and 32/110 events may
constrain these tiny fixtures only, never become a general batch-size rule.
Exact schema/row/value outcomes must be checked, not just those totals.
No Java fixture or ownership-policy change is needed for Stage B. Preserve the
Java source hash unless PM first approves an instrumentation correction.

Validate canonical fixture/capture/sequence and raw-log extraction equality,
not only the digest of a second trace copy. Reject unknown/extra PAGETRACE rows
instead of silently dropping them. Every semantic negative starts from a fresh
copy and repairs trace sequences, case counts, hashes and raw logs; assert its
intended diagnostic. Include malformed/missing/duplicate/unknown cases and
events, wrong arity/Base64/capture/sequence/log/digest, huge counts, wrong schema,
changed Boolean/Long/String, null/getter contradictions, missing or reordered
rows/page exhaustion, setters/addRecord, close/finish and terminal/cleanup.
Validate artifact identity separately and exercise unavailable/corrupt controls.
Capture-only and validate-only modes cannot emit the full live acceptance marker.

This decision is based on the first raw capture, not frozen-source acceptance.
Independent reproduction and final Demo remain required before any accepted
Reference Observation / Integration claim; no Rust policy is authorized here.

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

## Primary frozen-source acceptance

Frozen source: `1e7d5c987bac2ca9068606b7bb9a57147c3dea0c`.
Exactly the three owned new source/test paths differ from the activation base;
all existing schema/lifecycle/Rust sources remain unchanged. Java hash remains
`bb49b204003b3d021d78f0a7113136471f4f0ab70ea9a3df971414a7a8f66836`.
Final runner/wrapper SHA-256:
`c11df66e397beef649d65ee07bd757a6b64b98fd58ab216bcfa7af0ac07aaafa` /
`08644bf4695df0753a8ba049aacc726e098aac58dcff97e57a7f95234411bb2b`.

PM reviewed the complete source. Before freeze, review separated transport-only
capture from exact semantic validation, bounded canonical decimals before int
conversion, enforced combined trace order and actual log extraction equality,
and made duplicate-case testing preserve two rows to reach identity rejection.
Wrong process exit and overlong sequence received diagnostic-specific controls.
The writer's dedicated Error keeps evidence failures outside semantic catches.
The final full marker is emitted only by the wrapper after fresh positive,
artifact-negative and repaired raw-negative gates; validate-only cannot emit it.

Primary exact two-script Demo exited 0 at this frozen revision. It validated
two fresh Page fixtures (32/110 events), all 39 repaired raw controls, corrupt
artifact exit 3 and unavailable-runtime exit 56, exactly one full marker, and
unchanged S06 three live schema comparisons. Source identity in the live
evidence records the exact revision. Workspace tests passed 29 with five
intentional live ignores; formatting, strict workspace/all-target Clippy,
separate Bash syntax and ordinary/staged diff checks passed. Platform remains
macOS 26.5.1 arm64, Temurin 17.0.20, Rust/Cargo 1.98.1, Python 3.14.6,
Bash 3.2.57. No broader suite or live-test ignore is counted as a Page observation.

Primary combined logs: `/private/tmp/t0012-s07-primary-acceptance.JONwid`.
Stdout SHA-256:
`1e06241f0081e161a82b95ed9b5d02a09157ed882daa858f7d8232e6b72e216a`;
stderr is empty (runner warnings remain in its separate retained attempt log).
Page evidence: `${TMPDIR}/t0012-page-value-probe/run.JxF6HZ/evidence`;
S06 regression: `${TMPDIR}/t0012-s06.YP3O0O`.
Raw cases/traces SHA-256:
`cbff932bf5f6a30e130313a4f64ae39e5641d8d1ccc521da6a89df8a942387f8` /
`fd3e90c5f2a21c3ebebdd703d3402d4e604e3728f5bcd99530ec340841900295`.
Empty/typed-null trace SHA-256:
`22325d9f5e9a61936064b69e91e6eb359558bf3966c29c401383a7e910e19b92` /
`4e32f5b1a74157c73c0803a182febb2aaf6b1d99be0b048f2d9439ad8c42ba45`.

Implementer post-freeze exact Demo independently of the primary run also passed:
`/private/tmp/t0012-s07-stage-b.SMrOYM/frozen-demo.stdout.log`, Page evidence
`run.dCXoHy/evidence`, S06 `t0012-s06.8o2CAz`. Earlier 37-control/pre-commit
passing drafts remain separate and do not substitute for frozen acceptance.
Read-only Tester reproduction, final-head acceptance and integration remain
required. Evidence is selected Reference Observation / Integration plus local
validator Unit/Contract; unchanged S06 regression adds no new Differential claim.

### Independent frozen-source acceptance

Read-only Tester reproduced the exact Demo at `1e7d5c9` with persistent-session
actual child/tool exit 0. Two Page cases, 39 intended-diagnostic raw controls,
both artifact controls, one full marker and three unchanged S06 live schema
comparisons passed. Source hashes and the three-path source boundary match.
Workspace 29 passed/five intentional ignores, formatting, strict Clippy,
separate new runner/wrapper Bash syntax and diff checks passed independently.
The runner syntax check was added explicitly after the initial report listed
the existing S06 wrapper instead; no full Demo rerun or source change was needed.

Logs: `/private/tmp/t0012-s07-independent-persistent/demo.stdout.log` and
`demo.stderr.log`; stdout SHA-256
`14f8fef53349d0a10b59fcb4c0916a5265b3df2e5fe82ef0f03f88dfce50fae2`;
stderr empty. Primary inspected the retained logs and hashes.
Page evidence: `${TMPDIR}/t0012-page-value-probe/run.dX6Riz/evidence`;
S06: `${TMPDIR}/t0012-s06.ZJKLSy`. Raw cases/traces SHA-256:
`ff209a22d53e6cd29bdcfe4bdb1d0903ef5a127a12ba019db52dd7253cfddd04` /
`c4c9d48f54ad164bfa7f2bd4646835419809647ac54c86c85395b2b30c5bc584`.
No remaining acceptance finding. Final-head Demo and PR integration remain
required; source acceptance does not complete parent #15 or any native value gate.

### Final-head acceptance and integration

Final PR-head exact Demo passed with exit 0 at
`3b95ecdb6918b6ff6449ffb977ee79dba1c0dc21`: two Page fixtures, 39 raw controls,
artifact controls, one full marker and unchanged three-schema regression.
Source hashes match frozen acceptance; only canonical records changed afterward.
Logs: `/private/tmp/t0012-s07-final-head.pFH4ht`; stdout SHA-256
`8b6a73766fc2f0f35c41041d58d30bc19a1753cd3c5c99ab5a6790867ae287b3`;
stderr empty. Page evidence: `${TMPDIR}/t0012-page-value-probe/run.kbwGa8/evidence`;
S06: `${TMPDIR}/t0012-s06.sHVg2E`. Project delivery/governance and clean-head
checks passed before exact-head guarded squash integration. PR #81 merged as
`203d7daa9fe27f7421e06ea0a0eca91cc1dc1ff8`. This 3 SP slice is accepted;
known S03–S07 slice estimates total 15 SP, not parent completion or retroactive
S01/S02 points. Parent #15 stays open for remaining contracts.

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

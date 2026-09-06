# Compatibility

Compatibility is an evidence record, not a general promise.

The implementation objective is strict reproduction of observable behavior for
the pinned core and admitted plugins. Technical constraints, disproportionate
effort, or unavoidable Java/Rust differences may justify an explicit exception
only after recording a reproducer, alternatives, estimated effort, migration
impact, and owner decision. Missing implementation is not an accepted deviation.
Each approved exception must identify the affected pinned artifact and fixture
and remain a known deviation marked `Partial`; that scope cannot be `Verified`.
Unchanged subscopes may be verified only with explicitly delimited evidence.
See the [Rust design proposal](RUST_RUNTIME_DESIGN.md) for pending contract gates.

## Baseline

- Initial core behavior reference: Embulk `v0.11.5`, commit
  `c5ac2d471edac465b45088669d376a7e2a525f8f`
- Initial Java SPI reference: `org.embulk:embulk-spi:0.11`, source tag `v0.11`,
  commit `576e98033a14ba8ac994ed581d3c9d8fcdda2749`
- Admitted external plugin artifacts: none
- Older Embulk lines and every plugin artifact require separate admission and version pinning.

## Status Vocabulary

| Status | Meaning |
| --- | --- |
| Planned | Selected for investigation but not implemented. |
| Hosted | The original pinned artifact runs through a compatibility host. |
| Native | Observable behavior has been independently implemented in Rust. |
| Verified | The pinned implementation passes the required differential matrix. |
| Partial | Known supported and unsupported behavior is documented. |
| Blocked | Evidence, licensing, runtime, or upstream availability prevents support. |

A plugin may be Hosted and Verified, or Native and Verified. Hosted never implies Native.

## Verification Matrix

Verification covers configuration defaults and validation; schema and value semantics; empty input, nulls, malformed records, and boundary values; single-task and multi-task execution; output ordering where guaranteed; interruption, abort, cleanup, retry, and resume; external-service integration; and artifact origin, checksum, license, and notices.

## Current Support

No data-transfer path or plugin is Verified yet. The first target is a native File-to-File path covering CSV, JSON, gzip/bzip2, basic column filters, guessing, transaction handling, and resume.

The private raw-scalar resolver is Partial/internal, with 13 selected typed
outcomes compared live against the pinned Embulk 0.11.5 executable: nine
missing/null/value cases for required String, explicit String default, and
Optional<String> with null default; Boolean true/false; and Long 37/maximum.
The comparator uses actual reference results and rejects unknown exceptions,
malformed or incomplete evidence, and a changed expected outcome. See
[T-0012/S04](provenance/T-0012-live-scalar-differential.md) for acceptance status.
This is not YAML parsing, a public configuration API, whole-domain differential
coverage, exact Java diagnostics, lexical/fractional coercion, overflow behavior,
schema/value support, or end-to-end configuration compatibility. Those gaps
are pending work, not accepted deviations.

[T-0012/S05](provenance/T-0012-schema-boundary-probe.md) records reference-only
schema observations: empty, six ordered logical types, and duplicate-name
columns constructed and reached the run callback without changing their
ordered fingerprints. This does not add Native or Verified schema support,
name lookup, nullability, Page/value encoding, or a lifecycle contract.

The private ordered logical schema is Partial/internal. Primary and independent
[S06 acceptance](provenance/T-0012-ordered-schema-differential.md) compares the
same three selected cases against actual S05 run-phase data and preserves
the duplicate-name pair as two ordered positions. Internal tests also cover
owned-name storage and malformed evidence. This is not a full schema API,
validation policy, arbitrary-name compatibility, lookup, nullability, values,
Page/Arrow encoding or lifecycle claim. PR #69 integrated the slice as `5de35b7`.

[T-0013/S01](provenance/T-0013-input-lifecycle-probe.md) records a bounded
input-side reference observation: zero and one empty task processes exited 0,
with six and ten probe markers respectively, including cleanup. The one-task
probe's call to `PageOutput.finish()` returned normally. No resume or guess
marker occurred. This does not establish output callback ordering, delivery,
cleanup guarantees, failure/retry behavior or Native/Verified lifecycle support.
Primary and independent acceptance passed; PR #70 integrated as `e8b5726`.
S02's direct output-side primary observation records zero/eight output tasks
for zero/one input tasks, respectively. The one-input run records output
open/finish/commit/close pairs; no add, abort or resume marker occurred. This
is not a default fan-out algorithm, durable commit, general callback-order
guarantee or Native/Verified lifecycle claim. Independent acceptance passed;
PR #71 integrated as `d474b7b`. S03's primary input-run failure observation
records the exact injected exception propagating, output abort/close and
cleanup with fresh capture IDs and zero reports. Normal control exited 0;
failure exited 1. This is Reference Observation / Integration only, not native
failure handling, rollback, cleanup/retry guarantees or a Java loading contract.
Independent acceptance passed; PR #72 integrated as `8e43948`.
T-0021/S03's private coordinator passes five local lifecycle tests at `84edf00`
for explicit zero/one-input plans, separate reports/cleanup and the selected
input failure. Independent Tester reproduced these results. This is
Unit/Contract only, integrated through PR #73 (`14d5fb5`); no new Native/Verified lifecycle
entry follows.

T-0013/S04's two selected live projections pass primary acceptance at `98b6cac`;
independent Tester reproduced the results, and PR #74 integrated as `68d848c`
after final-head acceptance at `09ac159`. Its projections exclude
default planning, capture identity, Java report contents and zero-task live
coverage; no generalized lifecycle claim follows from activation.

S05's selected output commit failure observation passes primary acceptance at
`876e861`: only the failed handle aborts, all close, and cleanup receives input
1/output 7 reports for the observed 1/8 plan. Independent acceptance passes;
final-head acceptance passed and PR #75 integrated as `2901c31`. It adds no
native output-failure, partial-publication or rollback
policy, and does not observe arbitrary failure indexes.

T-0021/S04's private last-commit failure passes primary and independent
Unit/Contract acceptance at `b8dbc77` under ADR-0009; final-head acceptance
passed at `d885ba2` and PR #76 integrated as `b5cfb87`.
Its local candidate and existing input-failure live regression do not establish
a new output-failure Differential result or a public Native/Verified entry.
T-0013/S06 is the next test-only comparison packet for those two selected
output-commit scenarios. Primary source acceptance at `a284f8b` now matches
normal 44-event and selected last-failure 43-event projections, including
cleanup reports 1/8 versus 1/7 for the observed 1/8 plan. Independent Tester
reproduced these results; final-head acceptance at `7d90f5d` passed and PR #77
integrated as `3b16aaf`.
This is two selected Differential projections,
not general commit handling or a public plugin certification.
S07 prepares a separate first/middle reference-only observation; no new position
coverage or Rust policy is claimed before its capture and acceptance gates.
Its initial capture at `fb26813` records first/middle abort suffixes and retained
report counts. Primary and independent full source acceptance pass at `76dbab0`:
three cases, 57 semantic controls, two artifact controls and S05 regression.
Final-head acceptance at `133cddb` passed and PR #78 integrated as `14cc2a6`.
This is Reference Observation / Integration, not first/middle Rust compatibility;
see the packet's per-index observation matrix. T-0021/S05 now prepares the
private Unit/Contract candidate under ADR-0010 with no new Differential claim.
Its primary and independent source acceptance pass at `f2d9755`: first/middle
local execution retains prefix reports and aborts the uncommitted suffix, with
existing S04/S06 live regressions unchanged. This adds no new first/middle
Differential result or public verified plugin entry. Final-head acceptance
passed at `02673ba`; PR #79 integrated as `d36cf28`. S08 prepares the separate
three-case first/middle comparison gate; no new match is claimed before it passes.

S08 primary and independent acceptance at `4c591a0` now passes three selected
normal/first/middle empty-fixture comparisons, 57 raw controls and unchanged
S04/S06 regressions. Full event order, committed reports and aborted suffixes
match after exact runtime-local error validation. Workspace 29 passed/five
intentional ignores and strict checks pass. Evidence is Unit/Contract plus
selected Differential, not general index/concurrency, data transfer, durability,
resume, public API or production readiness. Final-head acceptance and integration
remain required; the parent and delivery gates stay open.

S08 final-head exact Demo passed at `ff8dec0`; PR #80 integrated as `de38a44`.
Its three selected Differential projections are accepted, not a general recovery
contract. Parent T-0013 returns to Backlog and remains open. T-0012/S07 now
prepares two isolated PageBuilder/test-local collector/PageReader observations
under its [packet](provenance/T-0012-page-value-probe.md), before selecting any
Rust value representation. Only Boolean/Long/String and explicit null inputs
are selected. No runtime, public API, Page encoding or transfer claim follows.

S07 initial capture at `66ef66a` returned two successful reference executions:
empty had zero Pages/rows; typed-null had one Page and three ordered rows with
true/MAX/empty text, false/MIN/newline-and-lambda text, then three explicit nulls.
Primary reviewed the complete raw capture before authorizing semantic guards
at `ec558d1`. This is initial observation, not source acceptance or a selected
Rust representation. Full negative gates, independent reproduction and final
integration remain required.

S07 primary and independent source acceptance pass at `1e7d5c9`: two fresh
Page observations, 39 diagnostic-specific repaired raw controls, two artifact
negatives and unchanged S06 three-schema comparison. Workspace 29 passed/five
intentional ignores, formatting, strict Clippy and Bash syntax pass. Evidence
is selected Reference Observation / Integration plus validator Unit/Contract;
no Rust values, production transfer or new Differential result. Final-head
acceptance and integration remain required; parent and phase gates stay open.

S07 final-head Demo passed at `3b95ecd`; PR #81 integrated as `203d7da`.
Its two bounded reference observations are accepted. T-0012/S08 implements
private owned Null/Boolean/Signed64/Text records under ADR-0011. At frozen source
`914ad2e`, primary and independent acceptance pass two selected getter-result comparisons,
18 raw controls, six local storage/transport tests and the unchanged three-schema
regression. Workspace 35 passed/six intentionally ignored, formatting and strict
Clippy pass. Final-head Demo passed at `332c721`; PR #82 integrated as `b428305`.
Schema coupling, physical encoding, public API and production transfer remain
outside this slice; parent and phase delivery gates stay open. S09 prepares a
separate reference-only double-value observation, with a capture-before-
expectations gate and no Rust Float64 or equality-policy change.
S09 primary and independent source acceptance pass at `3f18966`: two selected
reference double fixtures (114/93 events), 45 diagnostic-specific raw controls,
two artifact controls, unchanged S08/S06 regressions and strict quality checks.
Selected finite/subnormal/signed-zero/null/infinity/NaN bits are preserved in
these observations. Evidence is Reference Observation / Integration plus
validator Unit/Contract, not a native Float64 or numeric equality decision.
PR #91 is in Review; final-head acceptance and integration remain required.

S09 final-head Demo passed at `59f1b2e`; PR #91 integrated as `34757c8`.
Its selected reference observations are accepted; parent T-0012 remains open.
S10 implements the private bit-preserving representation permitted by ADR-0012.
Frozen source `3df2a88` passed implementer and independent Tester acceptance:
12 selected double/null cells, five bridge controls and unchanged S09/S08/S06
regressions. Its private equality is storage identity, not numeric equality.
Primary and final-head acceptance passed; PR #93 integrated as `742274f`.
The S10 slice is Done with Unit/Contract and the two selected Differential
projections. No public value, schema coupling, physical encoding, whole-domain
or production claim follows; parent and delivery gates remain open.

T-0021/S06 implements the private synchronous owned-record handoff permitted by
ADR-0013. Frozen source `8fe820b` passes primary and independent exact Demo:
five handoff tests, 46 workspace passes/seven intentionally ignored live tests,
format and strict Clippy. It moves records directly, preserves selected bits and
typed errors, and stops callbacks on the first failure. Final PR-head acceptance
passed at `8cb13ff`; PR #96 integrated as `56ef9e9`. S06 is Done.
Evidence is Unit/Contract only, not a public
API, schema/lifecycle policy, resource guarantee or Embulk compatibility claim.

T-0012/S11 Stage A at `a95e350` captured five outcomes and 289 events,
independently reproduced and fully reviewed by PM. Matching/null/duplicate-name
cases read selected values; fresh unset text fails at addRecord and string-to-long
misuse fails at the setter. Stage B automation passes at `b556ce0`: five exact vectors, 39 repaired-copy
controls and two artifact controls. Primary and separate reproduction pass;
final-head Demo passed at `da7e50f`; PR #99 integrated as `413f837`.
The bounded observation slice is Done; parent contracts remain open.
These diagnostic observations do not select native defaults or validation.
A separate reviewed decision must precede schema-bound record implementation.

T-0023/S01 is Done through PR #101 (`d0eebf8`). Seven local tests
passed primary and independent final-head acceptance as Unit/Contract evidence for an internal positional
batch invariant only; it adds no native Differential or supported schema/value claim.

T-0023/S02 is Done through PR #103 (`5d72866`) with Differential
evidence limited to matching, explicit-null and duplicate-name S11 projections.
Primary and independent final-head evidence passed at `ca9af0a`; this does not
broaden the supported product compatibility surface.

T-0012/S12 is Done through PR #105 (`67f0786`) for seven selected configuration-envelope observations.
It does not repeat S01/S02 scalar fixtures or establish native YAML, nested
configuration, unknown-key, default, or external-error policy. Primary and
independent Stage A agree on three successful 12-event traces and four
no-callback failures. Primary and independent final-head acceptance passed at
`9df0d5c`; this remains reference evidence, not native Differential compatibility.




The [parser candidate assessment](provenance/T-0022-parser-candidates.md) is
Planning only; no native YAML parser or coercion policy has been admitted.

T-0031/S01 adds an experimental native text transfer, accepted through PR #110.
It is not an Embulk compatibility entry: strict UTF-8, LF normalization, a 1 MiB
physical-line limit, exclusive output and possible partial files are native
experimental policies. See [usage and limitations](FILE_TRANSFER.md).

T-0031/S02's stdout/null targets use the existing native experimental Text rules.
They do not establish compatibility with any Embulk output plugin.

## Adding an Entry

T-0012/S13 is Done through PR #107 (`441040f`) for six syntax observations. No YAML, duplicate-key, alias,
encoding, or native configuration behavior is accepted. Primary and independent
Stage A agree on 60 events and six outcomes; primary and independent final-head
Demo passed at `65a2fb3`, including strict controls and unchanged S12 regression.

Each entry must identify the Embulk version, exact plugin artifact, configuration fixture, expected evidence, source/provenance record, and known deviations. Claims enter this document only after review evidence exists.

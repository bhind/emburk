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
output-commit scenarios; it has no runtime acceptance evidence yet.

## Adding an Entry

Each entry must identify the Embulk version, exact plugin artifact, configuration fixture, expected evidence, source/provenance record, and known deviations. Claims enter this document only after review evidence exists.

# T-0012/S05 schema-boundary observation

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- Branch: `research/t-0012-schema-boundary`
- State: Done as a slice; integrated through PR #68 as
  `68559dc8b81d45c2b236db3d1e5266f70ab589a9`; parent remains open
- Owner: Compatibility Host Implementer; records/integration: Project Manager
- Slice estimate: 3 SP within Current SP 8; Initial SP remains 5. Do not sum
  parent and slice delivery or award parent completion.
  Refinement score: implementation 1 (one bounded probe packet), uncertainty 1
  (schema observations), verification 1 (instrumented reference checks),
  environment 1 (established pinned Java route); raw 4 maps to 3 SP.
- Dependencies: T-0011 and S01's pinned executable route; S04 integrated first
  through PR #67 as `79cbcb94b25cecf41bb5587f540a509445d08351`.

## Decision and mutation packet

Observe schema before extending lexical scalar conversion: ordered logical
fields are an unresolved prerequisite to the runtime's schema/batch boundary.
Do not infer a Rust schema policy from API signatures. Independently construct
exactly three fixtures: empty schema; six distinctly named columns using
Boolean, Long, Double, String, Timestamp and JSON in that order; two columns
with the same name and different types. Record construction success or raw
exception, whether Control.run is entered, and separate transaction/run schema
fingerprints (count, ordered index/name/type-name). Successful fingerprints
must match across those phases. Duplicate-name behavior is an observation,
not a preselected success or rejection. No lookup behavior is claimed.

Implementer allowlist:

- `tools/t0012-config-presence/src/T0012InputPlugin.java`
- `tools/t0012-config-presence/run.sh`
- `tests/t0012_schema_boundary_probe_test.sh`

Add a schema mode without changing presence/conversion observations. Keep
actual output, exception class/message (null distinct from empty), process exits,
runtime identity, hashes and phase records externally. Fail closed on malformed,
missing, duplicate or truncated evidence; prove those validator controls with
mutated copies. Do not catch linkage/setup Errors as semantic observations.
Keep evidence writes outside the operation's exception-catching boundary.

Demo Command: `tests/t0012_schema_boundary_probe_test.sh`. It must run all
three live cases plus existing corrupt-hash and unavailable-runtime controls.
Also rerun S01/S02 demos and S04's live differential regression because their
runner is shared. No missing runtime skip or zero-observation pass is allowed.
Independent Tester reproduction and exact-revision evidence precede integration.
PM owns STATUS/TODO/ROADMAP/COMPATIBILITY, provenance/index and dated log;
ARCHITECTURE is also assigned to PM for correcting target-versus-implemented
wording and aligning recovery non-claims with the accepted design records.
RUST_RUNTIME_DESIGN may change only to reflect accepted observations.

## Provenance gate (2026-09-06)

Librarian performed read-only public-interface triage. The primary agent then
verified `javap -public` against the already admitted official
[Embulk 0.11.5 executable](https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar),
SHA-256 `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`,
corresponding to core commit `c5ac2d471edac465b45088669d376a7e2a525f8f`.
Artifact locators: `org/embulk/spi/Schema.class`, `Schema$Builder.class`,
`Column.class`, `InputPlugin$Control.class`, `type/Type.class`, and
`type/Types.class`. Public builder/accessor signatures and six type constants
are the only new implementation inputs. SPI pin remains 0.11 at
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`; this new inspection is artifact-level,
not a claim that its source checkout was inspected.

License classification and exact source LICENSE/NOTICE locators remain in
[T-0011](T-0011-embulk-reference-inventory.md): Apache-2.0 for core/SPI source;
executable `META-INF/LICENSE` and `META-INF/NOTICE` retained by the runner.
No upstream implementation, test, fixture or text is copied or translated.
The original test source is published; executable and generated JARs are not
redistributed. No new dependency or plugin is admitted. Transitive SBOM,
redistribution, patent/standards/trademark and freedom-to-operate reviews remain
unreviewed, not cleared by copyright permission or this interface inspection.

## Evidence and stop boundary

Expected evidence: Reference Observation / Integration only. No Rust schema,
public API, Arrow, Page/value encoding, nullability, plugin support, lifecycle
contract or compatibility claim. An unexpected duplicate result is retained
and reviewed before any policy implementation. Repair normal compilation,
retrieval and harness failures within scope; stop expansion for new dependencies,
production APIs, source translation, redistribution or material IP/security
uncertainty requiring owner/legal review.

## Primary acceptance and observations

The primary agent ran the exact Demo by absolute path from `/private/tmp` at
source revision `cc24730`: exit 0, three live successes, matching transaction/run
fingerprints and all eleven mutated-copy format controls exercised. The
unavailable-runtime 404/exit 56 and corrupted-copy exit 3 are expected negative
controls, not successful semantic cases. A prior synthetic-exception test had
retained a success marker incorrectly; primary reproduction failed with exit 4,
and the selector was corrected before this accepted run.

External evidence: `${TMPDIR}/t0012-config-presence-executable/run.qx7wtE/evidence`.
Actual observations (not inferred from fixture IDs):

| Fixture | Construction / process | Columns observed in transaction and run |
|---|---|---|
| empty | Success / 0 | Zero columns |
| ordered6types | Success / 0 | Indices 0–5, names `boolean_column`, `long_column`, `double_column`, `string_column`, `timestamp_column`, `json_column`; type names `boolean`, `long`, `double`, `string`, `timestamp`, `json` respectively |
| duplicate-name-differing-types | Success / 0 | Indices 0–1, both named `duplicate`, with type names `boolean`, `string` respectively |

Each successful case emitted one marker immediately before Control.run and
one independently read run-phase schema. This is not a callback-order, retry,
lookup, nullability, or value-encoding contract. Duplicate names must not be
silently lost by a future schema representation, but a Rust representation is
not implemented by this slice.

Evidence hashes (SHA-256):

- `schema-cases.raw`: `937615ea17c89c66e2a50864d548056a58b10f212197e877e6f400c52581dfa0`
- `schema-results.raw`: `89a418263b2cd2dca5eaf6d6b0e701af33d69f87cf8d9fc73cc9e66aa6718502`

Synthetic validator cases demonstrate null-versus-empty exception-message
transport only; they are not additional Embulk observations.

Independent Tester acceptance at full revision
`cc247301044627640656f7597445e47dc4a6aba6` reproduced the exact Demo, all eleven
format mutations, S01 (9 cases), S02 (9 cases), and S04 (13 live comparisons):
each full command exited 0. Primary shared-runner regression execution also
exited 0. Format, strict workspace/all-target Clippy, shell syntax, workspace
tests (9 passed, 1 intentionally ignored live test) and diff checks passed.

Tester logs: `/private/tmp/emburk-t0012-s05-acceptance-20260906T005027/`.
`schema-demo.log` SHA-256:
`758e07774a41ad1923babcc70e1f0caaaec331ac905b8db3bdd4321f6c17be89`.
Tester schema evidence `run.AgBYWy/evidence` has the same two raw-record hashes
as primary acceptance above. Platform: macOS 26.5.1 arm64, Bash 3.2.57,
Rust/Cargo 1.98.1, Python 3.14.6, Temurin JDK 17.0.20. No new source or runtime
artifact is redistributed. Evidence remains Reference Observation / Integration
only. Final-head primary Demo at `cc40f0fae1730075271b37d348eeab34769e5158`
exited 0 with evidence `run.r71A1u/evidence`. PR #68 integrated the slice;
parent T-0012 is not complete.

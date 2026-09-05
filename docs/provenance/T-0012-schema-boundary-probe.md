# T-0012/S05 schema-boundary observation

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- Branch: `research/t-0012-schema-boundary`
- State: In Progress; acceptance pending
- Owner: Compatibility Host Implementer; records/integration: Project Manager
- Slice estimate: 3 SP within Current SP 8; Initial SP remains 5. Do not sum
  parent and slice delivery or award parent completion.
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

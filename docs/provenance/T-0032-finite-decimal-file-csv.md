# T-0032/S05 bounded finite-decimal File/CSV observations

Status: Stage A reviewed; ADR-0028 authorizes the private Stage B candidate.

## Authority and boundary

Issue #153 and direct owner approval authorize this independently acceptable
5 SP slice. The only reference artifact is the already admitted local Embulk
0.11.5 JAR, SHA-256
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`,
executed with Java 17. The runner treats it solely as a local black box. No
upstream implementation source, dependency, NOTICE material, or new artifact
was admitted or copied. This record supplies engineering provenance, not legal
advice, license clearance, patent analysis, or freedom-to-operate clearance.
The exact release locator, core pin, 2026-09-06 access record, Apache-2.0
classification, executable NOTICE boundary, and unresolved redistribution/SBOM
questions remain in [T-0011](T-0011-embulk-reference-inventory.md) and
[T-0014](T-0014-file-csv-oracle.md); this slice admits no additional source.

## Stage A evidence

Frozen source `cb47c8c` contains an original driver and deterministic fixture
generator. The generator is itself hashed in every manifest before capture; it
includes a separate 64-value holdout from seed 3205. The oracle validates
regular-file confinement, checksums, UTF-8/LF evidence, bounded sizes, complete
tree inventories, process exits, timeouts, and tampering before any semantic
projection.

| Run | Root manifest SHA-256 |
| --- | --- |
| Primary | `/private/tmp/emburk-t0032-s05-finite-decimal-capture-5fvbkvww`, `3d7719230803e7c561010d9ce316c6205b44c6fb915e56055b0a32308ea7307d` |
| Independent | `/private/tmp/emburk-t0032-s05-finite-decimal-capture-3s6e7ame`, `47d710f5b8e7b4cae3f9b3feb3c1b0801fd37eb5d8a57dad9f273fa4d2f46bf6` |

Both roots validate with driver SHA-256
`352de872e57893cf7593ea1b9b486d0794fb05bb796464af0586e12a466926d0`.
All four cases exit zero, have no timeout, capture empty stderr, and have equal
per-case output hashes across the two runs.

The family corpus observes the canonical outputs `0 -> 0.0`, `-0` and
`-0.00 -> -0.0`, `1.00 -> 1.0`, `3.50 -> 3.5`, `42 -> 42.0`, and quoted
`3.5 -> 3.5`; the 64-value holdout repeats the same whole-value `.0` and
finite-decimal normalization pattern. A labeled two-column sentinel confirms
that a bare empty field remains empty while a quoted empty and `not-a-double`
row are omitted; the later `2.5` row remains. The boundary corpus confirms that
the reference also accepts `+3.5`, `03.5`, `.5`, `1.`, `1e2`, `NaN`,
`Infinity`, `3.141`, and values beyond the proposed magnitude bound.

Those latter outcomes are recorded gaps, not selected native parity. ADR-0028
selects a smaller finite grammar and preserves only the prior exact omission
sentinels.

## Qwen consultations

A prompt-only architecture review completed in 151.8 seconds and was rejected
as an authority source: it proposed exponent breadth beyond scope and made
unsupported signed-zero normalization and BigDecimal assertions. A 7.4-second
Stage A test suggestion usefully prompted signed-zero and broader finite-family
coverage; the frozen corpus at `cb47c8c` independently includes `0`, `-0`,
`-0.00`, `0.1`, `-0.1`, and bounded larger magnitudes. The empty-field
ambiguity was caught independently during review and corrected with the labeled
two-column sentinel. A 10.7-second
Stage B proposal was rejected before use because it referenced nonexistent
iteration APIs, had inclusive range errors, consumed the decimal point twice,
and could accept truncated syntax. A later 5.7-second prompt-only review
suggested `123.45a`, `123..45`, `+123.45`, and `-00123.45`; independent Rust
testing used the first, second, and fourth controls, while the plus-sign case
was already covered. No repository file, raw artifact, manifest, credential,
legal material, or security material was supplied to Qwen; no model code,
semantic mapping, or evidence was adopted.

## Stage B packet

The Rust Core Implementer may change only
`crates/emburk-core/src/configured_csv.rs`,
`crates/emburk-cli/tests/configured_csv.rs`, and
`tests/t0032_finite_decimal_differential_test.py`. The oracle and its tests are
frozen Stage A evidence. Stage B must use grammar and finite-value checks rather
than finite literal tables, preserve the existing three omission sentinels, and
compare only the selected in-domain family and holdout outcomes. Reference-only
boundary cases must assert native refusal rather than exact reference equality.

## Primary candidate evidence

At runtime/differential head `f46e00e`, the exact Issue #153 Demo exited zero:
formatting, locked strict Clippy, build, 152 workspace passes with eight
intentional ignores, configured CSV 8/8, Boolean 3/3, Float64 physical 3/3,
Float64 lexical 3/3, multi-file 3/3, and the S05 three selected equalities,
one admitted `03.5` normalization, and nine native refusals. The retained
S05 differential root is
`/private/tmp/emburk-t0032-s05-differential-skt78m5k`, manifest SHA-256
`f1be74bbdda927ec54a56561b381739152452ca4cabb3ed89e1a2ce71d550007`.

The final candidate adds only Rust test controls at `29647d7`: focused
configured CSV acceptance is 17/17 and covers trailing junk, repeated decimal
points, and negative leading-zero normalization. Runtime and differential-driver
source are byte-identical between `f46e00e` and `29647d7`. An independent clean
clone at `29647d7fac8b9df07cb3508afaf4504910ef6ef4` reproduced formatting,
locked strict Clippy, CLI build, 152 workspace passes with eight intentional
ignores, focused 17/17 CLI controls, and all 23 selected comparisons. Its S05
self-test manifest is `b00cc5493279688bb5f23eea643e785c505e42d259102f26d4fe7d20e4ed1dd9`,
its plain manifest is `f3255bbd6adfe524cfb203beda860e0937b86d334e1740e0bfd4c061fef65a23`,
and its fresh linked Stage A manifest is
`29b3d8a7bc80d2fd8c6d0ee63657313a7444e6db318a1db4551beb4067200963`.
Security and final provenance review remain required before integration.

## Final review

The independent tester reproduced the final head before this review. A
concurrency-slot limit prevented separate Security and Librarian agent threads,
so the Project Manager performed those two read-only reviews serially, without
tracked-file edits during either review. This is a review-role fallback, not an
independent security or legal clearance.

The Security review inspected `79e8add^..29647d7`, the parser, CLI controls,
and strict differential driver. `git diff --check` and a Cargo manifest/lock
diff both exited zero; `cargo metadata --locked --no-deps` exited zero. The
existing CSV record cap bounds the new scanner input. The implementation uses a
whole-token ASCII grammar before `f64` parsing, has no new dependency, network,
credential, shell interpolation, or unbounded output path, and the driver uses
fixed argument vectors, constrained `PATH`, regular-file confinement, bounded
trees, and mutation/link controls. No release blocker was found. Existing
configured path policy, hostile-artifact forgery resistance, sandboxing, and
security assurance remain outside this review.

The Librarian review confirmed the slice relies only on the already-admitted
pinned JAR as a black-box behavior oracle, repository-original fixtures, and
the prior T-0011/T-0014 provenance records. It found no upstream implementation
source, fixture, test, text, dependency, NOTICE material, or third-party code
copied into the candidate, and no dependency change. It found no provenance
blocker for this narrow behavioral observation. It does not clear license,
redistribution, patent, or freedom-to-operate questions.

## Stop rule and non-claims

Stop for a manifest mismatch, required literal exception, output-safety issue,
new grammar class, dependency or public-surface change, provenance concern, or
regression. This supplies neither general Float64/CSV compatibility nor claims
about exponent/non-finite/locale/rounding, JSON, multi-file operation,
transactions, resume, plugins, performance, security, patent/FTO, release, or
parent completion.

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
Stage A test suggestion found no material missing corpus control. A 10.7-second
Stage B proposal was rejected before use because it referenced nonexistent
iteration APIs, had inclusive range errors, consumed the decimal point twice,
and could accept truncated syntax. No repository file, raw artifact, manifest,
credential, legal material, or security material was supplied to Qwen; no model
code, semantic mapping, or evidence was adopted.

## Stage B packet

The Rust Core Implementer may change only
`crates/emburk-core/src/configured_csv.rs`,
`crates/emburk-cli/tests/configured_csv.rs`, and
`tests/t0032_finite_decimal_differential_test.py`. The oracle and its tests are
frozen Stage A evidence. Stage B must use grammar and finite-value checks rather
than finite literal tables, preserve the existing three omission sentinels, and
compare only the selected in-domain family and holdout outcomes. Reference-only
boundary cases must assert native refusal rather than exact reference equality.

## Stop rule and non-claims

Stop for a manifest mismatch, required literal exception, output-safety issue,
new grammar class, dependency or public-surface change, provenance concern, or
regression. This supplies neither general Float64/CSV compatibility nor claims
about exponent/non-finite/locale/rounding, JSON, multi-file operation,
transactions, resume, plugins, performance, security, patent/FTO, release, or
parent completion.

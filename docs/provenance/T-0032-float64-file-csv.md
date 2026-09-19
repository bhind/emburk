# T-0032/S03 bounded Float64 File/CSV values

Status: Done through PR #148 (`c410c953`). The integrated native Float64
File/CSV implementation remains limited to this record's selected boundary.

## Authority

Issue #147 and the owner authorize this independently acceptable 5 SP slice.
Jitro reviewed the complete first capture before accepting ADR-0026. The Rust
Core Implementer completed Stage B within the Issue allowlist; primary and
independent final-head evidence preceded PR #148 integration.

## Artifact and provenance boundary

The only reference executable is the local, already admitted Embulk 0.11.5 JAR
from T-0014/S01, SHA-256
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`.
The existing T-0014 record contains its source locator, module inventory,
license/NOTICE treatment, and runtime-only classification. This slice consulted
no upstream implementation source and copied or adapted no upstream code,
tests, or fixtures. The new driver and fixtures are original.

The JAR is copied only to a private owner-only evidence tree for local execution
and is not redistributed. Transitive SBOM/advisory review, redistribution,
trademark, standards, patent-family analysis, and freedom-to-operate remain
unreviewed. Librarian triage is read-only engineering provenance review, not
legal advice or clearance.

## Stage A evidence

`tools/t0032-float64-file-csv-oracle/run.py` binds the pinned JAR, Java 17,
driver hash, raw config/input/output bytes, process results, case order, and
complete regular-file evidence tree. It rejects symlinks, non-UTF-8 or
non-LF text, oversized input/config/log/output trees, tampering, and output
record overrun before semantic projection.

Both retained raw roots validate against the frozen driver:

| Run | Root manifest SHA-256 |
| --- | --- |
| Primary | `/private/tmp/emburk-t0032-s03-float64-capture-mv_khrta`, `daab25cd8705ddfb0f73c923585373272078a3b1cf78989b0dd8df1c11111acd` |
| Independent | `/private/tmp/emburk-t0032-s03-float64-capture-eecc_v2v`, `9fcb044c9646b8c46c4b1bc7c462f8afc10cbe4c6413e9478b0ae5f93d89b32c` |

Each case exited zero without timeout or captured stderr. The exact repeated
outputs are: `1.5`, `-0.0`, `0.0` are retained; a labeled unquoted empty field
becomes a bare CSV field while its quoted-empty row is omitted; and a
`not-a-double` middle row is omitted while `1.5` and `2.5` remain. These are
observations, not a general Float64 grammar or error-policy claim.

## Stage B packet

- Branch: `feat/t-0032-float64-file-csv`.
- Owner: Rust Core Implementer.
- Runtime/test allowlist: `crates/emburk-core/src/configured_csv.rs`,
  `crates/emburk-cli/tests/configured_csv.rs`,
  `tests/t0032_float64_file_csv_differential_test.py`,
  `tools/t0032-float64-file-csv-oracle/run.py`, and
  `tests/test_t0032_float64_file_csv_oracle.py` only. The latter two are frozen
  Stage A evidence unless a defect stops the slice for renewed PM review.
- Dependencies: T-0032/S01, T-0032/S02, T-0012/S09, T-0012/S10, ADR-0014,
  T-0014/S01, and T-0031/S03.
- Artifacts: existing pinned JAR and Java 17 only; no new dependency or source
  admission.

One synchronous, non-applying Qwen `fix` request is authorized for at most 90
seconds with default project context disabled. Its only supplied repository
context may be `crates/emburk-core/src/configured_csv.rs` and
`crates/emburk-cli/tests/configured_csv.rs`. It may suggest a patch but cannot
select compatibility behavior, be applied automatically, or become evidence.
Timeout, unavailable service, or an unhelpful answer is non-blocking.

## Acceptance and stop rule

The Stage B differential must validate an actual Stage A raw manifest before
using it, run actual native configurations, compare names/bytes/exits for the
three observed cases, and retain mutation controls. The final Demo is the exact
Issue #147 command: format; locked strict Clippy; locked workspace tests;
build the CLI; existing configured-CSV, Boolean, Float64, and multi-file
differentials; then `git diff --check`. Primary and independent final-head
runs, Security review, final provenance review, PR integration, and record
reconciliation remain required.

Stop on evidence invalidity, mismatch, any unobserved syntax requirement, new
dependency/public surface, unsafe output effect, IP/licensing uncertainty,
Qwen context breach, or regression. Do not guess behavior to obtain a passing
comparison.

## Integrated evidence

At exact pre-merge head `3cb9c32`, the primary Demo exited zero after format,
locked strict workspace Clippy, locked workspace tests (157 listed, eight
intentional external-oracle ignores), CLI build, and `git diff --check`. It
retained the following primary evidence manifests: configured CSV 8/8 at
`/private/tmp/emburk-t0032-differential-vf0c24dp`, SHA-256
`85fb39438505dde57c3ffa1a8e162e330553f6e6dd5d8fe46a7482fc53d30eae`;
Boolean 3/3 at `/private/tmp/emburk-t0032-s02-differential-it6mscwf`,
`c3b0fd4bfbb5bcabdb2bd985d780e2648f5535e323f5f55301fd02433bedc6b1`;
Float64 3/3 at `/private/tmp/emburk-t0032-s03-float64-differential-1fe8dzh3`,
`38be834ec60e339e66a411d88b59ea83e5a11d0f607d8b519ef51cd92123de99`;
and multi-file 3/3 at `/private/tmp/emburk-t0031-s03-differential-8pjhm9ru`,
`532d3964580ba8480b2138a3f4cdf52eeaa8855e6981241051b53f1b1c2a188c`.

An independent exact-head run reported the same command outcomes and retained
configured CSV SHA-256
`f6924e995991ae7da1649d7cad1b49156431230430ded89f5b38ae9358f2a70d`,
Boolean `a296f42f345a837e289f390899686177366d86b694207c33345743bcef4b87cc`,
Float64 `00947a051d196f1e2caf40dfda17b9d2b4a0f70b4fd9387a31fa114521f3eeb1`,
and multi-file `2160d0dec95032931b144c1ca60ed30d47292b6b9edec9f3e50d433de5908e5f`.
Jitro revalidated the two Float64 manifests with the frozen driver. Security's
re-review reported no blocker after the silent-drop and pre-read-size fixes;
per-captured-file post-read size caps remain a residual non-claim. PR #148
integrated the candidate as `c410c953`; Issue #147 is closed and its Project
item is Done.

The single authorized Qwen request supplied only the two allowed Rust files,
with default project context disabled. It timed out after 90 seconds with
`Errno 60`, returned no response, and was rejected; it had zero implementation
or evidence influence.

## Non-claims

No general Float64/CSV, non-finite/exponent/locale/rounding, Timestamp/JSON,
multi-file Float64, compression/filter, transaction/resume, plugin/host/API,
performance, security, patent/FTO, release, or parent-completion claim follows.

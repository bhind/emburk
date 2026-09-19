# T-0032/S03 bounded Float64 File/CSV values

Status: Stage A reviewed; Stage B authorized under ADR-0026. No native Float64
File/CSV implementation is integrated by this record.

## Authority

Issue #147 and the owner authorize this independently acceptable 5 SP slice.
Jitro reviewed the complete first capture before accepting ADR-0026. The Rust
Core Implementer may begin Stage B only within the Issue allowlist; final
acceptance still requires independent final-head evidence and merge.

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

## Non-claims

No general Float64/CSV, non-finite/exponent/locale/rounding, Timestamp/JSON,
multi-file Float64, compression/filter, transaction/resume, plugin/host/API,
performance, security, patent/FTO, release, or parent-completion claim follows.

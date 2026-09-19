# T-0032/S04 bounded Float64 lexical File/CSV observations

Status: Stage A reviewed. Stage B is authorized by ADR-0027 but no runtime
implementation is integrated.

## Authority

Issue #150 and direct owner approval authorize this independently acceptable
5 SP slice. Jitro reviewed the Stage A driver, focused tests, raw manifests,
and exact output bytes before accepting ADR-0027 for the bounded Stage B
candidate. Stage B remains subject to its stated primary and independent
acceptance, Security and provenance review, pull-request integration, and
canonical-record reconciliation.

## Artifact and provenance boundary

Stage A uses only the already admitted local pinned Embulk 0.11.5 JAR and Java
17 boundary recorded in [T-0014/S01](T-0014-file-csv-oracle.md) and
[T-0032/S03](T-0032-float64-file-csv.md). The capture driver treats that
artifact as a local black box. No external source, implementation, dependency,
NOTICE material, or license input was admitted; no upstream code was copied.
The Librarian's read-only triage permits exactly these local observations and
does not provide legal advice or patent/FTO clearance.

## Stage A evidence

Oracle source `2dc3b46` and its four focused tests bind the pinned artifact,
Java version, driver hash, raw fixture and output bytes, process result, case
order, and a complete regular-file evidence tree. The driver rejects symlinks,
non-UTF-8 or non-LF text, oversized inputs, tampering, malformed manifests,
and captures stderr and timeout status.

| Run | Root manifest SHA-256 |
| --- | --- |
| Primary | `/private/tmp/emburk-t0032-s04-float64-lexical-capture-verazyg9`, `531cf5378728cb7b4de920ce389ea4871bdf85e57832a03b36369295bfec9ddc` |
| Independent | `/private/tmp/emburk-t0032-s04-float64-lexical-capture-96x1rtsf`, `77356e5fb1bac91f1f2f9f8c7be1f190808f343f45b1ceb7d47c2eac1cd036e5` |

Both captures exited zero, did not time out, and captured empty stderr. The
exact repeated outputs are:

- plain: `ratio\n3.5\n-12.25\n`;
- quoted and unquoted: `ratio\n3.5\n3.5\n`;
- malformed middle: `ratio\n3.5\n42.0\n`.

These are selected local observations only, not a general lexical grammar,
parser, or error-policy claim.

## Stage B packet

- Branch: `feat/t-0032-float64-lexical-csv`.
- Owner: Rust Core Implementer.
- Runtime/test allowlist: `crates/emburk-core/src/configured_csv.rs`,
  `crates/emburk-cli/tests/configured_csv.rs`, and
  `tests/t0032_float64_lexical_differential_test.py` only.
- Dependencies: T-0032/S01, T-0032/S02, T-0032/S03, T-0012/S09, T-0012/S10,
  ADR-0014, ADR-0026, T-0014/S01, and T-0031/S03.
- Artifacts: the existing pinned JAR and Java 17 only; no new dependency,
  artifact, source, or licensing admission.

Stage B must preserve every ADR-0026 outcome, admit only ADR-0027's observed
lexical outcomes, and reject every other Float64 lexical value before final
publication. It must add a raw-evidence validation gate before expectation
projection and mutation controls for the three observed cases.

```sh
cargo fmt --all -- --check &&
cargo clippy --locked --workspace --all-targets -- -D warnings &&
cargo test --locked --workspace &&
cargo build --locked -p emburk-cli --bin emburk &&
bash tests/t0032_configured_csv_differential_test.sh &&
EMBURK_BINARY=target/debug/emburk python3 -I -B tests/t0032_boolean_file_csv_differential_test.py &&
EMBURK_BINARY=target/debug/emburk python3 -I -B tests/t0032_float64_file_csv_differential_test.py &&
EMBURK_BINARY=target/debug/emburk python3 -I -B tests/t0032_float64_lexical_differential_test.py &&
EMBURK_BINARY=target/debug/emburk python3 -I -B tests/t0031_multifile_configured_csv_differential_test.py &&
git diff --check
```

## Qwen consultations

Six non-applying consultations have completed. The two Stage A reviews took
46.1 and 24.7 seconds: the first produced mostly false missing-control findings
while one malformed-JSON test idea was retained independently; the second
confirmed most controls but incorrectly claimed timeout handling was absent
despite `wait(timeout)` and `killpg`. Stage B's 90-second patch proposal timed
out without output; its 60.1-second test review was rejected because it was
contradictory and missed existing tests; its 90-second changed-file review timed
out without output. No model code, semantic mapping, or evidence was adopted.

After owner correction, a sixth final changed-file review ran for 175.4 seconds
on the frozen `327cb0e..7951f23` diff with the exact three Stage B allowlisted
files and default project context disabled. It was rejected: it misread the
oracle summary interface, asserted a false file-close concern, treated a
deliberate private-evidence mutation self-test as a defect, and confused
Float64 literals with test markers. No model code, test, semantic mapping, or
evidence was adopted. The response arriving after 90 seconds shows that the
former task-specific bound was insufficient for this request; no load-duration
measurement attributes that delay to a cold load or network condition.

Future authorized consultations use a 600-second timeout and a 30-minute
keepalive. A two-to-three-minute cold model load is expected, but a timeout
remains a request outcome rather than proof of a network failure. Context must
remain only the exact task allowlist and must exclude artifacts, manifests,
`.git`, credentials, upstream/legal material, and security-review contents.
Answers are never applied automatically, do not gate delivery, and require
independent PM review; timeout or unhelpful output is not a delivery failure.

## Stop rule

Stop and return to Jitro before widening literals, row-recovery semantics,
configuration, public API, dependencies, artifacts, or provenance scope; on a
contradictory capture; on a security or license/provenance concern; or if raw
evidence validation cannot run before native expectation projection.

## Non-claims

No general Float64/CSV compatibility; no integer, exponent, non-finite,
locale, rounding, or generic malformed-row policy; no Timestamp/JSON,
multi-file Float64, compression/filter, transaction/resume, plugin/host/API,
performance, security, patent/FTO, release, or parent-completion claim follows.

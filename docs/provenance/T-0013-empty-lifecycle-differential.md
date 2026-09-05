# T-0013/S04 selected empty-lifecycle differential

- Tracking issue: [T-0013, #16](https://github.com/bhind/emburk/issues/16)
- State: Done (two selected Differential projections); PR #74 integrated
- Parent: Issue #16 remains open for S05 and remaining contracts
- Priority: P0; parent T-0010
- Slice estimate: 3 SP within parent Current SP 13, Initial SP 8; no new parent
  points or parent completion. Refinement: implementation 1, uncertainty 1,
  verification 1, environment 0; raw 3 maps to 3 SP.

## Authority

PM owns comparison policy, records, acceptance and integration. One implementer
owns the complete test-tool slice serially; Tester is read-only. Standing owner
authority permits implementation and PR integration after acceptance.

## Dependencies

T-0013/S03 original reference fixtures and validator, integrated by PR #72
(`8e43948`); T-0021/S03 private coordinator, independently accepted and integrated
by PR #73 (`14d5fb5`). Requeue T-0021 for remaining contracts, not Done or
Blocked. Combined WIP stays one. No parent dependency is declared complete.

## Branch and allowlist

Branch: `test/t-0013-empty-lifecycle-differential`.
One implementer owns exactly:

- `tools/t0013-empty-lifecycle-differential` (new Python driver)
- `tests/t0013_empty_lifecycle_differential_test.sh` (new acceptance wrapper)
- `crates/emburk-core/src/empty_lifecycle/differential_tests.rs` (new test bridge)
- `crates/emburk-core/src/empty_lifecycle.rs` (test-only child-module registration)

No production coordinator, other fake behavior, existing Java probes or their
validators, dependencies, manifests, CLI or public exports may change. PM owns
STATUS, TODO, ROADMAP, COMPATIBILITY, ARCHITECTURE, runtime design, provenance
and dated log. A required expansion returns to PM before mutation.

## Artifacts

Run the existing S03 complete probe test, including its invalid-evidence controls,
against the pinned executable on every live acceptance. Retain its complete
stdout/stderr and exactly identified evidence directory. Validate the resulting
raw cases/traces against their raw logs, counts and hashes; preserve all raw
inputs and a driver manifest. Do not substitute a saved golden outcome for a
live run. No new executable, upstream code or Java fixture is introduced.

Compare two selected cases: normal one-input empty execution and the original
injected input-run failure before finish. Zero-input behavior remains local
Unit/Contract evidence in this slice, not new Differential coverage. Derive the
actual output-task count from the reference transaction marker and pass it as an
explicit plan to Rust, with a test-harness cap of 1024. Reject larger counts
before allocation. This does not compare or implement default output planning.
The fake failure flag is test-owned input, never chosen from expected outcomes.

Use a versioned strict manifest to pass plan, scenario input, actual projected
reference events, result category and separate cleanup report counts into an
ignored Rust test. The test invokes the existing real coordinator and original
fake objects, then projects their actual events and compares the complete
selected projection. No fixture-ID dispatch in production, expected-trace
generator as execution, subprocess per event or public API is permitted.

### Projection policy

Every raw marker must be recognized and validated; exclusion is explicit, never
an unknown-event fallback. Validate Base64/UTF-8, exact arities, numeric fields,
canonical UUIDv4 capture identity and contiguous per-capture sequences. Retain
raw UUIDs but exclude them from cross-runtime equality: they are instrumentation
identities, not task, process, recovery or Rust object IDs.

| Reference marker | Rust event / comparison |
|---|---|
| Input/output transaction-entry | Input/OutputJobOpened |
| Input/output control-run-before | Input/OutputControlOpened |
| Output open/finish/commit/abort/close normal-return | Corresponding OutputTask event with actual index |
| Input run-entry | InputRan |
| Input finish-normal-return | InputFinished |
| Input run-runtime-exception | InputFailed, exact selected fixture error validated before mapping |
| Input/output control-run-normal-return | Corresponding ControlClosed(Normal) |
| Input/output transaction-normal-return | Corresponding JobClosed(Normal) |
| Input/output transaction-runtime-exception | Corresponding JobClosed(Failed) |
| Input/output cleanup-normal-return | Corresponding Cleaned, plus separate cleanup-entry report counts |

Validate but exclude paired output operation entry markers, input finish-before,
input run-normal-return, injection-before and cleanup-entry from event equality.
Those marker boundaries have no separate Rust event; never infer that an
unobserved callback happened. Rust ControlClosed(Failed) is excluded because the
Java fixture has one transaction exception marker, not a separately instrumented
control failure return. Validate its actual failed outcome locally; do not expand
one Java marker into two observed callbacks. Preserve event order across both
components for all selected events, not just membership or per-component order.

Reference error must be exactly
`T0013FailureInputPlugin$InjectedRunFailure` / `t0013-s03-injected-run-failure`
at input run and both transaction boundaries. Rust must return the original
`InputFailure("selected input failure")`. Only those original fixture-owned
errors map to the selected-input-failure category. Unknown errors fail closed;
this is not an exact Java diagnostic or general error equivalence claim.

Compare success/failure category and observed separate input/output cleanup
report counts against actual Rust cleanup contexts. Do not compare Java report
contents to Rust opaque tokens or require cleanup counts to equal a previous
control result. Existing Unit tests preserve actual Rust token values. Schema
column count must remain zero; reject add, resume, guess and unknown events.

## Acceptance criteria

- Both live cases compare the complete defined event projection, result category
  and separate report counts; exact nonzero ignored-test selection is verified.
- Existing full S03 acceptance and its malformed-evidence controls pass.
- Negative controls reject missing/duplicate/unknown rows, malformed fields,
  wrong hashes/raw logs, capture sequence reuse, unsupported plans/cap overflow,
  mutated event order/index, changed result and changed cleanup counts.
- Rust bridge independently rejects malformed/truncated/duplicate manifests and
  fails when expected actual outcomes are deliberately changed.
- No fixed fan-out factor, fixture-ID execution table, silent normalization,
  skipped unknown marker or unrelated source change.

## Demo Command

`bash tests/t0013_empty_lifecycle_differential_test.sh`

Also run `cargo test --workspace`, `cargo fmt --check`,
`cargo clippy --workspace --all-targets -- -D warnings`, per-file shell syntax
checks and `git diff --check`. Require a nonzero selected live test count and
two compared cases. Tester independently reproduces frozen source; PM reruns
the exact Demo at final PR head before integration. Network/JVM failures retain
raw evidence and trigger safe diagnosis/retry, not fabricated acceptance.

## Evidence class

Unit/Contract plus Differential (Embulk) for the two selected projections only,
if acceptance passes. Initial state is Planning, not an existing passing result.

Independent read-only packet review at `5a7076e` found no material executable
ambiguity or overclaim. It confirmed the two-case boundary, supplied counts,
single transaction-error projection, local failed-control assertions and
separate cleanup counts. This is Planning review, not source acceptance.

## Source acceptance

Primary acceptance at `98b6cacb8fdea06faece6ea33ccd0ca49aef5383` on 2026-09-06
passed the exact Demo (exit 0). The existing complete S03 probe and its controls
passed. Both selected live cases used observed input/output counts 1/8, supplied
to Rust with cap 1024, not a hardcoded fan-out rule. Normal comparison retained
44 events and input/output cleanup counts 1/8; failure retained 34 events and
counts 0/0. The exact ignored Rust test ran once and passed; two cases were
compared. These counts describe this run, not portable executor defaults.

Thirteen S04 raw controls rejected corrupted evidence. Missing cleanup, commit,
abort and close controls repair transport sequences, raw-log correspondence and
hashes, then assert the specific missing-marker diagnostic. A reordered excluded
input boundary likewise fails its order diagnostic; a mere sequence gap would
not establish that check. Rust's offline manifest controls reject malformed,
truncated, duplicate, unsupported and outcome-mutated inputs. Failed control
events must actually occur once per component before their explicit exclusion.

Workspace tests passed 20 with three intentional external live ignores. Format,
strict workspace/all-target Clippy, per-file shell syntax and diff checks exited
0. Environment: macOS arm64, rustc/cargo 1.98.1, Python 3.14.6, Temurin Java 17.
No production coordinator, existing probe or dependency source changed.

Primary local-only evidence:

- Driver root: `${TMPDIR}/t0013-s04.912Lk1`
- Reference root: `${TMPDIR}/t0013-input-failure.42cuJ2/evidence`
- `cases.raw` SHA-256:
  `608bc041f24ace78030bb8f7cd09eaf8c145f3ecffdf891cc24491e9083b45b9`
- `traces.raw` SHA-256:
  `ec35f0e32ac1a5d1455a905161c5ed39ae4abe91c7c6b3c2d6fcd8991643f0b5`
- Normalized manifest SHA-256:
  `5c3355c7c4993a8abffc2db7a04cf2f277fd7937088e1d2c031862a17b442913`

Raw hashes are per-run capture evidence, not cross-run goldens. Independent
Tester reproduced the frozen source: exact Demo exit 0, two comparisons,
13 rejected raw controls, 20 offline passes/three intentional ignores and all
strict checks passing. The initial sandbox-only attempt exited 4 without probe
output; the approved pinned-network rerun passed. No acceptance finding remains.
Tester logs are local-only at `/private/tmp/emburk-t0013-s04-acceptance.1RpvxZ`;
`demo-escalated.log` SHA-256:
`25d9c827398908058a72db7a3c1315773e7520878434e9a2b1d8f32f794a881f`.
Independent reference evidence is `${TMPDIR}/t0013-input-failure.MdR7qO/evidence`;
`cases.raw` SHA-256:
`3f438b9c3d85af64f9334119938cd68f058f455af5013c0348bb60afef187106`;
`traces.raw` SHA-256:
`3963a21d36a56ab3c4eae523f9e284853c6f7be136b5ceed11cb317bcf5b5e2d`.
Final-head acceptance at `09ac159020d530136e20b82028935cbb4d61b589` reproduced
the exact Demo and all strict checks (exit 0), with evidence root
`${TMPDIR}/t0013-s04.1VYi4N`. PR #74 integrated as
`68d848c0214d33077a80cfe4dafb5dbba85c3b06`; Issue #16 remains open.
The live result applies only to the declared projection, not raw marker identity,
default planning, report contents, zero-task behavior or complete lifecycle.

## Reference and reuse record

Access/review date 2026-09-06. Reuses only repository-owned original fixtures,
validators and Rust fakes from T-0013/S03 and T-0021/S03. Pinned official Embulk
0.11.5 executable SHA-256:
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`.
Exact source/API/license locators remain in those records and T-0011: core
`c5ac2d471edac465b45088669d376a7e2a525f8f`, SPI 0.11
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`, Apache-2.0 classification.
No upstream implementation/test code is copied or translated, no new external
plugin/dependency is admitted, and no downloaded/generated JAR is redistributed.
Transitive SBOM/notices, redistribution, patent/standards/trademark, jurisdiction
and freedom to operate remain unreviewed, not cleared.

## Stop rule

Fix ordinary tool/test problems in scope. Return to PM for changed projection,
new production semantics, additional callbacks/failures, new artifacts or
material security/IP uncertainty. Never weaken a failing comparison into a pass,
change the user checkout, or infer unsupported behavior.

## Non-claims

No full trace instrumentation equivalence, default planner, zero-task live
coverage, actual values/Pages/data transfer, unchanged plugin loading, JVM host,
output-operation failures, retry/resume, rollback, delivery/durability, parallel
ordering, performance, production API or parent #16/#18 completion.

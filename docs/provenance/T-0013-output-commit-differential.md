# T-0013/S06 selected output-commit differential

- Tracking issue: [T-0013, #16](https://github.com/bhind/emburk/issues/16)
- State: Ready; implementation has not started
- Priority: P0; parent T-0010
- Slice estimate: 3 SP (implementation 1, uncertainty 1, verification 1,
  environment 0). Parent Current SP remains 21; Initial SP remains 8.

## Authority

PM owns scope, canonical records, acceptance and integration. One implementer
owns the entire four-file test slice serially; the independent Tester is
read-only. Standing owner authority permits implementation and integration
after acceptance. No parent completion follows from this bounded slice.

## Dependencies

T-0013/S05 reference observation, PR #75 (`2901c31`), and T-0021/S04 private
last-commit implementation, PR #76 (`b5cfb87`), are integrated. The latter's
final-head Demo passed at `d885ba2`. T-0013/S04 comparison remains unchanged.
T-0021 returns to Backlog for remaining contracts. Combined WIP stays one.

## Branch and allowlist

Branch: `test/t-0013-output-commit-differential`.
One implementer owns exactly:

- `tools/t0013-output-commit-differential` (new Python test driver)
- `tests/t0013_output_commit_differential_test.sh` (new wrapper/controls)
- `crates/emburk-core/src/empty_lifecycle/output_commit_differential_tests.rs`
  (new private test bridge)
- `crates/emburk-core/src/empty_lifecycle.rs` (test-child registration only)

PM owns STATUS, TODO, ROADMAP, COMPATIBILITY, ARCHITECTURE, runtime design,
provenance/index and dated log. No production algorithm, public API, dependency,
Java fixture, existing S03/S04/S05 driver/wrapper/bridge, CLI, schema or scalar
change is permitted. Do not refactor accepted probes to share validators here.

## Artifacts

Run the full unchanged S05 gate and require its unique final
`T0013_COMMIT_FULL_PROBE=passed|evidence=...` marker. Retain raw evidence,
stdout/stderr, executable identity and digests. Strictly validate raw cases,
trace grammar, sequence/capture identity, logs, phases, scope propagation,
callback pairs, selection and cleanup before any normalization. Fail closed on
missing, duplicate, unknown, malformed or contradictory evidence.

Produce a canonical versioned `T0013-S06\t1` manifest with exactly `normal`
and `commit-failure`. Pass the observed positive output task count N as an
explicit Rust 1/N plan, with test-harness cap 1024 checked before allocations.
Do not compare or assume default fan-out. The independently configured Rust
failure input selects N-1; do not derive execution behavior from expected
result/events. Validate the Java selection marker agrees with N-1.

Compare actual Rust execution, not expected-trace replay: input/output job and
control entry; input run/finish; output open/finish and successful commit
returns; selected commit exception; abort/close returns; control/job normal
returns or failed-output job outcomes; separate cleanup. Preserve physical
cross-component order. Compare actual result category and separate report
counts (normal input 1/output N; failure input 1/output N-1).

Validate exact Java exception class
`T0013CommitFailureOutputPlugin$InjectedCommitFailure` and message
`t0013-output-commit-failure` at selected commit and both transaction failures.
Validate exact Rust `OutputFailure("selected last commit failure")` at failed
commit, result and all four scope outcomes. Only then normalize to the selected
output-failure category/index. Unknown origins/payloads fail.

Validate but exclude capture UUIDs, digests, output operation entry markers,
input finish-before/run-normal-return, selection/injection instrumentation and
cleanup-entry from equality. Java has no failed-control marker: assert exactly
one failed-output control closure per Rust component with exact payload before
excluding those two markers. Never filter unexpected output failures in normal
execution. Report contents remain Unit/Contract, not cross-runtime equality.

## Acceptance criteria

- Full unchanged S05 gate passes both fixtures and its 23 controls.
- Exactly two live projections pass through a nonzero selected ignored Rust
  test count. Zero-task and 1/1 remain local-only, not new live claims.
- Raw controls reject missing/duplicate/unknown/malformed cases/events,
  bad capture/sequence/hash/log, selection/index/cap/schema errors, wrong exact
  exception, missing successful commit, fabricated selected success, missing
  selected failure/abort/close and invalid phase/scope/cleanup ordering.
- Semantic raw mutations repair sequence, digest and raw-log envelope first;
  assert intended rejection diagnostics, not incidental transport failures.
- Bridge controls reject wrong result/report counts, changed failure category
  or index, mutated order and unexpected failure in normal execution.
- Existing S04 live regression and all offline workspace tests still pass.
- Primary source review, independent frozen-source Tester reproduction and
  exact final-head Demo precede integration; parents remain open.

## Demo Command

`bash tests/t0013_output_commit_differential_test.sh && bash tests/t0013_empty_lifecycle_differential_test.sh`

Also run `cargo test --workspace`, `cargo fmt --check`, explicit
`rustfmt --edition 2024 --check` on the new included child, strict
`cargo clippy --workspace --all-targets -- -D warnings`, separate shell syntax,
Python syntax compilation without tracked artifacts, and `git diff --check`.

## Evidence class

Planning only until executed. Intended acceptance: Unit/Contract for validators
and two selected Differential (Embulk) projections. Independent read-only
planning review supports this scope. PM fixes the cap at 1024 (not N), preserving
the existing harness safety policy; N remains observed, not a planner claim.

## Reference and reuse record

Access/review date: 2026-09-06. Reuse only repository-owned original test
infrastructure and pinned S05 observations. Embulk 0.11.5 executable SHA-256
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`;
core `c5ac2d471edac465b45088669d376a7e2a525f8f`, SPI 0.11
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`. Exact official URL/API/license
locators are retained in S05 and T-0011 records. No new upstream implementation
inspection, translation, external artifact or admitted plugin is needed.
Transitive notices/SBOM, redistribution, patents/standards/trademark and freedom
to operate remain unreviewed, not cleared.

## Stop rule

Repair ordinary implementation/test/network failures in scope. Return to PM
before changing raw observations, exclusions, production behavior, dependency,
public API or materially uncertain security/IP boundaries. Never weaken S05/S04
gates, silently accept zero comparisons, or modify the user's checkout.

## Non-claims

No general/first/middle-index failure policy, concurrent commit ordering,
unattempted-handle abort policy, rollback, durable publication, retry/resume,
exactly-once, public plugin API, real host, Pages/data transfer, default
scheduling, performance or release claim. UUIDs are instrumentation only.

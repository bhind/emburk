# T-0013/S06 selected output-commit differential

- Tracking issue: [T-0013, #16](https://github.com/bhind/emburk/issues/16)
- State: In Progress; primary and independent source acceptance passed, integration pending
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
Independent read-only packet review at `935878e` found no missing material
condition. It specifically requires `COMMITCASE` (not S03's `CASE`) envelopes,
the main-capture selection marker, complete callback/phase validation before
exclusion, four exact Rust output-error scope payloads and diagnostic-specific
negative controls. This is Planning evidence, not frozen-source acceptance.

### Primary frozen-source acceptance

The exact Demo passed at `a284f8bf0f14c2f01a5cf1c196514fcc586f7660`.
S06 compared exactly two live cases through one explicitly selected ignored
Rust test. Normal execution projected 44 events and cleanup input 1/output 8
reports; selected last-index failure projected 43 events and input 1/output 7
reports for the observed 1/8 plan. The unchanged prerequisite S05 gate passed
both fixtures and 23 controls. All 30 new raw controls rejected at their named
diagnostics. Two local bridge tests passed, including repaired event-count
mutations, 1/1 and 1/8 local fixtures, and direct per-component/payload guards.
The unchanged S04 regression compared two cases and rejected 13 raw controls.

Primary S06 evidence: `${TMPDIR}/t0013-s06.B5smPC`; reference:
`${TMPDIR}/t0013-output-commit-failure.SOR3zQ/evidence`.
Primary S04 evidence: `${TMPDIR}/t0013-s04.zQVUFu`.
Raw cases/traces SHA-256:
`03d0c5e33683d91c391e2992e3c314cbe6f6f10dcadec2c01e10e431ab6d6c4c` /
`b8e505aceb03bdfea097650529db3245841b806342c497e03fc353fd15e32224`.
Normalized manifest SHA-256:
`045dd55a4282a560052aa77c3ec9b28ea2be4b23177478f58fe4580d6a9f70ce`.
These hashes identify evidence, not hard-coded acceptance expectations.

Workspace tests passed 23 with four intentional live ignores. Cargo formatting,
explicit Rust 2024 included-file formatting, strict all-target Clippy, separate
shell syntax checks, Python compilation with an external cache, and diff checks
all exited 0. Environment: macOS 26.5.1 ARM64, Rust/Cargo 1.98.1,
Temurin 17.0.20+8, Python 3.14.6 and Bash 3.2.57.

Frozen source SHA-256:

- Registration-only `empty_lifecycle.rs`:
  `5b77d1820982196c13cacb45e46bdb01c79244493129327fdaae50a2eced255a`
- Rust child:
  `a58579549d58069725c0fb4149303cdaa291802505e47868c012c5a420fd922d`
- Shell wrapper:
  `62ac4f75f1e243a3390a1e2bfd27a4580c700c8ef68e61a0f19874110e42357a`
- Python driver:
  `10b0b4c91ae035501df41fb10ba9dcc2f8b1a40c892b7debfb84d6c781fe929d`

Review rejected the initial count-only scaffold. The accepted candidate uses
the repository-owned S05 validator and repaired-transport controls, preserves
the original raw-size check while adding the 1024 cap, and explicitly classifies
every event before exclusion. Review also required raw-derived cleanup/result
fields, category/index-only comparison, and one exact failure per scope variant
rather than aggregate counts. No production coordinator algorithm changed.
Evidence is Unit/Contract plus only these two selected Differential projections.
Independent acceptance, final PR-head Demo and integration remain required.

### Independent acceptance

Read-only Tester reproduced the exact Demo and every strict check at the same
`a284f8b` source revision, with the same counts and no unresolved findings.
The initial sandbox DNS failure passed on approved network retry; no gate was
weakened. Manual review confirmed the four-file allowlist, actual Rust execution,
strict raw validation, individual scope guards and repaired-transport controls.

Tester S06 root: `${TMPDIR}/t0013-s06.ahDEQp`; S05 raw root:
`${TMPDIR}/t0013-output-commit-failure.Wjamwc/evidence`; S04 regression root:
`${TMPDIR}/t0013-s04.5l6zHR`.
Tester cases/traces SHA-256:
`4e7c5b6a090d3211fcaad6c29c8ba726de4c867b8a7a3abb32492f44cc51a4dd` /
`311a8e295f15abdbd86fdce5a37a85c5d5bdb0e16124e85ed7599a95969c9778`.
The normalized manifest hash matches primary acceptance. Tester selected-live
log SHA-256:
`642e0781ac220b3e8f3148f3402785cdd94ad3501c40bfb64c7d17cf2451c640`;
driver evidence-manifest SHA-256:
`3db9d97094a45bd65c2add81908e110e5c33b9e40e3da13f5c246c31e677b5f4`.
Platform is the same macOS 26.5.1 build 25F80 / Darwin 25.5.0 ARM64.
All source hashes remained unchanged. Final PR-head acceptance and integration
remain required; parent #16 remains open.

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

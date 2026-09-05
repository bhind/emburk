# T-0021/S04 private last-commit failure

- Tracking issue: [T-0021, #18](https://github.com/bhind/emburk/issues/18)
- State: In Progress; source acceptance passed, PR integration pending
- Priority: P1; parent T-0020
- Slice estimate: 3 SP (implementation 1, uncertainty 1, verification 1,
  environment 0; raw 3 maps to 3 SP)
- Parent Current SP: 8, refined from 5; Initial SP remains 5. S01–S03 account
  for the original 5 SP; this separately accepted failure boundary requires
  additional implementation/regression verification. No parent completion or
  duplicated earned points follows.

## Authority

PM owns ADR-0009, records, scope, acceptance and integration. Rust Core
Implementer owns the two exact source paths; Tester is read-only. Standing owner
authority permits bounded implementation and PR integration after acceptance.

## Dependencies

T-0021/S03 private coordinator (PR #73, `14d5fb5`); T-0013/S04 two selected live
projections (PR #74, `68d848c`); independently accepted T-0013/S05 last-index
commit observation (PR #75, `2901c31`); accepted ADR-0009. Requeue T-0013 for
remaining comparisons/index/recovery contracts, not Done or Blocked. Combined
WIP stays one; neither parent's original semantic dependencies are complete.

## Branch and allowlist

Branch: `feat/t-0021-last-commit-failure`.
Rust Core Implementer owns exactly:

- `crates/emburk-core/src/empty_lifecycle.rs`
- `crates/emburk-core/src/empty_lifecycle/differential_tests.rs`
  (typed error/event adaptation and unchanged S04 regression only)

PM owns STATUS, TODO, ROADMAP, COMPATIBILITY, ARCHITECTURE, runtime design,
ADR-0009/index, provenance/index and dated log. No new module, public export,
Cargo/dependency, Java fixture, existing shell/Python probe/comparator, schema,
scalar, CLI, upstream implementation or external artifact change is authorized.

## Artifacts

Extend the private output handle commit callback to return a typed output
failure or an actual report token. Add an output-origin coordinator error and
common typed callback outcome for input/output job and control scope completion.
Preserve original payloads, not just a Boolean failed flag. Keep input run's
typed input failure and all existing plan rejection behavior.

Replace collect-all commit handling with incremental retention of actual
successful reports. On the supported final-handle commit failure, abort that
handle only, close all owned handles, drop them before scope completion/cleanup,
and pass the same output error through output then input scopes. Retain the
already returned input token and each earlier output token in their separate
cleanup contexts. Do not turn prior callback success into a durability claim,
discard actual returned tokens, or create reports for the failed commit.

The existing selected input-run failure still aborts every opened handle before
closing every handle, never commits, propagates its exact input failure and
passes empty report collections to cleanup. Normal zero/one-input execution
remains unchanged. Cleanup receivers must remain newly constructed capabilities
that need no live handles, original transaction fields or failure-selection state.

Add a test-owned fake last-index commit failure configuration. The fake callback
actually returns the failure; the core must not branch on fixture ID or fake
selection flag. Record a typed commit-failure event and full typed scope outcomes
so tests can distinguish input from output error payloads at all four scopes.
Update S04 bridge's exhaustive event/outcome mapping without changing its two
scenario inputs, existing projection, driver or acceptance expectations. An
unexpected new output-failure event in those scenarios must not be normalized
away or accepted.

A fallible method is mechanically broader than the selected fixture contract.
Do not add claims/tests implying reference coverage for earlier/middle failures,
unattempted-output abort policy or concurrent commit ordering. The current
private module has no real plugin caller. A separately observed/packet-reviewed
slice is required before a broader policy or public exposure. Other callback
fallibility and panics remain explicitly unimplemented.

## Acceptance criteria

- Execute actual fake last-index commit failures for 1/1 and 1/8 supplied plans.
- Assert complete typed traces: normal input finish/run, successful earlier
  commits, failed last commit, abort only failed handle, close all, exact typed
  failure through both components' control/job scopes, then separate cleanup.
- Assert original full input/output token values and the exact output failure;
  the one-output case retains one input token and no output token.
- Fresh cleanup receives the explicit plan/reports only; Drop counters still
  assert no live handles. No synthetic cleanup IDs or retained job state.
- Preserve existing normal, input-error, invalid-plan, token and cleanup tests;
  preserve both S04 live normal/input-failure comparisons and malformed controls.
- No fixture-name execution table, fixed fan-out, expected-trace replay, new
  dependency/API or source/probe change outside the allowlist.

## Demo Command

`cargo test -p emburk-core empty_lifecycle::tests -- --nocapture && bash tests/t0013_empty_lifecycle_differential_test.sh`

Require a nonzero passing local test count and exactly two existing live
comparisons with nonzero ignored-test selection. Also run workspace tests,
`cargo fmt --check`, strict workspace/all-target Clippy, explicit formatting
check for the included child Rust file if Cargo fmt does not discover it, and
`git diff --check`. Tester independently reproduces frozen source; PM reruns
the exact Demo at final PR head. Existing shell/Python/Java tools stay unchanged.

## Evidence class

Unit/Contract for new last-commit behavior; regression of the existing two S04
Differential projections only. No new output-failure Differential result until
a separate T-0013 comparison packet passes. Parent #18 remains open.

Independent read-only Planning review at `7ade007` found no material ambiguity.
It confirmed the last-index-only fixture, typed input/output scope payloads,
incremental reports, unchanged S04 projections and sufficient two-file allowlist.
This is not source acceptance or a new runtime claim.

### Source acceptance

Primary and independent read-only Tester acceptance passed at
`b8dbc77c1f2ef48e9c02be43bba0f29a8a1edd79`. The exact Demo exited 0:
seven local tests passed with one intentional live ignore, then the two existing
S04 live projections passed with 13 rejected raw negative controls. Workspace
tests passed 21 with three intentional live ignores. Cargo formatting,
`rustfmt --edition 2024 --check crates/emburk-core/src/empty_lifecycle/differential_tests.rs`,
strict workspace/all-target Clippy and diff checks all exited 0.

Review corrected an initially ambiguous failed-commit event to a distinct typed
failure event. An explicit Rust 2024 included-file formatting check then found
one semicolon adjustment; `0832928` is not the final accepted source revision.
Full typed error payloads, actual report tokens, failed-handle-only abort,
all-handle close, and drop-before-fresh-cleanup were independently verified.

Source SHA-256 values:

- `empty_lifecycle.rs`: `0a02985f9d6a8be3c17f3ba81ee090327f0ce3c3df6b1aa9396ffa9a8290eb9a`
- `differential_tests.rs`: `39ddca6e262c366de5d5140d8c815d226e348004dbb06d7d5787ee6c3f0e87e5`

Primary regression evidence: `${TMPDIR}/t0013-s04.uDqHFy`.
Tester evidence: `${TMPDIR}/t0013-s04.1MsCRi`; logs:
`/private/tmp/emburk-t0021-s04-acceptance.zIYDft`.
Tester Demo log SHA-256:
`c3cba0714dca600f6eceafbae9483ce150999581a30cdf93ef9ef71fc0756742`.
Tester cases/traces SHA-256:
`25de9bc1388920b2bb9615fb02bd7a33480f136f4fb30835efbafcbd59a06817` /
`fd2bfd78f299089d4e72e5773579580a3fdff8172b3e18651a184c923ca1fd73`.
Environment: macOS 26.5.1 ARM64, Rust/Cargo 1.98.1, Temurin 17.0.20+8,
Python 3.14.6 and Bash 3.2.57. The initially restricted reference download
passed on approved network retry; no acceptance gate was weakened.
Evidence remains Unit/Contract plus existing S04 regression, not a new
output-failure Differential claim. Final PR-head acceptance and integration
remain required; parent #18 stays open.

## Reference and reuse record

Access/review date: 2026-09-06. Independently authored from repository-owned
design, original fakes and the bounded S05 observations. Exact official Embulk
0.11.5 executable SHA-256:
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`;
core `c5ac2d471edac465b45088669d376a7e2a525f8f`, SPI 0.11
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`. Exact URL/API/license locators and
Apache-2.0 classification remain in T-0011/S05. No upstream implementation or
tests are copied/translated, and no new artifact/dependency/plugin is admitted.
Existing pinned probes run only as test regression. Transitive SBOM/notices,
redistribution, patent/standards/trademark, jurisdiction and freedom to operate
remain unreviewed, not cleared.

## Stop rule

Repair ordinary compile/test/network issues in scope. Return to PM before
changing observed projections, unsupported callback/index policy, public API,
artifacts or materially uncertain IP/security boundaries. Do not weaken existing
regressions to accommodate new error handling or silently change the user checkout.

## Non-claims

No general commit failure/recovery, first/middle-index reference coverage,
rollback, durable publication, retry/resume, exactly-once, default scheduling,
values/Pages/data transfer, real plugin API/host, performance or release claim.
The supplied count cap bounds handles, not total bytes or CPU.

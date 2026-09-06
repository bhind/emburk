# Roadmap

The roadmap is ordered by evidence gates. Dates are intentionally omitted until observed throughput and cycle time support forecasting.

## Phase 0: Governance and Compatibility Contract

- Establish canonical project records, roles, workflow, provenance, and release-compliance gates.
- Pin the Embulk core and selected plugin references.
- Specify configuration, schema, value, lifecycle, transaction, cleanup, and resume behavior.
- Build a differential-test harness.

Exit gate: the first implementation tasks have approved contracts and reproducible reference fixtures.

The governance portion of this phase also requires T-0003's executable packet
and WIP audit before T-0004 may automate Project synchronization or delivery
analytics.

T-0003 completed through PR #62. T-0004/S01 established weekly Iterations,
saved delivery views, read-only configuration checks, and burndown inputs. Its
planning charts do not satisfy a runtime evidence gate.

T-0021/S02 supplies the [Rust design worksheet](RUST_RUNTIME_DESIGN.md) for
configuration/value fixtures and lifecycle/failure traces. Its proposed
structure does not satisfy this exit gate; T-0012 and T-0013 must resolve the
reference-dependent questions before semantic APIs are accepted.
T-0012/S01 gathered a narrow absent/null/default observation via the pinned
official self-contained executable and a local-only probe plugin. Its annotated
String/Optional reference observation integrated through PR #61 as `e2532e2`;
it does not itself satisfy the configuration/schema/value contract or the
Phase 0 exit gate. T-0012/S02's Boolean/Long observation integrated through PR
#65 as `d7b4838`. T-0012/S03 integrated its private original-Rust scalar resolver
through PR #66 as `e03a2bc`. S04's live comparator matched 13 selected outcomes
at `3fe6546` in primary and independent Tester acceptance and integrated through
PR #67 as `79cbcb9`. S05 now observes schema construction and handoff. Even after
these bounded slices,
that limited matrix does not satisfy the full configuration/schema/value or
lifecycle gate.

S05 primary schema observations at `cc24730` preserve ordered columns and
duplicate names across handoff. Independent acceptance passed and PR #68
integrated as `68559dc`. S06 adds a private ordered representation and bounded
live comparison under ADR-0007, not Arrow/value
encoding or completion of the Phase 0 contract gate.

S06 primary acceptance at `c7c7872` matches three ordered schema outcomes with
the private Rust model. The bounded result advances the logical-contract
foundation but does not satisfy the full schema/value or lifecycle exit gate;
independent acceptance passed and PR #69 integrated as `5de35b7`.

T-0013/S01 now supplies a separate input lifecycle observation lane for zero
and one empty task. T-0012 and T-0021 are requeued after their accepted slices
to address this still-missing prerequisite. This is not parent completion or a
blocker; callback traits, cleanup guarantees and resume remain unverified.
Primary acceptance records successful zero/one empty task executions and strict
trace controls. This reference observation cannot satisfy the lifecycle exit
gate; direct output-side and failure/recovery evidence are still missing.
PR #70 integrated S01 as `e8b5726`; S02 now observes direct output callbacks
for the same empty-task boundary before Rust policy or failure injection.
S02 primary acceptance passed at `5739052`, including its actual one-input/
eight-output observation and strict evidence controls. This does not resolve
default scheduling, failure propagation, recovery or delivery gates.
Independent and final-head acceptance passed; PR #71 integrated as `d474b7b`.
S03 now observes one input-run failure boundary before choosing a private
empty-task coordinator. This is not a pre-publication or rollback guarantee.
S03 primary acceptance at `f35cb49` passed the normal and injected-run-failure
fixtures, capture identity validation and strict malformed-evidence controls.
It supplies bounded candidate evidence for private empty-task execution only;
parent lifecycle, resume, cleanup-error and delivery gates remain open.
Independent and final-head acceptance passed; PR #72 integrated as `8e43948`.
ADR-0008 now permits the private empty-task coordinator slice T-0021/S03.
Its five-test local Unit/Contract gate passes at `84edf00` under primary and
independent acceptance; final-head acceptance passed and PR #73 integrated as
`14d5fb5`. T-0013/S04 now activates a separately scoped two-case live projection
comparison. Neither slice completes Phase 0 or the File-to-File milestone.
S04 primary acceptance at `98b6cac` passes both declared projections and strict
negative controls; independent Tester reproduced the results. Final-head
acceptance at `09ac159` passed and PR #74 integrated as `68d848c`.
S05 now observes selected output commit failure before expanding Rust output
fallibility. This reference-only gate cannot establish partial publication,
rollback, retry or resume behavior.
S05 primary acceptance at `876e861` passes the two live fixtures and 23 controls;
independent Tester reproduced these results. Final-head acceptance at `6508221`
passed and PR #75 integrated as `2901c31`. It distinguishes selected
output commit failure from input-run failure without completing parent gates.
ADR-0009 now activates T-0021/S04's local private last-commit candidate while
requiring both existing live projections as regression. A separate future
T-0013 comparison must establish any new output-failure Differential evidence.
Primary and independent S04 source acceptance passed at `b8dbc77`, including
both unchanged live regressions; final-head acceptance at `d885ba2` passed and
PR #76 integrated as `b5cfb87`. Phase gates remain open. T-0013/S06 now prepares
two selected output-commit comparisons without widening the runtime contract.
S06 primary acceptance at `a284f8b` passes both declared live projections and
strict negative controls; independent Tester reproduced these results.
Final-head acceptance passed at `7d90f5d` and PR #77 integrated as `3b16aaf`.
This closes neither arbitrary-index failure nor phase delivery gates.
S07 prepares a separate reference-only first/middle observation with an explicit
capture-before-expectations gate; Rust policy remains unchanged.
That initial capture is now reviewed at `fb26813`; Stage B validates the
observed abort suffix and retained reports before any later native policy gate.
Primary and independent Stage B acceptance pass at `76dbab0`, including three
cases, 57 semantic controls and unchanged S05 regression. Final-head acceptance
at `133cddb` passed; PR #78 integrated as `14cc2a6`. This reference-only slice
does not pass a native or phase delivery gate. ADR-0010 permits T-0021/S05's
bounded native abort-suffix candidate; a later separate comparison is required
for first/middle Differential evidence.
T-0021/S05 primary and independent source acceptance now pass at `f2d9755`,
including all local suffix cases and unchanged S04/S06 live regressions.
Final-head exact Demo passed at `02673ba` and PR #79 integrated as `d36cf28`;
phase gates stay open. T-0013/S08 now prepares three selected position
comparisons with unchanged S04/S06 regressions, not a wider recovery claim.

S08 primary and independent source acceptance now passes at `4c591a0`, including
three selected live projections and unchanged S04/S06 regressions. This is a
test-only Differential boundary; no runtime policy, public type or phase gate
changes. Final-head acceptance and integration remain required.

S08 final-head exact Demo passed at `ff8dec0`; PR #80 integrated as `de38a44`.
Its three selected Differential projections are accepted, not a general recovery
contract. Parent T-0013 returns to Backlog and remains open. T-0012/S07 now
prepares two isolated PageBuilder/test-local collector/PageReader observations
under its [packet](provenance/T-0012-page-value-probe.md), before selecting any
Rust value representation. Only Boolean/Long/String and explicit null inputs
are selected. No runtime, public API, Page encoding or transfer claim follows.

S07 initial capture at `66ef66a` returned two successful reference executions:
empty had zero Pages/rows; typed-null had one Page and three ordered rows with
true/MAX/empty text, false/MIN/newline-and-lambda text, then three explicit nulls.
Primary reviewed the complete raw capture before authorizing semantic guards
at `ec558d1`. This is initial observation, not source acceptance or a selected
Rust representation. Full negative gates, independent reproduction and final
integration remain required.

S07 primary and independent source acceptance pass at `1e7d5c9`: two fresh
Page observations, 39 diagnostic-specific repaired raw controls, two artifact
negatives and unchanged S06 three-schema comparison. Workspace 29 passed/five
intentional ignores, formatting, strict Clippy and Bash syntax pass. Evidence
is selected Reference Observation / Integration plus validator Unit/Contract;
no Rust values, production transfer or new Differential result. Final-head
acceptance and integration remain required; parent and phase gates stay open.

S07 final-head Demo passed at `3b95ecd`; PR #81 integrated as `203d7da`.
Its two bounded reference observations are accepted. T-0012/S08 implements
private owned Null/Boolean/Signed64/Text records under ADR-0011. At frozen source
`914ad2e`, primary and independent acceptance pass two selected getter-result comparisons,
18 raw controls, six local storage/transport tests and the unchanged three-schema
regression. Workspace 35 passed/six intentionally ignored, formatting and strict
Clippy pass. Final-head Demo passed at `332c721`; PR #82 integrated as `b428305`.
Schema coupling, physical encoding, public API and production transfer remain
outside this slice; parent and phase delivery gates stay open. S09 prepares a
separate reference-only double-value observation, with a capture-before-
expectations gate and no Rust Float64 or equality-policy change.
S09 primary and independent source acceptance pass at `3f18966`: two selected
reference double fixtures (114/93 events), 45 diagnostic-specific raw controls,
two artifact controls, unchanged S08/S06 regressions and strict quality checks.
Selected finite/subnormal/signed-zero/null/infinity/NaN bits are preserved in
these observations. Evidence is Reference Observation / Integration plus
validator Unit/Contract, not a native Float64 or numeric equality decision.
PR #91 is in Review; final-head acceptance and integration remain required.

S09 final-head Demo passed at `59f1b2e`; PR #91 integrated as `34757c8`.
Its selected reference observations are accepted; parent T-0012 remains open.
S10 implements the private bit-preserving representation permitted by ADR-0012.
Frozen source `3df2a88` passed implementer and independent Tester acceptance:
12 selected double/null cells, five bridge controls and unchanged S09/S08/S06
regressions. Its private equality is storage identity, not numeric equality.
Primary and final-head acceptance passed; PR #93 integrated as `742274f`.
The S10 slice is Done with Unit/Contract and the two selected Differential
projections. No public value, schema coupling, physical encoding, whole-domain
or production claim follows; parent and delivery gates remain open.




## Phase 1: Native File-to-File MVP

- Build the compact execution core and MVP CLI.
- Implement Arrow-compatible batches, bounded scheduling, backpressure, cancellation, transactions, and resume state.
- Implement file/config inputs; file/stdout/null outputs; CSV/JSON; gzip/bzip2; rename/remove-columns; and format guessing.

Exit gate: representative File-to-File jobs match Embulk under normal execution, interruption, cleanup, and resume.

## Phase 2: Java Compatibility

- Define the versioned host protocol.
- Build an isolated JVM host and Maven-style plugin loader.
- Adapt Embulk SPI 0.11 lifecycle, configuration, batches, errors, and cancellation.
- Certify the first unchanged Java plugin.

Exit gate: a pinned external Java plugin passes differential tests without modifying its artifact.

## Phase 3: JRuby Compatibility

- Package JRuby as an optional component.
- Lock gem and Bundler resolution.
- Adapt Ruby plugin lifecycles.
- Verify a high-value Ruby plugin such as the BigQuery output plugin.

Exit gate: the selected unchanged Ruby artifact passes the same compatibility gates as Java-hosted plugins.

## Phase 4: Native Expansion and Delivery

- Rank and audit plugin candidates.
- Build native JDBC and S3 foundations, then reassess the remaining portfolio.
- Publish reproducible benchmarks, containers, SBOMs, notices, the compatibility matrix, and a migration guide.

Exit gate: common production paths can run without JVM/JRuby and have published compatibility and performance evidence.

## Later Horizons

- Control-plane API and GUI
- Terraform and multi-cloud packaging
- Adaptive scheduling based on observed workload evidence

These are not commitments until the execution contract and delivery evidence are stable.

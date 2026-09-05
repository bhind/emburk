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

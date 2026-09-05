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

T-0003 completed through PR #62. T-0004/S01 is establishing weekly Iterations,
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
Phase 0 exit gate. T-0012/S02 is packeted for an independent Boolean/Long
conversion observation and likewise cannot satisfy that gate without an
independently implemented Emburk comparator.

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

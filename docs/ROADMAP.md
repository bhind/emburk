# Roadmap

The roadmap is ordered by evidence gates. Dates are intentionally omitted until observed throughput and cycle time support forecasting.

## Phase 0: Governance and Compatibility Contract

- Establish canonical project records, roles, workflow, provenance, and release-compliance gates.
- Pin the Embulk core and selected plugin references.
- Specify configuration, schema, value, lifecycle, transaction, cleanup, and resume behavior.
- Build a differential-test harness.

Exit gate: the first implementation tasks have approved contracts and reproducible reference fixtures.

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

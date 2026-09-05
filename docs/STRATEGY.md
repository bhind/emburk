# Product Strategy

## Objective

Emburk aims to become a practical successor for teams that still depend on Embulk-style bulk data movement. Product value comes first, compatibility second, and Rust architecture research third. The architecture must nevertheless allow all three to reinforce one another.

The reference point is Embulk 0.11.5 and its separated SPI 0.11. Plugin artifacts are pinned and evaluated individually rather than assumed compatible as a family.

## Feasibility

| Objective | Assessment | Strategy |
| --- | --- | --- |
| Rust bulk loader | Feasible | Deliver a complete File-to-File slice before broad integrations. |
| Pluggable architecture | Feasible with explicit boundaries | Keep a compact core and version the plugin protocol independently. |
| Faster parallel execution | Plausible, not guaranteed | Preserve semantics first and retain performance claims only after benchmarks. |
| Existing Java plugins | Feasible through a JVM host | Run pinned artifacts unchanged through an optional isolated host. |
| Existing Ruby plugins | Feasible through JRuby with higher cost | Add only after the Java host; prioritize plugins with demonstrated value. |
| Rust-native plugin implementations | Feasible incrementally | Reimplement observable behavior and verify it differentially. |
| Every ecosystem plugin | Not finite or measurable | Maintain an explicit, versioned compatibility matrix. |
| GUI, Terraform, adaptive optimization | Feasible later | Defer until the execution and compatibility contracts are stable. |

## Product Decisions

1. **Migration target:** compatible configuration and behavior for a tested matrix, not a universal clone claim.
2. **Runtime:** Rust-native by default, with optional JVM/JRuby compatibility hosts.
3. **Host boundary:** begin out of process to isolate class loaders, dependencies, crashes, and unsafe boundaries.
4. **Native extensibility:** use a versioned process protocol for third-party plugins; do not expose Rust's unstable dynamic ABI.
5. **Data plane:** use an Arrow-compatible columnar representation with Emburk-owned logical metadata.
6. **Correctness:** define transaction and resume guarantees per output capability; never imply exactly-once universally.
7. **Plugin ordering:** decide from usage evidence, upstream activity, service relevance, security, license clarity, and differential-test cost.
8. **Source use:** adopt documented principles and observable behavior; avoid mechanical source translation.

## Compatibility Portfolio

The portfolio tracks separate states:

- **Hosted:** the original artifact runs through a compatibility host.
- **Native:** the behavior has been independently implemented in Rust.
- **Verified:** representative normal, failure, cleanup, and resume cases match the pinned reference.

The first native portfolio is the standard File-to-File path. Candidate expansion then covers JDBC, S3, BigQuery, GCS, Elasticsearch, Parquet, Kafka, and Snowflake, subject to the evidence-based ranking task.

## Performance Policy

Correctness gates precede performance gates. The first File-to-File release must remain within 10% of Embulk on agreed reference workloads. The README may claim acceleration only after Emburk reaches at least 1.5 times Embulk throughput on two published workloads without weakening output, recovery, or memory guarantees.

## Reference Material

- [Embulk repository](https://github.com/embulk/embulk)
- [Embulk maintenance-mode announcement](https://www.embulk.org/articles/2025/11/10/embulk-into-the-maintenance-mode.html)
- [Embulk SPI](https://github.com/embulk/embulk-spi)
- [Embulk plugin migration guidance](https://dev.embulk.org/topics/get-ready-for-v0.11-and-v1.0-updated.html)
- [Embulk plugin catalog](https://plugins.embulk.org/)

References inform strategy; they do not imply endorsement, compatibility, or permission beyond their applicable licenses.

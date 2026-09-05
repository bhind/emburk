# Emburk product backlog

Last updated: 2026-09-06

This file is the authoritative actionable-work inventory. GitHub Issues and the
GitHub Project mirror these stable identifiers for coordination. Parent epics
are intentionally unpointed; Story Points belong to independently acceptable
tasks. Dependencies name predecessor T-IDs and do not imply completion.

Current queue state: `T-0002`, `T-0003`, `T-0004`, and `T-0011` are `Done`;
`T-0021` and `T-0012/S05` are `In Progress`, and every other item is
`Backlog`. No item is `Blocked`. This is the two-item WIP limit.

Project Workstreams map as follows: T-0001–T-0006 are `Governance`;
T-0010–T-0014 are `Compatibility Contract`; T-0020–T-0026 are `Core Runtime`;
T-0030–T-0037 and T-0060–T-0067 are `Native Plugins`; T-0040–T-0045 are
`Java Host`; T-0050–T-0054 are `JRuby Host`; T-0070 is the `Delivery` epic;
T-0071 and T-0076 are `Verification`; and T-0072–T-0075 are `Delivery`.

## T-0001 — Governance and traceability

| ID | Outcome | Status | Priority | SP | Depends on | Owner Role | Evidence |
|---|---|---|---|---:|---|---|---|
| T-0001 | Epic: Governance and traceability | Backlog | P0 | — | None | Project Manager | Planning |
| T-0002 | Establish canonical records and stable IDs | Done | P0 | 3 | None | Project Manager | Unit/Contract |
| T-0003 | Establish roles, mutation ownership, and WIP enforcement | Done | P0 | 3 | T-0002 | Project Manager | Unit/Contract |
| T-0004 | Implement Project synchronization audit | Done | P1 | 5 | T-0002, T-0003 | Project Manager | Unit/Contract |
| T-0005 | Establish provenance, license, NOTICE, and SBOM gates | Backlog | P0 | 5 | T-0002 | Project Manager | Release |
| T-0006 | Establish trademark and patent review checkpoints | Backlog | P1 | 2 | T-0005 | Project Manager | Planning |

## T-0010 — Embulk compatibility contract

| ID | Outcome | Status | Priority | SP | Depends on | Owner Role | Evidence |
|---|---|---|---|---:|---|---|---|
| T-0010 | Epic: Embulk compatibility contract | Backlog | P0 | — | None | Project Manager | Planning |
| T-0011 | Pin reference versions | Done | P0 | 3 | None | Project Manager | Planning |
| T-0012 | Specify configuration, schema, and value semantics (S05: schema observation; S01–S04 integrated) | In Progress | P0 | 8 | T-0011 | Rust Core Implementer | Differential (Embulk) |
| T-0013 | Specify lifecycle, transaction, cleanup, and resume semantics | Backlog | P0 | 8 | T-0011 | Compatibility Host Implementer | Differential (Embulk) |
| T-0014 | Scaffold the differential harness | Backlog | P0 | 8 | T-0012, T-0013 | Compatibility Host Implementer | Differential (Embulk) |

## T-0020 — Compact Rust execution core

| ID | Outcome | Status | Priority | SP | Depends on | Owner Role | Evidence |
|---|---|---|---|---:|---|---|---|
| T-0020 | Epic: Compact Rust execution core | Backlog | P1 | — | T-0010 | Project Manager | Planning |
| T-0021 | Define workspace boundaries and core traits | In Progress | P1 | 5 | T-0012, T-0013 | Rust Core Implementer | Unit/Contract |
| T-0022 | Implement configuration loading and the MVP CLI | Backlog | P1 | 8 | T-0021 | Rust Core Implementer | Unit/Contract |
| T-0023 | Implement logical schema and Arrow-compatible batches | Backlog | P1 | 8 | T-0012, T-0021 | Rust Core Implementer | Unit/Contract |
| T-0024 | Implement bounded scheduling, backpressure, and cancellation | Backlog | P1 | 8 | T-0023 | Rust Core Implementer | Unit/Contract |
| T-0025 | Implement atomic transaction and resume state | Backlog | P1 | 8 | T-0013, T-0024 | Rust Core Implementer | Unit/Contract |
| T-0026 | Implement structured errors and observability | Backlog | P1 | 5 | T-0021 | Rust Core Implementer | Unit/Contract |

## T-0030 — Native File-to-File ETL

| ID | Outcome | Status | Priority | SP | Depends on | Owner Role | Evidence |
|---|---|---|---|---:|---|---|---|
| T-0030 | Epic: Native File-to-File ETL | Backlog | P1 | — | T-0020 | Project Manager | Planning |
| T-0031 | Implement file/config inputs and file/stdout/null outputs | Backlog | P1 | 5 | T-0022, T-0023 | Plugin Implementer | Unit/Contract |
| T-0032 | Implement the CSV parser and formatter | Backlog | P1 | 8 | T-0023 | Plugin Implementer | Differential (Embulk) |
| T-0033 | Implement the JSON parser | Backlog | P1 | 5 | T-0023 | Plugin Implementer | Differential (Embulk) |
| T-0034 | Implement gzip and bzip2 codecs | Backlog | P1 | 5 | T-0031 | Plugin Implementer | Differential (Embulk) |
| T-0035 | Implement rename and remove-columns filters | Backlog | P1 | 3 | T-0023 | Plugin Implementer | Differential (Embulk) |
| T-0036 | Implement format guessing | Backlog | P1 | 5 | T-0032, T-0033, T-0034 | Plugin Implementer | Differential (Embulk) |
| T-0037 | Pass File-to-File differential and resume acceptance | Backlog | P0 | 5 | T-0014, T-0025, T-0031–T-0036 | Tester | Differential (Embulk) |

## T-0040 — Java compatibility host

| ID | Outcome | Status | Priority | SP | Depends on | Owner Role | Evidence |
|---|---|---|---|---:|---|---|---|
| T-0040 | Epic: Java compatibility host | Backlog | P1 | — | T-0020 | Project Manager | Planning |
| T-0041 | Specify the versioned host protocol | Backlog | P1 | 5 | T-0023 | Compatibility Host Implementer | Unit/Contract |
| T-0042 | Implement the JVM sidecar and Maven loader | Backlog | P1 | 8 | T-0041, T-0005 | Compatibility Host Implementer | Integration |
| T-0043 | Implement the Embulk SPI lifecycle adapter | Backlog | P1 | 8 | T-0042 | Compatibility Host Implementer | Differential (Embulk) |
| T-0044 | Bridge configuration, batches, errors, and cancellation | Backlog | P1 | 8 | T-0041, T-0043 | Compatibility Host Implementer | Differential (Embulk) |
| T-0045 | Verify the first unchanged Java plugin | Backlog | P1 | 5 | T-0014, T-0044 | Tester | Integration |

## T-0050 — JRuby compatibility host

| ID | Outcome | Status | Priority | SP | Depends on | Owner Role | Evidence |
|---|---|---|---|---:|---|---|---|
| T-0050 | Epic: JRuby compatibility host | Backlog | P2 | — | T-0040 | Project Manager | Planning |
| T-0051 | Implement optional JRuby packaging and bootstrap | Backlog | P2 | 8 | T-0045, T-0005 | Compatibility Host Implementer | Integration |
| T-0052 | Implement locked gem and Bundler resolution | Backlog | P2 | 8 | T-0051 | Compatibility Host Implementer | Unit/Contract |
| T-0053 | Implement the Ruby lifecycle adapter | Backlog | P2 | 8 | T-0052 | Compatibility Host Implementer | Differential (Embulk) |
| T-0054 | Verify hosted BigQuery output | Backlog | P2 | 8 | T-0053 | Tester | Integration |

## T-0060 — Native plugin portfolio

| ID | Outcome | Status | Priority | SP | Depends on | Owner Role | Evidence |
|---|---|---|---|---:|---|---|---|
| T-0060 | Epic: Native plugin portfolio | Backlog | P2 | — | T-0030 | Project Manager | Planning |
| T-0061 | Rank plugins and audit artifacts | Backlog | P1 | 3 | T-0005, T-0011 | Project Manager | Planning |
| T-0062 | Implement the native JDBC foundation | Backlog | P2 | 8 | T-0023, T-0061 | Plugin Implementer | Integration |
| T-0063 | Implement PostgreSQL and MySQL inputs | Backlog | P2 | 8 | T-0062 | Plugin Implementer | Integration |
| T-0064 | Implement PostgreSQL and MySQL outputs | Backlog | P2 | 8 | T-0062 | Plugin Implementer | Integration |
| T-0065 | Implement native S3 input | Backlog | P2 | 8 | T-0061 | Plugin Implementer | Integration |
| T-0066 | Implement native S3 output | Backlog | P2 | 8 | T-0061 | Plugin Implementer | Integration |
| T-0067 | Reassess the remaining plugin order | Backlog | P2 | 3 | T-0061, T-0045 | Project Manager | Planning |

## T-0070 — Verification and delivery

| ID | Outcome | Status | Priority | SP | Depends on | Owner Role | Evidence |
|---|---|---|---|---:|---|---|---|
| T-0070 | Epic: Verification and delivery | Backlog | P1 | — | T-0030 | Project Manager | Planning |
| T-0071 | Build the comparative benchmark suite | Backlog | P1 | 5 | T-0037 | Rust Core Implementer | Benchmark |
| T-0072 | Deliver container, dependency lock, SBOM, and notices | Backlog | P1 | 5 | T-0005, T-0037 | Project Manager | Release |
| T-0073 | Publish the alpha migration guide and compatibility matrix | Backlog | P1 | 5 | T-0037, T-0071, T-0072 | Project Manager | Release |
| T-0074 | Research the GUI and control-plane boundary | Backlog | Icebox | 3 | T-0073 | Project Manager | Planning |
| T-0075 | Research Terraform deployment | Backlog | Icebox | 3 | T-0072 | Project Manager | Planning |
| T-0076 | Research adaptive optimization | Backlog | Icebox | 3 | T-0071 | Performance Reviewer | Planning |

## Pull order

T-0021 has two bounded slices under one serial integration lane:

- S01 (1 SP): physical workspace skeleton, integrated through PR #58
  (`5fe306a`) after independent acceptance at `cf56841`; structural
  Unit/Contract evidence only.
- S02 (1 SP): [runtime design proposal](docs/RUST_RUNTIME_DESIGN.md), integrated
  through PR #60 (`341f285`), Planning
  evidence only. Reviewable crate boundaries and contract worksheets do not
  complete T-0012/T-0013 or authorize guessed semantic implementations.

These estimates are within the parent's 5 SP, not additional points or accepted
velocity. Parent completion retains its listed dependencies.

T-0003 is complete through PR #62, and T-0004/S01 is complete through PR #63.
T-0012/S01 used the official self-contained executable through a local-only
Maven-style input plugin, rather than assembling the core POM graph. It
integrated through PR #61 as `e2532e2` after recording nine
presence/null/default observations. This is Reference Observation / Integration
evidence only and cannot complete the parent Differential gate. T-0012/S02
owned a separate, nine-case Boolean/Long conversion probe. It integrated
through PR #65 as `d7b4838`. T-0012/S03 integrated its private original-Rust
resolver through PR #66 as `e03a2bc`, with Unit/Contract evidence at `8432391`.
S04 (3 SP) adds live comparison and malformed-evidence gates for 13 supported
outcomes, reproduced by primary and independent Tester at `3fe6546`; PR #67
integrated as `79cbcb9`. T-0012's current estimate increased from 5 to 8 SP; Initial SP remains
5. The refinement accounts for the explicit oracle adapter, private test bridge,
and negative evidence validation omitted from the initial estimate. It does
not award parent completion or change the remaining configuration/schema/value
scope. T-0021 and T-0012 occupy the combined WIP limit of two.

S05 (3 SP within Current SP 8, not additional points) observes three schema
construction/handoff cases through the pinned executable before choosing a
Rust schema representation. See its [packet](docs/provenance/T-0012-schema-boundary-probe.md).
This is existing T-0012 scope and does not trigger another parent re-estimate.

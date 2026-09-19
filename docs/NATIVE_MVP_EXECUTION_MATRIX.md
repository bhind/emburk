# Native MVP execution matrix

Status: active execution plan as of 2026-09-19. This record turns the native
MVP request into independently verifiable work; it does not convert older,
bounded slices into completion claims.

## Definition of the native MVP

The native MVP is a documented local File-to-File profile that executes one
validated configuration model through a real typed pipeline. It must support
the selected six logical types, configured File/stdout/null sinks, CSV and JSON
object input, CSV output, gzip and bzip2, rename/remove columns, deterministic
bounded format guessing, ordered bounded parallelism, cancellation, durable
native recovery, and structured native outcomes.

The MVP excludes Java/JRuby hosts, databases, object stores, remote credentials,
plugin ABI loading, JSON output, a control plane, and universal Embulk
compatibility. Observable Embulk compatibility remains selected and pinned;
native behavior without a matching observation is identified as an Emburk-owned
policy, never silently represented as reference parity.

## Current executable baseline

The current executable has a narrow configured File-to-CSV path with local
single/two-input restrictions, CSV and JSON-object framing, gzip/bzip2, two
filters, one ordered writer, bounded standard-thread formatting, native
no-clobber publication and private single-input resume. It also exposes separate
experimental text transfer commands and an optional ordinary-run result sidecar.

The baseline is not the MVP: scalar behavior remains selected/literal-bounded,
JSON execution lacks Boolean/finite-decimal support, Timestamp and JSON logical
values are absent from records, schema/batches are not the runtime data plane,
lifecycle callbacks are fake/internal, configured stdout/null is absent, and
multi-input recovery is not a run-level protocol.

## Work matrix

| Parent | Completion needed for the native MVP | Evidence and boundary |
| --- | --- | --- |
| T-0005 | Deterministic local lock/dependency/license/NOTICE inventory, reproducible build checks, explicit unknowns | Build/Release evidence; unreviewed is not cleared |
| T-0006 | Executable material-risk checkpoint and escalation record | Operations/decision evidence; counsel remains required for material uncertainty |
| T-0012 | One config/default/schema/value contract for all selected MVP types | Original corpus plus selected differential and unit rules |
| T-0013 | Real internal lifecycle, cleanup, cancellation, commit and recovery state machine | Fault, interruption and state-invariant tests |
| T-0014 | Reusable bounded reference/capture harness for selected File/CSV/JSON behavior | Manifest, mutation and independent-capture checks |
| T-0021 | Runtime traits used by the real pipeline rather than fixture-only callbacks | Unit/contract and integration tests; no public plugin ABI |
| T-0022 | One production `run`/`resume` config and diagnostic path | CLI integration and invalid-config-before-output controls |
| T-0023 | Runtime-used typed batches, schema validation and all six selected logical values | Unit/contract plus pipeline projections; no unadmitted Arrow dependency |
| T-0024 | Bounded admission/backpressure, stable order and cooperative cancellation under load | Deterministic load/fault tests; standard threads remain acceptable |
| T-0025 | Atomic native publication and validated run-level multi-input recovery | Crash/fault/replay tests; no exactly-once or Embulk state-format claim |
| T-0026 | Structured native outcomes/counters for run, resume, cancellation and failure | Stable local contract and CLI tests |
| T-0031 | Configured File/stdout/null sinks and scalable ordered local file selection | Path/resource and integration tests |
| T-0032 | Grammar/type-family CSV parsing and formatting, escaped fields and row errors | Generated corpus/holdout; no literal exception tables |
| T-0033 | JSON object scalar mapping for selected six types | Bounded JSON framing/mapping tests |
| T-0034 | Codec composition, limits, finalization and corruption behavior | Round-trip, truncated and recovery tests |
| T-0035 | Schema-aware ordered rename/remove behavior | Duplicate/order/failure tests |
| T-0036 | Deterministic bounded CSV/JSON/codec guessing connected to validation | Generated seed/inference tests; no implicit TSV/charset scope |
| T-0037 | Composed MVP differential, recovery and user-visible demonstration | Selected reference/native matrix plus native policy matrix |

## Delivery order

1. T-0032/S06 establishes scalar-family evidence and removes literal-table
   implementation pressure. T-0005/S01 runs in parallel as the only independent
   delivery-evidence lane.
2. T-0023/S03 and T-0021/S07 make selected values/batches and lifecycle actual
   runtime components; T-0022/S02 then makes their configuration/diagnostics the
   single CLI path.
3. T-0031/S04, T-0024/S02 and T-0025/S03 complete local file/sink, bounded
   flow/cancellation and run-level recovery in dependency order.
4. T-0033/S02, T-0034/S02, T-0035/S02 and T-0036/S03 complete the selected
   format/filter/guess surface only when their source, tests and evidence paths
   are disjoint.
5. T-0026/S02 and T-0037/S02 close native observability and composed MVP
   acceptance. T-0006's checkpoint must pass before a release claim, but cannot
   declare legal, patent or freedom-to-operate clearance.

At most two Issue/Project items may be In Progress or Review. Canonical record
integration remains serial. Every implementation packet must use prompt-only
Qwen assistance for one bounded low-level activity when available, with a
600-second timeout and 30-minute keepalive; unavailability or advice never
blocks independent verification.

## Active packets

- [T-0032/S06 / Issue #156](https://github.com/bhind/emburk/issues/156): Stage A
  freezes generated scalar-family corpus and holdout before any native semantic
  mutation. A new ADR gates Stage B.
- [T-0005/S01 / Issue #157](https://github.com/bhind/emburk/issues/157): local,
  deterministic delivery-evidence inventory. It reports unknown facts as
  `unreviewed` and cannot clear them.

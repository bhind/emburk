# Emburk product backlog

Last updated: 2026-09-06

This file is the authoritative actionable-work inventory. GitHub Issues and the
GitHub Project mirror these stable identifiers for coordination. Parent epics
are intentionally unpointed; Story Points belong to independently acceptable
tasks. Dependencies name predecessor T-IDs and do not imply completion.

Current queue state: `T-0002`, `T-0003`, `T-0004`, and `T-0011` are `Done`;
`T-0013/S08`, `T-0012/S08` and `T-0021/S05` are integrated. T-0012/S09 is
integrated through PR #91 following fresh reference-probe acceptance runs.
T-0012/S10 is integrated through PR #93; T-0012, T-0013, T-0021 and all other
unfinished items are `Backlog`. T-0021/S06 is integrated through PR #96.
T-0012/S11 is Done through PR #99 after final-head acceptance. T-0023/S01 is
Done through PR #101 (`d0eebf8`), after primary and independent final-head Demo
at `196d648`. S01 accepts 5 SP. T-0023/S02 is In Progress as a separate 5-SP selected
comparison slice; parent Current refines 8 to 21, while Initial remains 8.
The estimate now covers accepted S01, S02 verification, and remaining physical,
timestamp and JSON uncertainty that does not fit 8 SP. It is a forecast, not
completion evidence. Parent #20 remains open; WIP is one of two.

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
| T-0012 | Specify configuration, schema, and value semantics (S11 observation automation integrated) | Backlog | P0 | 55 | T-0011 | Compatibility Host Implementer | Integration |
| T-0013 | Specify lifecycle, transaction, cleanup, and resume semantics (S01–S08 integrated) | Backlog | P0 | 34 | T-0011 | Compatibility Host Implementer | Differential (Embulk) |
| T-0014 | Scaffold the differential harness | Backlog | P0 | 8 | T-0012, T-0013 | Compatibility Host Implementer | Differential (Embulk) |

## T-0020 — Compact Rust execution core

| ID | Outcome | Status | Priority | SP | Depends on | Owner Role | Evidence |
|---|---|---|---|---:|---|---|---|
| T-0020 | Epic: Compact Rust execution core | Backlog | P1 | — | T-0010 | Project Manager | Planning |
| T-0021 | Define workspace boundaries and core traits (S01–S06 integrated; remaining contracts queued) | Backlog | P1 | 13 | T-0012, T-0013 | Rust Core Implementer | Unit/Contract |
| T-0022 | Implement configuration loading and the MVP CLI | Backlog | P1 | 8 | T-0021 | Rust Core Implementer | Unit/Contract |
| T-0023 | Implement logical schema and Arrow-compatible batches (S01 Done; S02 In Progress) | In Progress | P1 | 21 | T-0012, T-0021 | Compatibility Host Implementer | Differential (Embulk) |
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
T-0004/S02 completed through PR #85 and hosted run `34003581110`: the
zero-permission credential gate passed and review/snapshot mutation jobs safely
skipped while `PROJECTS_TOKEN` was absent. Issue #84 is closed and Done. The
slice did not register a credential or change Project schema.
T-0004/S03 completed through PRs #88 and #89 plus hosted run `34004702599`.
The registered `EMBURK_PROJECT_TOKEN` passed the credential gate; Project
audit, minimal paginated GraphQL snapshot, and metrics commit/push succeeded.
Issue #87 is closed and Done. The token value was never read or logged.
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
scope. T-0021 and T-0012 previously occupied the combined WIP limit of two.

S05 (3 SP within Current SP 8, not additional points) observes three schema
construction/handoff cases through the pinned executable before choosing a
Rust schema representation. See its [packet](docs/provenance/T-0012-schema-boundary-probe.md).
This is existing T-0012 scope and does not trigger another parent re-estimate.
Primary and independent Tester acceptance passed at `cc24730`, including all
three schema cases, validator controls and S01/S02/S04 regressions. PR #68
integrated as `68559dc`; parent completion and schema support are not claimed.

S06 (3 SP within Current SP 8) adds only a private ordered schema plus a bounded
live comparison of S05's three actual outcomes. ADR-0007 and its
[packet](docs/provenance/T-0012-ordered-schema-differential.md) exclude lookup,
nullability, values, Arrow, public APIs and plugin traits. No parent re-estimate
or completion follows from activation.
Primary and independent Tester acceptance passed at `c7c7872`: three live schema
outcomes, S04 regression, strict checks and 14 offline tests with two intentional
live ignores. PR #69 integrated as `5de35b7`.

T-0013/S01 (3 SP within unchanged Current/Initial SP 8) observes zero-task and
one-task input callback traces using a separate pinned-runtime probe. Its
[packet](docs/provenance/T-0013-input-lifecycle-probe.md) excludes fault injection,
retry, resume, production traits and delivery guarantees. T-0012 and T-0021
return to Backlog, not Done or Blocked, so this missing lifecycle evidence can
advance the core-trait dependency. Accepted slices remain accepted; no parent
velocity is awarded.

S01 primary acceptance at `b3f9c68` passed the two live input fixtures and all
artifact/trace controls. Independent Tester reproduced the complete Demo;
final-head Demo at `84e692f` passed and PR #70 integrated as `e8b5726`.
The next lifecycle decision needs direct output-side observations before
assigning commit, abort or close responsibilities to private Rust traits.

T-0013/S02 (3 SP within unchanged parent Current/Initial SP 8) observes output
callbacks for zero/one empty task through a separately identified original
output plugin. Its [packet](docs/provenance/T-0013-output-lifecycle-probe.md)
excludes failure injection, Pages, delivery guarantees and Rust traits. Parent
completion and additional parent points are not implied; combined WIP stays one.
Primary acceptance at `5739052` passed the exact S02 Demo, including actual
distinct input/output counts and 30 malformed-evidence controls. Independent
Tester reproduced the complete Demo; final-head acceptance at `55ed697` passed
and PR #71 integrated as `d474b7b`.

T-0013/S03 (3 SP within Current SP 13) observes one input-run exception before
its own finish call plus a normal control. S03 retains S02 output behavior in a
new original fixture with explicit capture-context IDs; S02 remains unchanged.
See its [packet](docs/provenance/T-0013-input-failure-probe.md). Current parent
SP changes from 8 to 13 because distinct input/output task contexts and strict
failure-evidence validation were underrepresented initially. Initial SP remains
8. No earned parent points or completion follows; retry/resume and the parent
Differential gate remain open. Combined WIP stays one.
S03 primary acceptance at `f35cb49` passed the exact normal/failure Demo and
25 invalid-evidence controls, including same-capture duplicate sequence 1 and
non-main capture checks. Independent Tester reproduced the full Demo;
final-head acceptance at `1cfa5af` passed and PR #72 integrated as `8e43948`.

T-0021/S03 is now active under ADR-0008 and its
[packet](docs/provenance/T-0021-empty-task-coordinator.md): a private empty-task
coordinator with explicit plans and original fake plugins. Its 3 SP stays within
unchanged parent Current/Initial SP 5. The normal and input-run failure paths
are bounded; other callback fallibility remains explicit unsupported scope.
No default fan-out, public plugin API or data transfer is inferred. Local
Unit/Contract acceptance precedes a separately packeted live callback comparison
under T-0013. T-0013 returns to Backlog, not Done or Blocked; WIP stays one.

S03 primary source acceptance at `84edf00` passed five selected lifecycle tests,
19 workspace tests with two intentional live ignores, format, strict Clippy
and diff checks. Independent Tester reproduced these results; final-head
acceptance at `264a12f` passed and PR #73 integrated as `14d5fb5`;
the parent semantic dependencies and live comparison gate remain open.

T-0013/S04 (3 SP within unchanged Current SP 13, Initial SP 8) is active under
its [packet](docs/provenance/T-0013-empty-lifecycle-differential.md). Compare
the live S03 normal/failure reference projections to the actual private Rust
coordinator with observed output counts as supplied plans. Zero-task behavior
remains Unit/Contract only. T-0021 returns to Backlog; no parent completion or
additional points follow. Combined WIP stays one.

S04 primary acceptance at `98b6cac` passed both live comparisons and 13 raw
controls; workspace tests passed 20 with three intentional live ignores, plus
format and strict Clippy. Independent Tester reproduced these results;
final-head acceptance at `09ac159` passed and PR #74 integrated as `68d848c`.

T-0013/S05 (3 SP) is active under its
[packet](docs/provenance/T-0013-output-commit-failure-probe.md). Observe normal
and selected output commit failure callbacks before choosing Rust output
fallibility. Current parent SP is refined 13 to 21: S01–S04 already represent
12 SP of accepted slices, while output-failure verification and recovery
uncertainty remain. Initial SP stays 8; no parent completion or earned parent
points are implied. Combined WIP stays one.

S05 primary acceptance at `876e861` passed both live fixtures, 21 targeted
evidence controls and two executable controls, separate shell syntax and diff
checks. Independent Tester reproduced these results; final-head acceptance at
`6508221` passed and PR #75 integrated as `2901c31`. Only selected
last-index reference observations are claimed, not general commit handling.

T-0021/S04 (3 SP) is active under ADR-0009 and its
[packet](docs/provenance/T-0021-last-commit-failure.md): typed last-commit failure
and retained actual reports, preserving the two existing live projections.
Current parent SP is refined 5 to 8 for added implementation/regression work;
Initial SP stays 5. T-0013 returns to Backlog for its next comparison and
remaining index/recovery contracts. Combined WIP stays one; no parent completion
or new output-failure Differential result is claimed.

S04 source acceptance at `b8dbc77` passes primary and independent Tester checks:
seven local tests, two existing live projections, 13 negative controls,
workspace 21 passed/three intentional ignores, formatting and strict Clippy.
Evidence is Unit/Contract plus existing regression; final-head acceptance passed
at `d885ba2` and PR #76 integrated as `b5cfb87`. Parent #18 remains open.

T-0013/S06 (3 SP within unchanged Current 21/Initial 8) is Review in PR #77 under its
[packet](docs/provenance/T-0013-output-commit-differential.md). Compare normal
and selected last-output-commit execution to the unchanged S05 reference gate.
Keep S04 unchanged; no production mutation or broader failure claim. Requeue
T-0021 to Backlog and retain a single serial implementation lane.

S06 primary source acceptance at `a284f8b` passes the exact Demo: two new live
projections, full S05 gate/23 controls, 31 raw controls, two local bridge tests,
and unchanged S04 two-case/13-control regression. Workspace 23 passed/four
intentional ignores and strict checks pass. Evidence is Unit/Contract plus two
selected Differential projections; independent Tester reproduced the same source
results. Final-head acceptance at `7d90f5d` passed and PR #77 integrated as
`3b16aaf`; parent #16 remains open.

T-0013/S07 (3 SP) is Review in PR #78 under its
[packet](docs/provenance/T-0013-output-commit-position-probe.md). Observe three
fixtures: normal, first-index failure and middle-index failure. Raw capture must
precede PM's per-index/cleanup expectation decision. All Rust and accepted
S05/S06 tests remain unchanged. Current SP is refined 21 to 34, Initial remains
8: 18 SP are accepted in S01–S06; further observation, native policy/comparison
and remaining cleanup/recovery uncertainty exceed the old forecast. No parent
completion, additional canonical task allocation or duplicate points follow.

S07 Stage A captured at `fb26813`; PM reviewed all raw callbacks and recorded
Stage B expectations: abort the selected and unattempted suffix, preserve prior
commit reports, close all handles. The observed plan was 1/8 with failures at 0
and 4. Initial capture is not acceptance or a Rust policy; Stage B tests and
independent reproduction remain required.

S07 source acceptance at `76dbab0` passes primary and independent Tester:
three live cases, 57 semantic controls, two artifact controls and unchanged
S05 full regression. Syntax, source hashes and diff checks pass. Final-head
acceptance at `133cddb` passed and PR #78 integrated as `14cc2a6`; parent #16
remains open and returns to Backlog for native comparison/recovery work.

T-0021/S05 (3 SP) is Review in PR #79 under ADR-0010 and its
[packet](docs/provenance/T-0021-commit-abort-suffix.md). Extend only the private
coordinator's failed/unattempted abort suffix, retaining committed reports and
all existing S04/S06 live regressions. Current SP is refined 8 to 13, Initial
stays 5: the eight accepted SP plus this three-point slice and remaining runtime
uncertainty exceed the former forecast. No parent completion or new first/middle
Differential claim follows.

S05 primary and independent source acceptance pass at `f2d9755`: three new
first/middle local fixtures, complete typed trace/report/cleanup assertions,
12 focused passes, four existing live projections and 13/31 raw controls.
Workspace 26 passed/four intentionally ignored and strict quality checks pass.
Final-head exact Demo passed at `02673ba`; PR #79 integrated as `d36cf28`.
Parent #18 stays open and returns to Backlog.

T-0013/S08 (3 SP within unchanged Current 34 / Initial 8) is Review in PR #80 under its
[packet](docs/provenance/T-0013-commit-position-differential.md). Compare exactly
normal/first/middle empty-fixture projections with actual private Rust execution,
strict raw validation and negative controls. S04/S06/S07 sources remain unchanged;
no production algorithm or public type changes. S01–S07 account for 21 accepted
SP, not parent completion; remaining cleanup/recovery work stays queued.

S08 primary and independent source acceptance pass at `4c591a0`: three selected
normal/first/middle live projections, 57 raw controls, three local Rust tests,
and unchanged S04/S06 regressions. Workspace 29 passed/five intentional ignores
and strict quality checks pass. Runtime policy is unchanged; evidence is
Unit/Contract plus selected Differential only. Final-head acceptance and PR
integration remain required; parent #16 remains open.

S08 final-head acceptance passed at `ff8dec0`; PR #80 integrated as `de38a44`.
S01–S08 account for 24 accepted slice-estimate points. Parent #16 stays open
and returns to Backlog; cleanup/recovery remains required.

T-0012/S07 is Review in PR #81 under its [packet](docs/provenance/T-0012-page-value-probe.md):
3 SP for two original Boolean/Long/String/null Page observations before Rust
value policy. Current estimate refines 8 to 34, Initial stays 5: known S03–S06
already total 12 accepted SP, with observation, native comparison and remaining
configuration/Float64/time/JSON uncertainty ahead. S01/S02 receive no retroactive
points. Independent readiness review passed after explicit per-page reader
exhaustion/callback capture was required. No parent completion follows.

S07 initial capture at `66ef66a` yielded two successful observations with zero
and three rows. Complete raw records retain exact null flags, typed values,
reader exhaustion and nested finish/close. PM reviewed all events and recorded
Stage B expectations at `ec558d1`; the strict validator and negative gates are
now being implemented. No accepted Rust values or full reference gate yet.

S07 primary and independent source acceptance pass at `1e7d5c9`: two live
fixtures, 39 raw controls, two artifact controls, unchanged three-schema
regression and strict quality gates. Final-head acceptance and PR integration
remain required. Parent #15 remains open; no Rust values or new Differential
claim follows from this bounded reference observation.

S07 final-head Demo passed at `3b95ecd`; PR #81 integrated as `203d7da`.
T-0012/S08 (5 SP within unchanged Current 34 / Initial 5) is prepared under
ADR-0011 and its [packet](docs/provenance/T-0012-private-record-values.md).
Only private values-only records and two selected live getter projections are
in scope; schema/physical/public coupling remain excluded. Primary source
acceptance at `914ad2e` passes both projections, 18 raw controls, six local tests,
unchanged S06 regression and strict checks. Independent Tester reproduced the
frozen source. Final-head Demo passed at `332c721`; PR #82 integrated as
`b428305`. Known accepted S03–S08 slice estimates total 20 SP; parent #15
remains open and Initial SP remains 5.

S09 is prepared under its [packet](docs/provenance/T-0012-double-value-probe.md):
5 SP within unchanged Current 34 / Initial 5 for finite/null and nonfinite
double-value reference observations. PM reviews complete raw capture before
semantic assertions or any later Rust Float64 representation/equality decision.

S09 Stage A at `7e46379` passed the exact capture Demo and primary reproduction.
PM reviewed all 114/93 events: both fixtures exit 0; finite bounds, subnormals,
signed zero, null, infinities and selected NaN bits remain distinguishable.
Stage B exact vectors and repaired-copy controls are authorized in the packet.
No full acceptance, native Float64 policy or parent completion follows yet.

S09 corrected source acceptance at `3f18966` passes primary and independent
Tester: two reference fixtures, 45 raw controls, two artifact controls, unchanged
S08/S06 regressions and strict quality checks. PR #91 is Review; final-head Demo
and integration remain required. Parent #15 stays open; no native Float64 or
whole-domain equality decision follows from this bounded reference slice.

S09 final-head Demo passed at `59f1b2e`; PR #91 integrated as `34757c8`.
Known accepted S03–S09 slice estimates total 25 SP; parent Current 34 / Initial
5 stay unchanged. S10's 5 SP private-double-storage/comparison packet and
ADR-0012 passed readiness review. Implementation at `3df2a88` now passes the
implementer and independent Tester exact Demo: 12 selected bit/null cells,
five bridge controls and unchanged S09/S08/S06 regressions. Primary and final
PR-head acceptance passed; PR #93 integrated as `742274f`. S10's 5 SP are
accepted, bringing known S03–S10 slice estimates to 30 SP; parent Current 34 /
Initial 5 remain unchanged. Parent #15 remains open and returns to Backlog.

T-0021/S06 implemented a private synchronous owned-record handoff seam
under accepted ADR-0013 and its [packet](docs/provenance/T-0021-owned-record-handoff.md).
Estimate 2 SP within Current 13 / Initial 5; prior accepted S01–S05 total 11 SP.
Independent readiness review passed; implementation is now Done. It connects existing private records to original
fake consumers without selecting schema, lifecycle or public plugin policy.
Parent T-0021 and all delivery gates remain open. Source `8fe820b` passes
primary and independent exact Demo: five handoff tests, 46 workspace passes,
seven intentional live ignores, format and strict Clippy. Final-head acceptance
passed at `8cb13ff`; PR #96 integrated as `56ef9e9`. The slice's 2 SP are
accepted, bringing S01–S06 to 13 SP. Parent Current 13 / Initial 5 are historical
forecasts, not proof of completion: remaining work requires refinement before
another slice is activated. Parent #18 remains open and returns to Backlog.

T-0012/S11 observes five bounded schema/value coupling cases
under its [packet](docs/provenance/T-0012-schema-value-coupling-probe.md).
Independent readiness review passed. Estimate 5 SP; Current refines 34 to
55, Initial remains 5: known accepted S03–S10 total 30 SP plus this slice and
remaining configuration/time/JSON/schema uncertainty exceed 34. No points are
awarded by planning. Stage A raw capture must precede PM-reviewed expectations;
unset/mismatched-setter observations cannot automatically become Rust policy.
Stage A at `a95e350` has now passed primary reproduction and full raw review:
289 events across five cases. Stage B automation passes primary and separate reproduction at `b556ce0`,
including 39 repaired-copy and two artifact controls. Final-head Demo passed
at `da7e50f`; PR #99 integrated as `413f837`. S11 is Done, accepting 5 SP;
known S03–S11 total 35 SP. Parent Current 55 / Initial 5 remain unchanged.
Parent #15 remains open and returns to Backlog; remaining work requires refinement.

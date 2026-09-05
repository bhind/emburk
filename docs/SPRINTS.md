# Kanban governance

Status: active

Emburk uses a GitHub Project for the Product Backlog and continuous Kanban
execution. Integrate accepted work continuously rather than waiting for a
calendar boundary, and review priorities, estimates, and WIP weekly.

## Board fields

The minimum Project schema is:

| Field | Type and values |
|---|---|
| Status | `Backlog`, `Ready`, `In Progress`, `Review`, `Done`, `Blocked` |
| Priority | `P0`, `P1`, `P2`, `Icebox` |
| Story Points | Number; Fibonacci values `1`, `2`, `3`, `5`, `8` |
| Initial SP | Number; immutable after commitment |
| Owner Role | Single select using the roles in `docs/GOVERNANCE.md` |
| Support Roles | Text |
| Parent T-ID | Text |
| Depends On | Text |
| Workstream | `Governance`, `Compatibility Contract`, `Core Runtime`, `Native Plugins`, `Java Host`, `JRuby Host`, `Verification`, `Delivery` |
| Work Type | `Epic`, `Product Slice`, `Research`, `Evidence`, `Review`, `Operations` |
| Evidence Class | `Planning`, `Unit/Contract`, `Differential (Embulk)`, `Integration`, `Benchmark`, `Release` |
| Demo Command | Text |
| Estimate Change Reason | Text |

Show Title, Status, Priority, Parent T-ID, Owner Role, Depends On, Story Points,
Demo Command, and Evidence Class on the execution board.
Keep the other fields available for refinement and review.

## Product Backlog and WIP

Order the backlog by satisfied dependencies, user migration value, risk
reduction, and priority. Maintain one active P0 when pullable work exists and at
least one completely prepared P1/Ready successor. A later candidate may remain
in Backlog with a forecast; it must not be presented as committed.

The total WIP limit is two across `In Progress` and `Review`. The Project Manager
may use both lanes only for work with explicit non-overlapping mutation and
evidence packets. Review, integration, and canonical record updates remain
serial.

Agent compute is a separate external budget. Default to the primary agent plus
at most one independently useful subagent, prefer read-only delegation, and use
the lower-cost configured Implementer or Tester profiles for bounded work.
Reserve high-reasoning profiles for Project Manager decisions and risk review.
Do not repeat broad scans or full test suites unless a changed artifact or new
failure justifies them. A local two-thread cap is recommended; it limits
concurrency but cannot measure or reset an account's weekly usage allowance.

## Definition of Ready

An item may enter `Ready` only when it has:

- one observable outcome and explicit non-goals;
- a stable parent T-ID and an independently acceptable slice;
- resolved predecessors or a named external clearing condition;
- one Owner Role and all required Support Roles;
- Initial SP with the dominant estimate factors;
- an evidence class and runnable Demo Command;
- a complete Issue packet containing authority, allowlist, artifacts, stop
  rule, and non-claims;
- no unresolved material license, redistribution, provenance, patent, or
  reimplementation-boundary ambiguity.

## Definition of Done

An item may enter `Done` only after:

- its Demo Command passes at the reviewed revision and environment;
- required tests and independent review are complete;
- failures, unsupported behavior, and non-claims remain visible;
- STATUS, TODO, ROADMAP, COMPATIBILITY, ADR, and provenance records are
  reconciled as applicable;
- the pull request is integrated and its real `work-item` Issue is closed.

Project metadata, prose, or a green subagent report is insufficient.

## Story-point calculation

Story Points express relative AI-assisted delivery risk, not hours, business
value, agent count, or individual productivity. Calculate a raw score during
refinement:

```text
raw = implementation + uncertainty + verification + environment
```

| Factor | Score | Meaning |
|---|---:|---|
| Implementation | 1-4 | Number and coupling of bounded mutation packets |
| Uncertainty | 0-3 | Unknown contract, compatibility, mechanism, or failure surface |
| Verification | 0-2 | Independent tests, differential replay, review, and evidence work |
| Environment | 0-2 | Cold builds, JVM/JRuby, external services, containers, or special setup |

Map the raw sum to Fibonacci points:

| Raw | SP |
|---:|---:|
| 1 | 1 |
| 2 | 2 |
| 3-4 | 3 |
| 5-6 | 5 |
| 7-9 | 8 |
| 10 or more | Split before `Ready`; no point value is assigned |

Parent epics receive no points. Count only independently acceptable slices so
implementation, testing, and review do not duplicate velocity. Preserve
`Initial SP`; when new evidence changes the estimate, update current `Story
Points` and record a dated, concrete `Estimate Change Reason`. Carry-over is
recommitted without rewriting the initial estimate.

## Review cadence

Use a lightweight weekly review until empirical throughput supports a different
cadence:

- planning: choose the next outcome, pull only Ready work, and record its
  acceptance path;
- mid-week correction: compare real progress with Initial SP, split only
  into independently acceptable slices, and preserve estimate changes;
- review: run an actual CLI, fixture, compatibility replay, or benchmark at an
  identified revision and explain what it proves and does not prove;
- retrospective: record one `Keep`, one observed `Problem`, and at most one
  bounded `Try` action;
- closeout: reconcile repository records and the Project, then prepare the next
  Ready item without waiting for a calendar boundary.

Do not set a fixed velocity from Raveil's history. Calibrate Emburk's capacity
after at least two weekly reviews using accepted SP, cycle time, blocked time,
and the serial Project Manager lane.

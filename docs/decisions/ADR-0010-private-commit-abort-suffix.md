# ADR-0010: Private Commit Failure Aborts the Uncommitted Suffix

- Status: Accepted
- Date: 2026-09-06
- Supersedes: ADR-0009's last-index-only supported fixture boundary

## Context

T-0013/S07 independently observed first and middle commit failures using
original empty fixtures against the pinned Embulk executable. PR #78 integrated
as `14cc2a6` after source and final-head acceptance. For observed N=8, failure
at 0 aborted 0–7; failure at 4 retained commits 0–3 and aborted 4–7. Both closed
all handles and cleanup received input report 1 and output reports 0/4.
These callback observations do not establish durable publication or rollback.

## Decision

Permit T-0021/S05 to extend the existing private serial empty-task coordinator
to the selected first/middle fixtures. On a commit error at k, retain actual
reports from successful commits before k, attempt no later commit, abort each
handle in [k,N), then close all handles. Never abort the committed prefix.
The completed input report, original typed error through all four scopes,
handle drop before cleanup and separate cleanup receivers remain unchanged.

Actual callback Results drive the algorithm, not fixture identifiers, a
hard-coded fan-out or a failure-index input to the coordinator. Existing fake
selection is test instrumentation only. The original fake error text remains
unchanged to preserve exact-payload regressions; it is not a runtime policy.
Input-run failure retains its separate all-abort/all-close/no-reports path.

The supported local fixture set includes first/middle failures in a supplied
1/8 plan and a 1/3 middle boundary case. The latter is Unit/Contract only; it
must not be described as an observed reference plan. Last-index 1/1 and 1/8,
normal, zero-task and invalid-plan coverage remain unchanged. Mechanical
generality does not establish arbitrary-index or concurrent reference coverage.

## Consequences

Only `crates/emburk-core/src/empty_lifecycle.rs` needs implementation/test
changes. No public or bridge type changes, dependencies or host are authorized.
Complete event vectors and actual report values must verify prefix retention,
suffix abort, all-close, identical typed scope failures and separate cleanup.
Both existing S04 and S06 live differential gates remain required regressions.
First/middle Differential evidence requires a later separate T-0013 packet.

All other ADR-0009 limitations remain: infallible fake abort/close/cleanup,
no panic/cancellation/process-loss handling, real plugin API, Pages, data
transfer, retry/resume, rollback, exactly-once, durability or release claim.
No upstream implementation was inspected or translated for this decision.
Existing artifact provenance applies; patent/FTO and redistribution gaps remain
unreviewed, not cleared.

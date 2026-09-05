# ADR-0009: Private Last-Commit Failure With Retained Reports

- Status: Accepted
- Date: 2026-09-06
- Extends: ADR-0008's selected private callback fallibility only

## Context

T-0013/S05 independently observed the original last-index commit exception and
integrated through PR #75 (`2901c31`). Unlike input-run failure, the selected
output failure followed normal input completion and earlier output commit
returns. Only the failed handle was aborted, all handles closed, and cleanup
received the input report and earlier output reports. These are empty-fixture
observations, not durable publication, rollback or arbitrary-index evidence.

## Decision

Permit T-0021/S04 to extend the existing private coordinator with typed output
commit failure, incremental report retention and a typed common input/output
failure outcome through all job/control scopes. Preserve the original callback
error payload and distinguish its input/output origin. Keep plan rejection
before effects, separate cleanup receivers and dropped handles before cleanup.

Only original fake last-index output commit failure is added to the supported
fixture contract. For that case, retain the completed input report and each
returned output token, abort the failed handle only, close all handles, propagate
the same output failure through both components' scopes and clean up with the
separate retained reports. Preserve the input-run failure path's all-abort then
all-close and empty reports; do not merge these into a generic abort-all policy.

Actual callback Results drive execution. The coordinator cannot inspect fixture
IDs or fabricate events/reports. A fallible private commit signature is
mechanically broader than current evidence: earlier/middle commit failures have
no supported reference coverage here. Do not present this candidate as general
commit recovery or expose it to real plugins. Additional index observations are
required before adopting a broader policy. Other output operations, setup,
cleanup, panics, cancellation and process loss remain outside this boundary.

## Consequences

Local tests cover last-index failure in explicit 1/1 and 1/8 plans, full typed
error propagation, actual event order, retained token values and fresh cleanup.
The 1/1 case is Unit/Contract evidence only, not a new upstream observation.
Existing S04 normal/input-failure live projections must still pass unchanged.
A separate T-0013 packet must compare the newly added output-failure projection
before making any new Differential claim.

No public API, loader, plugin admission, default planner, values/Pages, scheduler,
new dependency, storage format, retry/resume or delivery guarantee is authorized.
Opaque reports remain non-durable callback values; abort is not rollback.

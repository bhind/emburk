# ADR-0008: Private Empty-Task Coordinator Before Public Plugin Traits

- Status: Accepted
- Date: 2026-09-06

## Context

T-0013/S01–S03 observed zero/one empty input tasks, direct output callbacks and
an original input-run failure before its finish call against the pinned runtime.
Input and output task counts differed. Failure cleanup used fresh capture
contexts, so cleanup cannot require the original in-memory plugin instance.
No values, default executor mapping, output failure, retry or resume contract
was established. These observations are not themselves Rust execution evidence.

## Decision

Permit T-0021/S03 to implement a private, dependency-free synchronous empty-task
coordinator in `emburk-core`, with original fake plugins used by tests. Supply
input and output task counts explicitly: support zero input/zero output and
one input/one-or-more outputs within a caller-supplied output-task cap. Other
plans are explicitly unsupported at this boundary, not Embulk semantic errors.
Do not hardcode a fan-out factor or claim a default scheduling algorithm.

Execute actual callbacks through private typed interfaces and owned task-local
output handles. The core must not inspect fixture names, replay a captured
trace or construct a precomputed expected event list. Preserve input and output
report collections separately. Job/control scopes nest around task execution;
normal input completion precedes output commit/close, while the selected input
failure path invokes output abort/close and propagates its failure before job
cleanup. These choices reproduce only the observed empty-fixture boundaries.
They do not assert that abort rolls back external effects.

Cleanup receives the explicit plan and available reports through a distinct
job-level capability; it must not need still-open task handles or surviving
mutable transaction-instance state. Tests must exercise fresh cleanup context
objects on the failure path. Instrumentation capture UUIDs are not part of the
Rust task/report model or a recovery format.

Only the selected input-run failure is modeled initially. Private interfaces
may deliberately limit setup/output/cleanup callbacks to the infallible fake
fixture boundary; this limitation must be explicit in code and tests. Do not
turn unsupported callback failures, panics or process loss into successful
commit/rollback claims. No real plugins are admitted through these interfaces.
Public exposure or additional fallibility requires a separate reviewed packet.

## Consequences

This produces testable execution code without requiring the entire compatibility
matrix to finish first. It is an internal Unit/Contract slice, not a public
plugin API or Differential result. A later T-0013 slice must compare selected
actual reference callbacks with independently executed Rust callbacks, with an
explicit projection/normalization boundary. The full parent gates stay open.
The output-task cap bounds admitted handle count, not total bytes or CPU time.
No new crate, parser, values, Arrow dependency, scheduler runtime, transport,
serialization, durable state, CLI loader or Java/JRuby host is authorized.

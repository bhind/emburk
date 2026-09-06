# ADR-0020: Bounded ordered format workers

- Status: Accepted and integrated through PR #120 (T-0024/S01)
- Date: 2026-09-06

Use at most eight scoped native format workers with admission window twice the
worker count. The window counts every admitted but not committed row, not just
queued jobs. A serial parser produces owned records; workers format; one
coordinator preserves order and owns codec output/publication. Result size and
record size have explicit caps. Queues and pending results share the window.

Core cancellation is a borrowed AtomicBool. The CLI admits the pinned ctrlc
platform adapter solely to set that flag on SIGINT. On cancellation or failure,
close channels and join all workers. Publication remains irreversible once its
hard link succeeds; a late cancellation must not remove output. Existing line
commands and generic plugin/lifecycle contracts are unchanged.

This is original native scheduling, not an Embulk concurrency/performance
claim. Validated checkpoint/resume is a subsequent independently accepted slice.

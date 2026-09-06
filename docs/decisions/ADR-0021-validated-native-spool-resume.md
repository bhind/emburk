# ADR-0021: Validated native spool resume

- Status: Accepted for implementation; executable acceptance pending
- Date: 2026-09-06
- Scope: T-0025/S02, private single-input configured Unix profile

## Decision

Persist the uncompressed formatted output in a private, bounded spool. Resume
validates exact configuration, raw source content and identity, destination,
profile version, checkpoint chain, spool identity and saved prefix. Replaying
the parser and formatter must reproduce the saved prefix byte-for-byte before
any uncheckpointed tail is truncated. A saved row count alone is insufficient.

Encoding restarts from the verified completed spool. This avoids depending on
undocumented partial compressed-stream state. Recovery is O(N) prefix replay,
not a fast-seek optimization. State and spool remain available after completion.

A persistent kernel file lock prevents cooperating concurrent writers without
stale PID heuristics. Explicitly created state directories are private (0700),
with regular private files (0600). Immutable generations are published only
after synchronization, through exclusive hard links and directory sync. Record
size, manifest size, spool size and generation count all have explicit caps.

Before linking the final output, persist its prepared device/inode, length and
content hash after synchronization. Recovery recognizes a linked output only
when that prepared identity and content match. An unrelated existing output is
always a conflict, including equal bytes with a different identity. Publication
continues to use ADR-0018's no-clobber boundary; published output is never rolled
back because of a later cleanup or checkpoint failure.

## Consequences and limits

The ordinary run path remains unchanged. Explicit stateful commands require
exactly one selected regular input. Checkpoint state is a versioned private
native format, not an Embulk resume-file format or generic plugin contract.

The spool adds disk usage and full-source hashing/replay adds I/O. State cleanup,
multi-source recovery, remote stores and compressed fast seek remain out of
scope. Same-UID trusted stable local filesystems are assumed; kernel locks do
not stop unrelated writers. No hardware power-loss, hostile path-race,
distributed transaction or exactly-once guarantee is accepted.

Source/API/dependency provenance, exact bounds, Demo and stop rules are in the
[mutation packet](../provenance/T-0025-validated-resume.md). Acceptance requires
actual interrupted transfers and recovery conflicts, not documentation alone.

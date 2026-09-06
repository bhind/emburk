# ADR-0018: No-clobber single-output publication

- Status: Accepted for T-0025/S01 implementation; acceptance pending
- Date: 2026-09-06

## Decision

For the bounded configured pipeline, replace direct final-file creation with
an exclusively owned 0600 sibling temporary file. Flush and sync file contents
before a same-filesystem hard link creates the final path without replacement.
Successful linking is the irreversible visibility boundary. Sync the parent
directory before removing the temporary link, then sync cleanup metadata.

Never remove a published destination to compensate for a later failure.
Distinguish not published, published with uncertain durability, and published
with confirmed directory-sync completion. Cleanup disposition is independent:
an error after durable publication does not mean the transfer can be replayed.
Report phase and retained paths, including failure to remove an owned temp.

This narrowly supersedes ADR-0017's partial final-file failure behavior for
configured CSV only. Older experimental line commands are unchanged. A later
resume design must use these states and validate identities; existence or a
record count alone cannot establish resumability.

## Constraints

Unix local filesystem, same-directory hard-link and directory-sync support.
Failure on unsupported operations is explicit. No overwrite fallback, generic
filesystem durability claim, hostile same-UID protection, multiple-output
atomic commit or Embulk transaction parity is implied. No new dependency or
upstream implementation reuse is involved. See T-0025-safe-publication.md.

# ADR-0016: Experimental stdout and null output adapters

Status: Accepted for T-0031/S02 under the owner's Rust continuation request.
Date: 2026-09-06.

Extend ADR-0015's experimental CLI composition with two additive subcommands:
transfer-lines-stdout INPUT and transfer-lines-null INPUT. Existing file command
and path interpretation remain unchanged. Both consume the existing std-I/O
core function without public plugin types or core changes.

The stdout adapter uses a locked writer, emits only normalized record bytes,
and routes diagnostics/counts to stderr. Null uses std::io::sink but still
validates every input record. A broken pipe fails with exit 1, not panic or
silent success. Output already consumed downstream cannot be rolled back.

These are native experimental policies, not Embulk plugin, validation-timing,
transaction or resume semantics. No new dependencies or external sources.

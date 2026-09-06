# ADR-0015: Experimental text File-to-File consumer

Status: Accepted for T-0031/S01 under the owner's explicit implementation request.
Date: 2026-09-06.

The owner requests a real minimal transfer, not another disconnected probe.
Permit the CLI to open files and call a doc-hidden, unstable std-I/O core function
which adapts UTF-8 lines to private Text records and uses ADR-0013's owned handoff.
Only sibling visibility expands for that handoff; record/plugin types stay private.
The empty lifecycle coordinator and schema/batch representation remain unchanged.

The separate `transfer-lines` command is explicitly experimental. It normalizes
LF/CRLF lines to LF, bounds physical records to 1 MiB including terminators,
creates output exclusively and reports possible partial output on error. It does
not accept YAML or claim Embulk run, transaction, encoding or plugin semantics.
This extends ADR-0013's no-consumer/no-public-function restriction only enough
for this real consumer; it does not supersede the remaining compatibility gates.

File opening stays in the CLI composition boundary; core sees only std I/O.
No provider dependency, new crate or external source is introduced. A raw file
copy would not exercise the record handoff; a complete YAML/CSV pipeline is
deferred rather than simulated. The full File-to-File roadmap gate stays open.

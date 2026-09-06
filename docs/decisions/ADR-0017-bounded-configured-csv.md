# ADR-0017: Bounded configured CSV consumer

- Status: Accepted; T-0032/S01 integrated through PR #116
- Date: 2026-09-06

## Context

The owner authorized the seven-stage executable pipeline. T-0022/S01 (#114)
verified the pinned saphyr-parser 0.0.11 event interface in an isolated
experiment. T-0014/S01 (#115) reproduced eight real bundled File/CSV cases in
primary and independent Java 17 execution with explicit single-task settings.

## Decision

Narrowly supersede ADR-0006's no-parser/no-CLI rule only for an actual private
configured CSV consumer. Admit the exact eight-package lock graph recorded in
T-0022/S01 to emburk-core, behind a private YAML adapter. No dependency upgrade
or public configuration/plugin API is implied. Existing scalar resolution stays
unchanged. Original parser-neutral nodes preserve ordered mappings, scalar
text/style/tag/anchor and alias observations before profile compilation.

Add `emburk run CONFIG` for the explicitly bounded profile in
T-0032-configured-csv.md. The CLI composes the core consumer, whose doc-hidden
std-path entry point is unstable. Configuration validates before output opens.
Read one CSV record at a time, admit it to the existing private LogicalRecord
and LogicalSchema, pass it through the owned handoff and format immediately.
Do not buffer a complete file in LogicalBatch or expose a generic plugin API.

Freeze selected reference semantics: single matched file, explicit UTF-8 CSV
settings and single executor task; long/string columns; unquoted empty -> null,
quoted empty -> empty string; malformed long rows skipped; missing input ->
success/no output; file name suffix 000.00.csv; empty file -> header only;
selected duplicate skip_header_lines uses its last occurrence. These are
behavioral rules exercised by the fixtures, not hardcoded fixture winners.
Unsupported options/constructs fail visibly before output; they are pending
compatibility work, not approved permanent deviations. Relative paths resolve
against process CWD as in the oracle, not against configuration-file location.

## Limits and consequences

Config: 64 KiB, 4096 events, depth 64. CSV: 1 MiB logical-record bytes and
maximum 256 columns. These native safety bounds are not verified Embulk limits.
No alias expansion, tags/coercions, Liquid/environment interpolation, unknown
options, timestamp/JSON/double/Boolean column support, multiple matched files,
page scattering, arbitrary diagnostics or generic YAML compatibility follows.
Original UTF-8 bytes remain distinguishable from lossy replacement.

File creation is exclusive, Unix mode 0600; an existing generated destination
is rejected. The reference sentinel case covers the prefix file only, not
replacement of an existing generated destination. Destination replacement,
publication, durability and resume require the later failure/publication gate.
Partial newly created output can remain on failure and must be reported.
No source reuse, redistribution or legal/security/FTO clearance is asserted.

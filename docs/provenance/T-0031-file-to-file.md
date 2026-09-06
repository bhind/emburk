# T-0031/S01 experimental line-record File-to-File

Issue: [#24](https://github.com/bhind/emburk/issues/24). State: In Progress.
Branch: `feat/t-0031-file-to-file`. Slice: 5 SP; parent remains incomplete.

## Authority

The owner explicitly requested a working minimal File-to-File path. PM selects
a clearly named experimental native command, not an Embulk-compatible run mode.
ADR-0015 defines this narrow extension of ADR-0013.

## Dependencies

Accepted T-0021/S06 owned handoff and T-0012/S08 Text records. No YAML/parser,
new dependency or external source admission. Parent T-0022/T-0023 dependencies
remain for full configuration and schema-aware plugins, not this fixed Text path.

## Mutation owner and allowlist

Rust implementer owns crates/emburk-core/src/{lib,record_handoff,text_transfer}.rs,
crates/emburk-cli/src/main.rs and crates/emburk-cli/tests/file_transfer.rs.
PM owns this packet, ADR-0015 and its index, STATUS, TODO, ROADMAP, ARCHITECTURE,
COMPATIBILITY, provenance index, docs/FILE_TRANSFER.md and daily log.
No parallel overlapping mutation; reviewers are read-only.

## Artifacts

Only original Rust/std-library code. Test fixtures are generated in unique
external temporary directories. No downloads, third-party code or credentials.

## Acceptance criteria

`emburk transfer-lines INPUT OUTPUT` streams UTF-8 lines as single Text-cell
records through the existing owned handoff. LF/CRLF input is normalized to LF;
an unterminated final record receives LF. Empty input produces empty output.
Limit each physical input record to 1 MiB including its terminator; fail without
unbounded line allocation. Output uses create_new: existing targets, including
same path and symlinks, are never overwritten. Input must be a regular file.
Read/UTF-8/size/write/flush failures exit nonzero. A new partial output may
remain on failure and must be reported explicitly; no rollback or atomicity claim.
Invalid arguments exit 2, transfer failures exit 1, success exits 0 and reports
the record count. Preserve no-argument development status and provide help.
Tests cover actual files, Unicode, CRLF, empty/final lines, existing/same target,
missing input, malformed UTF-8, oversize records, and injected write/flush errors.

## Demo Command

`cargo test --workspace && cargo fmt --all --check && cargo clippy --workspace --all-targets -- -D warnings`

CLI integration tests execute the actual built binary and compare real files.
Primary and independent reviewed-head execution required before merge.

## Evidence class

Unit/Contract and local file Integration, not Differential (Embulk).

## Stop rule

Stop before YAML, CSV, external dependencies, public plugin interfaces, lifecycle
integration, overwrite, deletion, transaction/recovery or compatibility exceptions.
Bounded implementation failures may be fixed with evidence retained.

## Non-claims

No Embulk CLI/config/encoding parity, generic plugin, schema/batch path,
parallelism, crash durability, atomic publication, resume or full MVP completion.
License/patent/FTO gaps remain unreviewed; no external source was adopted.

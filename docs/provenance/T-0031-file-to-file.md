# T-0031/S01 experimental line-record File-to-File

Issue: [#24](https://github.com/bhind/emburk/issues/24). Slice: Done, PR #110.
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
the record count. No-argument status describes experimental availability; help
describes the command.
Tests cover actual files, Unicode, CRLF, empty/final lines, existing/same target,
missing input, malformed UTF-8, oversize records, and injected write/flush errors.

## Demo Command

`cargo test --workspace && cargo fmt --all --check && cargo clippy --workspace --all-targets -- -D warnings`

CLI integration tests execute the actual built binary and compare real files.
Primary and independent reviewed-head execution required before merge.

## Evidence class

Final primary and independent acceptance passed at
`0edc76906bbdd854027a1c52ca481b5c254976a9`, both with retained numeric exit 0:
68 tests passed (61 core, seven actual-binary file integration), eight existing
external-reference tests intentionally ignored; format and strict Clippy passed.
Rust/Cargo 1.98.1, macOS arm64. Root inspected independent logs and exit digest.
Primary stdout/stderr SHA-256:
`6f5b4ae8d721e60057c63a02c2f9a6426c0956005b0d71c34e2445881eb976ed` /
`eaecf570b6a4563c6726dbb9e6e4dd0b15dd9eafa998e5493cda4066c615ed7d`.
Independent stdout/stderr SHA-256:
`2199327d249fcfb25b24430c030a543a98ba6d9cd0b2419027ffe935a4d7ce0a` /
`c163d0f30a4224a373b1ca0e7f07af214802a2370e68671b755e36f1376c68ad`.
Security review's output-permission finding was fixed with Unix creation mode
0600 and an actual-binary umask-000 regression; reviewer confirmed resolution.
Non-Unix ACL behavior is documented, not claimed owner-only. A separate manual
four-record Unicode/blank-line transfer passed byte comparison and mode 0600.
PR #110 integrated as `c5fb13ff13a593f08072609dc94c9a1bff0d163d` with a matching
head guard. S01 accepts 5 SP; parent #24 remains open in Backlog for broader
configuration/stdout/null/plugin contracts. No full MVP completion follows.

Unit/Contract and local file Integration, not Differential (Embulk).

## Stop rule

Stop before YAML, CSV, external dependencies, public plugin interfaces, lifecycle
integration, overwrite, deletion, transaction/recovery or compatibility exceptions.
Bounded implementation failures may be fixed with evidence retained.

## Non-claims

No Embulk CLI/config/encoding parity, generic plugin, schema/batch path,
parallelism, crash durability, atomic publication, resume or full MVP completion.
License/patent/FTO gaps remain unreviewed; no external source was adopted.

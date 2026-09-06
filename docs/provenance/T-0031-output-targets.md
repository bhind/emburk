# T-0031/S02 experimental stdout and null targets

Issue: [#24](https://github.com/bhind/emburk/issues/24). Slice: Done, PR #112.
Branch: `feat/t-0031-s02-output-targets`. Owner: Rust Core Implementer.
Slice estimate: 3 SP (implementation 1, verification 1, uncertainty 1).
Parent Current forecast 8 / Initial 5; accepted S01 5 SP is not re-awarded.

## Authority

The owner requested committed, pushed, merged continuation of Rust implementation.
PM selects stdout/null targets already named by T-0031, limited to experimental
Text records. New subcommands preserve all existing transfer-lines path meanings.

## Dependencies

S01 integrated in PR #110/#111. Use its std-I/O transfer function unchanged.
Full YAML/config/schema/plugin parent dependencies remain pending, not waived.

## Branch and allowlist

Implementer: crates/emburk-cli/src/main.rs, crates/emburk-cli/tests/file_transfer.rs.
PM: this packet, STATUS, TODO, ROADMAP, ARCHITECTURE, COMPATIBILITY,
docs/FILE_TRANSFER.md, provenance index, daily log, ADR-0016 and decision index.
Reviewers/testers read-only. No core, Cargo, dependency or prior ADR edits.

## Artifacts

Original Rust std-library adapters only; real binary and unique temp fixtures.
No download, remote model, external implementation or source reuse.

## Acceptance criteria

Add `transfer-lines-stdout INPUT` and `transfer-lines-null INPUT`. Both require
regular UTF-8 input, use existing bounded normalized Text handoff, and propagate
read/encoding/size/write/flush failures. Stdout command emits only record bytes
on stdout, locks stdout for transfer, reports counts on stderr. Null command uses
std::io::sink(), emits no data on stdout, reports count on stderr, and still
fully reads/validates input. Existing file command behavior stays unchanged.
No files are created by either new command. Success 0, operation error 1,
argument error 2. Broken pipe is a nonpanic error with exit 1; no successful
summary follows failure. Partial stdout can already have been consumed.
Tests run actual binary for Unicode/CRLF/blank/final/empty cases, invalid UTF-8,
oversize/missing/directory input, arguments, output isolation and a closed stdout
pipe (Unix). Preserve all S01 file/permissions tests. No global stdout redirection.

## Demo Command

`cargo test --workspace && cargo fmt --all --check && cargo clippy --workspace --all-targets -- -D warnings`

## Evidence class

Primary and independent final Demo passed at
`c5df504d52a987db98035d1958f19804fd26c61d` with retained numeric exit 0:
71 tests passed (61 core, 10 CLI integration), eight existing intentional
external-reference ignores; format and strict Clippy passed. Core unchanged.
Primary stdout/stderr SHA-256:
`91b908b9ddbe6b1d66dcc0be3b462235340e09b5d1988a21b17ebe68262a89ba` /
`c91f226098ab5e6f70bf39fd2aa60dee5d4180d6f918c20ae98941e21cda7422`.
Independent stdout/stderr SHA-256:
`58654631eba9ae1ca79eec8db6396ed1b8ec6846b63f60fe78dee406c6d982cb` /
`486c8b2e6b0c62248a09ab6cb29f8a959b6dc0a34f8ab952303b54bc66e8d301`.
Root verified independent retained exit and hashes. Rust/Cargo 1.98.1, macOS
arm64. The closed-reader test uses a UnixStream-backed stdout descriptor,
not a portability claim for all pipe implementations. PR #112 integrated as
`2ec236e89b48a1ae15c5a952e3830fa12ceee074` with matching-head guard.
S02 accepts 3 SP; S01/S02 total 8 SP. Parent #24 stays open in Backlog,
Current 8 / Initial 5, with broader configuration/plugin semantics outstanding.

Unit/Contract plus local process/file Integration. Independent final-head Demo
and guarded PR integration required before slice Done. No points before acceptance.

## Stop rule

Stop before YAML/CSV, new dependency, generic plugin API, core handoff changes,
overwrite, deletion, lifecycle, transaction/resume or Embulk compatibility policy.

## Non-claims

No Embulk stdout/null plugin parity, byte-preserving binary copy, atomic output,
recovery, cross-platform pipe assurance or complete T-0031/MVP acceptance.
No new third-party material; previous patent/FTO/release gaps remain unreviewed.

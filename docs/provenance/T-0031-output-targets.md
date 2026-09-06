# T-0031/S02 experimental stdout and null targets

Issue: [#24](https://github.com/bhind/emburk/issues/24). State: Review, PR #112.
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

Unit/Contract plus local process/file Integration. Independent final-head Demo
and guarded PR integration required before slice Done. No points before acceptance.

## Stop rule

Stop before YAML/CSV, new dependency, generic plugin API, core handoff changes,
overwrite, deletion, lifecycle, transaction/resume or Embulk compatibility policy.

## Non-claims

No Embulk stdout/null plugin parity, byte-preserving binary copy, atomic output,
recovery, cross-platform pipe assurance or complete T-0031/MVP acceptance.
No new third-party material; previous patent/FTO/release gaps remain unreviewed.

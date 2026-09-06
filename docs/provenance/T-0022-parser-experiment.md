# T-0022/S01 parser experiment packet

Issue: [#19](https://github.com/bhind/emburk/issues/19). State: Done (S01 only).
Branch: `feat/t-0022-configured-transfer`. Slice forecast: 5 SP.

## Authority

The owner authorized stages 1–7 in docs/IMPLEMENTATION_SEQUENCE.md. This packet
admits an isolated parser experiment only after its exact artifact graph passes
read-only provenance/security triage. Production adoption follows observed results.
On 2026-09-06 the owner explicitly approved building and executing the isolated
experiment, including the three dependency build scripts and procedural macro,
after the automated safety review required this additional approval.

## Dependencies

Integrated S13 original syntax observations and T-0031/S01/S02 real consumers.
ADR-0006 production parser restriction remains until a narrow adoption decision.

## Branch and allowlist

PM owns this packet, implementation sequence, STATUS, TODO, ROADMAP,
COMPATIBILITY, provenance index and daily log. PM additionally owns
tools/parser-experiment/Cargo.toml, Cargo.lock and .gitignore (isolated build output only). Rust Core Implementer owns
only tools/parser-experiment/src/main.rs (observer and original unit tests).
Reviewers are read-only. No production files are admitted.

## Artifacts

Candidate saphyr-parser 0.0.11, pinned in the isolated experiment lockfile.
Metadata-only resolution selected arraydeque 0.5.1, thiserror and thiserror-impl
2.0.20, proc-macro2 1.0.107, quote 1.0.47, syn 3.0.5 and unicode-ident 1.0.24.
Librarian review verified all eight archive hashes against the lockfile.
The owner admits execution only in this isolated local experiment.
yaml-rust2 0.12.0 is a documented fallback, not
automatically admitted. No upstream implementation copying or translation.

The candidate archive SHA-256 is
`ebfd783fcf1b3f6bafd557be0e1427ec54f826f513c3cdd749f9844484df2a13`.
Source: https://static.crates.io/crates/saphyr-parser/saphyr-parser-0.0.11.crate,
accessed 2026-09-06. Its package metadata declares MIT OR Apache-2.0;
artifact review found both license families and no NOTICE. This is a local
experiment, not binary redistribution or patent/freedom-to-operate clearance.

All packages offer MIT or Apache-2.0 licensing; unicode-ident additionally
requires Unicode-3.0. Archive license files were inspected. Compilation
executes build scripts in thiserror, proc-macro2 and quote and the thiserror-impl
procedural macro. This declared surface is admitted locally, not audited safe.
Narrow RustSec searches found no candidate advisory, not vulnerability clearance.
Full redistribution, transitive security and patent/FTO remain unreviewed.
No material artifact blocker was identified. Consulted API declarations in
parser.rs: Event, Parser, SpannedEventReceiver, new_from_str, load;
scanner.rs: ScalarStyle, Marker, Span. No implementation or tests are reused.

## Acceptance criteria

Original fixtures preserve ordered duplicate entries, scalar text/style/tag,
anchors/aliases and locations; malformed input must retain candidate error.
S13 invalid bytes stay intact and are classified separately from decoded text.
Compare observed structure, not a claim of identical error text or YAML conformance.
Do not encode fixture-specific winners in the syntax observer.

Review requires production-reader tests, exact ordered duplicate values and
anchor/alias correspondence, not merely event counts or any-error assertions.
The observer's input/event/depth caps are experiment bounds, not a complete
parser memory/time or denial-of-service guarantee. Candidate diagnostics and
tag display are retained as candidate data, not normalized into Embulk output.

## Demo Command

`cargo test --locked --manifest-path tools/parser-experiment/Cargo.toml && cargo fmt --manifest-path tools/parser-experiment/Cargo.toml -- --check && cargo clippy --locked --manifest-path tools/parser-experiment/Cargo.toml --all-targets -- -D warnings && cargo test --locked --workspace`

## Evidence class

Unit/Contract experiment, not native compatibility; acceptance pending.

## Stop rule

No dependency changes outside the reviewed exact lock, no production Cargo/CLI
changes before experiment review, and no legal/FTO clearance claims.

## Non-claims

No parser adoption, configuration runtime, full scalar/encoding policy or stages
2–7 completion from this preparatory document.

## Implemented experiment and pending acceptance

The original observer now uses a common bounded reader (64 KiB), strict UTF-8,
and pull events with 4096-event and depth-64 guards. It preserves duplicate
order, scalar style/tag, anchor/alias identifiers and spans in deterministic
candidate output. Malformed YAML retains preceding events and the parser error.
Six tests cover these paths, the six project-authored S13 shapes, exact source
size boundaries and actual file reading. Raw invalid UTF-8 is rejected, unlike
S13's selected replacement result; no lossy policy is adopted. Aliases remain
references and duplicates remain ordered entries, not resolved configuration.
Candidate recursion can precede a depth-256 observer guard, so the explicit
observer guard is 64. This is a measured design constraint, not an Embulk limit.
Implementer Demo passed six experiment tests and 71 workspace tests (eight
existing intentional ignores); primary/independent reviewed-revision acceptance
and integration remain required. No points are accepted yet.

## Final acceptance

PR #114 integrated as 8b4805101fd06821ebcaf2cdb23bb89e7c24b824 after primary
and independent acceptance at 964b4b5ef04472d2ffd175fce0353a7ef1d6e22b.
Six experiment and 71 workspace tests passed; eight existing intentional
external-oracle ignores remain. Format and strict Clippy passed. Independent
actual-binary checks confirmed ordered duplicates, tags, anchor/alias, malformed
partial stdout with error/exit 1, raw-invalid and oversized input errors, and
missing-argument exit 2. S01 accepts 5 SP; parent T-0022 remains open.

Retained primary logs: /private/tmp/t0022-s01-primary.6Ic9TH, stdout SHA-256
4cda785794201ea39cdafb9970ac347860f73b55e1803175e7a1c36d5ef98c30,
stderr 820730b203dee957ad1368dcbcbf30cb25c544a518a009f70189a6612af2d167.
Independent logs: /private/tmp/t0022-s01-final-independent.E2t4gJ, stdout
53596ce64c1e7c36004d152c48e9fefa9dd6645ef18aef6ebf0a03196a0d6fbc,
stderr 2acaa954ba5b57c8b6064d979f93467395921c364b6347f554adb31c44c09bde.
Numeric exit 0 was retained and inspected. Independent offline mode used the
same exact lock. Evidence remains Unit/Contract, not parser production adoption.

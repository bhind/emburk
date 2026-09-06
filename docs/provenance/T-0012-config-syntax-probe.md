# T-0012/S13 selected configuration-syntax observation

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: Ready; Stage A capture authorized
- Branch: `research/t-0012-s13-config-syntax`
- Owner: Compatibility Host Implementer; PM owns records and acceptance
- Priority: P0; slice 5 SP (implementation 2, uncertainty 1, verification 1,
  environment 1). Parent Current 55 / Initial 5 is unchanged.

## Authority

The owner explicitly approved S13 start, lifecycle transitions, verified merge
and completion records. This does not waive the acceptance or raw-review gates.

The owner requested continued chained work after S12 closeout. This packet
permits original reference instrumentation, not native parser adoption, public
configuration policy or upstream implementation reuse. Stage A captures raw
outcomes; the PM must review those bytes before Stage B expectations are added.

## Dependencies

S12 and its factual closeout are integrated through PR #105/#106 (`67f0786`,
`82581e3`). S01/S02 already cover selected presence and scalar conversions;
S12 covers selected `in`/`out` missing/null envelopes. None establishes YAML
syntax behavior. ADR-0006's private in-memory resolver remains unchanged.

## Branch and allowlist

One implementer owns exactly three new source/test paths:

- `tools/t0012-config-syntax-probe/src/T0012ConfigSyntaxInputPlugin.java`
- `tools/t0012-config-syntax-probe/run.sh`
- `tests/t0012_config_syntax_probe_test.sh`

PM owns this packet, provenance index, STATUS, TODO, ROADMAP, COMPATIBILITY,
and daily log. Reviewers/testers are read-only. No existing probe, Rust, CLI,
Cargo/dependency, architecture, ADR, or other task changes are permitted.

## Artifacts

Reuse the admitted unmodified 0.11.5 executable and local Maven test-plugin
route from S12, plus bundled null output. All runtime/generated artifacts,
exact input bytes and raw output stay in unique external temporary storage.
No upstream build, source download, external plugin, or redistribution occurs.
Original repository S12 instrumentation may be adapted with its origin recorded;
that is not permission to copy upstream implementation or upstream test vectors.

## Acceptance criteria

Exactly six original configurations share S12's local Maven input structure
(plugin name `t0012_syntax`) and output `type: "null"`. Each document ends in LF.

| Case | Exact variation |
| --- | --- |
| control | `in.field: syntax-value` (plain String token) |
| quoted | Same field, double-quoted `"syntax-value"` |
| duplicate-field | Two consecutive `field` lines in `in`: `first-value`, then `second-value` |
| malformed-flow | Field line `  field: [unterminated` |
| scalar-alias | Root `seed: &v syntax-value` before `in`; field line `  field: *v` |
| invalid-utf8 | Field line bytes `b'  field: bad-\xff-value\n'` |

The known-good control is necessary to distinguish global initialization failure
from a selected observation. Do not preselect success, rejection, winning
duplicate value, alias behavior, replacement characters, or parser cause for
the other five cases. The plugin observes one required annotated String only;
it preserves null/empty exception messages and rethrows original exceptions.

Stage A must retain six exact byte files (never decode/re-encode invalid UTF-8),
separate stdout/stderr/numeric process exits, per-invocation UUIDs, independent
plugin-context UUIDs and context-local contiguous events. Preserve zero-event
files and unexpected context shapes; do not synthesize missing callbacks.
Use S12's callback vocabulary and safe base64 payloads. Capture source revision
and all three committed source hashes, runtime/plugin/toolchain identity and
LICENSE/NOTICE hashes. Validate bounded framing and control success only.
Expose evidence and numeric capture exit even on setup failures. All path
ancestors must be canonical, external and nonsymlinked before directory creation.

Stage A accepts only explicit `--capture`; the final Demo must clearly remain
unavailable until PM raw review. After raw review, Stage B may add full fresh
capture/strict validation and existing-evidence validate-only (no Java/network,
no writes, no fresh-success marker). Freeze actual byte/event/exit/diagnostic
vectors before implementing expectations. Runtime paths, timestamps and UUIDs
must not be erased by guessed normalization; any required normalization needs
demonstrated nondeterminism and PM review.

Stage B controls must use fresh copies and repair dependent hashes to exercise
exact semantic diagnostics: input bytes, fixture set, events/order/value/context,
invocation, exit, diagnostics, source and integrity. Include positive
validate-only, external-path/symlink rejection, corrupt-artifact and unavailable-
artifact controls. Preserve full logs and exact exits for each. A download error
cannot pass a semantic corruption control. Exact control count follows raw review.

## Demo Command

`bash tests/t0012_config_syntax_probe_test.sh && bash tests/t0012_config_envelope_probe_test.sh`

This is final Stage B acceptance, not Stage A. S12 remains unchanged and its
wrapper verifies the preceding envelope gate. No Rust changes or redundant
workspace suites are required. Primary and independent final-head Demo plus
record reconciliation and PR integration are required for completion/points.

## Evidence class

Reference Observation / Integration for the selected runtime fixtures;
Unit/Contract for validator controls. No native Differential claim follows.

## Provenance and admission

Local references: S12 original Java/runner/wrapper at `67f0786`, and the S01,
S02 and S12 provenance records. Use only their already-compiled public Config,
Task, ConfigSource.loadConfig, InputPlugin, Exec, empty Schema and PageOutput
signatures. Core pin `c5ac2d471edac465b45088669d376a7e2a525f8f`, public
configuration locators under `embulk-core/src/main/java/org/embulk/config/`;
SPI pin `576e98033a14ba8ac994ed581d3c9d8fcdda2749`, under
`src/main/java/org/embulk/spi/`. No new API or external source is needed.

Artifact: https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar
SHA-256 `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`.
Embedded LICENSE `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`;
NOTICE `27f0e45afdf10e406ee8bf478bfce38279e9087338a7981942a4a2762bcd5be8`.
The Apache-2.0 source classification is not whole-distribution legal clearance.
Transitive SBOM, redistribution, patents, standards, trademark, jurisdiction
and freedom to operate remain unreviewed. No legal advice or clearance is given.
Read-only Librarian reviewed local records and original code on 2026-09-06:
no new source/API admission is needed; syntax gaps do not duplicate S01/S02/S12.
PM retains the six fixtures above. The broken `[` fixture is a flow sequence,
not a mapping. The invalid byte is surrounded by ASCII to expose replacement.
No mapping-specific, parser-adoption or legal-clearance claim follows.

## Stop rule

Stop for PM raw review before Stage B, and before new fixtures/signatures,
artifacts, parser/dependency/native policy, upstream implementation inspection,
redistribution, or material IP/security uncertainty. Ordinary bounded harness
failures may be corrected while retaining failed evidence.

## Non-claims

No generic YAML conformance, duplicate-key/alias/encoding/error policy, native
parser, CLI, plugin, file transfer, lifecycle, File-to-File, or parent completion.
An observed outcome does not automatically authorize a native behavior.

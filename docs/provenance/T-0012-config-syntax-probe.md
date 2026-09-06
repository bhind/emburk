# T-0012/S13 selected configuration-syntax observation

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: In Progress; Stage A reviewed, Stage B validation authorized
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

## Stage A evidence and Stage B decision

Primary and independent `--capture` both exited 0 at
`3c705007673de22db1a94650471d6cb4ce9a300c`. PM verified the retained independent
exit and compared exact input bytes, stderr bytes and all projected events.
Six inputs, 60 events and outcomes agree; no diagnostic normalization is needed.
Raw timestamps, paths and UUIDs remain retained, not semantic comparisons.

| Case | Exit / events | Observed String or boundary |
| --- | --- | --- |
| control | 0 / 12 | `syntax-value` |
| quoted | 0 / 12 | `syntax-value` |
| duplicate-field | 0 / 12 | `second-value` |
| malformed-flow | 1 / 0 | No callback; flow-sequence parsing diagnostic |
| scalar-alias | 0 / 12 | `syntax-value` |
| invalid-utf8 | 0 / 12 | `bad-\uFFFD-value`; source still contains byte `ff` |

Each successful case has one unique context and sequence 1–12:
transaction-entry, config-load-entry, config-value(the value above),
control-entry, run-entry, finish-entry, finish-return, run-return,
control-return, transaction-return, cleanup-entry, cleanup-return.
All successful stderr files are empty. The malformed-flow stderr is 2725 bytes,
SHA-256 `480dfb5bc6be8e8e567869545710d73db2ce87b80882b372e735021606e3c950`.
Its selected diagnostic identifies a flow sequence at line 7/column 10 and
the unexpected colon at line 8/column 4; stack details are pinned observations,
not native errors or a claim about internal parser implementation.

| Exact input bytes | SHA-256 |
| --- | --- |
| control | `b6529ab10a9be386b12e6e26c75344ee4903e85464df1863e4e638398e4bee14` |
| quoted | `ad50b4ddf3864a4cebc2c88ca562e5fb3a94105f5d30bda41be9ab14c87ba2c5` |
| duplicate-field | `7a8659ae16b67e5a909c906477f511d6aa319c79d8c9ec0aad9fa661d398f257` |
| malformed-flow | `6f2b75feeb5f1df992e3f2472b7f1df53752fe4ee6bb3d9781cde2dfa3767cea` |
| scalar-alias | `f76fb799c7228956d07f25d340bb5325176c060073cc88f726a253e1dba9c4bf` |
| invalid-utf8 | `6856e72333e988149d1fe972c6c7790bf01893790bccaf86f7b496b0e9d1f056` |

Frozen Java SHA-256 `5f29ac5bef4ffa52dead57f7bf13b6f40dfd444384bbb7d775f40998d39859b3`;
Stage A runner `0561850fd53275a31231c6913fad55ffe977ffbba8a4600633acddbfd6fc11fe`;
wrapper `3be9134aadf5f0b87fc9a1605fdf8bfd21d46e484a68c68c687db135f5ee8a88`.
Primary outer stdout/stderr SHA-256:
`8061b00cbce50bff60cb466c5982d0933dc27148aa3b39bac0afde6b8ea858af` /
`677b102eba712e358838a62f226b5c0f64f5790f8ec0885bac39c32117fd4ce4`.
Independent hashes:
`e9ff63af1269851cb37eaf6f5ca516c0ad9e6c839ce6fab224ac74c5297cbe3c` /
`d3ee6883523a248f359167829f86ce7c1e29b78785ec718bdee9e68d84f485f5`.
Runtime pins matched. Raw evidence stays external/local-only. No full Demo,
Stage B acceptance, points, or native policy follows from capture.

PM authorizes Stage B only in the runner/wrapper, preserving Java semantics.
Keep explicit capture-only; add default full plus explicit validate-only with
no writes/runtime/network/full marker. Bind the exact inputs above, six unique
invocations, five unique contexts, per-case values, fixed exits/stderr, historical
three-source identities, before/after hashes, all files and integrity metadata.
Preserve source `ff` distinctly from result UTF-8 `ef bf bd`. Hashes are integrity
aids, not malicious-local-process attestation or security isolation.

Adapt S12's 16 raw-copy controls and add three selected controls: duplicate
result changed to first-value (event-vector), invalid source byte replaced with
UTF-8 U+FFFD (input-vector), and alias replaced with its plain value
(input-vector). Repair dependent case/integrity hashes for semantic mutations;
the integrity control deliberately does not. Add positive validate-only, one
symlink-path and two exact artifact-failure controls. Final Demo and independent
reproduction are still required before verified merge and completion.

## Evidence class

## Stage B implementation evidence

Source freeze `d95f2a9a39f921458c9b7af0b434113908bd1f66` passed the fresh
S13 wrapper with retained and process exit 0: six cases/60 events, 19 raw-copy
controls, one symlink-path control and two artifact controls. Java is unchanged.
Runner SHA-256 `2e5a8ad66820a065b36fc17a06a253843ddef5f5261e98fa1a16a72144123f57`;
wrapper `d740b9fe4f88bcc47fc800e1c2b66556fc4dcbadfd8d230bc422706d13223aaa`.
Outer stdout/stderr hashes are
`7c0bc07b6367e51fd00c2b6716ae564369dc05ea028e3056f49c1ae16fd239f4` /
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
The initial wrapper run at `5ae628f` exited 1 during missing-file control
preparation, not reference execution. Its logs remain retained; `d95f2a9`
preserves the missing entry's old digest so the validator tests file inventory.
Root review restored framing checks lost in the first draft. Independent
read-only source review found no remaining blocker; an event-value finding
was retracted after checking that the mutation receives complete event lines.
Final-head exact Demo and independent reproduction remain required. No points
are awarded by this implementation evidence.

## Evidence classification

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

# T-0012/S12 selected configuration-envelope observation

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: In Progress; Stage A capture authorized, raw review required before Stage B
- Branch: `research/t-0012-s12-config-envelope`
- Owner: Compatibility Host Implementer; Project Manager owns records
- Priority: P0; slice 5 SP (implementation 2, uncertainty 1, verification 1,
  environment 1). Parent Current 55 / Initial 5 remains unchanged.

## Authority

The owner authorized chained successor work. This slice observes a pinned
runtime with an original local test plugin; it does not choose native parser,
configuration validation, defaults, public errors, or plugin-loading policy.
The Project Manager must review the Stage A raw observations before enabling
strict expected-vector validation. No result is preselected from fixture names.

## Dependencies

T-0011 and T-0012/S01/S02 admitted the pinned executable route, configuration
annotations and input-plugin public signatures. T-0023/S02 must be integrated
before this serial lane is activated. ADR-0006 remains unchanged: the native
resolver is private and receives in-memory scalar inputs, not YAML.

S01's nine presence/default String cases and S02's nine Boolean/Long conversion
cases are already observed. They are not repeated or generalized here. The
missing question is which selected top-level envelopes reach the input
transaction and preserve a known field, not how scalar conversion works.

## Branch and allowlist

One implementer owns only these new files:

- `tools/t0012-config-envelope-probe/src/T0012ConfigEnvelopeInputPlugin.java`
- `tools/t0012-config-envelope-probe/run.sh`
- `tests/t0012_config_envelope_probe_test.sh`

The Project Manager separately owns this provenance packet and its index,
STATUS, TODO, ROADMAP, COMPATIBILITY, and the daily log. Testers/reviewers are
read-only. Do not modify existing probes, Rust, dependencies, architecture,
ADRs, CLI, or other tasks.

## Artifacts

Use only the same official unmodified 0.11.5 executable, an independently
authored local-only Maven-style input test plugin, and bundled null output.
Every runtime invocation uses a fresh isolated EMBULK_HOME. Downloads, generated
JARs, original YAML inputs, raw stdout/stderr, exits, metadata, and controls
remain in unique external temporary directories. No upstream build, external
product plugin, packaged runtime, or artifact redistribution is authorized.

## Acceptance criteria

Observe exactly seven independently authored cases:

| Case | Change from control |
| --- | --- |
| `control` | Local Maven input with required String `field: envelope-value`; bundled null output |
| `in-absent` | Omit the complete `in` mapping |
| `in-null` | Replace `in` with explicit null |
| `out-absent` | Omit the complete `out` mapping |
| `out-null` | Replace `out` with explicit null |
| `unknown-root` | Add unconsumed root mapping `extra: {nested: envelope-extra}` |
| `unknown-input` | Add that unconsumed mapping inside `in` |

Do not add an unknown output key because the selected test does not instrument
the bundled output's own configuration boundary. Unknown-key success would
mean only that this fixture still reaches the observed callbacks; it cannot
prove a global unknown-key acceptance policy or nested-field contract.

Stage A captures complete separate process logs and numeric exits, exact YAML,
source revision/hashes, artifact/toolchain identities, and ordered structured
callback events with per-process identity. The original plugin records entry,
required String loading result or raw exception class/message, control/run,
and cleanup markers without inventing events when initialization fails. Missing
callback events remain an observed boundary, not a diagnosis of parser cause.
Null and empty exception messages remain distinct. The control must execute
successfully so a global setup/linkage failure cannot become seven results.

Read-only implementer feasibility review confirmed the existing signatures on
2026-09-06. Before capture, the runner assigns a fresh random UUID to each case
and passes it to that process; each structured event carries case, invocation
UUID, a generated plugin-context UUID and a context-local contiguous sequence.
Preserve multiple contexts if observed (S11 demonstrated separate cleanup
contexts); never infer a process/class-loader boundary from context identity.
Each case has separate raw event/stdout/stderr files,
including an empty event file if initialization never invokes the plugin.
The event vocabulary is transaction-entry, config-load-entry, config-value or
config-exception, control-entry, run-entry, finish-entry, finish-return,
run-return, control-return, transaction-return, cleanup-entry, cleanup-return,
and callback-exception. Payload text is canonical UTF-8 base64 with a distinct
null marker. Stage A checks framing and known control success, not speculative
event order or exit status for the other six cases. Unknown callback/event
shapes stop raw review rather than being discarded or normalized.
Record each exact YAML and all three source hashes at the capture revision.
Capture each process exit explicitly even when nonzero. Check every temporary
path ancestor against symlinks and repository containment. No shared append
file or speculative cause attribution is permitted.

Stage A cannot emit a full acceptance marker. After complete primary raw review,
the PM records exact expected vectors and permits Stage B. Stage B implements
fresh full and existing-evidence validate-only modes. Strict validation binds
case inputs, unique case/event order, process results, historical source hashes,
and artifact identity to the reviewed vectors. Validate-only never runs Java
or emits a fresh-runtime marker. Evidence paths reject symlink substitution;
reads are bounded and writes never overwrite unrelated evidence.

The full wrapper runs fresh capture and exact validation, positive validate-only,
diagnostic-specific repaired-copy rejection controls for input, event, result,
source and hash corruption, plus corrupt-artifact and unavailable-artifact
controls. Each control retains complete logs and numeric exits. Unrelated
download failures cannot count as successful corruption rejection. Final-head
primary and independent acceptance is required before integration and Done.

## Demo Command

`bash tests/t0012_config_envelope_probe_test.sh && bash tests/t0012_config_presence_probe_test.sh && bash tests/t0012_config_conversion_probe_test.sh`

This is the final Stage B Demo. Stage A must stop at raw review first. Bash
syntax, Java compilation, and diff checks also apply. No Rust changed, so a
second broad workspace/differential suite is not required for this observation.

## Evidence class

Reference Observation / Integration for the exact seven runtime fixtures;
Unit/Contract for the validator. No native Differential or supported product
configuration claim follows.

## Provenance and admission

Read-only Librarian-role review by the primary agent on 2026-09-06 examined
the local S01/S02 provenance and original config-presence Java/runner/tests,
ADR-0006, and actual CLI. The current CLI only prints development status.
No new external source, implementation, API signature, or dependency was read.

Use only public `Config`, `Task`, `ConfigSource.loadConfig`, `InputPlugin`,
`Exec.newConfigDiff/newTaskSource/newTaskReport`, empty `Schema.builder`, and
`PageOutput.finish` signatures already compiled by S01/S02. Source locators:
core commit `c5ac2d471edac465b45088669d376a7e2a525f8f`,
`embulk-core/src/main/java/org/embulk/config/`; SPI commit
`576e98033a14ba8ac994ed581d3c9d8fcdda2749`, `src/main/java/org/embulk/spi/`.
The observed runtime route is documented in
`docs/provenance/T-0012-config-presence-probe.md` and
`docs/provenance/T-0012-config-conversion-probe.md`.

Artifact URL: https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar
SHA-256: `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`.
Embedded LICENSE SHA-256:
`cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`.
Embedded NOTICE SHA-256:
`27f0e45afdf10e406ee8bf478bfce38279e9087338a7981942a4a2762bcd5be8`.
Source classification is Apache-2.0, not legal clearance for the complete
distribution. No upstream implementation, tests, or vectors are copied or
translated. Original repository harness patterns may be reused with provenance.
Transitive SBOM, redistribution, patents, standards, trademark, jurisdiction,
and freedom to operate remain unreviewed. This is not legal advice.

## Stop rule

Return to PM before a new signature/artifact, fixture expansion, parser/native
policy, upstream implementation inspection, distribution, or material IP or
security uncertainty. Stage A requires raw review before expectations or full
validation. Routine retrieval/compilation failures may be repaired in scope,
with unsuccessful evidence retained.

## Non-claims

No generic YAML grammar, nested typed configuration, unknown-key/default/error
policy, native parser, CLI/job execution, product plugin, file I/O, data transfer,
lifecycle compatibility, File-to-File milestone, or parent completion is claimed.

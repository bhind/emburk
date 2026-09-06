# T-0012/S12 selected configuration-envelope observation

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: Done through PR #105 (`67f0786422a152bed3ef6b78b253e3372a13b7ec`)
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

## Reviewed Stage A and Stage B decision

Primary and independent Stage A capture passed at
`73362497197713136025cd14656ed268bc8cc457`, each with retained and tool-reported
exit 0. The PM compared complete raw output, semantic vectors, exact YAML and
stderr across both captures. YAML and stderr bytes agree; UUIDs, timestamps,
temporary paths and runtime progress logs are retained but not normalized into
configuration semantics. No source implementation was consulted.

| Case | Exit / events | Observed boundary |
| --- | --- | --- |
| control | 0 / 12 | Required String returns `envelope-value`; run/finish/cleanup return |
| unknown-root | 0 / 12 | Same selected trace; no generic unknown-key policy follows |
| unknown-input | 0 / 12 | Same selected trace; nested value was unconsumed, not typed |
| in-absent | 1 / 0 | No input callback; ConfigException reports required `in` absent |
| out-absent | 1 / 0 | No input callback; ConfigException reports required `out` absent |
| in-null | 1 / 0 | No input callback; ConfigException reports forbidden task-field null |
| out-null | 1 / 0 | Same selected null diagnostic; no inferred parser cause |

Each successful case has one context and sequence 1 through 12:
transaction-entry, config-load-entry, config-value(`envelope-value`),
control-entry, run-entry, finish-entry, finish-return, run-return,
control-return, transaction-return, cleanup-entry, cleanup-return.
Each failure has an empty event file and exact observed stderr. These are
environment-specific observations, not native diagnostics or public policy.

| Exact input | SHA-256 |
| --- | --- |
| control.yml | `7c9ada0e4980778337fd8f6bd2cbbecbd5c272639c7ed4769578e379457e352a` |
| in-absent.yml | `8a78b8bbe035efdad6a3720ae8e876230eafa40c7e81b58e79e0535665da2537` |
| in-null.yml | `3aa644cca147381a85b544ad83268f961fe4f1f1b05b0cb083bc0d252138242e` |
| out-absent.yml | `0a38b49f8dbb4ed56c3646051b9b603b3eaef245c90cd345a071144674fc3b45` |
| out-null.yml | `0f15af301b5f5d35a4eb11b473e3fb0a9b3635af3e9c0b9161ac07ff9bed50e1` |
| unknown-input.yml | `bf5850e7e14376e6448af61b0f471cf2ba00e2c6b47d4e8554c27ae21b46defa` |
| unknown-root.yml | `6b57e54900c5284402ee433ad44f47ee875a10c1c17f12f49f7a1b4ecdda8ffb` |

Failure stderr SHA-256: in-absent
`50bb1f14e8c2c4f2febd4654047759d0ea536dddd7657393ee639634c29f777e`;
out-absent `2c65acdc27b8590701eb8c8c94f4e266b1b4f80115f88fa922b1d652d4861e85`;
both null cases `2534ee6510f7d3b8c233d783c2b36b60ad09e235d58b0e04b1242094df4c7289`.
Successful stderr is empty. The existing fixture Java SHA-256 is frozen at
`fda93051323c91e42d504f3e915b1c3421c32ecb5dacdfcc6116a91d5c9593c6`;
Stage A runner `7cd35071f4fc9e21bd7c0d414fa832793f5687d86d12a61aa7459013cb01ed7d`,
wrapper `3f44348fea348c642bf23276d1a77308c3939dc08d5cc51324c36ea465d1f252`.

Primary outer stdout/stderr hashes:
`e3ddc0f19507919e4ab4d78e6da3fb6160855b060dff6138902639d2015c1ae0` /
`d1690dfa759d1680549cc72bc7128f286ffa20008799b48298c651da51088af9`.
Tester hashes:
`09c9d7a0759a1fa803d296eae091d34cce6dbd3ee324c3047ba354771b1371f0` /
`0c17cc30714a65b44eead87c02b2ce67a5e4b19b98f9ca04cb554ec94681d67e`.
Initial uncommitted implementer captures and retrieval failures remain
diagnostic-only. Raw artifacts remain external and local-only.

PM now authorizes Stage B within the same runner/wrapper allowlist: preserve
capture-only, add default full capture plus strict validation, and explicit
existing-evidence validate-only with no runtime execution or full marker.
The Java fixture semantics stay frozen. Validate exact seven inputs, 36 events,
three unique successful contexts, seven unique invocations, fixed exit/stderr
vectors, source identities, artifact hashes and the complete evidence manifest.
Source hashes are integrity/provenance aids, not hostile-local-process attestation.
No Stage A result is final acceptance.

Use fresh repaired copies for input, missing/extra case, event removal/order/
payload/context, invocation, exit, stderr, source and integrity corruption;
retain exact rejection diagnostics. Repair integrity after semantic mutations,
so failures prove semantic checks rather than only a stale checksum. Add
positive validate-only, symlink-path rejection, and corrupt/unavailable-runtime
controls. Unrelated retrieval failures cannot pass a corruption control.
Run the final Demo at a reviewed head before integration and points.

## Frozen implementation review

PR #105 freezes source at `afd7fb8d12e96ccf7d977e156f25fbb693cc63d5`.
Java retains the Stage A hash above; runner SHA-256 is
`1cd82d6d4c46627142791f140716fb4007ae011c759635e8d6e5e4139e93090b`;
wrapper is `fae6ae6345189e9c2bd53fdee8beb3a27fbea52ba878238ced64f179fd1e2f2f`.
The primary full wrapper at preceding `3ae96f9` passed seven observations,
positive validate-only, 16 raw-copy controls (15 repair dependent hashes; the
integrity control intentionally does not), one symlink-path control and two
artifact controls. Outer stdout SHA-256:
`491385ec41c1864218bf8ba001c6505c93580cad899c1ff8a3b0e7e215d5be71`;
stderr is empty; numeric exit 0. The frozen follow-up changes only the final
control-count wording, not behavior. Read-only source review found no concrete
blocker; Bash syntax and diff checks passed. Subsequent final-head evidence
and integration are recorded below.

## Final acceptance and integration

Primary and independent exact Demo both passed at
`9df0d5c1a37c2aa5719fd222f3886dc2f4a856e5`, each with tool-reported exit 0
and retained exit files. PM verified the Tester exit and hashes before merge.
Frozen source hashes above remained unchanged.

| Run | stdout SHA-256 | stderr SHA-256 |
| --- | --- | --- |
| Primary | `de236e31f2b119c8c38b5924b9d969d7aea1113ee2dce2938bdf50a3d120b405` | `2867b8b5eada947aa21b51dac2e61c10c7fc61ad8201935224e8310356a09995` |
| Tester | `78562b100a82ce9a0396fa16f610675f9aab492691e3a505a17e5fc0918f1477` | `019ff888debcc450cd71d808e5a45a8d31d5ed0759733fad076e0e551e427fab` |

Both runs prove seven selected envelopes/36 events, positive validate-only,
16 raw-copy controls, one path control, two artifact controls, and unchanged
nine-case S01 presence and nine-case S02 conversion regressions. Environment:
macOS arm64, Temurin 17.0.20, Python 3.14.6, Bash 3.2.57. Logs and runtime
artifacts remain external/local-only. No Rust changed; no redundant workspace
suite was required by the packet.

PR #105 integrated as `67f0786422a152bed3ef6b78b253e3372a13b7ec`. The owner
explicitly approved this completion-record transition after the execution gate
requested confirmation. S12 accepts 5 SP; known S03–S12 acceptance totals 40 SP.
Parent #15 remains open, Current 55 / Initial 5 unchanged. All non-claims remain.

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

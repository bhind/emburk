# T-0012/S01 configuration-presence reference probe

- Tracking issue: [#15](https://github.com/bhind/emburk/issues/15)
- Parent work item: `T-0012`; T-0012/S01 is an independently acceptable
  reference-observation slice, not a replacement for the parent differential gate.
- Branch: `research/t-0012-config-presence`
- Lifecycle owner: Project Manager
- Mutation owner: Compatibility Host Implementer
- Required reviewer: Librarian (Vreji), reviewed 2026-09-05; Project Manager
  independently reproduced the Demo Command at `1f2e737` on 2026-09-05
- Access date: 2026-09-05
- State: `Done` as a slice; integrated through PR #61 as
  `e2532e245bff8114d075c8f35e9871d889d717a3`. The parent T-0012 remains open.

## Outcome and boundary

Produce a runnable, independently authored local probe that records how the
pinned Embulk configuration API responds to absent, explicitly null, and
present fields. It is limited to a required `String`, a defaulted `String`, and
an `Optional<String>` configuration field. The probe records a raw success
value or the raw exception class and message for every case.

The probe does not add Rust configuration code, define Emburk configuration,
schema, or value semantics, or compare an Emburk result with Embulk. It loads
only an independently authored, generated, local test plugin plus the
executable's bundled null output; neither is an admitted Emburk plugin. Its
successful execution is **Reference Observation / Integration**
evidence only. It cannot satisfy T-0012's `Differential (Embulk)` evidence
gate until an independently implemented Emburk comparator exists.

## Independently authored probe plan

The implementation packet may add only:

- `tools/t0012-config-presence/` for the runner, a small Java probe, and its
  resolution metadata;
- `tests/t0012_config_presence_probe_test.sh` for runner-structure checks.

It must not edit Rust production code, Cargo manifests, canonical project
records, or copy/adapt upstream source or tests. It must run with a temporary
directory outside the repository and leave all downloaded artifacts and raw
outputs untracked.

The required Demo Command is `tests/t0012_config_presence_probe_test.sh`.
It must invoke the runtime probe; an offline structural check is a separate
implementation check and cannot satisfy this Demo Command or accept S01. The
runner downloads the official unmodified v0.11.5 release asset
`https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar`
into a per-run external temporary directory, records its resolved URL, SHA-256,
manifest version, Java/OS identity, and local probe-JAR SHA-256, then invokes
the downloaded filename through `java -jar` with an isolated `EMBULK_HOME`.
The independently authored probe is a test-only Maven-style input plugin and
is not a distributed or admitted Emburk plugin. The executable's normal CLI
initialization loads its bundled dependencies before plugin dispatch. Temporary
evidence is not committed; public records omit credentials, tokens, personal
paths, and raw classpaths. GitHub did not expose a release digest during route
selection, so the recorded local digest is identity evidence, not a
published-checksum verification.

The matrix preserves distinctions rather than normalizing them:

| Field declaration | Input state | Recorded outcome |
| --- | --- | --- |
| required `String` | absent, explicit null, value | raw value, or exception class and message |
| `String` with `@ConfigDefault("\"fallback\"")` | absent, explicit null, value | raw value, or exception class and message |
| `Optional<String>` with `@ConfigDefault("null")` | absent, explicit null, value | empty/present value, or exception class and message |

The runner must fail clearly if artifacts cannot be resolved, their identity
cannot be recorded, compilation fails, or the Java 17 runtime cannot execute
the probe. It must not silently substitute a different Embulk version or
discard error messages. It must distinguish a null exception message from an
empty message, validate each unique declaration/input-state matrix key, and
fail setup or linkage errors rather than recasting them as case results.

## Reference locators and reuse decision

| Reference | Immutable identity and locator | Observation use | Reuse decision |
| --- | --- | --- | --- |
| Embulk core | `v0.11.5`, commit `c5ac2d471edac465b45088669d376a7e2a525f8f`; `embulk-core/src/main/java/org/embulk/config/Config.java`, `ConfigDefault.java`, `ConfigLoader.java`, and `ModelManager.java` | Locate public configuration annotations and source creation/loading entry points | No source text, implementation, or test is reused. |
| Embulk core test-only context | Same commit; `embulk-deps/src/test/java/org/embulk/deps/config/TestConfigSource.java` | Identifies that optional/default presence cases deserve independent observation | No test text, vectors, fixtures, or expected outputs are reused. |
| Embulk SPI | `v0.11`, commit `576e98033a14ba8ac994ed581d3c9d8fcdda2749` | Resolve exact separately-versioned API signatures during compilation | Interface reference only; no source text reused. |
| Executable CLI and plugin route | Core commit `c5ac…`; `org/embulk/cli/Main.java`, `plugin/maven/MavenPluginSource.java`, `MavenPluginRegistry.java`, and `spi/InputPlugin.java` | Locate documented CLI initialization and local Maven-style test-plugin loading route | Public-interface observation only; no source text or implementation copied. |

The core and SPI source licenses are recorded as Apache-2.0 in the T-0011
inventory. The executable distribution's NOTICE and dependency inventory, all
transitive runtime licenses, artifact redistribution, patent/standards and
freedom-to-operate questions remain unreviewed. This slice downloads only a
local test runtime and must not commit, package, or redistribute it.

The executable route corresponds to pinned tag commit
`c5ac2d471edac465b45088669d376a7e2a525f8f`. `LICENSE` and
`NOTICE-executable` are required executable provenance locators. The bundled
third-party obligations, local-plugin compatibility, redistribution, security,
patent/standards, and freedom-to-operate questions remain unreviewed. No
`embulk-deps` artifact is admitted by this route.

## Acceptance and stop rule

Accept the slice for review only if the structural test passes **and** the
required Demo Command proves it used the pinned coordinate and records complete
raw results for all nine cases. A diagnostic artifact-resolution or runtime
failure must be retained with its identity/environment record, but does not
pass the Demo Command or accept S01. A successful upstream-only run is not a
compatibility result. Report ordinary retrieval or setup failures with their
exact boundary and continue once corrected; stop scope expansion only for a
material license/NOTICE/redistribution uncertainty, or if work would add
Emburk semantics or an upstream build.

The pull request references, but must not close, Issue #15 because S01 is a
partial slice and T-0012 remains open. The repository's automatic Review
transition is intentionally limited to a closing-linked Issue. The Project
Manager therefore records the S01 Review transition manually after the pull
request head and acceptance evidence are reconciled.

## Runtime evidence state

- Demo Command: `tests/t0012_config_presence_probe_test.sh` passed at
  `1f2e73767d6091375c89b7355b2a44d24f3495c2` on 2026-09-05; corrupt-copy
  checksum rejection exited 3 and unavailable-asset retrieval exited 56.
- Integration: PR #61 was manually moved to Review because it references,
  rather than closes, parent Issue #15. It was then squash-merged as
  `e2532e245bff8114d075c8f35e9871d889d717a3`; Issue #15 remains open for
  subsequent slices.
- Environment: Temurin Java 17.0.20 on macOS arm64.
- Official executable: v0.11.5 asset URL recorded above; SHA-256
  `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`;
  manifest `Main-Class: org.embulk.cli.Main`; extracted executable locators
  `META-INF/LICENSE` and `META-INF/NOTICE` were nonempty.
- Generated local test plugin: source SHA-256
  `8c18185fa65077a9880b8add9341adbe7efb8735cd573b702bdbab551507f0c7`;
  JAR SHA-256 `1f1b96f17ba96133440ddfc307bc8398dc22e960d229275f731a0d019c86758b`;
  isolated coordinate `org.embulk.t0012:embulk-input-t0012:0.0.1`. The CLI
  loaded it through the local Maven registry. It is generated externally and
  not distributed.
- Observed matrix, limited to this pinned loader and annotated fixture:
  required `String` was an exception when absent or null and `observed-value`
  when present; defaulted `String` was `fallback` when absent, an exception
  when null, and `observed-value` when present; defaulted `Optional<String>`
  was empty when absent or null and `present:observed-value` when present.
- External raw evidence is retained locally and deliberately not linked here
  because it can contain personal paths; it contains raw binary observations,
  exact exception messages, executable/plugin hashes, and environment data.

### Prior core-POM diagnostic

- Environment: Temurin Java 17.0.20 on macOS arm64; Gradle 8.10.2.
- Resolved public runtime graph: `org.embulk:embulk-core:0.11.5`
  (`231ec2c7c68833a14a5d522b23879e03af1b83d86b79213137f0c1951d849f77`),
  `org.slf4j:slf4j-api:2.0.13`
  (`e7c2a48e8515ba1f49fa637d57b4e2f590b3f5bd97407ac699c3aa5efb1204a9`), and
  `org.msgpack:msgpack-core:0.8.24`
  (`4147ed3fc32e61ab0f00aa357ea24d304318518931b5e1d72c97752867db9bc1`).
- Exact failure boundary: after compilation, `new ModelManager()` raised
  `LinkageError` for unavailable
  `org.embulk.deps.config.ModelManagerDelegateImpl`, with an underlying
  `ClassNotFoundException`. No case output exists.
- External diagnostic evidence is retained locally and deliberately not linked
  here because raw output can contain personal paths. Probe source SHA-256:
  `65e2b85a531c6b0f5d13726daefe4e9075bd0df32a5ffc06ebb5a22e7905f140`.
- Public-interface-only observation: `javap` against the exact resolved core
  JAR examined `ConfigLoader`, `ModelManager`, and `ConfigSource`, locating
  `ConfigLoader(ModelManager)`, `ModelManager()`, `fromYamlString(String)`, and
  `loadConfig(Class)`. No source build, source/test reuse, or implementation
  translation occurred.
- Execution tooling: Gradle 8.10.2 was temporarily fetched from
  `https://downloads.gradle.org/distributions/gradle-8.10.2-bin.zip`; its
  official `.sha256` sidecar agreed with the hard-pinned SHA-256
  `31c55713e40233a8303827ceb42ca48a47267a0ad4bab9177123121e71524c26`.
  Tooling is neither committed nor redistributed; its license classification
  is unreviewed here.
- Required runtime dependency audit: pending T-0005. The core POM graph is not
  asserted complete. `embulk-deps` and any further artifact remain unadmitted;
  their coordinates, licenses, NOTICE obligations, checksums, transitive graph,
  runtime route, and redistribution decision require a separate packet. The
  core POM route is not used for the active executable route.

## Non-claims

This record makes no claim about Emburk configuration, schema, value,
lifecycle, transaction, resume, plugin, performance, security, production,
redistribution, patent, freedom-to-operate, or Embulk compatibility behavior.

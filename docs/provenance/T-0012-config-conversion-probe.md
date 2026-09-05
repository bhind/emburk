# T-0012/S02 configuration-conversion reference probe

- Tracking issue: [#15](https://github.com/bhind/emburk/issues/15)
- Parent work item: `T-0012`; S02 is an independently acceptable
  reference-observation slice and does not replace its Differential (Embulk)
  evidence gate.
- Branch: `research/t-0012-config-conversion`
- Lifecycle owner: Project Manager
- Mutation owner: Compatibility Host Implementer
- Required reviewer: Librarian (Vreji), reviewed 2026-09-05; independent Tester
  review is required before acceptance.
- Access date: 2026-09-05
- State: `In Progress` (packet prepared; no runtime observation yet)

## Outcome and boundary

Record nine independently authored observations of a pinned Embulk loader's
handling of selected annotated Boolean and Long values. Each isolated fixture
must preserve the raw result or exception, process exit, and an observable
phase marker. `probe config load` means the local test plugin emitted its marker
while loading its annotated configuration; `before probe callback` means no
such marker was emitted and the raw process log/exit is retained. The latter is
an observation label, not a claim that a YAML or CLI parser caused the result.

This slice deliberately excludes absent, explicit-null, and default behavior;
S01 already observed those states only for String/Optional fixtures. It does
not establish Boolean/Long defaults, primitive-versus-boxed behavior, a generic
typed-getter contract, Emburk behavior, or a complete configuration contract.

## Matrix and acceptance

The runner must execute the following nine isolated configurations with a
required annotated `Boolean` or `Long` field, retaining each raw input spelling
in local evidence:

| Case | Field type | YAML value | Permitted observation phase |
| --- | --- | --- | --- |
| `boolean-true` | `Boolean` | `true` | probe config load |
| `boolean-false` | `Boolean` | `false` | probe config load |
| `boolean-quoted-true` | `Boolean` | `"true"` | probe config load |
| `boolean-invalid` | `Boolean` | `not-boolean` | probe config load |
| `long-37` | `Long` | `37` | probe config load |
| `long-quoted-37` | `Long` | `"37"` | probe config load |
| `long-max` | `Long` | `9223372036854775807` | probe config load |
| `long-fractional` | `Long` | `37.5` | probe config load |
| `long-overflow` | `Long` | `9223372036854775808` | probe config load or before probe callback |

The required Demo Command will be
`tests/t0012_config_conversion_probe_test.sh`. It must invoke the runtime
probe, validate nine unique complete case records, retain per-case raw logs and
process exits, and prove known controls `boolean-true` and `long-37` reached
`probe config load` successfully. A permitted `before probe callback` record
is valid only for `long-overflow` with a nonzero process exit and retained raw
log; it must not turn a global startup/linkage failure into nine accepted case
records. Existing S01 Demo behavior must remain unchanged. Corrupt-checksum and
unavailable-runtime controls must still reject before semantic observations.

The implementation allowlist is limited to:

- `tools/t0012-config-presence/run.sh`;
- `tools/t0012-config-presence/src/T0012InputPlugin.java`;
- `tests/t0012_config_conversion_probe_test.sh`;
- `TODO.md`, `docs/STATUS.md`, `docs/ROADMAP.md`, `docs/log/2026-09-05.md`, and
  `docs/provenance/` for this packet and results.

No Rust production code, Cargo manifest, upstream source or test, executable
binary, generated plugin JAR, raw output, credentials, or product plugin may be
committed. The runner must keep all downloads and evidence in a safe external
temporary directory. The official executable and generated test plugin remain
local runtime artifacts only.

## Reference locators, rights, and reuse decision

| Reference | Immutable locator | Observation use | Reuse decision |
| --- | --- | --- | --- |
| Core annotations and task API | Embulk v0.11.5 commit `c5ac2d471edac465b45088669d376a7e2a525f8f`: `embulk-core/src/main/java/org/embulk/config/Config.java`, `ConfigDefault.java`, `Task.java`, and `ModelManager.java` | Locate public annotation syntax and task/configuration entry points | Interface observation only; no source text, implementation, test, or vector is reused. |
| Plugin lifecycle | Embulk SPI v0.11 commit `576e98033a14ba8ac994ed581d3c9d8fcdda2749`: `src/main/java/org/embulk/spi/InputPlugin.java` | Locate public input-plugin lifecycle signatures for the local test plugin | Interface observation only; no source text or implementation is reused. |
| Executable route | Official v0.11.5 executable `https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar`, SHA-256 `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`, manifest `Main-Class: org.embulk.cli.Main`, embedded `META-INF/LICENSE` and `META-INF/NOTICE` | Same pinned local-runtime route as S01 | Download for local execution only; no artifact redistribution. |

The core and SPI source licenses are Apache-2.0, as recorded in T-0011. The
downloaded executable's embedded NOTICE and licenses are evidence locators, not
an admission of every bundled dependency. Transitive runtime licensing,
redistribution, security, patent/standards, and freedom-to-operate questions
remain unreviewed. The Librarian found no material provenance blocker for this
observation-only packet, conditional on retaining S01 identity and isolation
controls. That review is not legal advice or patent/FTO clearance.

## Stop rule and non-claims

Retain ordinary retrieval, compilation, startup, linkage, and case failures
with their exact local evidence and repair only the bounded harness when safe.
Stop scope expansion for a material license, NOTICE, redistribution,
reimplementation-boundary, or security uncertainty, or before any Rust
semantic implementation, upstream build, external plugin admission, or artifact
redistribution. A successful upstream-only run remains Reference Observation /
Integration evidence, never Differential evidence or an Emburk compatibility
claim.

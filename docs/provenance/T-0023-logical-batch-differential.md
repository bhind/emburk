# T-0023/S02 selected logical-batch differential bridge

- Issue: [T-0023, #20](https://github.com/bhind/emburk/issues/20)
- State: Review; frozen implementation acceptance pending
- Branch: `test/t-0023-s02-logical-batch-differential`
- Owner: Compatibility Host Implementer; Project Manager owns records and integration
- Priority: P1; estimate 5 SP (implementation 2, uncertainty 0, verification 2,
  environment 1; raw 5)
- Evidence target: Unit/Contract plus selected Differential (Embulk)

## Authority

The owner explicitly authorized S02 and chained successor execution. ADR-0014
and S01 are integrated. This packet authorizes only a test harness and test-
only Rust bridge over the existing private boundary. It does not authorize a
public API, physical representation, consumer, parser, runtime change, or
permanent compatibility exception. Internal representation differences remain
pending reimplementation and differential verification before public exposure.

## Dependencies

Require integrated S01 at `d0eebf8`, accepted ADR-0007/S06 schema,
ADR-0011/S08 values, ADR-0012/S10 Float64 bits, and strict S11 automation.
Use only S11's selected `matching`, `explicit-null`, and `duplicate-name`
outcomes. S11 unset-text and wrong-setter observations remain diagnostic-only
and cannot define native defaults, misuse, nullability, or diagnostics.

## Branch and allowlist

One Compatibility Host Implementer owns exactly:

- `crates/emburk-core/src/logical_batch.rs` for a test-only manifest bridge,
  offline local bridge/negative tests, and one ignored exact Rust test;
- `tools/t0023-logical-batch-differential` for an original Python-standard-
  library projection/validation driver;
- `tests/t0023_logical_batch_differential_test.sh` for the exact Demo wrapper
  and controls.

Do not change `logical_schema.rs`, `logical_record.rs`, `record_handoff.rs`,
`lib.rs`, Cargo manifests, dependencies, CLI, public exports, S11 Java/runner/
wrapper, or canonical records. The Project Manager owns this packet/index and
all decision, status, roadmap, architecture, compatibility, runtime-design and
log records. Testers/reviewers are read-only.

Frozen source is `e0a44ad5de68e6367fdb62354eb482b3a5d40815`:

| Source | SHA-256 |
| --- | --- |
| `crates/emburk-core/src/logical_batch.rs` | `700cc999e8a7efe683cfb04b147a9df0aceed61fc4d440dcdfe4488c2c1cd146` |
| `tools/t0023-logical-batch-differential` | `5edd95eec859be8231743c105c87c7bd8e8df25517197dd8db37051134be62d9` |
| `tests/t0023_logical_batch_differential_test.sh` | `4c04b7daf177387cd94edc6c7991d1c7c233af2beee26431b2808f5e79a1cb4f` |

## Artifacts

No external source, artifact, dependency, or upstream observation is admitted.
The wrapper runs the unchanged S11 full automation exactly once and obtains its
external evidence path. The driver must require a succeeding exact S11
validate-only result before projection; generated TSV, logs, hashes and copied
controls stay in external temporary storage. A failed S11 invocation must fail
the S02 run and cannot qualify as a mutation-rejection result.

## Acceptance criteria

Project independently observed transaction-schema and run-schema fields, then
the strict S11 supplied cells, null flags and typed getter outcomes into
canonical UTF-8 TSV `T0023-S02\t1`, for exactly: matching (four columns/one
row), explicit-null (the same four/one row), and duplicate-name (two positional
columns/one row). Never manufacture schema or reference values from fixture
labels or supplied inputs. Preserve ordered phase fields, names, types, rows and
cells; encode names/text safely; preserve raw Float64 bits. Apply explicit caps,
UTF-8 validation and canonical LF transport.

The ignored Rust test must construct actual `LogicalSchema`, `LogicalRecord`,
and `LogicalBatch::try_new` values, then compare actual stored results against
independently projected reference cells. An expected-only mutation must fail
without changing supplied inputs. Test canonical header/arity/case/field/row/
cell ordering, missing/duplicate/unknown/reordered entries, dimensions and
indices, malformed UTF-8/hex/type/tag/bits/numbers, null/getter contradictions,
and expected-only payload mutation. Fresh raw-evidence copies must fail S11
strict validation before any projection.
The wrapper must prove that exactly the named ignored Rust test ran and passed
once; a Cargo exit status, zero selected tests, or a runtime skip is insufficient.

## Demo Command

`bash tests/t0023_logical_batch_differential_test.sh && cargo test --workspace && cargo fmt --all -- --check && cargo clippy --workspace --all-targets -- -D warnings && bash tests/t0012_double_value_differential_test.sh && bash tests/t0012_page_value_differential_test.sh && bash tests/t0012_schema_differential_test.sh`

The S02 wrapper runs S11 once; do not add a second S11 invocation to this Demo.

## Frozen implementation under review

At frozen source, the exact S02 wrapper passed: three projections/ten cells,
four offline bridge tests, positive validate-only, four repaired raw-evidence
controls, two projector-contradiction controls, and three path/existing-output
controls. Workspace checks report 57 passed/eight intentional ignores, format
and strict Clippy. The root source-check outer log is
`/private/tmp/t0023-s02-source-check.3rCrcR`, exit 0, stdout SHA-256
`ff8808dc1e50d72bbefcdf4c144cb5b9f6cb11df67ba61a50a8cc3c8429339fc`, with
empty stderr. A first S11 retrieval attempt at
`/private/var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T/t0023-s02.HBx2dA`
exited 56 and is retained as non-acceptance evidence. Final PR-head Demo and
separate Tester reproduction remain required; source freeze is not completion.

## Evidence class

Unit/Contract for transport and local controls; Differential (Embulk) only for
the three named S11 projections after accepted final-head reproduction. This
does not broaden S11, S01, or the supported compatibility surface.

## Stop rule

Stop and return to the Project Manager before any allowlist expansion, new
source/artifact/dependency/observation, native consumer or physical encoding,
public exposure, S11 modification, or material IP/security uncertainty.

## Non-claims

No timestamp/JSON values, metadata/nullability, lookup, defaults, coercion,
unset or misuse policy, external diagnostics, Arrow/Page encoding, resource or
lifecycle behavior, plugins, transfer, File-to-File result, parent completion,
or permanent exception is claimed.

# T-0023/S01 private positional logical batch admission

- Issue: [T-0023, #20](https://github.com/bhind/emburk/issues/20)
- State: Done; PR #101 integrated as `d0eebf8` after final-head acceptance
- Branch: `feat/t-0023-s01-schema-bound-record`
- Owner: Rust Core Implementer; Project Manager owns decision, records, and integration
- Priority: P1; estimate 5 SP within unchanged parent Current/Initial 8 SP
  (implementation 2, uncertainty 1, verification 1, environment 1; raw 5)
- Evidence target: Unit/Contract

## Authority

The owner approved the bounded internal design after reviewing the differences
from Embulk. ADR-0014 is accepted. Internal representation differences are
permitted; timestamp/JSON, unset and externally observable error behavior remain
pending verification before public exposure, not permanent compatibility
exceptions. This packet authorizes only the bounded private implementation.

## Dependencies

Accepted dependencies are ADR-0007/S06 ordered schema, ADR-0011/S08 values,
ADR-0012/S10 Float64 bits, T-0012/S11's strict selected schema/value
observation validator, and parent T-0021/S06's completed private handoff
boundary. This slice does not modify or consume that handoff.

S11 permits only selected positional matching, explicit-null, and
duplicate-name evidence. Its unset-text and wrong-setter observations are
diagnostic-only and do not authorize native defaults, misuse validation, or
external diagnostics.

## Branch and allowlist

Branch: `feat/t-0023-s01-schema-bound-record`.

One Rust Core Implementer owns exactly:

- `crates/emburk-core/src/logical_schema.rs` for sibling-private type/accessor support only;
- `crates/emburk-core/src/logical_batch.rs` for original batch admission and local tests;
- `crates/emburk-core/src/lib.rs` for private module registration only.

Do not modify `logical_record.rs`, `record_handoff.rs`, Cargo manifests,
dependencies, CLI, public exports, reference probes, S11 automation, or
canonical records. The Project Manager owns ADR-0014, this packet/index, and
all status, roadmap, compatibility, architecture, runtime-design and log
records. Testers/reviewers are read-only.

Frozen source is `9f842509761677b9f56291a8682e56f5bca15a05`:

| Source | SHA-256 |
| --- | --- |
| `crates/emburk-core/src/lib.rs` | `61dd14e8f8f65a3669ce3152f15353ec85891b96fd3a7f7038bb7e4940c7c9f1` |
| `crates/emburk-core/src/logical_schema.rs` | `cde5913afeafb75998c98222b8fafe22e4e9ca9985992e1b76ad46c488229cc0` |
| `crates/emburk-core/src/logical_batch.rs` | `178171f559dc122712cc493387710e6bb69530b15bbe29c3760e7c3550ceba7a` |

## Artifacts

No new external source, reference artifact, dependency, runtime fixture, or
generated repository artifact is admitted. Reuse the accepted S11 validator
only as an unchanged regression and evidence-integrity gate. Generated build
and test output remains outside the repository.

## Proposed private boundary

Add an original `LogicalBatch` which owns one private ordered schema and zero
or more owned logical-record rows. `try_new` consumes its inputs. It rejects,
in exact local precedence: (1) the first Timestamp or Json schema column;
(2) after the entire schema is supported, the first row with unequal width;
and (3) after all widths pass, the first row-major non-null cell whose logical
value category differs from its positional schema column. Null is accepted
only in Boolean, Signed64, Float64, and Text columns. Rejected inputs are not
recoverable through this constructor.

This is a private invariant, not an Embulk validation, nullability, coercion,
or error-timing contract. Preserve positional order, duplicate names, owned
text and actual Float64 bits. Provide only private read-only access;
`record_handoff` remains unchanged.

## Frozen implementation under review

The frozen source adds the private batch module and narrowly scoped
sibling-private schema access. Seven focused local tests cover accepted
matching, explicit-null and duplicate-name composition; empty-schema cases;
unsupported Timestamp/Json precedence; widths; and row-major type mismatch
precedence. Implementer checks report format, focused tests, strict Clippy and
diff checks passing. This is source-review evidence only: the exact Demo at the
final PR #101 head, a separate Tester reproduction, record reconciliation and
integration were subsequently satisfied as recorded below.

## Final acceptance and integration

Primary and independent Tester ran the exact Demo at final PR head
`196d648d078ce6ca6a424232747b1d4f476fed6a`, both exit 0. Workspace: 53 passed,
seven intentionally ignored live tests, including seven batch tests; format,
strict Clippy and unchanged S11/S10/S08/S06 passed. Primary reviewed all source
and corrected full-cell and global validation-priority assertions before freeze.
Independent review found no concrete blockers. Source hashes above match.

Primary logs: `/private/tmp/t0023-s01-primary.cXq4b4`; stdout SHA-256
`5aec3679f15a4ef687a9a1d5bea09beaf21943bb602d3745a9a86945ca89b556`;
stderr `b665742cabe4cac1b5ffbbe7e5ddb5e52c85df5ca5b0aa4f540776be66a02d2b`.
Tester logs: `/private/tmp/t0023-s01-tester.jHdx8i`; stdout SHA-256
`6f69e41bf849bd52ed9794f021d3a2497a8ac82691b4ed4845410a8f3a473b20`;
stderr `8ed196c31a377459fda8495314f5838e16253f53e21885f70994299a456e4f93`.
Environment: Darwin arm64, Rust/Cargo 1.98.1, Temurin 17.0.20, Python 3.14.6.
Temporary evidence must be reproduced if removed.

PR #101 integrated as `d0eebf886d78ab593649c0b2d6c6a59b6843b005`.
S01 accepts 5 SP, Unit/Contract only; parent #20 remains open/Backlog,
Current 8 / Initial 8 unchanged. No successor is activated by this closeout.

## Acceptance criteria

Local tests must construct matching, explicit-null, and duplicate-name cases
using actual private schema and value objects; assert exact schema/row/cell
order, owned text, and raw negative-zero Float64 bits. They must reject
Timestamp/Json before values even when null, a width-zero row for a non-empty
schema, short/long rows, and each cross-type pairing. Empty-schema/zero-row
and empty-schema/one-empty-row batches must admit. Tests must prove the stated
global precedence: all schema support checks, then all row widths, then
row-major value checks.

Primary and independent final-head reproductions, source/diff checks and
canonical-record reconciliation are required before integration.

## Demo Command

Run:

`cargo test --workspace && cargo fmt --all -- --check && cargo clippy --workspace --all-targets -- -D warnings && bash tests/t0012_schema_value_coupling_probe_test.sh && bash tests/t0012_double_value_differential_test.sh && bash tests/t0012_page_value_differential_test.sh && bash tests/t0012_schema_differential_test.sh`

## Evidence class

Unit/Contract. The existing S11 runner verifies its provenance evidence but
grants no new native Differential result.

## Stop rule

Stop and return to the Project Manager before allowlist expansion, a new
artifact or source observation, an external dependency, a physical encoding,
a consumer rewrite, or material IP/security uncertainty.

## Non-claims

Do not add timestamp/JSON values, schema metadata or nullability, name lookup,
defaults, coercion, external diagnostics, public APIs, Arrow/Page encoding,
resource bounds, lifecycle, plugins, transfer, or a compatibility claim.

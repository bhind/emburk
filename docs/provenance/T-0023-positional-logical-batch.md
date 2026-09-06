# T-0023/S01 private positional logical batch admission

- Issue: [T-0023, #20](https://github.com/bhind/emburk/issues/20)
- State: In Progress; owner-approved ADR-0014, implementation acceptance pending
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

Branch reservation: `feat/t-0023-s01-schema-bound-record`.

One Rust Core Implementer would own exactly:

- `crates/emburk-core/src/logical_schema.rs` for sibling-private type/accessor support only;
- `crates/emburk-core/src/logical_batch.rs` for original batch admission and local tests;
- `crates/emburk-core/src/lib.rs` for private module registration only.

Do not modify `logical_record.rs`, `record_handoff.rs`, Cargo manifests,
dependencies, CLI, public exports, reference probes, S11 automation, or
canonical records. The Project Manager owns ADR-0014, this packet/index, and
all status, roadmap, compatibility, architecture, runtime-design and log
records. Testers/reviewers are read-only.

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

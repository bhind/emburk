# T-0012/S11 bounded schema/value coupling observation

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: In Progress, Stage A only; approved packet integrated through PR #98 as `b98d044`
- Branch: `research/t-0012-schema-value-coupling`
- Owner: Compatibility Host Implementer; PM owns records and adoption decisions
- Priority: P0; estimate 5 SP (implementation 2, uncertainty 1, verification 1,
  environment 1). Parent Current refines 34 to 55, Initial remains 5: known
  S03–S10 acceptance totals 30 SP; this slice plus unresolved configuration,
  timestamp/JSON and schema contracts exceeds 34. No parent completion follows.

## Authority

Standing owner authority permits bounded reference instrumentation and accepted
PR integration. One source owner; independent read-only Tester and Librarian.
At most one active item for this serial lane; preserve all user worktrees.

## Dependencies

T-0011 pins and S05/S07/S09 public-interface provenance are integrated.
S10 private doubles integrated through PR #93; T-0021/S06 handoff integrated
through PR #96. Schema and record storage remain separate under ADR-0007 and
ADR-0011/0012. No schema validation or data-bearing lifecycle policy is selected.

The next decision needs actual positional/null/unset/mismatched-setter evidence,
not another disconnected native abstraction. An observation does not itself
authorize T-0023 schema validation: PM must separately classify supported use,
misuse and unspecified behavior before a native coupling ADR or packet.

## Branch and allowlist

One Compatibility Host Implementer owns exactly three new paths:

- `tools/t0012-schema-value-coupling-probe/src/T0012SchemaValueCouplingInputPlugin.java`
- `tools/t0012-schema-value-coupling-probe/run.sh`
- `tests/t0012_schema_value_coupling_probe_test.sh`

PM owns this packet, provenance index, STATUS/TODO/ROADMAP/COMPATIBILITY/
ARCHITECTURE/runtime design and dated log. No existing tools, Rust source/tests,
Cargo, dependencies, CLI, public API, schema policy or lifecycle edits.
Original repository-owned instrumentation may be adapted; no upstream copying.

## Artifacts

Reuse only the admitted S07 test-local PageBuilder/PageOutput/PageReader route
and S09 double transport. Each fixture runs in a separate pinned runtime process.
The collector reads synchronously during add(Page), with the existing local
reader lifetime, no page forwarding/retention, physical-byte inspection or
runtime output transfer. Record null before a declared-type getter and never
invoke typed getters for null. Every operation has an entry/return or exception.

Exactly five original fixtures, with supplied cells separate from observed data:

1. `matching`: one row in ordered `flag:boolean`, `number:long`, `ratio:double`,
   `text:string`, assigned true, 37, raw double `8000000000000000`, and `A|B`.
2. `explicit-null`: the same schema, all four positions explicitly null.
3. `unset-text`: the same schema, assign only the first three matching values,
   deliberately omit the fresh builder's text setter, then call addRecord.
4. `wrong-setter`: one `number:long` column, deliberately call the already
   admitted setString(Column, String) with `wrong`, then addRecord if it returns.
5. `duplicate-name`: two columns named `shared`, respectively long and string;
   write 37 and `right` using the actual positional Column objects, then read
   by those positions and declared types.

Do not assume these operations succeed, fail, default or reset. Wrong-setter
and unset results are diagnostic observations, potentially unsupported or
unspecified API use, not automatic native validation/default rules. No repeated
row/reset or arbitrary wrong-setter matrix is included.

## Stage A: raw capture before expectations

Implement capture only first. Capture complete physical-order callback and
operation traces, fixture/capture UUID/sequence, both schema phase fingerprints,
supplied setter intent, actual null/getter values, exact exception class/message
(null distinct from empty), process exit, terminal outcome, cleanup and reports.
Preserve failures and full stdout/stderr/exit. Do not guess success counts,
exception vectors or Page counts. PM must inspect all raw results before Stage B.

Stage A command: `T0012_COUPLING_MODE=capture bash tools/t0012-schema-value-coupling-probe/run.sh`.
Freeze source before capture. No full-success or validate-success marker may
be emitted by capture-only mode. Stage A is not slice acceptance.

## Stage B: strict evidence gates

After PM records actual expectations, implement strict full and validate-only
modes. Full runs fresh captures and artifact controls; validate-only checks
existing evidence and cannot admit a runtime or emit a live/full marker.
Bind metadata to the historical source revision and exact source paths/hashes,
fresh capture IDs, fixture matrix, physical event order, schema/cell positions,
typed/null payloads, exceptions, terminal/process outcome and cleanup. Verify
the runtime artifact before execution, retain LICENSE/NOTICE and their hashes.
Canonical external temporary evidence only, reject symlinks/path substitution,
never overwrite unrelated artifacts. Record source, toolchain and runtime IDs.

Use fresh repaired evidence copies for diagnostic-specific rejection of missing,
duplicate, reordered or mutated fixture/schema/event/capture/source/hash/value/
exception/terminal/cleanup data. Include corrupt and unavailable artifact
controls. Each negative retains full stdout/stderr/exit and its actual diagnostic;
an unrelated retrieval error cannot pass a corruption test. Control count and
vectors are selected only from reviewed Stage A evidence, not pre-guessed here.

## Acceptance criteria

All five actual outcomes receive a bounded decision table separating supplied
operations, observation, evidence class and remaining policy uncertainty.
Primary and independent Tester reproduce exact final Demo at frozen source,
retain complete logs/exits and source hashes, and review all repaired controls.
Run Bash syntax, Java compile, workspace format/tests/strict Clippy and diff
checks. No missing-runtime skip or weakening prior regressions. Resolve findings,
reconcile records, run final PR-head Demo and integrate before slice completion.

## Demo Command

`bash tests/t0012_schema_value_coupling_probe_test.sh && bash tests/t0012_double_value_differential_test.sh && bash tests/t0012_page_value_differential_test.sh && bash tests/t0012_schema_differential_test.sh`

This is the final Stage B acceptance command, not Stage A authorization.

## Evidence class

Reference Observation / Integration plus validator Unit/Contract only.
No native Differential comparison is added by this slice.

## Provenance and admission

Read-only Librarian and PM reviewed existing records/code on 2026-09-06; no new
external source, artifact or signature was inspected or adopted. Reuse public
signatures recorded in S05 (Schema/Builder/Column), S07 (Page APIs) and S09
(setDouble/getDouble and raw bit transport). Exact class locators remain in
those linked records under `org/embulk/spi/` and `org/embulk/spi/type/Types.class`.
Official artifact URL:
[Embulk 0.11.5](https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar),
SHA-256 `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`,
11109700 bytes; core `c5ac2d471edac465b45088669d376a7e2a525f8f`,
SPI `576e98033a14ba8ac994ed581d3c9d8fcdda2749`.
LICENSE SHA-256 `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`;
NOTICE SHA-256 `27f0e45afdf10e406ee8bf478bfce38279e9087338a7981942a4a2762bcd5be8`.
Apache-2.0 source classification is not executable redistribution or patent
clearance. Generated/downloaded JARs remain local and external. No upstream
implementation/tests are copied or translated. SBOM, redistribution, patents,
standards, trademark, jurisdiction and freedom-to-operate remain unreviewed.

## Stop rule

Return to PM before new fixtures/API signatures/artifacts, timestamp/JSON,
native schema/null/default policy, parser/config/lifecycle/Arrow changes, or
material security/IP uncertainty. Stage A must stop for PM raw review before
expected vectors or Stage B. Routine retrieval/build issues may be repaired
in scope with failed evidence retained.

## Non-claims

No native batch, schema enforcement/default rule, public API, physical layout,
parser/config behavior, timestamp/JSON representation, lifecycle integration,
File-to-File, memory/backpressure, recovery, performance, release or parent
completion. Unsupported use observed to succeed is not a compatibility promise.

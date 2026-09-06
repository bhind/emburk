# T-0012/S11 bounded schema/value coupling observation

- Issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- State: Done; PR #99 integrated as `413f837` after final-head acceptance
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

After an editing-policy gate rejected capture-only to full/validate expansion,
the owner explicitly approved that expansion, including default behavior changes,
and requested automation on 2026-09-06. This authorizes the scoped Stage B
implementation below; it does not waive evidence, review or provenance gates.

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

### Stage A reviewed observations (2026-09-06)

Frozen capture source: `a95e3507dd91bdf005b09e4ebfb5582c4ed21164`.
Implementer exact capture command exited 0 with complete outer logs at
`/private/tmp/t0012-s11-stage-a.iaeqSO`; raw evidence:
`/private/var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T/t0012-schema-value-coupling/run.vHxMGd/evidence`.
Primary independently reproduced the command (exit 0), retaining complete logs
at `/private/tmp/t0012-s11-primary-stage-a.GWcWHc` and raw evidence at
`/private/var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T/t0012-schema-value-coupling/run.FfEXas/evidence`.
Primary read all 289 decoded events and compared both physical-order streams
with only UUIDs replaced by ordinal context identities: all five matched.

| Fixture | Process exit / events | Actual operation and outcome | Policy limit |
|---|---|---|---|
| matching | 0 / 78 | One four-cell row read as true, 37, raw double `8000000000000000`, `A\|B`; all null flags false | Selected matching assignments only |
| explicit-null | 0 / 74 | One row; four true null flags; no typed getter invoked | Explicit null, not unset/default equivalence |
| unset-text | 1 / 46 | `builder-add-record` throws `java.lang.NullPointerException`; no collector add/read, no run success | Fresh unset text only, not a general width/default rule |
| wrong-setter | 1 / 31 | `builder-set-string` on long column throws `java.lang.IllegalStateException`; addRecord never called | One setter/type misuse only |
| duplicate-name | 0 / 60 | One row; distinct positions read long 37 and string `right`, both non-null | Position-specific selected observation, not name lookup |

Exact observed NPE message: `Cannot invoke "String.length()" because "value" is null`.
Exact IllegalStateException message: `Setting a STRING value to a LONG column: number, long`.
These diagnostics are tied to the observed executable/JVM environment, not a
portable/public Rust diagnostic contract. Normal cases have one page/row in this
capture, exact finish/close/reader exhaustion and one task/one cleanup report.
Both error cases close the test-local collector/reader at zero pages/rows,
propagate the same exception through run/control/transaction, emit an exception
terminal and have cleanup task 1/report 0. Do not generalize Page counts.

Normal cases use one UUID context with contiguous sequence including cleanup.
Error cases have the primary context ending at terminal, then a distinct UUID
context containing only cleanup-entry/cleanup-return with sequence 1/2. Stage B
must preserve and validate these exact physical segments; reject reused, extra,
interleaved or reordered contexts. This is an observed trace shape, not proof
of class-loader/process/ownership mechanics. No internal runtime was inspected.

The initial capture at `7bd305a` failed its single-context transport assumption:
outer logs `/private/tmp/t0012-s11-stage-a.9Vc2k3`, exit 1; raw evidence
`/private/var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T/t0012-schema-value-coupling/run.ts0jwr/evidence`.
It remains retained, not acceptance. Non-amended correction `a95e350` preserves
observed contexts and uses only previously admitted positional schema APIs.

Primary stdout SHA-256:
`83767caad542703e5b82c9dd281c883bab6170167bdf621746d75052481b83f0`.
Primary stderr SHA-256:
`5ff3a462e0bad90363979ae1e680321e1b9bfa61e0adaa45734f0d4d66f0d306`;
retained diagnostics are executable ZIP-prefix warnings and Java deprecation
notes. LICENSE/NOTICE hashes match the admitted values in both runs.
Java source SHA-256 `3458f499a93ad307c75395950c8ee1e3478c5eaeba706a645909124e53a305e3`;
capture runner `598ae1c811c5bd14b8356849cef5fb65fd1f7f5bcc008be353c9c88434e071d7`;
unavailable Stage B wrapper `f7e051f8f1f9cff08ad27b45bd7bd6d0fc1055ae24a83a4e0c6e4a9648e14cd3`.
Temporary evidence must be reproduced if removed.

Stage B vector representation is UTF-8 JSON with compact separators and
unescaped Unicode, no trailing newline: ordered rows contain first-occurrence
UUID ordinal (starting at 1), integer sequence, event name and decoded payload
array (null token becomes JSON null). No event or payload is omitted. PM
independently recomputed these hashes from its retained Stage A capture:

| Fixture | Normalized vector SHA-256 |
|---|---|
| matching | `db8a49da05d479051bc36b14c5a409679d09866cf9b46fb1b686aa1068e3e7de` |
| explicit-null | `0d24d2b54aaf18ea9dbaada67e8d16d24c6e6711346cff7162979eb7e25cbeec` |
| unset-text | `e72894c14d5558e0b56132e9506e498507568b396e130e7fd2d728d17ce7d1d1` |
| wrong-setter | `8cbf19bd93e6c3b69f1dc1da7275bdf3b9e60790906b4400cb6d70ae064df081` |
| duplicate-name | `90128852fbb049c8ad82d0d788e4be85cbfac3a995f7016c770bc67685d3210e` |

Canonical raw spelling, UUID uniqueness, exact physical segments and provenance
must be checked separately; normalization cannot excuse invalid raw transport.

PM authorizes only Stage B strict validation/control implementation from these
reviewed full vectors. Java fixture semantics remain frozen. No native policy,
full acceptance, Differential result or parent completion follows from Stage A.

After PM records actual expectations, implement strict full and validate-only
modes. The default full runner captures and strictly validates fresh outcomes;
the acceptance wrapper additionally runs artifact and repaired-evidence controls.
Validate-only checks
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

## Stage B source acceptance

Frozen source: `b556ce01bb311b96a260a2a656bb4b18056b36e2`.
The user-approved default is `full`; explicit `capture` remains observation-only,
and `validate` checks existing evidence without executing the reference runtime.
The wrapper automates five exact outcome vectors, a positive validate-only
check, 39 distinct structured rejection controls and corrupt/unavailable runtime
controls (expected exits 3/56). Each malformed copy must change its target and
produce exactly one specified diagnostic with exit 4 and empty stdout.

Primary exact four-wrapper Demo passed with exit 0. Complete logs:
`/private/tmp/t0012-s11-primary-demo.Tod1kD`; stdout SHA-256
`d0d6d90bfdbf22ea5bd86e6e27193a080d0b956b960d7105e287ce1b81cee184`;
stderr is empty. Fresh S11 evidence:
`/private/var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T/t0012-schema-value-coupling/run.quDR3j/evidence`.
Primary separately verified all 39 distinct retained stdout/stderr/exit triplets.
Existing S10 (12 cells/five bridge controls plus full S09), S08 (two projections/
18 controls), and S06 (three schemas) passed unchanged.

Primary quality logs: `/private/tmp/t0012-s11-primary-quality.Sl0MZJ`, exit 0:
workspace format, 46 Rust passes/seven intentional live ignores, strict
all-target Clippy, Bash syntax and diff check. Java compilation occurs in each
fresh capture. Read-only final-delta review found no additional blocker.
Separate read-only reproduction passed at the same frozen revision:
`/private/tmp/t0012-s11-tester.TXT3jc`, five traces/39 controls/two artifact
controls and unchanged S10/S08/S06 wrappers, all exit 0. Workspace tests
(46 passed/seven ignored), format, strict Clippy, syntax and diff checks passed.
The interrupted initial chained logging attempt is excluded; completed individual
reruns supply the reproduction evidence. Reviewers previously authored intermediate
source, so this is separate reproduction, not a blind-review claim.
Final exact four-wrapper Demo passed at PR head
`da7e50fa6c6e80c2c6c8f448d35c6ffddc29e584`, exit 0, logs
`/private/tmp/t0012-s11-pr-head.kcluXM`; stdout SHA-256
`c5e2667cf554ffaf88764aaa99efd41e6e6650d1471fcea21b96e021fdac4a57`,
stderr empty. PR #99 integrated as
`413f837f2ee5eff72494415002e557e0e2c1d8db`. S11 is Done (5 SP); known
S03–S11 acceptance totals 35 SP. Parent #15 remains open/Backlog,
Current 55 / Initial 5 unchanged. Both Project audits passed (54 items).

Source SHA-256:

- Java: `3458f499a93ad307c75395950c8ee1e3478c5eaeba706a645909124e53a305e3` (unchanged from Stage A);
- runner: `442a51465f7d8ee878e08c5e49f899479a14ac6f82d48a85771b1a9a4ce5e8fa`;
- wrapper: `bab01b3190c924403ccebad79399cf882e978572e70ac83fc4a37b7ae1722d21`.

Intermediate revisions `7657195`, `1d7da8e` and `9c1ca21` did not satisfy the
complete acceptance matrix. The initial generic control grid was replaced,
not counted as passing coverage. Intermediate live results (including
`/private/tmp/t0012-s11-stage-b.b4bbEm`) remain retained and superseded.
Final controls preserve historical revision-to-source-blob checks and separately
test canonical paths/transport, provenance, contexts and semantic alterations.
Hash manifests detect accidental or tested changes; they are not signatures or
proof against a malicious local process rewriting the entire evidence set.

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

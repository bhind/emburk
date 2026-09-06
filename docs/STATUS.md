# Current status

Last updated: 2026-09-06

Development state: `experimental native pipeline`

## Implemented facts

- The repository contains a minimal Rust binary and Cargo project suitable for
  verifying the development environment. T-0021/S01 establishes a virtual
  workspace with an inward-only `emburk-cli -> emburk-core` dependency while
  retaining the explicit not-yet-a-loader smoke test.
- T-0031/S01 implements an experimental `transfer-lines INPUT OUTPUT` path:
  real files, private Text records and the existing synchronous owned handoff.
  PR #110 integrated after primary and independent acceptance (68 passing tests,
  eight existing intentional ignores). It does not load Embulk
  configuration, execute plugins, or implement transactions and resume.
- A bounded private configured File/CSV consumer is integrated through PR #116;
  no public plugin API or Java/JRuby-hosted plugin is implemented or verified.
- Thirteen selected private raw-scalar outcomes match the pinned Embulk
  executable in a live differential test. No full configuration, plugin,
  data-transfer, or performance claim has passed its evidence gate.
- A private ordered logical schema preserves owned names, type tags, order and
  duplicates. T-0023/S01 adds integrated private positional batch admission
  for selected Boolean, Signed64, Float64 and Text values under ADR-0014. Timestamp/JSON, nullability, lookup and physical
  encoding remain unimplemented.
- Private owned Null/Boolean/Signed64/Text records preserve row/cell order and
  distinguish null from false, zero and empty text. Primary acceptance matches
  two selected reference getter-result projections, reproduced by an independent
  Tester and integrated through PR #82. This is not a production transfer path.
- A private synchronous empty-task coordinator executes original fake callbacks
  with separate cleanup capabilities and reports. Its Unit/Contract tests
  cover zero/one-input plans, one selected input-run failure, and selected
  first/middle/last output-commit failures with retained actual reports. Other callback
  failures and actual plugin execution are not implemented.
- The product strategy selects a compact Rust execution core, optional
  out-of-process compatibility hosts, explicit versioned compatibility, and a
  native File-to-File vertical slice as the first runtime milestone.
- Governance defines stable T-IDs, canonical repository records, role and
  mutation ownership, a two-item combined `In Progress`/`Review` WIP limit,
  traceable upstream observation, and separate license and patent-risk
  review.

Parser-selection research now has a [candidate assessment](provenance/T-0022-parser-candidates.md).
T-0022/S01 is Done through PR #114 after primary and independent acceptance
of six experiment tests, 71 workspace tests and actual-binary checks.
T-0014/S01 is Done through PR #115 after eleven harness tests, 71 workspace
tests and matching independent eight-case reference projections. The
T-0032/S01 consumer is Done through PR #116 (66c6125), after 81 passing tests,
eight existing ignores and eight independently matching selected real file
projections at 59a7cca. T-0025/S01 is Done through PR #117 (aac0003): 87 passes,
eight existing ignores, actual interruption and operation-failure tests, and
unchanged eight-case CSV comparison. T-0014/S02 is Done through PR #118:
nine tests and matching independent five-case format/filter observations.
T-0033/S01 is Done through PR #119 (95b5592): 97 tests and thirteen selected
comparisons passed independently at 39c97d8. T-0024/S01 now starts stage 7 with
bounded ordered formatting/cancellation, now integrated through PR #120
(24b99fa) after 106 passes and thirteen independent comparisons at 4970e46.
T-0025/S02 integrated validated native resume through PR #121 (9d364c4), after
118 passing tests, eight intentional ignores and thirteen selected comparisons
at 0d39e51 in primary and independent final Demo runs. The owner-authorized
[seven-stage sequence](IMPLEMENTATION_SEQUENCE.md) is complete within its
explicit bounded native profile; broader parent compatibility gates remain open.

## Delivery queue

T-0012/S08 is integrated through PR #82. The owner approved continuation of
T-0012/S09 after the reference-execution explanation. Stage A at `7e46379`
captured 114/93 events with exact selected double bits preserved; primary
reproduction and complete raw review authorize Stage B strict validation.
The slice integrated through PR #91 as `34757c8`. S10's private double-storage
decision passed readiness review and integrated through PR #92. S10 is now
Done through PR #93. T-0021/S06 is Done through PR #96 after primary,
independent and final-head acceptance. T-0012/S11 is Done through PR #99 after final-head acceptance.
T-0023/S01 is Done through PR #101 (`d0eebf8`), after primary and independent
final-head Demo at `196d648`: 53 workspace passes, seven intentional ignores,
seven batch tests and unchanged regressions. T-0023/S02 is Done through PR #103
(`5d72866`) after primary and independent Demo at `ca9af0a`: three selected
projections/ten cells, 57 workspace passes/eight intentional ignores, and
unchanged regressions. It adds no runtime behavior. T-0012/S12 is Done through
PR #105 (`67f0786`): primary and independent final-head Demo at `9df0d5c`
passed seven cases/36 events, strict controls and unchanged S01/S02 regressions.
No native configuration behavior is added. T-0012, T-0013 and T-0021 parent
contracts remain open. S13 is Done through PR #107 (`441040f`) after primary
and independent final-head Demo at `65a2fb3`: six syntax cases/60 events,
strict controls and unchanged S12 regression. T-0031/S01 is Done through PR #110
(`c5fb13f`) for the explicitly requested experimental native File-to-File path.
T-0031/S02 is Done through PR #112 (`2ec236e`) for experimental stdout/null
consumers: 71 tests passed, eight existing intentional ignores, primary and
independent acceptance at `c5df504`. T-0025/S02 is integrated; the full
file/plugin parent stays open. Core transfer semantics remain unchanged.

| Item | State | Purpose |
|---|---|---|
| T-0002 | Done | Established canonical records and stable IDs |
| T-0011 | Done | Pinned Embulk core and SPI references; no external plugin admitted |
| T-0003 | Done | Enforce Project discovery, packet checks, and WIP auditing |
| T-0004 | Done | Established Project delivery operations and burndown inputs |
| T-0012/S11 | Done | Automated strict observation validation; PR #99 integrated |
| T-0023/S01 | Done | Private positional batch admission; PR #101 integrated |
| T-0023/S02 | Done | Selected three-case LogicalBatch differential bridge; PR #103 integrated |
| T-0012/S12 | Done | Seven-case reference observation and validator; PR #105 integrated |
| T-0012/S13 | Done | PR #107 integrated; primary and independent final-head acceptance passed |
| T-0013 | Backlog | S01–S08 integrated; remaining cleanup/recovery contracts |
| T-0021 | Backlog | S06 handoff integrated; remaining runtime contracts |

T-0025/S01 is Done through PR #117. T-0014/S02 is Done through PR #118.
T-0033/S01 is Done through PR #119. T-0024/S01 is Done through PR #120.
T-0025/S02 is Done through PR #121. No implementation item remains active in
the seven-stage sequence; broader parent tasks return to Backlog.
Other unfinished stable tasks remain `Backlog`. Parent epics are
unpointed. The private [Emburk Delivery Project](https://github.com/users/bhind/projects/2)
is the coordination mirror. Its 52 items, lifecycle states, initial estimates,
roles, dependencies, workstreams, evidence classes, and views were reconciled
to the repository records on 2026-09-05.

T-0003 adds a fail-closed, read-only audit that dynamically discovers the one
open Project linked to the repository, validates the combined `In Progress`
plus `Review` WIP limit, and exposes reusable packet-validation checks. It does
not automate lifecycle transitions or provide delivery analytics.

T-0004/S01 added weekly Iteration, Start date, and Target date fields plus the
requested delivery and missing-metadata views. Its initial iteration snapshot
contained T-0004, then-blocked T-0012, and T-0021 for 15 Story Points. A read-only snapshot
records remaining Issues, remaining points, completion, and Status distribution
without double-counting pull requests.

T-0004 was integrated through PR #63 as `fce883c`. Issue #11 closed and its
Project item moved to Done. The first `project-metrics` snapshot was committed
as `7bd0807`: W36 had 2 remaining Issues / 10 Story Points and 1 completed
Issue / 5 Story Points after integration. The Action is installed and active.

T-0004/S02 repaired the delivery workflow event and credential gates through
PR #85 as `5d4a0f7`. Default-branch dispatch run `34003581110` completed
successfully with the zero-permission credential gate passing and both mutation
jobs skipped because `PROJECTS_TOKEN` remains absent. Issue #84 is closed and
Done. This proves safe no-credential behavior; it does not prove credentialed
Project mutation or daily snapshot publication.

T-0004/S03 aligned the workflow with the registered Actions Secret
`EMBURK_PROJECT_TOKEN` through PR #88, then replaced the failing CLI item
materialization with a minimal paginated Project GraphQL query through PR #89
as `a75b529`. Hosted run `34004702599` passed the credential gate, Project
audit, snapshot generation, and metrics commit/push. Metrics commit `72e87af`
updates the W36 CSV, JSON, and SVG artifacts. Issue #87 is closed and Done.
No credential value was read or logged; its scope and rotation policy were not
independently validated.

## Evidence and non-claims

Current evidence includes repository checks, private scalar Unit/Contract tests,
and a live comparison of 13 selected typed outcomes. Strategy and planning
records are not runtime evidence.
In particular, the repository does not yet demonstrate:

- Embulk-compatible configuration, schema, value, lifecycle, or resume
  behavior;
- general parallel ETL beyond the selected single-file ordered formatter;
- successful loading of any unchanged Java or Ruby plugin;
- exactly-once behavior for any source/output combination;
- a performance, security-isolation, production-readiness, or ecosystem
  coverage claim.

The shared bootstrap integration for `T-0002` and `T-0011` passed its stated
checks at revision `9416ec3` and was squash-merged by
[PR #53](https://github.com/bhind/emburk/pull/53) as `230e3af`. The two tasks
are complete; their evidence establishes only the bootstrap and reference-pin
boundaries described above.

T-0021/S01 is structural only. It does not define configuration, schema,
values, plugin traits, lifecycle, transactions, resume behavior, scheduling,
or a stable public Rust API.

T-0021/S01 was integrated through [PR #58](https://github.com/bhind/emburk/pull/58)
as `5fe306a`. Independent acceptance at `cf56841` recorded successful format,
Clippy, one unit test, workspace metadata, CLI run, and `git diff --check`.
This is Unit/Contract evidence for the structural workspace boundary only.
T-0021/S02 was integrated through [PR #60](https://github.com/bhind/emburk/pull/60)
as `341f285`, after review and `git diff --check` at `5059900`. Planning is
complete: it provides a [runtime design proposal](RUST_RUNTIME_DESIGN.md), configuration/value fixture
worksheet, lifecycle responsibilities, and explicit uncertain commit outcomes.
This is Planning evidence only. T-0012/T-0013 contracts and differential
verification remain prerequisites to completing the parent task.

T-0012/S01 initially diagnosed why the core POM graph cannot initialize its
configuration delegate; that graph was not expanded. Its bounded official-
executable route and local-only Maven-style input plugin recorded nine
annotated String/Optional fixture observations and integrated through PR #61
as `e2532e2`. This is Reference Observation / Integration evidence only, not a
generic typed-getter contract, a verified Emburk semantic, or the parent task's
Differential (Embulk) evidence. T-0012/S02's nine-case Boolean/Long runtime
observation integrated through PR #65 as `d7b4838`. Its evidence remains
Reference Observation / Integration only. T-0012/S03 implemented the private
Rust raw-scalar resolver and integrated through PR #66 as `e03a2bc`. Independent
and named Tester acceptance at `8432391` passed eight core tests, format,
Clippy, and diff checks. Its evidence is Unit/Contract only. S04 implements
a live oracle comparison for 13 supported outcomes. Primary acceptance at
`3fe6546` passed the exact Demo Command and negative controls, nine offline core
tests (one live test explicitly ignored), format, Clippy, and diff checks.
Independent Tester acceptance reproduced the same results; PR #67 integrated
the slice as `79cbcb9`. S05 is observing schema construction and phase handoff
before any Rust schema policy. See the
[S04 evidence record](provenance/T-0012-live-scalar-differential.md).

S05 primary acceptance at `cc24730` recorded three schema construction/handoff
successes: zero columns, six ordered logical types, and two same-name columns
with distinct types. Actual transaction/run fingerprints matched. Its strict
evidence validator and mutated-copy controls passed the exact Demo. Independent
Tester reproduced it and S01/S02/S04 regressions; PR #68 integrated as `68559dc`.
This is Reference Observation /
Integration only; no Rust schema, values or batches are added.

S06 implements the private ordered schema permitted by ADR-0007 and a
three-case live comparator. Primary acceptance at `c7c7872` passed all three
live outcomes and negative controls; workspace tests passed 14 with two
explicitly ignored live tests, plus format and strict Clippy. Independent
Tester reproduced S06 and S04 live regression; PR #69 integrated as `5de35b7`.
Its evidence is Unit/Contract plus
Differential for the three selected ordered outcomes only; no public schema
support or physical encoding claim follows.

T-0013/S01 now observes actual input callback traces before Rust lifecycle
traits are chosen. Primary acceptance at `b3f9c68` passed the exact Demo:
zero/one empty task processes exited 0 with six/ten input probe markers,
respectively, plus artifact and malformed-evidence controls. Independent
Tester reproduced the complete Demo; final-head acceptance at `84e692f` passed
and PR #70 integrated as `e8b5726`. No callback, cleanup or resume
contract is implemented or verified. See the
[S01 evidence record](provenance/T-0013-input-lifecycle-probe.md).

S02 now observes output callbacks using the unchanged S01 input fixture and a
separate original local output plugin. Primary acceptance at `5739052` passed
both fixtures and all artifact/trace controls. One input task produced eight
output tasks in this local reference run, each with open/finish/commit/close
pairs; no add, abort or resume marker occurred. Independent Tester reproduced
the complete Demo; final-head acceptance at `55ed697` passed and PR #71
integrated as `d474b7b`. No Rust lifecycle trait or output durability policy
is inferred; the fan-out factor is not a portable constant.

S03 adds a normal control and one injected input-run exception before its own
finish call. Primary acceptance at `f35cb49` passed: normal process exit 0,
injected failure exit 1 with the exact fixture exception propagated. Failure
output abort/close and cleanup under fresh capture IDs were observed.
Independent Tester reproduced the complete Demo; final-head acceptance at
`1cfa5af` passed and PR #72 integrated as `8e43948`.
T-0013 Current SP is refined from 8 to 13
for distinct task contexts and failure-evidence validation; Initial SP remains
8, and parent completion is not implied.

ADR-0008 permits T-0021/S03 to implement a private synchronous empty-task
coordinator with explicit plans and original fake plugins. Source acceptance at
`84edf00` passed five selected lifecycle tests and 19 workspace tests (two
intentional live-test ignores), format, strict Clippy and diff checks. Separate
cleanup receivers receive preserved reports after task handles are dropped;
the selected input failure aborts all handles before closing all handles.
Independent Tester reproduced these results at the same source revision;
final-head acceptance at `264a12f` passed and PR #73 integrated as `14d5fb5`.
This is Unit/Contract only;
it adds no public API, default scheduling, JVM host or loader claim.

T-0013/S04 now implements a live comparison of two explicitly defined empty-job
projections. It compares actual callbacks and cleanup counts for supplied plans,
not default fan-out, raw instrumentation identity or general lifecycle behavior.
Primary acceptance at `98b6cac` passed both comparisons, 13 raw-evidence controls,
20 offline workspace tests (three intentional live ignores), format and strict
Clippy. Independent Tester reproduced these results; final-head acceptance at
`09ac159` passed and PR #74 integrated as `68d848c`. Evidence is
Differential for those two projections only; zero tasks remain Unit/Contract.

S05 now observes a normal control and one selected output commit exception.
No output-failure Rust policy is added before that evidence. T-0013 Current SP
is refined 13 to 21 to include output-failure verification and remaining lifecycle
uncertainty; Initial SP stays 8 and the parent remains open.

S05 primary acceptance at `876e861` passed the normal/selected commit-failure
Demo and 23 controls. Failure aborted only the failed handle, closed all, and
fresh cleanup captures received input 1/output 7 reports in the observed 1/8
plan. Independent Tester reproduced these results. This is Reference Observation
/ Integration only; final-head acceptance at `6508221` passed and PR #75
integrated as `2901c31`, with no Rust output-failure policy added by that slice.

ADR-0009 now permits T-0021/S04's private last-commit failure candidate with
typed scope errors and retained reports. Primary and independent source
acceptance passed at `b8dbc77`: seven local tests, two existing live projections,
13 negative controls and workspace 21 passed/three intentionally ignored;
format, explicit included-file Rust 2024 formatting and strict Clippy passed.
Final-head acceptance at `d885ba2` passed; PR #76 integrated as `b5cfb87`.
Evidence is Unit/Contract plus existing regression,
not a new output-failure Differential result; earlier/middle
failure positions and general recovery remain outside its reference coverage.
Current T-0021 SP is refined 5 to 8; Initial SP stays 5 and parent gates stay open.

T-0013/S06 now has a reviewed comparison packet for normal and selected
last-output-commit failure. It changes only test infrastructure. Primary source
acceptance at `a284f8b` passes both live projections (normal 44/failure 43 events,
cleanup reports 1/8 and 1/7 in the observed 1/8 plan), 31 raw controls, two local
bridge tests and unchanged S04 live regression. Workspace tests pass 23 with
four intentional ignores; formatting, strict Clippy and syntax checks pass.
Independent Tester reproduced these results at the same source revision;
final-head acceptance at `7d90f5d` passed and PR #77 integrated as `3b16aaf`.
T-0021 remains requeued without closing its parent.

T-0013/S07 is prepared as a reference-only first/middle commit observation.
Its two-stage packet requires raw capture review before post-failure assertions;
no Rust policy is selected. Current SP is refined 21 to 34, Initial remains 8:
S01–S06 used 18 accepted SP, with position observation, native comparison and
cleanup/recovery uncertainty still remaining. This is forecast, not completion.

S07 initial capture at `fb26813` observed first failure aborting outputs 0–7,
and middle failure at 4 retaining commits 0–3 then aborting 4–7. Both close all
outputs; cleanup reports are input 1/output 0 and input 1/output 4. PM inspected
the full raw logs and recorded Stage B expectations. This is initial reference
observation only, with no Rust change.

S07 primary and independent source acceptance at `76dbab0` pass the exact
three-case Demo, 57 diagnostic-specific semantic controls, two artifact controls
and unchanged S05 full regression. Both reproduce the observed abort suffix and
retained report counts. Shell syntax, source hashes and diff checks pass.
Evidence is Reference Observation / Integration only. Final-head acceptance at
`133cddb` passed; PR #78 integrated as `14cc2a6`. That reference slice added
no Rust behavior. ADR-0010 now permits the bounded T-0021/S05 abort-suffix
candidate, preserving existing live regressions. Current T-0021 SP is refined
8 to 13; Initial stays 5. Parent completion and new Differential claims remain
separate gates.

T-0021/S05 primary and independent source acceptance pass at `f2d9755`.
The private coordinator preserves committed reports, aborts the failed and
unattempted suffix and closes all handles. Three new local cases verify complete
typed traces/tokens/cleanup. Exact Demo passes 12 local tests, S04/S06 four
existing live projections and their 13/31 raw controls. Workspace tests pass
26 with four intentional ignores, plus formatting and strict Clippy. Evidence
is Unit/Contract plus existing Differential regression only. Final-head exact
Demo passed at `02673ba`; PR #79 integrated as `d36cf28`. T-0021 stays open and
returns to Backlog. T-0013/S08 now prepares three selected live commit-position
comparisons without changing runtime policy. Current 34 / Initial 8 SP remain
unchanged; the 3 SP slice fits the current forecast.

S08 primary and independent source acceptance pass at `4c591a0`: three selected
normal/first/middle live projections, 57 raw controls, three local Rust tests,
and unchanged S04/S06 regressions. Workspace 29 passed/five intentional ignores
and strict quality checks pass. Runtime policy is unchanged; evidence is
Unit/Contract plus selected Differential only. Final-head acceptance and PR
integration remain required; parent #16 remains open.

S08 final-head exact Demo passed at `ff8dec0`; PR #80 integrated as `de38a44`.
Its three selected Differential projections are accepted, not a general recovery
contract. Parent T-0013 returns to Backlog and remains open. T-0012/S07 now
prepares two isolated PageBuilder/test-local collector/PageReader observations
under its [packet](provenance/T-0012-page-value-probe.md), before selecting any
Rust value representation. Only Boolean/Long/String and explicit null inputs
are selected. No runtime, public API, Page encoding or transfer claim follows.

S07 initial capture at `66ef66a` returned two successful reference executions:
empty had zero Pages/rows; typed-null had one Page and three ordered rows with
true/MAX/empty text, false/MIN/newline-and-lambda text, then three explicit nulls.
Primary reviewed the complete raw capture before authorizing semantic guards
at `ec558d1`. This is initial observation, not source acceptance or a selected
Rust representation. Full negative gates, independent reproduction and final
integration remain required.

S07 primary and independent source acceptance pass at `1e7d5c9`: two fresh
Page observations, 39 diagnostic-specific repaired raw controls, two artifact
negatives and unchanged S06 three-schema comparison. Workspace 29 passed/five
intentional ignores, formatting, strict Clippy and Bash syntax pass. Evidence
is selected Reference Observation / Integration plus validator Unit/Contract;
no Rust values, production transfer or new Differential result. Final-head
acceptance and integration remain required; parent and phase gates stay open.

S07 final-head Demo passed at `3b95ecd`; PR #81 integrated as `203d7da`.
Its two bounded reference observations are accepted. T-0012/S08 implements
private owned Null/Boolean/Signed64/Text records under ADR-0011. At frozen source
`914ad2e`, primary and independent acceptance pass two selected getter-result comparisons,
18 raw controls, six local storage/transport tests and the unchanged three-schema
regression. Workspace 35 passed/six intentionally ignored, formatting and strict
Clippy pass. Final-head Demo passed at `332c721`; PR #82 integrated as `b428305`.
Schema coupling, physical encoding, public API and production transfer remain
outside this slice; parent and phase delivery gates stay open. S09 prepares a
separate reference-only double-value observation, with a capture-before-
expectations gate and no Rust Float64 or equality-policy change.
S09 primary and independent source acceptance pass at `3f18966`: two selected
reference double fixtures (114/93 events), 45 diagnostic-specific raw controls,
two artifact controls, unchanged S08/S06 regressions and strict quality checks.
Selected finite/subnormal/signed-zero/null/infinity/NaN bits are preserved in
these observations. Evidence is Reference Observation / Integration plus
validator Unit/Contract, not a native Float64 or numeric equality decision.
PR #91 is in Review; final-head acceptance and integration remain required.

S09 final-head Demo passed at `59f1b2e`; PR #91 integrated as `34757c8`.
Its selected reference observations are accepted; parent T-0012 remains open.
S10 implements the private bit-preserving representation permitted by ADR-0012.
Frozen source `3df2a88` passed implementer and independent Tester acceptance:
12 selected double/null cells, five bridge controls and unchanged S09/S08/S06
regressions. Its private equality is storage identity, not numeric equality.
Primary and final-head acceptance passed; PR #93 integrated as `742274f`.
The S10 slice is Done with Unit/Contract and the two selected Differential
projections. No public value, schema coupling, physical encoding, whole-domain
or production claim follows; parent and delivery gates remain open.

T-0021/S06 implements the private synchronous owned-record handoff permitted by
ADR-0013. Frozen source `8fe820b` passes primary and independent exact Demo:
five handoff tests, 46 workspace passes/seven intentionally ignored live tests,
format and strict Clippy. It moves records directly, preserves selected bits and
typed errors, and stops callbacks on the first failure. Final PR-head acceptance
passed at `8cb13ff`; PR #96 integrated as `56ef9e9`. S06 is Done.
Evidence is Unit/Contract only, not a public
API, schema/lifecycle policy, resource guarantee or Embulk compatibility claim.

T-0012/S11 Stage A at `a95e350` captured five outcomes and 289 events,
independently reproduced and fully reviewed by PM. Matching/null/duplicate-name
cases read selected values; fresh unset text fails at addRecord and string-to-long
misuse fails at the setter. Stage B automation passes at `b556ce0`: five exact vectors, 39 repaired-copy
controls and two artifact controls. Primary and separate reproduction pass;
final-head Demo passed at `da7e50f`; PR #99 integrated as `413f837`.
The bounded observation slice is Done; parent contracts remain open.
These diagnostic observations do not select native defaults or validation.
A separate reviewed decision must precede schema-bound record implementation.

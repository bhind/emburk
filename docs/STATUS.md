# Current status

Last updated: 2026-09-06

Development state: `bootstrap`

## Implemented facts

- The repository contains a minimal Rust binary and Cargo project suitable for
  verifying the development environment. T-0021/S01 establishes a virtual
  workspace with an inward-only `emburk-cli -> emburk-core` dependency while
  retaining the explicit not-yet-a-loader smoke test.
- The binary does not load Embulk configuration, transfer records, execute
  plugins, or implement transaction and resume behavior.
- No native, Java-hosted, or JRuby-hosted plugin is implemented or verified.
- Thirteen selected private raw-scalar outcomes match the pinned Embulk
  executable in a live differential test. No full configuration, plugin,
  data-transfer, or performance claim has passed its evidence gate.
- The product strategy selects a compact Rust execution core, optional
  out-of-process compatibility hosts, explicit versioned compatibility, and a
  native File-to-File vertical slice as the first runtime milestone.
- Governance defines stable T-IDs, canonical repository records, role and
  mutation ownership, a two-item combined `In Progress`/`Review` WIP limit,
  traceable upstream observation, and separate license and patent-risk
  review.

## Delivery queue

T-0021 (`In Progress`) and T-0012/S04 (`In Progress`) are the only active work
items. The combined WIP is two of two; no item is `Ready` or `Blocked`.

| Item | State | Purpose |
|---|---|---|
| T-0002 | Done | Established canonical records and stable IDs |
| T-0011 | Done | Pinned Embulk core and SPI references; no external plugin admitted |
| T-0003 | Done | Enforce Project discovery, packet checks, and WIP auditing |
| T-0004 | Done | Established Project delivery operations and burndown inputs |
| T-0012/S04 | In Progress | Live comparison of 13 supported scalar outcomes; S01–S03 integrated |
| T-0021 | In Progress | Workspace skeleton (S01, PR #58) and runtime design proposal (S02) |

All other stable tasks in `TODO.md` remain `Backlog`. Parent epics are
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
Issue / 5 Story Points after integration. The Action is installed and active;
scheduled and ready-for-review executions still require the repository owner
to add the `PROJECTS_TOKEN` secret, so no hosted-run success is claimed.

## Evidence and non-claims

Current evidence includes repository checks, private scalar Unit/Contract tests,
and a live comparison of 13 selected typed outcomes. Strategy and planning
records are not runtime evidence.
In particular, the repository does not yet demonstrate:

- Embulk-compatible configuration, schema, value, lifecycle, or resume
  behavior;
- bounded parallel ETL or File-to-File transfer;
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
Independent Tester acceptance reproduced the same results; PR integration
remains pending. See the
[S04 evidence record](provenance/T-0012-live-scalar-differential.md).

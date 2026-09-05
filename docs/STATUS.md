# Current status

Last updated: 2026-09-05

Development state: `bootstrap`

## Implemented facts

- The repository contains a minimal Rust binary and Cargo project suitable for
  verifying the development environment. A unit smoke test fixes its explicit
  not-yet-a-loader status message.
- The binary does not load Embulk configuration, transfer records, execute
  plugins, or implement transaction and resume behavior.
- No native, Java-hosted, or JRuby-hosted plugin is implemented or verified.
- No compatibility or performance claim has passed an evidence gate.
- The product strategy selects a compact Rust execution core, optional
  out-of-process compatibility hosts, explicit versioned compatibility, and a
  native File-to-File vertical slice as the first runtime milestone.
- Governance defines stable T-IDs, canonical repository records, role and
  mutation ownership, a two-item combined `In Progress`/`Review` WIP limit,
  traceable upstream observation, and separate license and patent-risk
  review.

## Delivery queue

T-0021 is the only active task. No work item is currently `Ready`, `Review`,
or `Blocked`.

| Item | State | Purpose |
|---|---|---|
| T-0002 | Done | Established canonical records and stable IDs |
| T-0011 | Done | Pinned Embulk core, SPI, and admitted plugin reference versions |
| T-0021 | In Progress | Workspace skeleton (S01, PR #58) and runtime design proposal (S02) |

All other stable tasks in `TODO.md` remain `Backlog`. Parent epics are
unpointed. The private [Emburk Delivery Project](https://github.com/users/bhind/projects/2)
is the coordination mirror. Its 52 items, lifecycle states, initial estimates,
roles, dependencies, workstreams, evidence classes, and views were reconciled
to the repository records on 2026-09-05.

## Evidence and non-claims

Current evidence is limited to repository inspection and the existing minimal
Rust development path. Strategy and planning records are not runtime evidence.
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

T-0021/S01 remains an unmerged implementation candidate in
[PR #58](https://github.com/bhind/emburk/pull/58). T-0021/S02 provides a
[runtime design proposal](RUST_RUNTIME_DESIGN.md), configuration/value fixture
worksheet, lifecycle responsibilities, and explicit uncertain commit outcomes.
This is Planning evidence only. T-0012/T-0013 contracts and differential
verification remain prerequisites to completing the parent task.

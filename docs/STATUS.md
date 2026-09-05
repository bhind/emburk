# Current status

Last updated: 2026-09-05

Development state: `bootstrap`

## Implemented facts

- The repository contains a minimal Rust binary and Cargo project suitable for
  verifying the development environment.
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

No work item is currently `Ready`, `In Progress`, `Blocked`, or `Done`.

| Item | State | Purpose |
|---|---|---|
| T-0002 | Review | Establish canonical records and stable IDs |
| T-0011 | Review | Pin Embulk core, SPI, and admitted plugin reference versions |

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

The shared bootstrap integration for `T-0002` and `T-0011` is under review in
[Draft PR #53](https://github.com/bhind/emburk/pull/53). Neither item becomes
`Done` until the reviewed revision passes, the pull request is integrated, and
the Issues and repository records are reconciled.

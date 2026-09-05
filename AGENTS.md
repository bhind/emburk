# Repository instructions

These rules apply to every change in this repository, including work performed
by coding agents.

## Start here

Before changing Emburk, inspect the relevant executable code and tests, then
read `docs/STATUS.md` and `TODO.md`. Use `README.md` for the product overview
and follow links to architecture, compatibility, roadmap, workflow, and
decision records only when the task requires them.

All repository text, source comments, commit messages, Issues, and Project
metadata must be written in English.

## Preserve project memory

Documentation is part of the implementation. Keep these records synchronized:

- implemented facts: `docs/STATUS.md`;
- actionable work and stable task identifiers: `TODO.md`;
- delivery gates: `docs/ROADMAP.md`;
- component boundaries: `docs/ARCHITECTURE.md`;
- supported behavior and plugin status: `docs/COMPATIBILITY.md`;
- accepted architectural decisions: `docs/decisions/ADR-*.md`;
- third-party source observations and license-aware provenance:
  `docs/provenance/`.

GitHub Issues and Projects are coordination views. They do not override code,
tests, repository records, or acceptance evidence.

When records disagree, resolve them in this order and correct the stale record:

1. executable code and tests;
2. `docs/STATUS.md`;
3. accepted ADRs;
4. `docs/ARCHITECTURE.md` and `docs/COMPATIBILITY.md`;
5. `docs/ROADMAP.md` and `TODO.md`;
6. GitHub coordination metadata.

## Stable identifiers and completion

- Tasks use monotonically allocated `T-0001` identifiers.
- Architectural decisions use monotonically allocated `ADR-0001` identifiers.
- Independently acceptable slices may add `/S01`, `/S02`, and so on to a
  parent T-ID without creating another canonical task.
- Never reuse an abandoned or deleted identifier.
- Parent epics are unpointed. Story Points belong only to independently
  acceptable child tasks or slices.

Before declaring a task complete, run its stated `Demo Command` at the
reviewed revision, record the evidence class and remaining non-claims, reconcile
STATUS/TODO/ROADMAP/COMPATIBILITY and relevant ADR/provenance records, and
confirm that the associated pull request is integrated. Conversation, Project
metadata, or a subagent report alone is not completion evidence.

## Branch and pull-request workflow

Inspect `git status` before changing files and preserve unrelated work. Use one
dedicated branch per independently reviewable change:

```text
<type>/<record-id>-<short-slug>
```

Allowed types are `feat`, `fix`, `docs`, `test`, `build`, `chore`, and
`research`. Use lowercase identifiers and kebab-case slugs, for example
`feat/t-0021-bounded-scheduler`. Changes to `main` should arrive through a pull
request. Do not rewrite published history or discard another worktree's edits.

## Agent orchestration

The Project Manager owns task classification, priority, canonical records,
acceptance criteria, integration, and final status transitions. `Jitro` is the
Project Manager's call sign; a request to ask or summon Jitro routes to the
project-scoped `emburk-project-manager` custom agent. Specialist roles operate
within explicitly assigned boundaries.

- At most two Project items may be `In Progress` or `Review` in total.
- Parallel tracked-file mutation is permitted only for independently acceptable
  tasks with disjoint files, artifacts, tests, and evidence paths.
- Each mutation packet names the real Issue, full T-ID, branch, owner, exact
  file allowlist, dependencies, artifacts, `Demo Command`, evidence class,
  stop rule, and non-claims.
- Implementers do not edit canonical project records unless the Project Manager
  explicitly assigns those files.
- Testers and reviewers remain read-only with respect to tracked files.
- Subagents return paths, commands, exit status, evidence class, findings, and
  unresolved risks. The primary agent verifies their work before integration.
- Project record reconciliation and final acceptance remain serial even when
  implementation and review can run concurrently.

See `docs/GOVERNANCE.md` for role definitions and `docs/WORKFLOW.md` for the
full lifecycle.

## Embulk reference and intellectual-property boundary

Emburk is a traceable, license-aware reimplementation. Public Embulk behavior,
documentation, configuration examples, test observations, and documented
architecture may be studied to define compatibility. Do not mechanically
translate or copy upstream implementation code.

Before external code, protocol details, or a patented mechanism influences an
implementation:

- record the exact source, version or commit, locator, access date, and license;
- distinguish observed behavior from implementation ideas;
- distinguish copyright/license permission from patent licensing and freedom
  to operate;
- preserve applicable Apache-2.0 notices for material that is actually reused;
- treat patent, standards, redistribution, and provenance gaps as `unreviewed`,
  not cleared;
- escalate material uncertainty to the Project Manager and qualified counsel
  before adoption.

The Librarian role performs read-only source and IP-risk triage. It
does not provide legal advice, decide infringement, declare freedom to operate,
or approve implementation. Security reports and private legal analysis must
not be copied into public Issues or Project fields.

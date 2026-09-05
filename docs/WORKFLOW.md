# Development workflow

Status: active

## Before a change

1. Read `AGENTS.md`, inspect `git status`, and preserve unrelated changes.
2. Map the work to an existing T-ID, roadmap gate, and relevant ADR or
   provenance record. Search `TODO.md` before allocating a new identifier.
3. Confirm that the GitHub Project item and repository records agree on status,
   priority, dependencies, and scope.
4. Refine the item to the Definition of Ready in `docs/SPRINTS.md`.
5. Create or reuse a real open Issue for every epic and actionable work item,
   label epics `epic` and actionable items `work-item`, add it to the Project,
   and record this packet before `Ready`:
   `Authority`, `Dependencies`, `Mutation owner`, `Allowlist`, `Artifacts`,
   `Acceptance`, `Evidence class`, `Stop rule`, and `Non-claims`.
6. Create the dedicated task branch and move the item to `In Progress` only
   after all metadata is populated.

The Project Manager performs lifecycle transitions. A partial remote update
must fail safe: leave the item outside the next lifecycle status, report the
fields that changed, and reconcile before implementation continues.

Project-scoped Codex roles live under `.codex/agents/`. Ask for `Jitro` to route
Project Manager work. Personal endpoints, approval choices, and concurrency
limits remain in the ignored `.codex/config.toml` rather than shared agent
definitions.

Project delivery configuration and read-only snapshots are audited with
`python3 scripts/project_delivery.py audit`. GitHub built-in workflows remain
the first choice for item-added, close, merge, and linked-pull-request events.
Use a custom Action only for a verified gap such as ready-for-review or an
ideal-line daily snapshot, following `docs/PROJECT_OPERATIONS.md`.

## Kanban lifecycle

```text
Backlog -> Ready -> In Progress -> Review -> Done
                         |            |
                         +-> Blocked <-+
```

- `Backlog`: ordered work that is not yet pullable. Epics and low-confidence
  forecasts may remain unpointed.
- `Ready`: independently acceptable, fully packeted, dependency-clear work.
- `In Progress`: actively owned mutation on a matching branch and open Issue.
- `Review`: implementation is complete, a pull request is open, and the exact
  reviewed revision is undergoing acceptance and record reconciliation.
- `Blocked`: work was Ready or active but has an exact blocker, clearing
  condition, and responsible owner. Removing a card from view is not a blocker.
- `Done`: acceptance passed, required records are reconciled, the pull request
  is integrated, and the Issue is closed.

At most two items may be `In Progress` or `Review` combined. Two mutation lanes
are allowed only when file, artifact, test, evidence, correctness, and rollback
boundaries are disjoint. Otherwise use one mutation lane and one independent
test or review lane.

## During a change

- Stay within the Issue's allowlist and preserve other worktrees.
- Keep external types and runtimes behind Emburk-owned versioned adapters.
- Resolve plugin dependencies during installation or preparation, never as an
  implicit side effect of executing a job.
- Record upstream observations in provenance without copying implementation
  text. Stop if a license, notice, redistribution, patent, or reimplementation
  boundary becomes materially ambiguous.
- Add regression tests for corrected defects. Retain negative results and
  unsupported cases rather than converting them into success claims.
- Update STATUS, TODO, ROADMAP, COMPATIBILITY, ADRs, and provenance in the same
  coherent change when their facts change.

## Review and completion

Before moving an item to `Review`, verify that the pull request head matches the
task branch, its diff stays inside the mutation packet, its body links the real
Issue, and its test and documentation evidence are current.

At the reviewed revision:

1. run the task's exact `Demo Command` and relevant format, lint, unit,
   integration, differential, interruption, and security checks;
2. record command, exit status, revision, platform/tool versions, test counts,
   evidence class, and remaining non-claims;
3. have the Tester reproduce the acceptance path when the task changes runtime
   behavior, compatibility, transaction semantics, or release claims;
4. request Performance Reviewer, Security & Supply-chain Reviewer, and
   Librarian review when their risk surfaces are affected;
5. reconcile canonical records and resolve review findings;
6. integrate the pull request, confirm the Issue is closed, then move the item
   to `Done` last.

Story Points are awarded only for accepted `Done` slices. No partial points are
awarded. A failed acceptance remains visible with its current status and exact
failure boundary.

## Commit messages

Keep one coherent change per commit and use:

```text
type(scope): imperative summary

Optional rationale and boundary notes.

Records: STATUS, TODO, ROADMAP, COMPATIBILITY, ADR-000N, provenance, or none
Evidence: exact command and result, or not run
```

Allowed types are `feat`, `fix`, `docs`, `test`, `build`, `chore`, and
`research`. Write the subject in English without a trailing period.

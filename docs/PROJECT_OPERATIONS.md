# GitHub Project operations

Status: active

The private GitHub Project linked from this repository is the delivery view for
Issues and pull requests. Repository code, tests, and canonical records remain
authoritative. Automation discovers the linked Project at runtime and fails
closed if discovery is ambiguous; the owner login, Project number, node IDs,
and URL are never embedded in repository automation.

## Field model

| Planning concept | Project field | Ownership |
|---|---|---|
| Lifecycle | `Status`: Backlog, Ready, In Progress, Blocked, Review, Done | Automated at supported events; Project Manager for exceptions |
| Type | `Work Type` | Project Manager during refinement |
| Iteration | `Iteration`, weekly from Monday | Project Manager during commitment or rollover |
| Estimate | `Story Points`; `Initial SP` preserves commitment | Project Manager during refinement |
| Priority | `Priority` | Project Manager |
| Person | GitHub `Assignees` | Maintainer or assignee |
| Authority | `Owner Role` and `Support Roles` | Project Manager |
| Schedule | `Start date` and `Target date` | Project Manager when dates are evidence-based |

Do not create duplicate `Type`, `Estimate`, or `Owner` fields. The established
fields above already carry those meanings and preserve the distinction between
a person and an authority role. Parent epics remain unpointed.

## Saved views

| View | Purpose |
|---|---|
| Current iteration | Board filtered by `Iteration:@current` |
| Backlog | Uncommitted work with Status Backlog |
| In progress | In Progress and Review work |
| Blocked | Exact blockers and clearing conditions |
| By owner | Non-Done work with Assignees and Owner Role visible |
| Roadmap | Non-Done work on the iteration/date timeline |
| Recently completed | Done items closed in the last 30 days |
| Needs iteration | Items with no Iteration |
| Needs estimate | Non-epic items with no Story Points |

GitHub filters cannot express OR across two different fields, so missing
Iteration and missing estimate are intentionally separate views.

## Insights and burndown

GitHub Insights provides current and historical charts. Configure these saved
charts in the Project UI, all filtered by `Iteration:@current`:

1. **Remaining issues**: historical chart, X-axis Time, Y-axis item count; read
   the Open series as remaining and Completed as completed.
2. **Remaining Story Points**: historical chart, X-axis Time, Y-axis sum of
   Story Points; read the Open series as remaining estimate.
3. **Completed throughput**: historical chart, X-axis Time, Y-axis item count
   or sum of Story Points; read the Completed series.
4. **Status distribution**: current chart grouped by Status. GitHub does not
   expose historical custom-Status series through its public Project API.

Insights does not provide a configurable ideal line. The read-only command
below emits one idempotent CSV row per day, a JSON summary, and two SVG charts
with dashed ideal and solid actual lines:

```sh
python3 scripts/project_delivery.py snapshot --output-dir PATH
```

The issue burndown falls as Issues reach Done. The point burndown falls by
their Story Points. The ideal line is linear from the first captured total to
zero at the end of the Iteration; it is a planning reference, not a prediction.
Scope added after the first snapshot raises the actual line but does not rewrite
the committed baseline. Completed count and points are recorded alongside a
daily Status distribution. Pull requests are excluded from totals so linked
Issue and PR cards are not counted twice.

## Automation boundary

Enabled built-in workflows cover item-added defaults, closed items, merged pull
requests, and pull requests linked to Issues. The repository demonstrated that
closing a linked Issue moves its Project item to Done. Use closing keywords in
pull request descriptions so the Issue, pull request, and Project converge.

Iteration, Story Points, Priority, Assignees, Owner Role, Start date, and Target
date require human judgment. Blocked also requires an exact blocker and
clearing condition. GitHub has no public API for creating Insights charts or
configuring built-in workflows, so those UI settings require direct read-back.

The daily snapshot requires repository automation plus a user-Project
credential. `GITHUB_TOKEN` cannot access a user Project. Use a repository
secret named `PROJECTS_TOKEN` containing
a fine-grained credential limited to this repository and Projects access, give
the workflow only `contents: write`,
and store the daily history on a dedicated `project-metrics` branch. Never
print, persist, or place the credential in command arguments or artifacts.

The snapshot workflow runs at 00:17 UTC and can also be dispatched manually
from the default branch. It refuses non-default refs. A zero-permission gate
checks whether the Project credential is configured without printing it. When
the secret is absent, the workflow succeeds with a non-sensitive job summary
and skips all Project reads and mutations. When present, the secret is exposed
only to the gate and the audit, snapshot, or review step that requires it. The
snapshot path accepts only schedule and manual-dispatch events; pull request
events cannot invoke it. It fails before writing if Project discovery or
configuration audit fails.
Ready-for-review automation uses
`pull_request_target`, checks out only the default branch without persisting
credentials, accepts only numeric PR identifiers, and runs only for OWNER,
MEMBER, or COLLABORATOR authors targeting the default branch from a branch in
the same repository. Fork pull requests never receive the Project mutation
credential. It updates only one closing-linked Issue whose current Status is In
Progress; every ambiguous or conflicting case fails before mutation and
requires Project Manager reconciliation. The
`project-metrics` branch must exist before the snapshot workflow is enabled; a
missing branch fails safely.

## Verification

Run:

```sh
python3 scripts/project_delivery.py audit
python3 -m unittest tests.test_project_delivery
git diff --check
```

The audit checks required fields, views, and enabled built-in workflow names by
live API read-back. It does not claim UI-only workflow mappings or Insights
chart configuration that the public API cannot expose.

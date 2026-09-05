# Project governance

Status: active

Emburk combines repository-owned project memory with a GitHub Project used as
the live delivery queue. Code, tests, STATUS, TODO, ROADMAP, COMPATIBILITY, ADRs,
and provenance records remain authoritative. The board communicates work; it
does not create implementation facts.

## Roles

Roles are responsibility boundaries, not full-time staffing assignments. One
agent may fill more than one role serially, but must preserve each role's
authority and write limits.

Jitro is the Project Manager's call sign. Vreji is the Librarian's call sign.
Call signs identify the project-scoped agents; Project fields retain the role
names below.

| Role | Responsibility | Write boundary |
|---|---|---|
| Project Manager | Scope, stable IDs, priority, acceptance, canonical records, integration, and Project transitions | May integrate all assigned project files; final authority remains with the repository owner |
| Rust Core Implementer | Rust execution core, configuration, data model, scheduler, transaction, and resume behavior | Only the task packet's explicit source and test allowlist |
| Compatibility Host Implementer | Versioned plugin protocol and isolated JVM/JRuby compatibility hosts | Only the task packet's explicit host, protocol, and test allowlist |
| Plugin Implementer | Rust-native built-ins and independently specified plugin behavior | Only the named plugin and tests |
| Tester | Independent reproduction, differential fixtures, interruption tests, and clean-environment verification | Read-only for tracked files; ignored logs and build artifacts are allowed |
| Performance Reviewer | Benchmark design, fairness, resource accounting, noise, and claim review | Read-only |
| Security & Supply-chain Reviewer | Isolation, supply chain, credentials, paths, unsafe code, serialization, and failure boundaries | Read-only |
| Librarian | Context routing, upstream provenance, license inventory, prior-art similarity, and patent/IP-risk triage | Read-only; no legal clearance or implementation approval |

Add a specialized role only when a recurring responsibility cannot be expressed
through these boundaries. Role names belong in the Project `Owner Role` and
`Support Roles` fields; GitHub assignees identify people, not authority.

## Decision and evidence governance

Create an ADR when a change accepts or supersedes an architectural invariant,
public interface, compatibility boundary, dependency policy, process-isolation
choice, or external-source adoption rule. Accepted ADRs are superseded rather
than silently rewritten.

Use these evidence classes consistently:

- `Planning`: scope or design only;
- `Unit/Contract`: behavior or a contract verified in the local test boundary;
- `Differential (Embulk)`: the same fixture compared against a pinned Embulk reference;
- `Integration`: verified against a real external service or plugin artifact;
- `Benchmark`: reproducible performance or resource measurement;
- `Release`: packaged delivery evidence including required notices and metadata.

An evidence class describes what was tested, not the strength of unrelated
claims. A hosted plugin is not a Rust-native port. Passing a local fixture is
not integration evidence. Throughput is not a product claim until the benchmark
gate in the roadmap is met.

## External-source governance

The Librarian role returns a source packet before implementation when work depends
on Embulk internals, third-party plugins, wire formats, patents, standards, or
vendor-specific behavior. The packet records:

- technical similarity and the exact source/version/locator;
- license, notice, redistribution, and access status;
- any known patent-family or standards reference and relevant jurisdiction;
- what was observed, what may be reused, and what must be independently
  specified;
- contradictions, missing searches, adoption hazards, and `unreviewed` gaps.

Public availability, an open-source license, an expired-looking patent, or an
absent search result does not establish freedom to operate. Material reuse or
an unresolved adoption risk requires an explicit Project Manager decision and,
when appropriate, qualified legal review. Compatibility tests should prefer
black-box inputs and outputs over implementation-derived structure.

## GitHub coordination

The [Emburk Delivery Project](https://github.com/users/bhind/projects/2) is
private. It contains a Product Backlog and an execution Kanban. Every epic and
actionable item uses a real Issue and carries its full T-ID in the title. Epics
use the `epic` label; actionable items use `work-item` and contain the work
packet defined in `docs/WORKFLOW.md`. Backlog state does not waive this
traceability requirement.

Apply `type:decision` when acceptance requires choosing or revising a
compatibility baseline, architecture boundary, governance policy, plugin
priority, or later-horizon scope. Apply `legal-review` only to items that
require explicit license, notice, redistribution, patent, or trademark review.

Remote publication, Project visibility changes, paid services, new credentials,
destructive actions, and legal-clearance claims always remain owner decisions.

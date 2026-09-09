# Qwen-assisted development

This document defines how Emburk uses the Windows-hosted Qwen3-Coder service as
an implementation assistant while keeping Codex and the Project Manager focused
on higher-level engineering judgment.

Qwen is advisory. It is not a Project role, does not own files, does not mutate
the repository, and cannot approve a change or supply completion evidence.

## Responsibility split

Codex and the Project Manager retain responsibility for:

- problem framing, product semantics, and compatibility intent;
- architecture, component boundaries, and public interfaces;
- licensing, provenance, patent, security, and operational risk decisions;
- task packets, file ownership, acceptance criteria, and verification plans;
- final diff inspection, evidence assessment, integration, and status changes.

Qwen is the default first-pass assistant for eligible bounded work such as:

- explaining repository-original code selected by an implementer;
- triaging a compiler, test, or runtime error;
- proposing a local implementation or test approach within an assigned packet;
- identifying edge cases and missing tests;
- reviewing a permitted diff before the authoritative review.

The assigned implementer remains accountable for every resulting line and must
understand, inspect, and independently verify it.

## Eligibility and information boundary

A Qwen request is eligible only when its purpose is bounded and every supplied
file appears in the task packet's separate `Qwen context allowlist`. The
mutation allowlist grants write ownership and does not grant permission to send
a file to the model. Send only repository-original, non-sensitive material that
is necessary for the request.

Never send:

- `.codex`, `.git`, credentials, tokens, environment files, or local machine
  configuration;
- private security reports, legal analysis, or confidential provenance notes;
- upstream implementation source or mechanically translated code;
- build outputs, generated artifacts, dependency caches, or large files.

The CLI enforces a conservative path and size policy, but that enforcement does
not replace human classification. When uncertain, omit the material and ask the
Project Manager or Librarian to resolve the boundary.

The CLI normally adds `AGENTS.md` and the workspace `Cargo.toml`. The task's
Qwen context allowlist must name those files when they are needed. Otherwise,
pass `--no-project-context` and add only explicitly allowed `--context` or
command-specific files.

## Operating loop

1. Codex or the Project Manager defines the outcome, boundaries, acceptance
   criteria, mutation allowlist, Qwen context allowlist, evidence class, and
   `Demo Command`.
2. For eligible work, the implementer attempts one useful Qwen first pass with
   `explain`, `error`, `fix`, or `review` before completing the low-level work.
3. The implementer classifies the response as `used`, `revised`, or `rejected`
   and records the prompt scope, elapsed time, rationale, and any material risk.
4. The implementer manually produces the repository change. Qwen output is
   never applied automatically.
5. The implementer runs deterministic checks such as formatting, compilation,
   linting, and focused tests. Qwen's answer is not evidence.
6. Codex reviews the actual diff and evidence against the higher-level intent.
7. The Project Manager runs or confirms the task's `Demo Command`, reconciles
   records, integrates the pull request, and performs the final status change.

Qwen is deliberately non-blocking. If it is unreachable, exceeds the configured
timeout, or produces an unusable answer, record that outcome once and continue
with the assigned work. Repeated retries are not a delivery gate and do not
consume a separate Kanban item.

## Decision exclusions

Qwen must not decide or approve:

- product scope, architecture, or an ADR;
- Embulk compatibility or behavioral support claims;
- licensing, patent, provenance, privacy, or security conclusions;
- destructive commands, external publication, or repository integration;
- test sufficiency, completion, or release readiness.

These exclusions keep Codex focused on decisions whose consequences span
components or releases while using Qwen where local implementation feedback is
most useful.

## Recording a consultation

For material consultations, add a concise entry to the task log or provenance
record. Record the command mode, file names or prompt scope, elapsed time,
response disposition, and independent verification. Do not copy a sensitive
prompt or a long generated response into repository records.

Example:

```text
Qwen consultation: review of src/example.rs and tests/example.rs; 42 s;
disposition: revised (kept the boundary-case idea, rejected the API change);
verification: cargo fmt --check, cargo check, and focused tests passed.
```

See `docs/DEVELOPMENT.md` for CLI commands and environment configuration.

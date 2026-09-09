# T-0080 Qwen-assisted workflow

Status: In Progress

## Purpose and authority

Issue #132 authorizes an operational policy that moves Codex and Project
Manager attention toward requirements, architecture, boundaries, risk,
acceptance, and integration while making the existing Qwen3-Coder CLI the
default non-blocking first pass for eligible low-level implementation work.

The change is limited to repository instructions, project-scoped role prompts,
workflow and development documentation, static policy tests, and canonical
records. It changes no runtime, Cargo dependency, compatibility behavior, or
public API.

## Consultation observation

On 2026-09-09, the first attempted Qwen consultation correctly failed before
transmission because its requested context included `.codex/agents`, which the
CLI excludes. A second consultation supplied only public
`docs/WORKFLOW.md` and `docs/GOVERNANCE.md`. The Windows-hosted
`qwen3-coder:30b` service responded in 260.7 seconds.

The response suggested making the assistant expectation visible in the shared
agent and workflow configuration but did not provide a concrete or sufficiently
bounded policy. Its disposition was `revised`: the general visibility direction
was retained, while Codex independently specified the authority split,
information boundary, non-blocking behavior, response disposition, and
verification contract. No generated prose or code was copied.

After the policy draft passed its static tests, a second consultation supplied
only `docs/QWEN_ASSISTED_DEVELOPMENT.md` and `docs/WORKFLOW.md` and asked for
authority, automatic-application, data-exposure, blocking, and evidence gaps.
The service responded `POLICY_OK` in 15.6 seconds. Its disposition was `used`
as a no-finding advisory review; it caused no repository change and is not
acceptance evidence.

Codex's subsequent independent review found one issue that Qwen did not report:
the CLI's default `AGENTS.md` and `Cargo.toml` context could make a mutation
allowlist look like outbound-data permission. The final policy therefore adds a
separate `Qwen context allowlist` and requires `--no-project-context` whenever
the default files are not explicitly listed.

## Accepted boundary

- Qwen owns no repository role, file, decision, evidence, or lifecycle state.
- Eligible implementers attempt one useful first pass and continue when the
  service is unavailable, slow, or unhelpful.
- Model output is never applied automatically and is classified as used,
  revised, or rejected.
- Only explicitly permitted repository-original, non-sensitive context may be
  sent. `.codex`, upstream implementation source, credentials, private legal or
  security material, build outputs, `.git`, and large files remain excluded.
- Mutation ownership and outbound context permission are separate. The task
  packet records a dedicated Qwen context allowlist when the assistant is used.
- Codex and the Project Manager retain higher-level judgment, actual diff
  review, independent verification, integration, and final acceptance.

## Evidence plan

The task's authoritative Demo Command is:

```sh
python3 -m unittest tests.test_qwen_workflow_policy tests.test_qwen_assistant && \
  python3 scripts/project_governance_audit.py audit && \
  git diff --check
```

The evidence class is Unit/Contract plus Integration. Integration here means
the recorded advisory call reached the configured Qwen service; it is not
runtime, compatibility, correctness, or performance evidence.

## Non-claims

This policy does not show that Qwen is correct, faster than Codex, continuously
available, appropriate for confidential material, or capable of replacing
independent engineering judgment. It does not establish any Embulk
compatibility or product-runtime behavior.

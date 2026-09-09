# T-0079 Qwen development-assistant packet

## Authority and scope

The repository owner requested a local development-assistant integration on
2026-09-09. T-0079 is tracked by Issue #129 on branch
`chore/t-0079-qwen-assistant`. The Rust Core Implementer owns the tracked-file
allowlist in that Issue. There are no task dependencies because the tool does
not change the Emburk runtime or compatibility contract.

The implementation may send only deliberately selected, original Emburk
repository text to the owner's Windows-hosted Ollama service. It must provide
chat, explanation, error analysis, patch proposal, and diff-review workflows;
environment-configurable connection settings; bounded outbound-data controls;
an IntelliJ invocation path; and independent local verification. The CLI must
not apply generated patches.

## External system and initial observation

- System: owner-operated Ollama HTTP service on the private LAN.
- Native base URL: `http://192.168.10.112:11435/api`.
- OpenAI-compatible base URL: `http://192.168.10.112:11435/v1`.
- Model identifier: `qwen3-coder:30b`.
- Observation date: 2026-09-09.
- Model-list result: HTTP success; the selected model reported 30.5B
  parameters, GGUF family `qwen3moe`, quantization `Q4_K_M`, and a 262,144-token
  context length.
- Generation result: a native non-streaming `/api/chat` request with
  `keep_alive` set to `30m` returned exactly `READY`.
- Timing: 161.7 seconds total, including 117.9 seconds reported load duration.
- OpenAI-compatible result: the repository CLI used the `/v1` base URL and
  dummy key `ollama`, inferred the compatible request/response shape, and
  returned exactly `OPENAI_READY` in 3.6 seconds after the model was loaded.

This is connectivity and integration evidence only. The model metadata is the
service's self-report and has not been independently audited. The selected LAN
transport is unencrypted HTTP and must not be routed over an untrusted network.

## Source and intellectual-property boundary

No upstream Embulk implementation source, external code, protocol
implementation, or patented mechanism was consulted for this implementation.
The client uses Python's standard HTTP and JSON libraries against the endpoint
specified by the owner. The acceptance explanation selects only original
Emburk Rust code already licensed with this repository.

Qwen output is untrusted advisory text. It is not copied into the runtime by
this task and cannot establish correctness, compatibility, legal clearance,
patent licensing, or freedom to operate. The externally deployed model and its
weights are not redistributed by Emburk; their licensing and provenance remain
unreviewed for redistribution.

## Safety and acceptance boundary

The client enforces repository containment, symlink resolution, blocked private
and generated directories, credential filename checks, UTF-8 text-only input,
per-file and total-byte bounds, known-token redaction, and private-key blocking.
These are defense in depth, not authorization to transmit confidential data.

Fix proposals must contain a unified diff and are displayed with an explicit
untrusted/not-applied warning. The command surface intentionally has no apply
operation. After a person or Codex separately implements an inspected change,
the local verification command runs Rust format, check, and tests without
consulting Qwen.

## Demo Command

```sh
python3 -m unittest tests.test_qwen_assistant && \
  cargo fmt --all -- --check && \
  cargo check --locked --workspace && \
  cargo test --locked --workspace && \
  git diff --check
```

Live smoke:

```sh
python3 tools/qwen-assistant/run.py explain \
  --file crates/emburk-core/src/csv_stream.rs \
  --start 162 --end 183 \
  --prompt "Explain the behavior, invariants, and edge cases of this function. Do not propose code."
```

## Current evidence and non-claims

The initial direct connectivity and exact-response checks passed. The
repository-local CLI then sent only `AGENTS.md`, the workspace `Cargo.toml`,
and the complete original `append_field` function at
`crates/emburk-core/src/csv_stream.rs:162-183`. A response arrived in 46.6
seconds. It correctly described conditional CSV quoting and doubled embedded
quotes, but also incorrectly stated that a Rust `&str` cannot contain a null
byte. Rust strings can contain `U+0000`. No part of the response was adopted.
This result proves the guarded request/response path while demonstrating why
model text cannot be treated as correctness evidence. The final local Demo
remains pending until the implementation revision is available.

A staged-diff review redacted seven fixture-like credential patterns before
transmission and returned in 77.0 seconds. The response hallucinated an
`emburk.py` file, a Cargo command addition, and an IntelliJ plugin, then
recommended argument, patch-shape, endpoint, and redaction checks that the
supplied diff already contained. No review text was adopted. This is further
transport evidence, not a successful semantic review.

This task does not replace Codex, approve or apply model output, change runtime
behavior, establish Embulk compatibility, provide a general AI-provider API,
or claim that outbound filtering eliminates every disclosure risk.

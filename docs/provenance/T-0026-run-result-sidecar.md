# T-0026/S01 native run-result sidecar

Status: In Progress

## Authority and scope

Issue #135 authorizes a 3 SP Rust Core slice on
`feat/t-0026-run-result-sidecar`. It adds an opt-in, Emburk-owned result JSON
for ordinary configured `run` only. The mutation allowlist is limited to the
CLI manifest/lock, CLI entry point, one integration-test file, native/developer
documentation, and canonical records. No core execution file changes.

## Original native contract

The fixed UTF-8 JSON v1 shape plus trailing LF is:

```json
{"schema":"emburk.run-result/v1","command":"run","outcome":"succeeded","exit_code":0,"records":1,"error":null}
```

Success reports the exact `usize` already returned by
`run_config_with_cancel`. Failure and cancellation use `records: null`, retain
exit 1 or 130, and store the complete canonical stderr diagnostic. The report
is created exclusively with Unix mode 0600 after successful SIGINT-handler
installation and before configuration loading. An existing path exits 2 before
execution. Exact report/output collision invokes the existing output
no-overwrite failure and leaves a failed report.
Because reservation precedes input selection, callers must also keep the report
outside the configured input `path_prefix`. A collision remains visible as a
failed report rather than silently changing selection rules.

Serialization produces one object and LF and explicitly flushes the file. It is
not atomic, durability-guaranteed, or crash-complete. A report write failure
after successful publication exits 1 without invalidating an already published
configured output. After pipeline failure/cancellation, report I/O failure
preserves the pipeline exit and can leave an empty or partial report.

This contract was independently specified from the repository's existing
native return and error paths. No Embulk or third-party implementation source
was consulted or copied.

## Qwen consultation

One `fix` request sent only the Issue-authorized CLI manifest, entry point,
configured/parallel tests, and a non-sensitive original prompt, with default
project context disabled. `EMBURK_QWEN_TIMEOUT_SECONDS` was set to 90. The
request timed out with no response, so its disposition is `rejected`; it was not
retried and did not influence code or evidence.

## Dependency provenance

The CLI adds a direct `serde_json = "=1.0.151"` edge solely to encode the error
string safely. The exact package/version/checksum and transitive graph were
already selected and reviewed for T-0033; Cargo.lock changes only the
`emburk-cli` dependency list and adds no package, version, or checksum.

The exact archive source recorded by T-0033 is
`https://static.crates.io/crates/serde_json/serde_json-1.0.151.crate`, accessed
2026-09-06. Its declared license is MIT OR Apache-2.0; LICENSE-APACHE and
LICENSE-MIT were present and no NOTICE was found. This record reuses linked
public APIs only and does not copy crate source. T-0033's security, SBOM,
redistribution, patent, and freedom-to-operate non-clearance remains unchanged.

## Evidence

Implementation-stage checks passed:

- `cargo fmt --all -- --check`;
- `cargo check --locked --workspace`;
- strict workspace Clippy;
- eight focused CLI integration tests covering success, failure, cancellation,
  exclusive reservation, mode 0600, and input/output collisions;
- the remediated full workspace suite: 134 passed and eight intentional
  live-oracle tests ignored; the existing long SIGINT/resume test completed in
  81.32 seconds;
- `git diff --check`.

The initial implementation-stage authoritative Demo passed. An independent
read-only Tester then reran `git diff --check`, all seven initial focused
integration tests, and
the exact SIGINT test separately; all passed. The Tester confirmed exact JSON
bytes and LF, exit codes 0/1/2/130, diagnostic equality, exclusive no-overwrite,
both collision boundaries, Unix mode 0600, and no final output after
cancellation. Final-head acceptance remains pending.

Security review then identified a reservation-to-handler SIGINT race that could
leave an empty report. The candidate now installs the handler first, reserves
the report before configuration loading, observes any already-handled signal,
and includes an eighth test that sends SIGINT after observing reservation.
Post-remediation authoritative acceptance passed. Security re-review found the
prior medium blocker resolved and no remaining security or supply-chain
finding. Final-head acceptance after commit remains pending.

## Non-claims

No complete error taxonomy, schema promise beyond v1, report-on-crash,
atomic/durable report, partial record count on failure/cancellation, telemetry,
logging, tracing, metrics, stateful/resume/guess/transfer-lines report, core
publication/cancellation/resume change, Tokio adoption, plugin API, T-0026 or
Phase 1 completion, or Embulk structured-error/report compatibility is claimed.

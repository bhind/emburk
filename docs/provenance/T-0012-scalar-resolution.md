# T-0012/S03 internal scalar resolution

- Tracking issue: [#15](https://github.com/bhind/emburk/issues/15)
- Branch: `feat/t-0012-scalar-resolution`
- Owner: Rust Core Implementer; canonical records and lifecycle: Project Manager
- Estimate: 3 SP within the existing T-0012 parent estimate
- State: `Done` (independent source and Tester acceptance passed;
  [PR #66](https://github.com/bhind/emburk/pull/66) integrated as
  `e03a2bc2e2353776a8f7c1c387dd481ee3a0062f`)

## Authority, inputs, and boundary

Implement original, dependency-free Rust code in `emburk-core` that resolves
project-constructed raw scalar values. Its only compatibility inputs are S01
and S02's integrated Reference Observation / Integration records (PR #61
`e2532e2`, PR #65 `d7b4838`) and ADR-0006. No additional upstream source,
artifact, dependency, source text, test, or implementation is consulted or
reused.

The resolver may cover complete native domains: required/defaulted/optional
String identity and Missing/Null presence rules; the explicit S01 String-default
policy; the explicit S01 Optional<String> null-default policy (Missing/Null to
None only for that named policy); Boolean identity; and signed-64-bit integer
identity. Unsupported type combinations must be distinct internal outcomes, not
claimed Embulk rejections. It must not identify cases by fixture ID or call the
reference runtime. Lexical Boolean/Long conversion, decimal conversion,
overflow-token handling, Boolean/Long defaults, YAML parsing, public APIs, CLI
wiring, and plugins remain out of scope until separate evidence supports a
general rule.

## Packet

- Allowlist: `crates/emburk-core/src/lib.rs` and one new private module under
  `crates/emburk-core/src/` containing its unit tests; the canonical records,
  ADR-0006, log, and this provenance record only.
- Artifacts/dependencies: none beyond the existing workspace; no network or
  third-party dependency resolution.
- Demo Command: `cargo test -p emburk-core`.
- Acceptance: the Demo, `cargo fmt --check`, `cargo clippy -p emburk-core
  -- -D warnings`, and existing core tests pass; an independent reproduction is
  required. Tests cover arbitrary Strings, Boolean true/false, i64 minimum/
  maximum, and Missing versus Null; no fixture-ID dispatch is permitted. A
  documented narrow `dead_code` allowance is permitted only if needed to keep
  the resolver private; warnings must not be disabled globally.
- Evidence: Unit/Contract, traceable to reference observations; not
  Differential.
- Stop rule: stop expansion for any parser/public API/dependency request or
  material provenance, license, security, or reimplementation uncertainty.
- Non-claims: no complete Emburk configuration behavior, compatibility,
  parser, external plugin, performance, security, patent, or FTO claim.

## Runtime evidence

- Independent primary-agent acceptance at
  `8432391837a7877b7ab2d9e987b3720cbdc570d4` passed `cargo fmt --check`,
  `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test -p
  emburk-core` (8 tests), `cargo test --workspace` (8 core tests and 0 CLI
  tests), and `git diff --check`.
- This is Unit/Contract evidence for the private original Rust resolver only.
  It does not compare an Emburk execution, reproduce Java exception text or
  timing, add a parser, or satisfy T-0012's Differential gate.
- Named read-only Tester reproduction at `8432391` also passed core tests,
  format, workspace Clippy with warnings denied, and diff check. Its local raw
  log SHA-256 was
  `297ac906ecc9030d5997ac0ad809207153806927b58af5fd7f92a7730d927657`;
  the path is deliberately omitted from this public record.

# T-0012/S03 internal scalar resolution

- Tracking issue: [#15](https://github.com/bhind/emburk/issues/15)
- Branch: `feat/t-0012-scalar-resolution`
- Owner: Rust Core Implementer; canonical records and lifecycle: Project Manager
- Estimate: 3 SP within the existing T-0012 parent estimate
- State: `In Progress` (packet only)

## Authority, inputs, and boundary

Implement original, dependency-free Rust code in `emburk-core` that resolves
project-constructed raw scalar values. Its only compatibility inputs are S01
and S02's integrated Reference Observation / Integration records (PR #61
`e2532e2`, PR #65 `d7b4838`) and ADR-0006. No additional upstream source,
artifact, dependency, source text, test, or implementation is consulted or
reused.

The resolver may cover only: required/defaulted/optional String presence rules;
native Boolean true/false and quoted `"true"`; invalid Boolean; native Long 37
and maximum; quoted Long 37; decimal token `37.5` resolving to 37; and an
above-maximum Long error. It must not identify cases by fixture ID or call the
reference runtime. Unobserved spellings, Boolean/Long defaults, negative and
other decimals, YAML parsing, public APIs, CLI wiring, and plugins remain out
of scope.

## Packet

- Allowlist: `crates/emburk-core/src/lib.rs` and one new private module under
  `crates/emburk-core/src/` containing its unit tests; the canonical records,
  ADR-0006, log, and this provenance record only.
- Artifacts/dependencies: none beyond the existing workspace; no network or
  third-party dependency resolution.
- Demo Command: `cargo test -p emburk-core`.
- Acceptance: the Demo, `cargo fmt --check`, `cargo clippy -p emburk-core
  -- -D warnings`, and existing core tests pass; an independent reproduction is
  required. Tests assert project-owned values and errors rather than an
  invented general YAML contract.
- Evidence: Unit/Contract, traceable to reference observations; not
  Differential.
- Stop rule: stop expansion for any parser/public API/dependency request or
  material provenance, license, security, or reimplementation uncertainty.
- Non-claims: no complete Emburk configuration behavior, compatibility,
  parser, external plugin, performance, security, patent, or FTO claim.

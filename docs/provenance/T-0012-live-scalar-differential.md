# T-0012/S04 live scalar differential

- Tracking issue: [T-0012, #15](https://github.com/bhind/emburk/issues/15)
- Branch: `test/t-0012-live-scalar-differential`
- State: In Progress; independent acceptance passed, integration pending
- Slice estimate: 3 SP; parent Current SP 8, Initial SP unchanged at 5
- Owner: Rust Core Implementer; canonical records and integration: Project Manager
- Access dates: 2026-09-05–2026-09-06

## Scope and transport

Compare exactly 13 S01/S02-supported typed outcomes through the pinned local
oracle and the actual private Rust resolver. The nine presence cases cover
required String, explicit String default, and Optional<String> with explicit
null default, each with missing/null/value input. The four native-value cases
cover Boolean true/false and Long 37/maximum. Lexical conversion, fractional
conversion and overflow cases from S02 remain outside this comparison.

A Python-standard-library driver retains actual oracle outcomes, exception
classes and messages as external JSONL and writes versioned TSV with hex-encoded
strings. Rust parses only that TSV. IDs validate manifest membership and count;
they never select resolver outputs. Input/request specifications are test-owned;
expected typed outcomes must derive from actual oracle results, not those input
specifications. Only recognized ConfigException messages may map to the two
observed rejection categories; unknown errors fail closed.

## Mutation and acceptance packet

Implementer allowlist: `crates/emburk-core/src/scalar_resolution.rs` test-only
bridge, executable Python driver `tools/t0012-live-differential`, and
`tests/t0012_live_scalar_differential_test.sh`. The resolver implementation,
existing oracle runner/plugin, Cargo manifests and public APIs must not change.
The Project Manager separately owns STATUS/TODO/ROADMAP/COMPATIBILITY,
provenance records and the dated log.

Demo Command: `tests/t0012_live_scalar_differential_test.sh`. It must run the
pinned oracle and exactly one ignored Rust test comparing all 13 cases. Missing
oracle evidence, network failure or zero selected tests cannot pass or skip the
Demo. Ordinary tests remain offline and explicitly ignore that one live test.
Negative tests cover missing/duplicate/truncated evidence, malformed tags and
hex, unknown oracle exceptions, and mutation of only the expected outcome.
Retain temporary evidence; do not commit raw logs or downloaded artifacts.

Evidence class on successful independent acceptance: Differential (selected
typed outcomes only). Exact Java exception text/timing, YAML parsing and the
full configuration contract remain unimplemented or unverified, not approved
semantic deviations. No whole-scope Verified status or parent completion follows.

## Reference and reuse record

The only upstream inputs are the integrated S01/S02 observation records and
their existing official Embulk v0.11.5 executable, corresponding to core commit
`c5ac2d471edac465b45088669d376a7e2a525f8f`:
[release artifact](https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar),
SHA-256 `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`.
Embedded `META-INF/LICENSE` and `META-INF/NOTICE` are retained by the oracle
runner; core/SPI source classification remains Apache-2.0 per T-0011.
No new upstream source or tests are inspected, copied or translated. Recorded
runtime outputs are observations, not reused implementation code. Source
categories: prior public-interface observations and current executable behavior.
The adapter's exception-message recognition literals come from these generated
observations of the pinned executable, not from upstream source or tests. They
identify two rejection categories; they do not reproduce Java diagnostics in
the Rust product or establish whole-message compatibility.

Runtime artifacts are local-only; none are redistributed by this slice.
Transitive dependency/SBOM and redistribution review remain pending T-0005;
patent/standards/trademark and freedom-to-operate questions remain unreviewed.
Prior S01/S02 provenance review does not constitute legal clearance. Independent
code/test review passed for the bounded comparator; this is not legal approval.

## Stop boundary

Repair ordinary harness and retrieval failures within the packet. Stop expansion
for material security, license, redistribution or reimplementation uncertainty,
or before adding production dependencies, a parser or a public API. No plugin,
data-transfer, performance, production-readiness or general compatibility claim
is made by this slice.

## Primary acceptance

At source revision `3fe6546`, the primary agent ran the absolute path to
`tests/t0012_live_scalar_differential_test.sh` from `/private/tmp`: exit 0,
13 actual outcomes and 13 TSV rows plus one header. Exactly one selected live
Rust test passed (zero ignored); exactly one selected negative-control Rust
test passed. `cargo test -p emburk-core --offline` passed nine tests with one
explicitly ignored live test. Format, workspace/all-target Clippy with warnings
denied, and `git diff --check` each exited 0.

External evidence directory: `${TMPDIR}/t0012-s04.E2DAE9` (not a distributed
artifact). SHA-256:

- `live.tsv`: `0173df227ed0268f4cd30bf1f5b7b02ee94c4a1e5df1ad9d4b9b05363dbe14d6`
- `oracle-actual.jsonl`: `6d9922dcb534b674cacd2406b899abc678d558e8ad799dc90f8221cb6d2ae387`

The JSONL retains actual exception classes/messages and values. The manifest
retains both upstream evidence directories. PR integration is pending; the
parent T-0012 remains open.

Independent Tester reproduced the exact Demo and all auxiliary checks at full
revision `3fe654610d7b34d5eeb3a5b582accb7f94964b18`, with no findings. Its
external evidence directory is
`/private/tmp/t0012-s04-acceptance-3fe654610d7b34d5eeb3a5b582accb7f94964b18`.
TSV and JSONL hashes match primary acceptance above. The live Rust test log
hash is `c6c4b1e66c87249a022d170c8da9d1c97fb2ee837acc393097e07b4c90060ee9`;
exactly one live test passed, with zero ignored. Offline workspace tests passed
nine tests and intentionally ignored that live test. Platform: macOS 26.5.1
arm64, Rust/Cargo 1.98.1, Python 3.14.6, Bash 3.2.57, Temurin JDK 17.0.20.
Evidence class: Differential (selected typed outcomes only).

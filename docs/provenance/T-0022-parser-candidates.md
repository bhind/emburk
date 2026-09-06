# T-0022 parser candidate assessment

Status: Proposed refinement, not dependency admission or slice acceptance.
Issue: [T-0022, #19](https://github.com/bhind/emburk/issues/19).
Access date: 2026-09-06. Evidence class: Planning.

## Authority and boundary

The owner requested the next step after S13. PM owns this assessment, TODO,
STATUS, ROADMAP, COMPATIBILITY, provenance index and daily log on
`research/t-0022-parser-candidates`. Librarian support is read-only.
No Cargo, Rust, CLI, accepted ADR or existing probe changes are included.
This refinement leaves T-0022 in Backlog and awards no Story Points.

## Recommendation and sources

Evaluate `saphyr-parser` 0.0.11 first, with `yaml-rust2` 0.12.0 as a fallback,
in an isolated exact-version experiment before production admission. This is
an inference from documented interfaces and maintenance direction, not an
executed compatibility result. Avoid direct deserialization into job structs:
typed trees can erase distinctions needed by independent compatibility rules.

| Exact source | Observation | Evaluation consequence |
| --- | --- | --- |
| [saphyr-parser 0.0.11 Event](https://docs.rs/saphyr-parser/0.0.11/saphyr_parser/enum.Event.html) | Scalar events carry text, style, anchor identity and tag; aliases and mappings are exposed. Metadata declares MIT OR Apache-2.0, arraydeque and thiserror. | Preferred low-level candidate; actual preservation and resource behavior need tests. |
| [yaml-rust2 0.12.0 package](https://docs.rs/crate/yaml-rust2/0.12.0) and [Event](https://docs.rs/yaml-rust2/0.12.0/yaml_rust2/parser/enum.Event.html) | Comparable events; basic maintenance/stable API, with feature development directed toward saphyr. MIT OR Apache-2.0; arraydeque/hashlink and optional encoding_rs. | Fallback; stable API is useful but future maintenance needs scrutiny. |
| [serde_yaml 0.9.34+deprecated](https://docs.rs/serde_yaml/0.9.34+deprecated/serde_yaml/) | Documentation says the project is no longer maintained. | Do not select as a new default. |
| [serde_yml RUSTSEC-2025-0068](https://rustsec.org/advisories/RUSTSEC-2025-0068.html) | RustSec reports unsoundness and lack of maintenance. | Exclude from the initial shortlist. |

Only documentation, declarations and metadata were consulted; no implementation
was copied or translated. The historical [saphyr-parser 0.0.6 package](https://docs.rs/crate/saphyr-parser/0.0.6)
describes inherited license sets required in redistributions. This is a review
lead, not verification of the selected archive. Exact archives, transitive
graph, license sets, notices, SBOM and current advisories must be inspected
before execution/adoption. Top-level metadata does not clear redistribution,
patents, standards, trademark, jurisdiction or freedom to operate; these remain
unreviewed. No legal clearance is asserted.

## Local constraints and proposed boundary

The CLI prints development status. ADR-0006 permits private project-constructed
scalar resolution, not lexical YAML parsing. S12/S13 are integrated reference
observations, not parser adoption. YAML 1.2 conformance is not Embulk parity.

Proposed, not an accepted API:

`source bytes -> decoding adapter -> parser events -> owned raw configuration -> compatibility resolution -> job preparation`

Retain original bytes separately from decoded text, ordered mapping entries
including duplicates, scalar style/tag and source locations. Distinguish absent
from explicit null. Keep parser types inside a private adapter; create no empty
crates or public configuration/plugin API before a real consumer requires them.

## Decision gates

| Gate | Required evidence | Failure decision |
| --- | --- | --- |
| Artifact admission | Exact archive hashes/features, locked graph, MSRV, notices and advisories | Record the unresolved package/obligation; do not execute an unreviewed graph. |
| Information preservation | Duplicate entries, style/tag, anchors/aliases and locations survive the adapter | Try the other candidate before considering a custom parser; never silently discard data. |
| Selected parity | Original S13 bytes, candidate output/errors retained separately from reference results | Record mismatches; no fixture-specific hardcoded success. |
| Encoding | Preserve source ff while observing decoded U+FFFD | One fixture cannot authorize universal lossy decoding; observe multibyte/truncated input, BOM and relevant encodings first. |
| Scalar rules | S01/S02 extension for lexical spellings, ranges, tags and quoted/plain forms | Do not inherit YAML 1.2 coercions as Embulk semantics. |
| Errors and resources | Locations/categories, depth, size, expansion and cyclic-alias tests | No guessed diagnostic normalization; resource limits need explicit compatibility decisions. |
| Production adoption | Narrow ADR revision, admitted dependency graph, adapter owner and regression evidence | Keep production Cargo and CLI unchanged until this passes. |

S13's second duplicate value, scalar alias and single invalid-byte replacement
do not settle all duplicate rules, merge/complex keys, recursive aliases, tags,
multiple documents, Liquid/environment expansion or general encoding/errors.

## Actionable successor

Reserve T-0022/S01 for the isolated candidate experiment, forecast 5 SP
(implementation 1, uncertainty 2, verification 1, environment 1). Parent Initial
8 remains unchanged; no acceptance points are added. Before Ready, fix a full
packet: exact artifacts/features, file allowlist, Demo Command, dependency graph
and security/provenance review. This note is not permission to execute dependencies.

The experiment can consume accepted S12/S13 evidence without completing the
entire runtime epic. Production loading and `run <config>` still require an
actual T-0021 preparation/lifecycle consumer. Merely reading bytes is not a run
path. After the experiment, choose one parser or explain why neither works,
then propose the narrow adoption ADR and real consumer slice.

## Verification and stop rule

Planning Demo: `git diff --check`, plus review of the documentation-only file
allowlist. No candidate was compiled or benchmarked. Stop before dependency
execution/adoption, public policy, implementation reuse or material unresolved
supply-chain/IP risk. No native compatibility, safety, performance, parent
completion or legal-clearance claim follows.

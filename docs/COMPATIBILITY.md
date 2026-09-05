# Compatibility

Compatibility is an evidence record, not a general promise.

The implementation objective is strict reproduction of observable behavior for
the pinned core and admitted plugins. Technical constraints, disproportionate
effort, or unavoidable Java/Rust differences may justify an explicit exception
only after recording a reproducer, alternatives, estimated effort, migration
impact, and owner decision. Missing implementation is not an accepted deviation.
Each approved exception must identify the affected pinned artifact and fixture
and remain a known deviation marked `Partial`; that scope cannot be `Verified`.
Unchanged subscopes may be verified only with explicitly delimited evidence.
See the [Rust design proposal](RUST_RUNTIME_DESIGN.md) for pending contract gates.

## Baseline

- Initial core behavior reference: Embulk `v0.11.5`, commit
  `c5ac2d471edac465b45088669d376a7e2a525f8f`
- Initial Java SPI reference: `org.embulk:embulk-spi:0.11`, source tag `v0.11`,
  commit `576e98033a14ba8ac994ed581d3c9d8fcdda2749`
- Admitted external plugin artifacts: none
- Older Embulk lines and every plugin artifact require separate admission and version pinning.

## Status Vocabulary

| Status | Meaning |
| --- | --- |
| Planned | Selected for investigation but not implemented. |
| Hosted | The original pinned artifact runs through a compatibility host. |
| Native | Observable behavior has been independently implemented in Rust. |
| Verified | The pinned implementation passes the required differential matrix. |
| Partial | Known supported and unsupported behavior is documented. |
| Blocked | Evidence, licensing, runtime, or upstream availability prevents support. |

A plugin may be Hosted and Verified, or Native and Verified. Hosted never implies Native.

## Verification Matrix

Verification covers configuration defaults and validation; schema and value semantics; empty input, nulls, malformed records, and boundary values; single-task and multi-task execution; output ordering where guaranteed; interruption, abort, cleanup, retry, and resume; external-service integration; and artifact origin, checksum, license, and notices.

## Current Support

No data-transfer path or plugin is Verified yet. The first target is a native File-to-File path covering CSV, JSON, gzip/bzip2, basic column filters, guessing, transaction handling, and resume.

## Adding an Entry

Each entry must identify the Embulk version, exact plugin artifact, configuration fixture, expected evidence, source/provenance record, and known deviations. Claims enter this document only after review evidence exists.

# T-0033/S01 bounded native formats and filters

Issue: [#26](https://github.com/bhind/emburk/issues/26). State: Done through PR #119.
Forecast: 8 SP. One independently acceptable stage-6 configured-pipeline slice;
JSON, codec and filter parent tasks remain open outside the selected profile.

## Authority and dependencies

Owner authorized stages 1–7 and routine testing/integration absent incidents.
PM owns dependency admission and acceptance. T-0032/S01 (#116), T-0025/S01
(#117) and T-0014/S02 (#118, ecf9cc4) are integrated. Source/runtime observation
provenance is T-0014-formats-oracle.md; no upstream implementation translation.

## Branch and allowlist

Branch feat/t-0033-native-formats. PM initially owns Cargo.lock and core Cargo.toml
for metadata-only resolution and exact dependency review. After admission,
Rust Core Implementer owns only those two files, core/src/lib.rs,
core/src/configured_csv.rs, core/src/native_formats.rs,
crates/emburk-cli/tests/native_formats.rs, and
tests/t0033_native_formats_differential_test.sh; core paths are under crates/.
One serial source mutation owner. PM owns this packet, ADR-0019, STATUS/TODO/
ROADMAP/COMPATIBILITY/ARCHITECTURE, IMPLEMENTATION_SEQUENCE, provenance index,
T-0014/S02 closeout, third-party notices and daily log. Reviewers remain read-only.
Do not alter publication.rs, prior source/schema/CSV/oracle/test files.

The implementer supplied only the uncompiled native_formats adapter and then
paused. PM took serial source ownership of the same allowlist for integration,
array-depth correction, explicit test coverage and the retained comparator.

## Dependency admission

Admit exactly serde_json=1.0.151 (default std), flate2=1.1.10
(default-features=false, miniz_oxide), bzip2=0.6.1 (default libbz2-rs-sys).
No C backend or zlib build, no optional unbounded-depth/derive/precision/indexmap
features. Cargo.lock fixes each selected transitive version/checksum. Before
building, compare every registry entry against the previously downloaded
official package archive inventory plus the integrated YAML graph; stop on new
or changed entries. The prospective 37-package metadata graph was not built.
Only the selected subset is admitted here; sha2/ctrlc are not admitted yet.

Sources accessed 2026-09-06: exact version archives from
https://static.crates.io/crates/serde_json/serde_json-1.0.151.crate,
https://static.crates.io/crates/flate2/flate2-1.1.10.crate,
https://static.crates.io/crates/bzip2/bzip2-0.6.1.crate and equivalent exact
Cargo.lock-version archive locators for transitives. Manifest/license metadata
was inspected; consult public API documentation/signatures only as needed.
Use linked dependency APIs, not copied implementation. Direct crates are
MIT OR Apache-2.0. Transitive exceptions: adler2 (0BSD OR MIT OR Apache-2.0),
memchr (Unlicense OR MIT), miniz_oxide (MIT OR Zlib OR Apache-2.0),
libbz2-rs-sys (bzip2-1.0.6), unicode-ident (Unicode-3.0 with MIT/Apache terms).
Preserve required attribution for distributed material. Archives had no NOTICE;
this is not a complete release SBOM, security audit or patent/FTO clearance.
PM admits ordinary local compilation under the authorized implementation
workflow; any tool approval denial remains binding and requires escalation.

Metadata resolution produced 23 exact registry entries, all matching the
previously reviewed archive checksums or integrated YAML graph. The selected
normal/build graph excludes serde/serde_derive (lock-only conditional entries).
New selected build.rs files in crc32fast 1.5.1, serde_core 1.0.229, zmij 1.0.23
and serde_json 1.0.151 were inspected from those exact archives: compiler/target
feature detection, rustc --version and serde_core generation under OUT_DIR.
No additional installer/network action was found in these scripts. This is a
bounded build-script observation, not an audit of all dependency implementation.
No new procedural macro is selected beyond the integrated YAML graph.
The bzip2 backend license is retained in docs/THIRD_PARTY_NOTICES.md.

## Acceptance

Extend `emburk run CONFIG` with explicit JSON long/string columns, optional
single gzip/bzip2 decoder and encoder (levels 6/9), and ordered rename columns
mapping / remove_columns remove list. Validate all options before output.
All use the same private logical schema/record pipeline and safe publication.
Support arbitrary selected values/names; no fixture-constant special cases.

JSON framing accepts a whitespace-separated sequence of objects, including
multiline objects. Retain at most 1 MiB per raw object, depth at most 64, before
serde parsing; strict UTF-8 and malformed/nonobject values visibly fail.
Selected fields support signed64, text, null/missing. Selected row payload is
also capped at 1 MiB before cloning repeated schema fields. Broader JSON coercion,
root pointers, arrays and malformed-row recovery remain unfinished, not parity.
Codec streams must finalize successfully before publication; truncated/corrupt
input cannot publish. No whole-file decompression or all-record collection.
Apply filters in declared order and preserve column/value alignment; missing
remove target fails before output as observed. General rename rules/keep remain
unsupported. Output extension/naming remains the observed explicit CSV profile.

Run all five S02 fixture configs through actual native CLI and pinned reference.
Compare exact exits, full output names, and plain/decoded bytes. Preserve raw
compressed output, do not assert compressed bitstream identity. Keep all eight
earlier CSV comparisons and 87 existing workspace tests. Add native tests for
JSON byte/depth bounds, escaped/multiline/UTF-8 cases, wrong scalar types,
truncated codec streams, unknown options, filter ordering and no partial final.

## Demo Command

`cargo fmt --all -- --check && cargo clippy --locked --workspace --all-targets -- -D warnings && cargo test --locked --workspace && bash tests/t0032_configured_csv_differential_test.sh && bash tests/t0033_native_formats_differential_test.sh && git diff --check`

Set the pinned local EMBURK_REFERENCE_JAR and Java17 JAVA_HOME. Retain final-head
primary/independent evidence and negative controls; no points before integration.

## Evidence class, stop rule and non-claims

Accepted 8 SP through merge 95b5592cfb9c344fd44203501d89edcb3d942e4c.
Primary and independent exact Demo passed at
39c97d86165d1a23e5a7d929d229942c358de351: 97 tests passed, eight existing
intentional ignores; all eight CSV and five format/filter comparisons matched.
Fmt/strict locked Clippy/diff-check passed. Negative forced exit mismatch under
PYTHONOPTIMIZE returned 1 with incomplete retained evidence. No concrete defect
found in read-only review. macOS arm64, Rust/Cargo 1.98.1, Java17.

Primary /private/tmp/t0033-s01-primary.CzzNmN stdout SHA256
4167421e21da60d60ab15d3448d94f972f9da42d4ba418e3b4c6d4b7621f5870;
stderr 080f5b01bf72db11c7b74c2b6ae1e147e7e8d9872edbf8120c7c1fcb714b393d.
Independent /private/tmp/emburk-t0033-acceptance.72IInY stdout SHA256
ef2b624e5938d6fdc7ba91ff77fb6873d3212fe166b777f2fa51e57e329a0bc9;
stderr 19f60937c3b8d111a50f0a9b51719b6958cdeb6b9c936209dc875ba78bce379b.
Both exit 0; exit-file SHA256
9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa.
Parent #26 remains Backlog; Current 8 / Initial 5 unchanged. No points awarded
to broader codec/filter parents by implication.

Selected Differential plus Unit/Contract and local Integration. Stop on new
unreviewed dependency, codec finalization/cleanup failure, unexplained reference
mismatch, source/IP uncertainty or output damage. No full plugin certification,
all JSON/coercion/options support, compressed bitstream identity, distributed
transaction, parallel performance, cancellation/resume or legal clearance claim.

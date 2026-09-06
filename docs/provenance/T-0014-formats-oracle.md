# T-0014/S02 bundled format and filter observations

Issue: [#17](https://github.com/bhind/emburk/issues/17). State: Done through PR #118.
Forecast: 3 SP. Reference-only preparation for stage 6.

## Authority and dependencies

Owner authorized stages 1–7 and independent parallel work. PM owns acceptance.
T-0014/S01 (#115) and T-0032/S01 (#116) are integrated. This slice is independent
of active T-0025/S01: no shared implementation, tests, evidence or rollback.

## Branch and allowlist

Branch research/t-0014-formats-oracle. Compatibility Host Implementer owns only
tools/formats-oracle/run.py and tests/test_formats_oracle.py. PM owns this packet.
Other canonical closeout records reconcile serially after the publication PR.
No mutations to the prior oracle, Cargo dependencies, runtime or other records.

After PR #117 integrated, PM fast-forwarded this branch and serially owns its
publication closeout in STATUS/TODO/ROADMAP/COMPATIBILITY/ARCHITECTURE,
ADR-0018, provenance index/T-0025 packet, implementation sequence and daily log.
No implementer edits those records. Final source acceptance remains pending.

## Rejected fixture attempts

The initial implementation used an undocumented `rename` key rather than the
packet's documented `columns` mapping, producing misleading filter outcomes.
PM rejected those inputs. Raw evidence /private/tmp/emburk-t0014-s02-run-e5e3fbra
is retained as an invalid fixture attempt, not compatibility evidence. Corrected
fixtures use identical `columns: {name: renamed}` and `remove: [renamed]` options
with order alone changed. The preliminary corrected run
/private/tmp/emburk-t0014-s02-run-cktdrnj4 observes rename-then-remove success
and the reverse order failing for a missing renamed column. Final validators
also reject altered exact fixture bytes, unsafe paths, timeout and UUID mixing.

## Artifacts and provenance

Use the same verified outer Embulk 0.11.5 JAR and Java 17 controls as
T-0014-file-csv-oracle.md. Outer SHA256:
e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47.
Official artifact URL:
https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar.
Bundled runtime-only module inventory, read 2026-09-06:

| Embedded module | SHA256 |
| --- | --- |
| embulk-parser-json-0.11.2.jar | ac8c240f1a49af2cdba7384c7bac2da1c25b9ed903234df1aa0e61eecaca7048 |
| embulk-decoder-gzip-0.11.1.jar | 438de3a5f3f8b76d087b442633f67b2882f2ae6e847e5a220875f1d2791762c0 |
| embulk-decoder-bzip2-0.11.1.jar | 77c9ec4926317ea6ada8b486ecc7e3e4348ac84e12c7e44fcac441dc5e3d0df5 |
| embulk-encoder-gzip-0.11.1.jar | 9461eaa218422f9a7d10f9da437e708b0abbf6732688ae9e62c7c2ea5225c772 |
| embulk-encoder-bzip2-0.11.1.jar | 075edbc111decd8329da61418b8ad9ac1d244e856fc2fca503da0935b0b26ee5 |
| embulk-filter-rename-0.11.1.jar | bd964c44ac70071d11aced194a1a865d2b2b99baa64302787bc4494994c6f780 |
| embulk-filter-remove_columns-0.11.1.jar | e8880fbf6d5e3970aae4a86742796a79a4c5ade2507e8bffd3a0ff86e782d0b2 |

Each inner archive contains Apache-2.0 LICENSE and no inner NOTICE; outer
LICENSE/NOTICE hashes remain pinned by S01. Runtime observation only, no source
translation/reuse/redistribution; full transitive SBOM, patent/FTO, security and
release clearance remain unreviewed. Source commits are not newly inferred.

Official configuration documentation, accessed 2026-09-06:
https://www.embulk.org/docs/built-in.html, headings JSON parser, gzip/bzip2
decoder/encoder, Rename and Remove columns. JSON explicit long/string columns
extract same-name properties. Codec chains appear under decoders/encoders;
observe gzip level 6 and bzip2 level 9. Rename columns mapping and remove list
are selected; generic rename rules, keep and unmatched acceptance stay outside
scope. This paragraph describes documentation, not observed runtime behavior.

## Acceptance

Capture five cases: json-scalars (several objects with long/string/null/empty
and Unicode values); gzip-csv; bzip2-csv; rename-then-remove; remove-before-rename.
Use relative input/output paths and explicit max_threads=1/min_output_tasks=1,
the previously pinned explicit CSV formatter profile, fresh private dirs and
verified read-only JAR snapshot. No download or external plugin installation.
Record real exits, timeouts, complete raw output names/bytes/hashes, input and
config hashes, stdout/stderr, Java version, UUID, reference artifact. Preserve
failed observations; never convert a timeout into a behavioral result.

For codec cases also retain exact decompressed output and its metadata. Codec
bitstreams are not assumed equal. Validate manifests against retained files,
exhaustive output inventories and expected fixture bytes. Include negative
controls for modified config/input/output/exit/decoded data, missing/extra
case evidence, timeout, artifact mismatch and path escape. No optimized-away
Python assert acceptance guards. Use existing S01 helpers read-only when useful.
Primary and independent runs must match selected semantic projections (exits,
names, decoded/plain content); raw compressed bytes may differ and stay retained.

## Demo Command

`python3 -I -B -m unittest discover -s tests -p test_formats_oracle.py && python3 -I -B tools/formats-oracle/run.py && git diff --check`

Set EMBURK_REFERENCE_JAR and JAVA_HOME to the pinned local artifact and Java17.

## Evidence class, stop rule and non-claims

Accepted 3 SP through ecf9cc47c964fc678de98992afc13335b9521ea0 after primary
and independent exact Demo at dad393c3aaf154b447ab38e97c18ec2ab5988a60.
Nine harness tests passed. All five actual input/config/exit/output-name and
plain/decoded-content projections matched between runs; no timeouts. JSON,
gzip, bzip2 and rename-then-remove exit 0; reverse filter order exits 1 without
output. Compressed bytes are retained, not normalized into bitstream parity.

Primary /private/tmp/t0014-s02-primary.ermKcq stdout SHA256
f5147a0066bc816327cdbd73bb88736e6b456e352900f68ef42bbf19ac3c8879;
stderr b35463792dff49415b3025f515a855650b957e546842ecbbcd8a81a9573f833a.
Independent /private/tmp/emburk-t0014-s02-acceptance.XjNBHt stdout SHA256
231c8726eb81e213307a47e0c720c8a52adc4b128c93af25a036d72e1fb8bd63;
stderr 212d7f3f8085850412f7dd751ef30309fa2a5c6cfc44fe45b2db05bc1c185736.
Both numeric exit 0, exit-file SHA256
9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa.
Raw runs: /private/tmp/emburk-t0014-s02-run-tm_jxcje and
/private/tmp/emburk-t0014-s02-run-kj60p8_o. Parent #17 remains open in Backlog;
S01/S02 accept 8 SP total, not full harness completion.

Reference-only observation plus Unit/Contract harness controls. Stop on artifact
mismatch, unsafe filesystem writes, unexplained timeout or source/IP issue.
No native implementation acceptance, full JSON/codecs/filter parity, compressed
bitstream identity, external JSON formatter, concurrency or resume claim.

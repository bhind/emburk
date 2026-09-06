# T-0014/S01 bundled File/CSV reference observation

Issue: [#17](https://github.com/bhind/emburk/issues/17). State: In Progress.
Slice forecast: 5 SP. No full differential-harness acceptance is claimed.

## Authority

The owner authorized stages 1–7 and continued local implementation and testing.
PM admits the already-pinned official executable's bundled File/CSV plugins
for local reference execution after read-only Librarian artifact review.
No plugin installation, source copying or redistribution is authorized here.

## Dependencies

T-0011 official executable inventory, S12/S13 syntax observations and T-0022/S01
parser experiment (PR #114, 8b48051) are integrated. This observation precedes
native configured CSV semantics, not the entire T-0012/T-0013 parent contracts.

## Branch and allowlist

Branch research/t-0014-file-csv-oracle. Compatibility Host Implementer owns only
tools/file-csv-oracle/run.py and tests/test_file_csv_oracle.py. PM owns this
packet, T-0022-parser-experiment.md closeout, STATUS, TODO, ROADMAP,
COMPATIBILITY, provenance index and daily log. Testers/Librarian are read-only.
Existing probe scripts and production Rust remain unchanged.

## Artifacts

Official Embulk 0.11.5 executable:
https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar
SHA-256 e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47.
Core commit c5ac2d471edac465b45088669d376a7e2a525f8f. Runtime only, Java 17.
The runner requires EMBURK_REFERENCE_JAR pointing to a byte-exact local copy;
it must verify the checksum before execution and never download implicitly.

| Bundled module | SHA-256 | Source commit |
| --- | --- | --- |
| input-file 0.11.1 | e18475e5e58efddbf719d91123c83df366fec56c84c8fcc7ee82d6c8285e98bd | b9737ee9f73d73c567f8d862ca67ddabb6e0d736 |
| parser-csv 0.11.6 | f47c554c4bb8593c8ce5050c22f802c38332759c0ba27d2629a56bd09f52cd32 | 43e9c77fa35c06d7e92677089bce78e0d1e53763 |
| output-file 0.11.1 | 2364f76b41cb1c12714d10e0126f2ba1cf594404f9b55224e960e1789653b0de | 874f965fff16d08636c4e1cc540dd3cad8a8552d |
| formatter-csv 0.11.2 | d3f27c5b7905f3380408a27c57c7f4dcf35492d4d4131dcf4d52f4d9896f2062 | f90bb5ef99965b93a17ee320d4ae85303f7cfbd5 |

Sources: https://www.embulk.org/docs/built-in.html and the four official
embulk/embulk-{input-file,parser-csv,output-file,formatter-csv} repositories at
the listed commits, accessed 2026-09-06. Only docs/manifests/license metadata
were consulted. Each module contains Apache-2.0 LICENSE, no module-local NOTICE;
the outer executable supplies LICENSE and NOTICE. The bundled classpaths use
util-config 0.5.0, Jackson 2.16.2, validation-api 2.0.1.Final and relevant
util-file 0.2.0, util-csv 0.3.0, util-text 0.2.0, util-timestamp 0.3.0,
util-rubytime 0.4.0 and util-json 0.5.0. Complete SBOM, advisory, redistribution
and patent/FTO reviews remain unreviewed, not cleared. No material blocker
was identified for this local oracle. All fixture content is original.

## Acceptance criteria

Capture exact original input/config bytes, Java version, executable identity,
per-invocation stdout/stderr/exit, generated output filenames/bytes/checksums
and unique run identity. Each case has an isolated temporary directory outside
the repository and a 60-second process timeout. Never touch user input/output.
Cases: normal two-column CSV, quoted comma/multiline/Unicode, empty input,
blank/null cells, malformed numeric record, missing input, duplicate selected
configuration key and existing output-prefix sentinel. Capture behavior before
asserting an expected result; failures are retained, not silently normalized.
Runner validation tests must reject wrong artifact identity and malformed or
incomplete capture metadata. This slice observes the reference only.

## Demo Command

`python3 -m unittest discover -s tests -p test_file_csv_oracle.py && python3 tools/file-csv-oracle/run.py && cargo test --locked --workspace`

Set EMBURK_REFERENCE_JAR to the verified local artifact and JAVA_HOME to the
available Java 17 installation before Demo. The runner creates its evidence
directory with mkdtemp under /private/tmp and prints the retained location.

## Evidence class

Reference Observation / Integration, not native differential acceptance.

## Stop rule

Stop on artifact mismatch, output outside the newly allocated evidence tree,
unrecognized capture structure or missing raw evidence. Record actual plugin
failures as observations; do not guess successful semantics. No production
implementation or reference source translation in this packet.

## Non-claims

No full CSV/configuration compatibility, all encodings/types, transactions,
resume, performance, redistribution or legal/security clearance. No points
accepted before primary/independent Demo and integration.

## Preparation findings

Security review found ambient environment forwarding and a mutable reference
path between hash verification and execution. The runner now allowlists the
child environment and executes a read-only, exclusively created snapshot of
the verified bytes. Review cleared these findings within the trusted private
fixture/same-UID boundary; OS network isolation is not claimed.

Initial absolute-input-path attempts timed out after 60 seconds with exit -9
after loading the CSV plugin. Evidence is retained, including
/private/tmp/emburk-t0014-normal-dy_rhswk and
/private/tmp/emburk-t0014-normal-2txexgcj. A live Java 17 thread dump on 2026-09-06
showed directory traversal in the input plugin's real-case path lookup, not
CSV record execution (/private/tmp/t0014-diagnostic-72495-jstack.txt).
No upstream implementation was inspected or translated. The next fixture
revision uses input.csv and output/result relative to its private process CWD;
this is an experiment to avoid the observed absolute-path traversal boundary,
not a claim that the reference has completed or that absolute paths are unsupported.

The confirmed relative-path run /private/tmp/emburk-t0014-run-9i68hz6n completed
all eight cases with exit 0. With exec: {}, the host generated eight output
files for a single input task: one data file and seven header-only files.
Missing input generated no output; malformed long skipped its row and emitted
headers, not a failing process. Blank/unquoted versus quoted-empty cells stayed
distinct in output. The existing prefix sentinel remained beside generated files.
To remove CPU-count dependence from the selected first native profile, the final
fixture sets max_threads: 1 and min_output_tasks: 1. These documented executor
options (https://www.embulk.org/docs/built-in.html, local executor section,
accessed 2026-09-06) are explicit reference inputs, not output normalization.
Final primary/independent acceptance will use these single-task fixtures, with
duplicate skip_header_lines set first to 2 then 1 to observe an actual winner
in output data, rather than only a warning for an unskipped invalid header.

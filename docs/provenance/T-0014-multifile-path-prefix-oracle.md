# T-0014/S03 multi-file File input observation

Status: Review on PR #139

## Authority and boundary

Issue #138 authorizes a 3 SP reference-only observation on
`research/t-0014-multifile-path-prefix-oracle`. It captures three selected
multi-file File input `path_prefix` outcomes before any native implementation.
No Rust runtime, Cargo file, existing oracle, reference artifact, or plugin
source is mutable in this slice.

The only external runtime is the already-admitted local Embulk 0.11.5 JAR,
SHA-256
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`,
under Java 17. The official URL, core commit, four bundled File/CSV module
versions, hashes and commits, 2026-09-06 access date, Apache-2.0 license
findings, outer NOTICE, and unresolved SBOM/security/redistribution/patent/FTO
questions remain recorded in
[T-0014/S01](T-0014-file-csv-oracle.md#artifacts). This slice reuses that local
runtime boundary and original fixtures; it inspects or copies no upstream
implementation source.

## Selected observations

Raw capture precedes semantic assertions for:

1. `input.10.csv` with `10,alpha` and `input.20.csv` with `20,beta`;
2. the same filenames with those complete contents exchanged;
3. one `input.10.csv` regular file and one newly created empty
   `input.15.csv` directory.

Every case uses explicit File/CSV configuration, `max_threads: 1`,
`min_output_tasks: 1`, a new private `/private/tmp` tree, the allowlisted Java
child environment, a read-only exclusive snapshot of verified JAR bytes, and a
60-second process timeout. The runner gives the JVM an explicit case-local
`java.io.tmpdir`, terminates its isolated process group on every completion or
interruption path, and retains the complete case tree, including JVM temporary
artifacts. Exact inputs, entry types, process outputs, exit, timeout state,
output inventory/bytes/hashes, Java version, artifact identity, and run
identity are retained and structurally validated.

## Primary observations

The first raw capture completed before these expectations were added. A second
run then reproduced the resulting semantic projections:

| Case | Selected files and tasks | Exact output |
| --- | --- | --- |
| `two-regular` | `[input.10.csv, input.20.csv]`; two tasks; `last_path` is `input.20.csv` | `result000.00.csv` is `id,name\n10,alpha\n`; `result001.00.csv` is `id,name\n20,beta\n` |
| `two-regular-swapped` | `[input.10.csv, input.20.csv]`; two tasks; `last_path` is `input.20.csv` | `result000.00.csv` is `id,name\n20,beta\n`; `result001.00.csv` is `id,name\n10,alpha\n` |
| `regular-and-directory` | `[input.10.csv]`; one task; `last_path` is `input.10.csv` | only `result000.00.csv`, equal to `id,name\n10,alpha\n` |

Within this matrix, regular files are selected in lexical filename order, one
task/output is used per selected regular file, each file's configured header is
skipped independently, and the selected empty matching directory is excluded.
Those statements are bounded observations, not general File plugin policy.
All three processes exited 0 without timeout or stderr. Timestamped stdout is
retained raw but is not compared byte-for-byte across runs; validation projects
only the stable selected-file, task-count, and `last_path` lines.

Raw pre-assertion evidence is under
`/private/tmp/emburk-t0014-s03-gcmq68yc`, with summary SHA-256
`2c326dc4648fd6491779eac55a4882bf9f076b0dae31f049a68ca594a4a53b03`;
the first asserted primary rerun is under
`/private/tmp/emburk-t0014-s03-vliuo1sl`, with summary SHA-256
`5f801ad0949ee76772e7fa0468e5c2a30f18cd6e3d8c6f4f2b548cbef21bb39b`.
These directories are local evidence and are not repository or release
artifacts.

The first independent reproduction is under
`/private/tmp/emburk-t0014-s03-ivah2o2i`, with summary SHA-256
`586a706a0c2f1ced8e5842c50aa4b420026b0ee1d0dc9bae25a0237853889174`.
It matched the stable projections and exact output bytes. Security review then
identified evidence-integrity gaps in normal-exit descendant cleanup and
unrecorded case-tree entries. The candidate now terminates the process group
on normal, timeout, and interrupted waits; rejects an extra case-tree entry;
explicitly locates JVM temporary files; rechecks the JAR snapshot after all
cases; and exercises real delayed-descendant regressions. Post-remediation
primary evidence is under `/private/tmp/emburk-t0014-s03-a84e4rh5`, with
summary SHA-256
`a4114afb67dc4946b0bb2bea277a2ca0b4f9b4099f16ac57d26a18bc1db66d4e`.
The final-remediation independent capture is under
`/private/tmp/emburk-t0014-s03-pbqcvmd9`, with summary SHA-256
`5362f83b5e4e27ef6c9fefd335fc83cacfc1e9a39a54ff823eb07f7adf18ff48`.
It passed all thirteen focused tests and reproduced all three stable
projections and exact outputs. The primary exact Demo then captured
`/private/tmp/emburk-t0014-s03-1frgdxve`, with summary SHA-256
`212cdc90c5fae3af08668ceb335752f76f7db1af072110acf01fb92983ed2659`.

## Qwen consultation

One `fix` consultation sent only the original existing File/CSV harness and its
unit test with default project context disabled. It contained no documentation,
provenance, JAR, evidence, generated log, upstream source, credential, legal,
security, `.git`, or `.codex` material. The sandbox-denied call made no outbound
request; the same authorized consultation then reached its 90-second timeout
without a response. Its disposition is `rejected`; it was not retried and does
not influence code, observations, or evidence.

## Evidence state

The harness implementation, first raw capture, thirteen focused unit tests,
primary and independent semantic reproduction, and the primary full Demo pass.
The full workspace result is 134 passed with eight intentional external-oracle
ignores. Security review reports no remaining High or Medium finding.
Final-head acceptance and integration remain pending.

## Non-claims

No native implementation, multi-file compatibility certification, general
ordering/header/task/output policy, glob or recursive traversal semantics,
symlink/FIFO/device behavior, authenticated Java host, OS-level filesystem
containment, defense against a hostile same-UID process that changes sessions,
signed or immutable evidence, plugin admission, redistribution, security
clearance, patent/FTO conclusion, T-0014 completion, or Phase 1 completion is
claimed.

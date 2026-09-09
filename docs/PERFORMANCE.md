# Performance evidence

Performance statements in this repository are tied to an exact revision,
machine, workload, and command. They are not general product claims.

## T-0071/S01 native File-to-File benchmark

The reproducible runner generates deterministic quoted CSV and JSON inputs,
executes a fresh process for every sample, and rejects a run unless all worker
counts and both engines produce the expected byte-identical CSV output. The
`evidence` profile performs one warmup and records the median of three samples.

Evidence source revision: `6762f6ca53b2cb68e0ab4a91f3c6d10ca6e04b0a`
(clean tracked worktree). The machine-readable report is
[`T-0071-parallel-mvp.json`](provenance/T-0071-parallel-mvp.json).

Environment: Darwin 25.6.0 arm64, eight logical CPUs, Rust 1.98.1, Cargo
1.98.1, Python 3.14.6, and Temurin Java 17.0.20. The pinned reference is the
official Embulk 0.11.5 executable with SHA-256
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`.

| Workload | Engine | 1 worker | 4 workers | 8 workers |
| --- | --- | ---: | ---: | ---: |
| 60,663,244-byte quoted CSV, 120,000 × 16 | Emburk 0.11.5 median | 1.740 s | 1.726 s | 1.734 s |
|  | Emburk native median | 0.751 s | 0.429 s | 0.391 s |
|  | Emburk native input throughput | 77.0 MiB/s | 134.8 MiB/s | 148.0 MiB/s |
|  | Native scaling vs 1 worker | 1.00× | 1.75× | 1.92× |
|  | Native throughput vs reference | 2.32× | 4.02× | 4.44× |
| 41,780,600-byte JSON, 150,000 × 8, to CSV | Embulk 0.11.5 median | 1.432 s | 1.443 s | 1.432 s |
|  | Emburk native median | 0.810 s | 0.660 s | 0.622 s |
|  | Emburk native input throughput | 49.2 MiB/s | 60.4 MiB/s | 64.1 MiB/s |
|  | Native scaling vs 1 worker | 1.00× | 1.23× | 1.30× |
|  | Native throughput vs reference | 1.77× | 2.19× | 2.30× |

These are cold-process end-to-end wall times; process/JVM startup, parsing,
formatting, writing, fsync, and publication are included. Each run uses a fresh
output directory and, for the reference, a fresh Embulk home. The operating
system page cache is not flushed. CPU frequency, thermal state, and background
load are not controlled. The single-file reference workload remained one input
task at every configured thread count, while Emburk parallelizes record
formatting inside that task. This difference is part of the measured execution
model and prevents interpreting the table as scheduler parity.

The quoted-CSV fast path was measured before optimization with the same runner:
1.090/0.638/0.617 seconds at 1/4/8 workers. Buffered input scanning and
copy-free formatting changed those medians to 0.751/0.429/0.391 seconds, an
absolute improvement of 1.45×/1.49×/1.58× in that run. JSON improved at one
worker but its parallel medians were noise-level slower in the immediate
before/after comparison; no optimization claim is made for that case.

## Reproduce

Build and run the quick smoke profile:

```sh
cargo build --release --locked && \
python3 tools/t0071-benchmark/run.py \
  --binary target/release/emburk \
  --profile smoke \
  --output target/t0071-smoke.json && \
python3 tools/t0071-benchmark/validate.py target/t0071-smoke.json
```

The smoke profile validates real execution and output equality but is too short
for performance conclusions. For the recorded evidence profile, provide the
already-downloaded byte-exact reference executable and Java 17:

```sh
cargo build --release --locked && \
python3 tools/t0071-benchmark/run.py \
  --binary target/release/emburk \
  --profile evidence \
  --reference-jar "$EMBURK_REFERENCE_JAR" \
  --java "$JAVA_HOME/bin/java" \
  --output target/t0071-benchmark.json && \
python3 tools/t0071-benchmark/validate.py target/t0071-benchmark.json
```

The runner never downloads Embulk or dependencies. It verifies the pinned JAR
digest before reference execution. Report validation checks identities,
parameters, sample counts, medians, throughput calculations, worker speedups,
and reference ratios.

## Dependency and runtime choice

Dependencies are declared per crate in `Cargo.toml` and resolved exactly in
`Cargo.lock`. The core currently pins `saphyr-parser`, `serde_json`, `flate2`,
`bzip2`, and `sha2`; the CLI pins `ctrlc` and depends on the local core crate.
Tokio is intentionally absent.

This profile reads and writes local regular files with a single ordered writer.
The parallel work is CPU-side record formatting with a strict window of at most
twice the configured worker count. Scoped `std::thread` workers provide that
model without an async executor or another dependency. Adding Tokio alone would
not make regular-file parsing or formatting parallel and would not justify its
runtime/dependency cost. Tokio can be reassessed for network plugins or a
control-plane server where many concurrent waits make async I/O useful.

## Non-claims

The evidence does not establish performance on other machines, filesystems,
data shapes, codecs, plugin graphs, long-running warmed JVM jobs, multiple input
tasks, network sources, warehouses, or cloud object stores. It is not a memory,
energy, tail-latency, scheduler-parity, production-readiness, or universal
Embulk-superiority claim.

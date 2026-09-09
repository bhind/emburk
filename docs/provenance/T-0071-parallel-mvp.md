# T-0071/S01 native parallel MVP benchmark

Issue: [#47](https://github.com/bhind/emburk/issues/47). State: Review pending.
Forecast: 5 SP. Evidence class: Benchmark plus Unit/Contract.

## Authority and boundaries

The repository owner requested a runnable File-to-File MVP demonstration and
visible Rust-native parallel speed. T-0037/S01 is integrated. The implementation
uses only original repository code and public executable behavior; no upstream
source code was consulted or translated for this slice.

The selected source revision is
`6762f6ca53b2cb68e0ab4a91f3c6d10ca6e04b0a`. It changes buffered CSV scanning,
owned-record formatting, the benchmark runner and strict validator. It does not
change configuration syntax, worker/window caps, output ordering, cancellation,
checkpoint format, codec policy, or publication semantics.

## Reference artifact

- Artifact: official Embulk 0.11.5 self-contained executable.
- URL: `https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar`
- SHA-256: `e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`.
- Runtime: Temurin Java 17.0.20.
- Access date: 2026-09-09, from the previously pinned local artifact only.
- License/provenance status: already inventoried by T-0011; executable behavior
  is observed without redistribution. No patent or freedom-to-operate conclusion.

## Method and evidence

The `evidence` profile generates two deterministic files: 120,000 × 16 quoted
CSV records (60,663,244 bytes) and 150,000 × 8 JSON records (41,780,600 bytes).
Every native and reference run must produce the same expected CSV size and
SHA-256. A fresh process/output directory is used per sample. After one warmup,
the median of three end-to-end wall-time samples is recorded for 1/4/8 workers.

The strict report at `T-0071-parallel-mvp.json` validates as
`VALID|emburk-benchmark-v1|evidence|1,4,8`. The clean source revision, release
binary digest, exact sample values, environment, workload/output identities,
throughput and ratios are retained there. Selected native results:

- quoted CSV: 0.751/0.429/0.391 seconds and 77.0/134.8/148.0 MiB/s; scaling
  1.00×/1.75×/1.92×;
- JSON to CSV: 0.810/0.660/0.622 seconds and 49.2/60.4/64.1 MiB/s; scaling
  1.00×/1.23×/1.30×;
- native/reference throughput ratios are 2.32×/4.02×/4.44× for quoted CSV and
  1.77×/2.19×/2.30× for JSON at 1/4/8 configured workers.

The reference retained one single-file input task at all thread settings. JVM
startup is included. These facts are material to interpretation and prevent a
general Embulk performance or scheduler claim.

## Acceptance and non-claims

Primary pre-documentation acceptance passed 126 workspace tests with eight
intentional ignores, strict Clippy, formatting, six benchmark-tool tests,
smoke execution, two full native/reference evidence workloads, strict report
validation, and diff checks. Final-head Demo, independent review, pull-request
integration, canonical closeout, and Project Done transition remain required.

No performance claim extends beyond the exact report. This is not memory/RSS,
energy, tail-latency, multi-file, codec, network, production-readiness,
exactly-once, general Embulk compatibility, legal-clearance, patent, or
freedom-to-operate evidence.

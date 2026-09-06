<p align="center">
  <img src="assets/brand/emburk-icon-master.png" alt="Emburk whale shark icon">
</p>

# embuяk

Emburk is an independent, Rust-native bulk data loader inspired by Embulk. It is intended to give existing Embulk users a practical migration path while developing a smaller, safer, and more observable execution engine.

Emburk has an experimental native File-to-File pipeline with a bounded configuration profile, CSV and JSON input, CSV output, gzip/bzip2 codecs, column filters, ordered parallel formatting, and cooperative cancellation. Selected results are compared against pinned Embulk artifacts. General plugin compatibility, validated recovery, and production readiness remain under development.

## Why Emburk

Embulk demonstrated the value of a pluggable, parallel data loader, but the upstream project is now in maintenance mode and its ecosystem spans Java, JRuby, and many independently maintained plugins. Emburk preserves the useful ideas while making compatibility explicit, measurable, and replaceable over time.

## Characteristics

- **Rust-native by default:** the execution core and progressively reimplemented plugins are designed to run without a JVM.
- **Compact core:** the core is designed to own orchestration and stable contracts, while utilities and integrations stay outside it.
- **Pluggable by design:** built-ins are intended to be statically linked; external plugins will use a versioned, isolated protocol.
- **Practical migration:** planned optional JVM and JRuby hosts will bridge selected unported plugins.
- **Correctness before speed:** transactions, cleanup, cancellation, and resume behavior are specified and tested before optimization.
- **Evidence-based compatibility:** support is claimed only for pinned versions that pass differential tests against Embulk.
- **Traceable reimplementation:** upstream behavior and design documents may inform Emburk, but source is not mechanically translated into Rust.

## Near-term Goals

1. Specify the compatibility contract for configuration, schemas, values, plugin lifecycles, transactions, and resume state.
2. Deliver a native File-to-File vertical slice with CSV, JSON, compression, filtering, format guessing, bounded parallelism, and recovery.
3. Add an optional Java compatibility host for selected Maven-style Embulk plugins.
4. Add JRuby compatibility only after the Java host contract is stable.
5. Reimplement high-value plugins in Rust in an order justified by usage, maintenance value, security, and testability.

## Long-term Goals

- Make JVM- and JRuby-free deployments practical for common production pipelines.
- Build a broad native plugin portfolio for databases, object stores, warehouses, and streaming systems.
- Demonstrate performance improvements through published, reproducible benchmarks.
- Provide reproducible container and multi-cloud deployment artifacts.
- Add a control-plane API and graphical interface after the execution contract is stable.
- Explore adaptive optimization only when real workload evidence justifies it.

"All plugins" is not a finite or verifiable target. Emburk instead maintains an explicit compatibility matrix in which a plugin can be **Hosted**, **Native**, and/or **Verified** for a pinned artifact version.

## Project Documentation

- [Strategy](docs/STRATEGY.md)
- [Roadmap](docs/ROADMAP.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Compatibility](docs/COMPATIBILITY.md)
- [Experimental native pipeline](docs/NATIVE_PIPELINE.md)
- [Documentation index](docs/README.md)

## Independence and License

Emburk is an independent project. It is not an official Embulk project and is not endorsed by the Embulk maintainers. Embulk is referenced only to describe origin and compatibility.

Emburk is licensed under the [Apache License 2.0](LICENSE). Upstream materials and plugin artifacts retain their own licenses and are reviewed per version before reuse or redistribution.

# Development

Emburk currently provides a minimal CLI that verifies the Rust development environment. Data transfer and plugin functionality are not implemented yet.

## Rust

Install the stable Rust toolchain with [rustup](https://rust-lang.org/tools/install/). On macOS, install Xcode or the Xcode Command Line Tools as well.

```sh
rustup component add rustfmt clippy rust-src
git clone https://github.com/bhind/emburk.git
cd emburk
cargo run
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
```

If `cargo` is unavailable immediately after installation, restart the terminal or run `source "$HOME/.cargo/env"`.

## IntelliJ IDEA

1. Open Settings → Plugins and install JetBrains' **Rust** plugin.
2. Open the repository directory containing `Cargo.toml` as the project.
3. Open Settings → Languages & Frameworks → Rust and verify the toolchain location. The default rustup location is `~/.cargo/bin`.
4. After Cargo synchronization, use the gutter action next to `main` in `src/main.rs` to run or debug.
5. Run the Cargo verification commands from the integrated terminal as needed.

If IntelliJ requests plugin license activation, open Help → Register and verify the subscription. See [JetBrains' Rust plugin documentation](https://www.jetbrains.com/help/idea/rust-plugin.html) for details.

## Contribution Requirements

Read [Governance](GOVERNANCE.md), [Workflow](WORKFLOW.md), and [Compatibility](COMPATIBILITY.md) before implementing compatibility work. Any upstream reference must follow the project's provenance and licensing rules.

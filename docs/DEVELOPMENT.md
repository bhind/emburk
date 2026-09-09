# Development

Emburk is a Rust 2024 workspace with an experimental native File-to-File
pipeline. See [Current status](STATUS.md) for the precise supported boundary.

## Rust

Install the stable Rust toolchain with [rustup](https://rust-lang.org/tools/install/). On macOS, install Xcode or the Xcode Command Line Tools as well.

```sh
rustup component add rustfmt clippy rust-src
git clone https://github.com/bhind/emburk.git
cd emburk
cargo run -p emburk-cli
cargo fmt --all -- --check
cargo check --locked --workspace
cargo clippy --locked --workspace --all-targets -- -D warnings
cargo test --locked --workspace
```

If `cargo` is unavailable immediately after installation, restart the terminal or run `source "$HOME/.cargo/env"`.

## IntelliJ IDEA

1. Open Settings → Plugins and install JetBrains' **Rust** plugin.
2. Open the repository directory containing `Cargo.toml` as the project.
3. Open Settings → Languages & Frameworks → Rust and verify the toolchain location. The default rustup location is `~/.cargo/bin`.
4. After Cargo synchronization, use the gutter action next to `main` in `src/main.rs` to run or debug.
5. Run the Cargo verification commands from the integrated terminal as needed.

The repository also provides the shared run configurations **Qwen: Explain
Current File** and **Qwen: Review Working Tree**. They use the Shell Script
plugin and invoke the bounded project CLI described below. If they do not
appear after opening the repository, verify that the bundled Shell Script
plugin is enabled and reload the project. The explanation configuration uses
IntelliJ's `$FilePath$` macro for the active editor file.

If IntelliJ requests plugin license activation, open Help → Register and verify the subscription. See [JetBrains' Rust plugin documentation](https://www.jetbrains.com/help/idea/rust-plugin.html) for details.

## Qwen development assistant

`tools/qwen-assistant/run.py` sends bounded, sanitized project context to a
Qwen model through Ollama. It is advisory tooling: Codex or a human must inspect
every answer, make any change separately, and run independent verification.
The CLI has no command that applies a model-generated patch.

The defaults select the project owner's Windows Ollama service:

```sh
export EMBURK_QWEN_API_URL=http://192.168.10.112:11435/api
export EMBURK_QWEN_MODEL=qwen3-coder:30b
export EMBURK_QWEN_TIMEOUT_SECONDS=600
export EMBURK_QWEN_KEEP_ALIVE=30m
```

These variables are optional because the shown values are the defaults. To use
Ollama's OpenAI-compatible endpoint, select the `/v1` base URL. The CLI infers
the API style and sends the dummy key `ollama` unless it is overridden:

```sh
export EMBURK_QWEN_API_URL=http://192.168.10.112:11435/v1
export EMBURK_QWEN_API_STYLE=openai
export EMBURK_QWEN_API_KEY=ollama
```

Examples for each supported workflow are:

```sh
# Normal chat. Omit --prompt to read the question from standard input.
python3 tools/qwen-assistant/run.py chat \
  --prompt "Describe the current native pipeline boundaries."

# Explain a complete file or a selected line interval.
python3 tools/qwen-assistant/run.py explain \
  --file crates/emburk-core/src/csv_stream.rs --start 162 --end 183

# Analyze captured errors without asking the CLI to execute the failing command.
cargo check --locked --workspace 2>&1 | \
  python3 tools/qwen-assistant/run.py error

# Request a patch proposal. The response must be a unified diff and is not applied.
python3 tools/qwen-assistant/run.py fix \
  --file crates/emburk-core/src/csv_stream.rs \
  --goal "Add one focused boundary test."

# Review tracked staged and unstaged changes relative to HEAD.
python3 tools/qwen-assistant/run.py review
python3 tools/qwen-assistant/run.py review --staged
python3 tools/qwen-assistant/run.py review --base origin/main
```

Use `--context FILE` repeatedly to add relevant UTF-8 files. `AGENTS.md` and
the workspace `Cargo.toml` are included by default; use
`--no-project-context` when they are unnecessary. `--dry-run` displays the
sanitized request locally without contacting the model.

The outbound-data boundary rejects files outside the repository, symlink
escapes, `.git`, `.idea`, `.codex`, build/output directories, common credential
files, binaries, non-UTF-8 input, files over 128 KiB, and combined requests over
512 KiB. Known token and credential-assignment patterns are redacted, while
private-key material blocks the request. These checks reduce accidental
disclosure but do not make an external model appropriate for confidential
material. The configured LAN endpoint uses unencrypted HTTP, so do not route it
over an untrusted network. Review every selected file and diff before sending
it.

For selected text in IntelliJ, create a local External Tool if the shared
current-file configuration is too broad:

1. Open Settings → Tools → External Tools and add `Qwen: Explain Selection`.
2. Set Program to `python3` and Working directory to `$ProjectFileDir$`.
3. Set Arguments to
   `$ProjectFileDir$/tools/qwen-assistant/run.py chat --prompt "$SelectedText$" --context "$FilePath$"`.
4. Use Tools → External Tools from an editor selection. IntelliJ stores this
   local tool outside the repository, so each workstation configures it once.

After manually implementing an inspected proposal on a dedicated branch, run:

```sh
python3 tools/qwen-assistant/run.py verify
# Or narrow the final test invocation while retaining format and cargo check:
python3 tools/qwen-assistant/run.py verify --test-filter direct_field_formatter
```

`verify` runs `cargo fmt --all -- --check`, `cargo check --locked --workspace`,
and `cargo test --locked --workspace`. Passing Qwen output is never evidence;
only the repository's executable checks and reviewed acceptance process can
establish success.

## Contribution Requirements

Read [Governance](GOVERNANCE.md), [Workflow](WORKFLOW.md), and [Compatibility](COMPATIBILITY.md) before implementing compatibility work. Any upstream reference must follow the project's provenance and licensing rules.

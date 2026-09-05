#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
evidence_dir=${T0012_S04_EVIDENCE_DIR:-$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-s04.XXXXXX")}
mkdir -p -- "$evidence_dir"
printf 'T0012_S04_EVIDENCE_DIR=%s\n' "$evidence_dir"

"$root/tools/t0012-live-differential" --self-test \
  > "$evidence_dir/python-self-test.log" 2>&1
cargo test --manifest-path "$root/Cargo.toml" -p emburk-core \
  scalar_resolution::tests::live_tsv_bridge_rejects_invalid_manifests_and_rows \
  -- --exact \
  > "$evidence_dir/rust-negative-controls.log" 2>&1
grep -Fqx 'test scalar_resolution::tests::live_tsv_bridge_rejects_invalid_manifests_and_rows ... ok' \
  "$evidence_dir/rust-negative-controls.log"
grep -Eq '^test result: ok\. 1 passed; 0 failed; 0 ignored; .* filtered out;' \
  "$evidence_dir/rust-negative-controls.log"

"$root/tools/t0012-live-differential" \
  --tsv "$evidence_dir/live.tsv" \
  --jsonl "$evidence_dir/oracle-actual.jsonl" \
  --evidence-manifest "$evidence_dir/oracle-evidence-directories.txt" \
  > "$evidence_dir/driver.log" 2>&1

[[ $(wc -l < "$evidence_dir/oracle-actual.jsonl" | tr -d ' ') == 13 ]]
[[ $(wc -l < "$evidence_dir/live.tsv" | tr -d ' ') == 14 ]]

T0012_S04_TSV="$evidence_dir/live.tsv" \
  cargo test --manifest-path "$root/Cargo.toml" -p emburk-core \
    scalar_resolution::tests::live_scalar_differential \
    -- --ignored --exact > "$evidence_dir/live-rust-test.log" 2>&1

grep -Fqx 'test scalar_resolution::tests::live_scalar_differential ... ok' \
  "$evidence_dir/live-rust-test.log"
grep -Eq '^test result: ok\. 1 passed; 0 failed; 0 ignored; .* filtered out;' \
  "$evidence_dir/live-rust-test.log"
printf '%s\n' 'T0012/S04: compared exactly 13 live typed outcomes; negative controls passed'

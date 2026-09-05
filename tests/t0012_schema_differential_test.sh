#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
evidence_dir=${T0012_S06_EVIDENCE_DIR:-$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-s06.XXXXXX")}
mkdir -p -- "$evidence_dir"
printf 'T0012_S06_EVIDENCE_DIR=%s\n' "$evidence_dir"

"$root/tools/t0012-schema-differential" --self-test > "$evidence_dir/python-self-test.log" 2>&1
cargo test --manifest-path "$root/Cargo.toml" -p emburk-core logical_schema::tests::live_tsv_bridge_rejects_invalid_or_mutated_evidence -- --exact > "$evidence_dir/rust-negative-controls.log" 2>&1
grep -Fqx 'test logical_schema::tests::live_tsv_bridge_rejects_invalid_or_mutated_evidence ... ok' "$evidence_dir/rust-negative-controls.log"
grep -Eq '^test result: ok\. 1 passed; 0 failed; 0 ignored; .* filtered out;' "$evidence_dir/rust-negative-controls.log"

"$root/tools/t0012-schema-differential" --tsv "$evidence_dir/live.tsv" --evidence-manifest "$evidence_dir/oracle-evidence-directories.txt" --raw-hashes "$evidence_dir/raw-evidence-hashes.txt" > "$evidence_dir/driver.log" 2>&1
[[ $(wc -l < "$evidence_dir/live.tsv" | tr -d ' ') == 12 ]]
grep -Eq '^schema-cases\.raw=[0-9a-f]{64}$' "$evidence_dir/raw-evidence-hashes.txt"
grep -Eq '^schema-results\.raw=[0-9a-f]{64}$' "$evidence_dir/raw-evidence-hashes.txt"

T0012_S06_TSV="$evidence_dir/live.tsv" cargo test --manifest-path "$root/Cargo.toml" -p emburk-core logical_schema::tests::live_schema_differential -- --ignored --exact > "$evidence_dir/live-rust-test.log" 2>&1
grep -Fqx 'test logical_schema::tests::live_schema_differential ... ok' "$evidence_dir/live-rust-test.log"
grep -Eq '^test result: ok\. 1 passed; 0 failed; 0 ignored; .* filtered out;' "$evidence_dir/live-rust-test.log"
printf '%s\n' 'T0012/S06: compared exactly 3 live ordered schema outcomes; negative controls passed'

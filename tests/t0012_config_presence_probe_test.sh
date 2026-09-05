#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$repository_root/tools/t0012-config-presence/run.sh"
[[ -x "$runner" ]] || { printf '%s\n' "runner is not executable: $runner" >&2; exit 2; }

output=$("$runner")
printf '%s\n' "$output"
case_rows=$(printf '%s\n' "$output" | grep '^CASE|' || true)
[[ $(printf '%s\n' "$case_rows" | sed '/^$/d' | wc -l | tr -d ' ') == 9 ]] || {
  printf '%s\n' 'runtime probe did not emit nine cases' >&2; exit 1;
}
evidence_dir=$(printf '%s\n' "$output" | sed -n 's/^T0012_EVIDENCE_DIR=//p' | tail -n 1)
[[ -n "$evidence_dir" && -f "$evidence_dir/requested-coordinate.txt" ]] || {
  printf '%s\n' 'runtime probe did not preserve an evidence directory' >&2; exit 1;
}
grep -Fxq 'org.embulk:embulk-core:0.11.5' "$evidence_dir/requested-coordinate.txt"
grep -Eq '^RESOLVED\|org\.embulk:embulk-core:0\.11\.5\|embulk-core-0\.11\.5\.jar\|[0-9a-f]{64}$' "$evidence_dir/resolved-artifacts.raw"
[[ -s "$evidence_dir/resolved-jars.sha256" && -s "$evidence_dir/java-version.txt" && -s "$evidence_dir/gradle-version.txt" && -s "$evidence_dir/os-family.txt" && -s "$evidence_dir/probe-source.sha256" ]]
[[ -s "$evidence_dir/observations.raw.bin" && -s "$evidence_dir/gradle-distribution.sha256" ]]

#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$repository_root/tools/t0012-config-presence/run.sh"
[[ -x "$runner" ]] || {
  printf 'runner is not executable: %s\n' "$runner" >&2
  exit 2
}

run_negative_control() {
  local control=$1
  local expected_exit=$2
  local output
  local actual_exit

  if output=$(T0012_NEGATIVE="$control" "$runner" 2>&1); then
    printf 'negative control unexpectedly passed: %s\n' "$control" >&2
    exit 1
  else
    actual_exit=$?
  fi
  if [[ "$actual_exit" != "$expected_exit" ]]; then
    printf 'negative control %s exited %s; expected %s\n' \
      "$control" "$actual_exit" "$expected_exit" >&2
    exit 1
  fi
  printf '%s\n' "$output"
}

corrupt_output=$(run_negative_control corrupt-hash 3)
corrupt_evidence=$(printf '%s\n' "$corrupt_output" | sed -n 's/^T0012_EVIDENCE_DIR=//p' | tail -1)
[[ -s "$corrupt_evidence/negative-control.txt" ]]
grep -Fxq 'corrupt-copy-injected' "$corrupt_evidence/negative-control.txt"
run_negative_control unavailable-runtime 56 >/dev/null

output=$("$runner")
printf '%s\n' "$output"
case_rows=$(printf '%s\n' "$output" | grep '^CASE|' || true)
[[ $(printf '%s\n' "$case_rows" | sed '/^$/d' | wc -l | tr -d ' ') == 9 ]]
evidence_dir=$(printf '%s\n' "$output" | sed -n 's/^T0012_EVIDENCE_DIR=//p' | tail -1)
for file in executable-url.txt executable.sha256 executable-manifest.txt LICENSE-executable NOTICE-executable executable-license-notice-locators.txt java-version.txt os-family.txt plugin-source.sha256 plugin-jar.sha256 plugin-coordinate.txt observations.raw.bin cases.raw; do
  [[ -s "$evidence_dir/$file" ]]
done
grep -Fxq 'e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47' "$evidence_dir/executable.sha256"
grep -Fxq 'META-INF/LICENSE|META-INF/NOTICE' "$evidence_dir/executable-license-notice-locators.txt"
grep -Eq '^source=maven\|group=org\.embulk\.t0012\|name=t0012\|version=0\.0\.1\|artifact=embulk-input-t0012\|local-only$' "$evidence_dir/plugin-coordinate.txt"

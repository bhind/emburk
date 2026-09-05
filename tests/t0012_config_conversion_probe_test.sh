#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$repository_root/tools/t0012-config-presence/run.sh"
[[ -x "$runner" ]] || {
  printf 'runner is not executable: %s\n' "$runner" >&2
  exit 2
}

run_negative_control() {
  local control=$1 expected_exit=$2 output actual_exit
  if output=$(T0012_MODE=conversion T0012_NEGATIVE="$control" "$runner" 2>&1); then
    printf 'negative control unexpectedly passed: %s\n' "$control" >&2
    exit 1
  else
    actual_exit=$?
  fi
  [[ "$actual_exit" == "$expected_exit" ]] || {
    printf 'negative control %s exited %s; expected %s\n' "$control" "$actual_exit" "$expected_exit" >&2
    exit 1
  }
  printf '%s\n' "$output"
}

corrupt_output=$(run_negative_control corrupt-hash 3)
corrupt_evidence=$(printf '%s\n' "$corrupt_output" | sed -n 's/^T0012_EVIDENCE_DIR=//p' | tail -1)
[[ -s "$corrupt_evidence/negative-control.txt" ]]
grep -Fxq 'corrupt-copy-injected' "$corrupt_evidence/negative-control.txt"
run_negative_control unavailable-runtime 56 >/dev/null

output=$(T0012_MODE=conversion "$runner")
printf '%s\n' "$output"
evidence_dir=$(printf '%s\n' "$output" | sed -n 's/^T0012_EVIDENCE_DIR=//p' | tail -1)
case_rows=$(printf '%s\n' "$output" | grep '^CONVERSION_CASE|' || true)
[[ $(printf '%s\n' "$case_rows" | sed '/^$/d' | wc -l | tr -d ' ') == 9 ]]

for file in executable-url.txt executable.sha256 executable-manifest.txt LICENSE-executable NOTICE-executable java-version.txt os-family.txt plugin-source.sha256 plugin-jar.sha256 plugin-coordinate.txt observations.raw.bin conversion-cases.raw conversion-results.raw; do
  [[ -s "$evidence_dir/$file" ]]
done
grep -Fxq 'e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47' "$evidence_dir/executable.sha256"

for case_name in boolean-true boolean-false boolean-quoted-true boolean-invalid long-37 long-quoted-37 long-max long-fractional long-overflow; do
  [[ $(grep -Ec "^CONVERSION_CASE\\|$case_name\\|" "$evidence_dir/conversion-cases.raw") == 1 ]]
  [[ -s "$evidence_dir/$case_name.raw.log" ]]
  [[ -s "$evidence_dir/$case_name.input.yml-value" ]]
done
grep -Eq '^CONVERSION_CASE\|(boolean-true|boolean-false|boolean-quoted-true|boolean-invalid)\|boolean\|probe config load\|[0-9]+$' "$evidence_dir/conversion-cases.raw"
grep -Eq '^CONVERSION_CASE\|(long-37|long-quoted-37|long-max|long-fractional)\|long\|probe config load\|[0-9]+$' "$evidence_dir/conversion-cases.raw"
grep -Eq '^CONVERSION_CASE\|long-overflow\|long\|(probe config load\|[0-9]+|before probe callback\|[1-9][0-9]*)$' "$evidence_dir/conversion-cases.raw"
grep -Fqx 'CONVERSION_CASE|boolean-true|boolean|probe config load|0' "$evidence_dir/conversion-cases.raw"
grep -Fqx 'CONVERSION_CASE|long-37|long|probe config load|0' "$evidence_dir/conversion-cases.raw"
grep -Fqx 'CONVERSION_CASE|boolean|boolean-true|SUCCESS|dHJ1ZQ==|' "$evidence_dir/conversion-results.raw"
grep -Fqx 'CONVERSION_CASE|long|long-37|SUCCESS|Mzc=|' "$evidence_dir/conversion-results.raw"

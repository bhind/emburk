#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0012-double-value-probe/run.sh"
[[ -x "$runner" ]] || exit 2
attempt=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-double-capture.XXXXXX")
mode=${T0012_DOUBLE_MODE:-capture}
if T0012_DOUBLE_MODE="$mode" "$runner" > "$attempt/stdout.log" 2> "$attempt/stderr.log"; then status=0; else status=$?; fi
printf 'T0012_DOUBLE_CAPTURE_ATTEMPT=%s|exit=%s\n' "$attempt" "$status"
[[ "$mode" == capture && "$status" == 0 ]]
[[ $(grep -c '^T0012_DOUBLE_CAPTURE_ONLY=collected|evidence=' "$attempt/stdout.log") == 1 ]]
evidence=$(sed -n 's/^T0012_DOUBLE_CAPTURE_ONLY=collected|evidence=//p' "$attempt/stdout.log")
[[ -d "$evidence" ]]
for file in executable-url.txt executable.sha256 LICENSE-executable NOTICE-executable java-version.txt source-revision.txt plugin-source.sha256 runner-source.sha256 wrapper-source.sha256 stage.txt double-cases.raw double-traces.raw raw-evidence-hashes.txt finite-null.raw.log nonfinite.raw.log finite-null.trace.raw nonfinite.trace.raw; do [[ -s "$evidence/$file" ]]; done
grep -Fqx e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47 "$evidence/executable.sha256"
grep -Eq '^DOUBLECASE\|finite-null\|[0-9]+\|[0-9]+\|[0-9a-f]{64}$' "$evidence/double-cases.raw"
grep -Eq '^DOUBLECASE\|nonfinite\|[0-9]+\|[0-9]+\|[0-9a-f]{64}$' "$evidence/double-cases.raw"
if output=$(T0012_DOUBLE_MODE=validate T0012_DOUBLE_EVIDENCE_DIR="$evidence" "$runner" 2>&1); then [[ "$output" == T0012_DOUBLE_VALIDATE_ONLY=passed ]]; else exit 1; fi
if output=$(T0012_DOUBLE_MODE=full "$runner" 2>&1); then exit 1; else status=$?; fi
[[ "$status" == 2 && "$output" == T0012_DOUBLE_STAGE_B_REQUIRED ]]
printf 'T0012_DOUBLE_CAPTURE_PROBE=passed|evidence=%s\n' "$evidence"

#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0012-double-value-probe/run.sh"
mode=${T0012_DOUBLE_MODE:-full}

if [[ ! -x "$runner" ]]; then
  printf '%s\n' 'T0012 double probe runner is not executable' >&2
  exit 2
fi

if [[ "$mode" == validate ]]; then
  T0012_DOUBLE_MODE=validate "$runner"
  exit $?
fi

if [[ "$mode" != capture ]]; then
  T0012_DOUBLE_MODE="$mode" "$runner"
  exit $?
fi

attempt=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-double-capture.XXXXXX")
status=0
T0012_DOUBLE_MODE=capture "$runner" > "$attempt/stdout.log" 2> "$attempt/stderr.log" || status=$?
printf 'T0012_DOUBLE_CAPTURE_ATTEMPT=%s|exit=%s\n' "$attempt" "$status"
if [[ "$status" != 0 ]]; then
  exit "$status"
fi

if [[ $(grep -c '^T0012_DOUBLE_CAPTURE_ONLY=collected|evidence=' "$attempt/stdout.log") != 1 ]]; then
  printf '%s\n' 'capture marker missing or duplicated' >&2
  exit 1
fi
evidence=$(sed -n 's/^T0012_DOUBLE_CAPTURE_ONLY=collected|evidence=//p' "$attempt/stdout.log")
if [[ ! -d "$evidence" ]]; then
  printf '%s\n' 'capture evidence directory missing' >&2
  exit 1
fi

required=(
  executable-url.txt executable.sha256 executable-manifest.txt
  executable-license-notice-locators.txt LICENSE-executable NOTICE-executable
  java-version.txt os-family.txt source-revision.txt
  plugin-source-path.txt plugin-source.sha256
  runner-source-path.txt runner-source.sha256
  wrapper-source-path.txt wrapper-source.sha256
  plugin-jar.sha256 plugin-coordinate.txt stage.txt
  double-cases.raw double-traces.raw raw-evidence-hashes.txt
  finite-null.raw.log nonfinite.raw.log
  finite-null.trace.raw nonfinite.trace.raw
)
for file in "${required[@]}"; do
  if [[ ! -s "$evidence/$file" ]]; then
    printf 'missing capture artifact: %s\n' "$file" >&2
    exit 1
  fi
done

expected=e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47
grep -Fqx "$expected" "$evidence/executable.sha256"
grep -Fqx 'META-INF/LICENSE|META-INF/NOTICE' "$evidence/executable-license-notice-locators.txt"
grep -Fqx 'capture' "$evidence/stage.txt"
grep -Eq '^DOUBLECASE\|finite-null\|[0-9]+\|[0-9]+\|[0-9a-f]{64}$' "$evidence/double-cases.raw"
grep -Eq '^DOUBLECASE\|nonfinite\|[0-9]+\|[0-9]+\|[0-9a-f]{64}$' "$evidence/double-cases.raw"

validation=$(T0012_DOUBLE_MODE=validate T0012_DOUBLE_EVIDENCE_DIR="$evidence" "$runner")
if [[ "$validation" != T0012_DOUBLE_VALIDATE_ONLY=passed ]]; then
  printf '%s\n' 'validate-only marker mismatch' >&2
  exit 1
fi

printf 'T0012_DOUBLE_CAPTURE_PROBE=passed|evidence=%s\n' "$evidence"

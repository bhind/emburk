#!/usr/bin/env bash
set -euo pipefail

# Stage A only: collect and retain the raw two-fixture observation envelope.
# Fixture-specific semantic acceptance and the full marker are intentionally absent.
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0012-page-value-probe/run.sh"
[[ -x "$runner" ]] || exit 2

attempt=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-page-stage-a.XXXXXX")
if T0012_PAGE_MODE=capture "$runner" \
  > "$attempt/runner.stdout.log" 2> "$attempt/runner.stderr.log"; then
  exit_code=0
else
  exit_code=$?
fi
printf 'T0012_PAGE_STAGE_A_ATTEMPT=%s|exit=%s\n' "$attempt" "$exit_code"
cat "$attempt/runner.stdout.log"
cat "$attempt/runner.stderr.log" >&2
[[ "$exit_code" == 0 ]]

[[ $(grep -c '^T0012_PAGE_CAPTURE_ONLY=collected|evidence=' \
  "$attempt/runner.stdout.log") == 1 ]]
[[ $(grep -c '^T0012_PAGE_FULL_PROBE=passed' \
  "$attempt/runner.stdout.log") == 0 ]]
evidence=$(sed -n 's/^T0012_PAGE_CAPTURE_ONLY=collected|evidence=//p' \
  "$attempt/runner.stdout.log")
[[ -n "$evidence" && -d "$evidence" ]]
for file in executable-url.txt executable.sha256 executable-manifest.txt \
  LICENSE-executable NOTICE-executable executable-license-notice-locators.txt \
  java-version.txt os-family.txt source-revision.txt plugin-source-path.txt \
  plugin-source.sha256 plugin-jar.sha256 plugin-coordinate.txt stage.txt \
  page-cases.raw page-traces.raw raw-evidence-hashes.txt empty.raw.log \
  typed-null.raw.log empty.trace.raw typed-null.trace.raw; do
  [[ -s "$evidence/$file" ]]
done
grep -Fqx 'e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47' \
  "$evidence/executable.sha256"
grep -Fqx 'capture' "$evidence/stage.txt"
[[ $(grep -c '^PAGECASE|' "$evidence/page-cases.raw") == 2 ]]
[[ $(grep -c '^PAGECASE|empty|' "$evidence/page-cases.raw") == 1 ]]
[[ $(grep -c '^PAGECASE|typed-null|' "$evidence/page-cases.raw") == 1 ]]
printf 'T0012_PAGE_STAGE_A=collected|evidence=%s\n' "$evidence"

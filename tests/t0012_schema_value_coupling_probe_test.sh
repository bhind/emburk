#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0012-schema-value-coupling-probe/run.sh"
attempt=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-coupling-full.XXXXXX")
attempt=$(cd -- "$attempt" && pwd -P)
status=0
T0012_COUPLING_MODE=full "$runner" > "$attempt/stdout.log" 2> "$attempt/stderr.log" || status=$?
printf '%s\n' "$status" > "$attempt/exit.txt"
printf 'T0012_COUPLING_FULL_ATTEMPT=%s|exit=%s\n' "$attempt" "$status"
[[ "$status" == 0 ]]
evidence=$(sed -n 's/^T0012_COUPLING_FULL_RUN=passed|evidence=//p' "$attempt/stdout.log")
[[ -d "$evidence" && $(grep -c '^COUPLINGCASE|' "$evidence/coupling-cases.raw") == 5 ]]

control=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-coupling-negative.XXXXXX")
cp -R "$evidence" "$control/evidence"
printf '%s\n' 0 > "$control/evidence/matching.exit.txt"
printf '%s\n' 1 > "$control/evidence/explicit-null.exit.txt"
control_status=0
T0012_COUPLING_MODE=validate T0012_COUPLING_EVIDENCE_DIR="$control/evidence" "$runner" \
  > "$control/stdout.log" 2> "$control/stderr.log" || control_status=$?
printf '%s\n' "$control_status" > "$control/exit.txt"
[[ "$control_status" == 4 && ! -s "$control/stdout.log" ]]
grep -Eq '^T0012_COUPLING_VALIDATION_ERROR\|(process-exit|raw-hash)$' "$control/stderr.log"
printf 'T0012/S11: five exact reviewed traces and one repaired-copy rejection passed|evidence=%s|control=%s\n' "$evidence" "$control"

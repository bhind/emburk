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

artifact_control() {
  local name=$1 expected=$2 log status=0
  log=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-coupling-artifact.XXXXXX")
  log=$(cd -- "$log" && pwd -P)
  T0012_COUPLING_MODE=full T0012_COUPLING_NEGATIVE="$name" "$runner" \
    > "$log/stdout.log" 2> "$log/stderr.log" || status=$?
  printf '%s\n' "$status" > "$log/exit.txt"
  [[ "$status" == "$expected" ]]
  if [[ "$name" == corrupt-hash ]]; then
    grep -Fqx 'pinned executable checksum mismatch' "$log/stderr.log"
  else
    grep -Fq 'unable to retrieve pinned executable:' "$log/stderr.log"
  fi
  printf 'T0012_COUPLING_ARTIFACT_CONTROL=%s|attempt=%s\n' "$name" "$log"
}
artifact_control corrupt-hash 3
artifact_control unavailable-runtime 56

rebuild_integrity() {
  local dir=$1 file name
  for file in "$dir"/coupling-cases.raw "$dir"/coupling-traces.raw "$dir"/*.stdout.log \
    "$dir"/*.stderr.log "$dir"/*.trace.raw "$dir"/*.exit.txt
  do
    [[ -f "$file" ]] || continue
    name=${file##*/}
    shasum -a 256 "$file" | awk -v name="$name" '{print name "=" $1}'
  done | LC_ALL=C sort > "$dir/raw-evidence-hashes.txt"
  find "$dir" -maxdepth 1 -type f ! -name integrity-manifest.txt ! -name integrity-manifest.sha256 -print |
    LC_ALL=C sort | while IFS= read -r file
  do
    name=${file##*/}
    shasum -a 256 "$file" | awk -v name="$name" '{print name "=" $1}'
  done > "$dir/integrity-manifest.txt"
  shasum -a 256 "$dir/integrity-manifest.txt" | awk '{print $1}' > "$dir/integrity-manifest.sha256"
}

repair_and_reject() {
  local kind=$1 change=$2 expected=$3 control status=0 dir
  control=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-coupling-negative.XXXXXX")
  control=$(cd -- "$control" && pwd -P)
  dir="$control/evidence"
  cp -R "$evidence" "$dir"
  case "$kind:$change" in
    fixture:missing) rm "$dir/duplicate-name.trace.raw" ;;
    fixture:duplicate) sed -n '1p' "$dir/coupling-cases.raw" >> "$dir/coupling-cases.raw" ;;
    fixture:reordered) { sed -n '2p' "$dir/coupling-cases.raw"; sed -n '1p' "$dir/coupling-cases.raw"; sed -n '3,5p' "$dir/coupling-cases.raw"; } > "$dir/cases.tmp"; mv "$dir/cases.tmp" "$dir/coupling-cases.raw" ;;
    fixture:mutated) sed -i '' '1s/matching/not-matching/' "$dir/coupling-cases.raw" ;;
    schema:missing) sed -i '' '1d' "$dir/matching.trace.raw" ;;
    schema:duplicate) sed -n '1p' "$dir/matching.trace.raw" >> "$dir/matching.trace.raw" ;;
    schema:reordered) { sed -n '2p' "$dir/matching.trace.raw"; sed -n '1p' "$dir/matching.trace.raw"; sed -n '3,$p' "$dir/matching.trace.raw"; } > "$dir/trace.tmp"; mv "$dir/trace.tmp" "$dir/matching.trace.raw" ;;
    schema:mutated) sed -i '' 's/c2NoZW1hLWNvbHVtbg==/bm90LXNjaGVtYQ==/' "$dir/matching.trace.raw" ;;
    event:missing) sed -i '' '10d' "$dir/matching.trace.raw" ;;
    event:duplicate) sed -n '10p' "$dir/matching.trace.raw" >> "$dir/matching.trace.raw" ;;
    event:reordered) { sed -n '11p' "$dir/matching.trace.raw"; sed -n '10p' "$dir/matching.trace.raw"; sed -n '1,9p' "$dir/matching.trace.raw"; sed -n '12,$p' "$dir/matching.trace.raw"; } > "$dir/trace.tmp"; mv "$dir/trace.tmp" "$dir/matching.trace.raw" ;;
    event:mutated) sed -i '' '10s/.$/A/' "$dir/matching.trace.raw" ;;
    capture:missing) sed -i '' '1d' "$dir/unset-text.trace.raw" ;;
    capture:duplicate) sed -n '1p' "$dir/unset-text.trace.raw" >> "$dir/unset-text.trace.raw" ;;
    capture:reordered) { sed -n '2p' "$dir/unset-text.trace.raw"; sed -n '1p' "$dir/unset-text.trace.raw"; sed -n '3,$p' "$dir/unset-text.trace.raw"; } > "$dir/trace.tmp"; mv "$dir/trace.tmp" "$dir/unset-text.trace.raw" ;;
    capture:mutated) sed -i '' '1s/[0-9a-f]\{8\}-[0-9a-f-]\{27\}/00000000-0000-4000-8000-000000000000/' "$dir/unset-text.trace.raw" ;;
    source:missing) rm "$dir/runner-source-path.txt" ;;
    source:duplicate) printf '%s\n' extra >> "$dir/runner-source-path.txt" ;;
    source:reordered) sed -i '' 's#tools/#tests/#' "$dir/runner-source-path.txt" ;;
    source:mutated) printf '%s\n' deadbeef > "$dir/runner-source.sha256" ;;
    hash:missing) rm "$dir/raw-evidence-hashes.txt" ;;
    hash:duplicate) sed -n '1p' "$dir/raw-evidence-hashes.txt" >> "$dir/raw-evidence-hashes.txt" ;;
    hash:reordered) { sed -n '2p' "$dir/raw-evidence-hashes.txt"; sed -n '1p' "$dir/raw-evidence-hashes.txt"; sed -n '3,$p' "$dir/raw-evidence-hashes.txt"; } > "$dir/hash.tmp"; mv "$dir/hash.tmp" "$dir/raw-evidence-hashes.txt" ;;
    hash:mutated) sed -i '' '1s/.$/0/' "$dir/raw-evidence-hashes.txt" ;;
    value:*) sed -i '' 's/QXxC/QXxD/' "$dir/matching.trace.raw" ;;
    exception:*) sed -i '' 's/TnVsbFBvaW50ZXJFeGNlcHRpb24=/SWxsZWdhbFN0YXRlRXhjZXB0aW9u/' "$dir/unset-text.trace.raw" ;;
    terminal:*) sed -i '' 's/dGVybWluYWw=/bm90LXRlcm1pbmFs/' "$dir/matching.trace.raw" ;;
    cleanup:*) sed -i '' '$s/.$/A/' "$dir/wrong-setter.trace.raw" ;;
  esac
  rebuild_integrity "$dir"
  T0012_COUPLING_MODE=validate T0012_COUPLING_EVIDENCE_DIR="$dir" "$runner" \
    > "$control/stdout.log" 2> "$control/stderr.log" || status=$?
  printf '%s\n' "$status" > "$control/exit.txt"
  [[ "$status" == 4 && ! -s "$control/stdout.log" ]]
  grep -Eq "^T0012_COUPLING_VALIDATION_ERROR\\|(${expected})$" "$control/stderr.log"
  printf 'T0012_COUPLING_REPAIRED_CONTROL=%s:%s|attempt=%s|diagnostic=%s\n' "$kind" "$change" "$control" "$expected"
}

# Each malformed copy has its raw and complete integrity manifests repaired, so
# rejection reaches the intended contract check rather than an unrelated hash.
for kind in fixture schema event capture source hash value exception terminal cleanup; do
  for change in missing duplicate reordered mutated; do
    case "$kind" in
      fixture) expected='missing-artifact|case-count|case-grammar' ;;
      schema|event|value|exception|terminal|cleanup) expected='event-count|sequence|expected-vector' ;;
      capture) expected='event-count|sequence|capture-id' ;;
      source) expected='missing-artifact|metadata-line|source-path|source-hash' ;;
      hash) expected='missing-artifact|hash-manifest-grammar|hash-manifest-order|raw-hash' ;;
    esac
    repair_and_reject "$kind" "$change" "$expected"
  done
done
printf 'T0012/S11: five exact reviewed traces and 40 repaired-copy diagnostic rejections passed|evidence=%s\n' "$evidence"

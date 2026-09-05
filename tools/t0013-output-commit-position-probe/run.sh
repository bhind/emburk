#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
input_src="$root/tools/t0013-input-failure/src/T0013FailureInputPlugin.java"
output_src="$root/tools/t0013-output-commit-position-probe/src/T0013CommitPositionOutputPlugin.java"
s05_output_src="$root/tools/t0013-output-commit-failure/src/T0013CommitFailureOutputPlugin.java"
url=https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar
expected_sha=e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47
expected_input_sha=d45f0b6e83d39458331a2cf1be27a01d1b6863017bd87807f0e49d160c96d252
expected_s05_output_sha=6889081e838e19052ba7ea34193a8ad7bf64ec5b7339e4d825e1ad09adfb65d3
tmp=$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-output-commit-position.XXXXXX")
evidence="$tmp/evidence"
input_repo="$tmp/home/lib/m2/repository/org/embulk/t0013/s07/embulk-input-t0013s07input/0.0.1"
output_repo="$tmp/home/lib/m2/repository/org/embulk/t0013/s07/embulk-output-t0013s07output/0.0.1"
mkdir -p "$evidence" "$tmp/input-classes" "$tmp/output-classes" "$input_repo" "$output_repo"
trap 'printf "T0013_POSITION_EVIDENCE_DIR=%s\n" "$evidence"' EXIT

jarfile="$tmp/embulk.jar"
if [[ ${T0013_POSITION_NEGATIVE:-} == unavailable-asset ]]; then
  url=https://github.com/embulk/embulk/releases/download/v0.11.5/unavailable.jar
fi
printf '%s\n' "$url" > "$evidence/executable-url.txt"
if ! curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error \
    -o "$jarfile" "$url"; then
  if [[ ${T0013_POSITION_NEGATIVE:-} == unavailable-asset ]]; then
    printf '%s\n' unavailable-asset-request-failed > "$evidence/negative-control.txt"
  fi
  exit 56
fi
if [[ ${T0013_POSITION_NEGATIVE:-} == corrupt-copy ]]; then
  printf corrupt >> "$jarfile"
  printf '%s\n' corrupt-copy-injected > "$evidence/negative-control.txt"
fi
actual_sha=$(shasum -a 256 "$jarfile" | awk '{print $1}')
printf '%s\n' "$actual_sha" > "$evidence/executable.sha256"
[[ "$actual_sha" == "$expected_sha" ]] || exit 3

actual_input_sha=$(shasum -a 256 "$input_src" | awk '{print $1}')
actual_s05_output_sha=$(shasum -a 256 "$s05_output_src" | awk '{print $1}')
[[ "$actual_input_sha" == "$expected_input_sha" ]]
[[ "$actual_s05_output_sha" == "$expected_s05_output_sha" ]]
printf '%s\n' "$actual_input_sha" > "$evidence/input-source.sha256"
shasum -a 256 "$output_src" | awk '{print $1}' > "$evidence/output-source.sha256"
printf '%s\n' 'tools/t0013-input-failure/src/T0013FailureInputPlugin.java' \
  > "$evidence/input-source-path.txt"
printf '%s\n' 'tools/t0013-output-commit-position-probe/src/T0013CommitPositionOutputPlugin.java' \
  > "$evidence/output-source-path.txt"
if diff -u "$s05_output_src" "$output_src" > "$evidence/output-source-vs-s05.diff"; then
  exit 4
else
  diff_code=$?
  [[ "$diff_code" == 1 ]] || exit "$diff_code"
fi
unzip -p "$jarfile" META-INF/LICENSE > "$evidence/LICENSE-executable" \
  || [[ -s "$evidence/LICENSE-executable" ]]
unzip -p "$jarfile" META-INF/NOTICE > "$evidence/NOTICE-executable" \
  || [[ -s "$evidence/NOTICE-executable" ]]
java -XshowSettings:properties -version > "$evidence/java-version.txt" 2>&1

javac -cp "$jarfile" -d "$tmp/input-classes" "$input_src"
javac -cp "$jarfile" -d "$tmp/output-classes" "$output_src"
printf '%s\n' 'Manifest-Version: 1.0' \
  'Embulk-Plugin-Main-Class: T0013FailureInputPlugin' \
  'Embulk-Plugin-Category: input' \
  'Embulk-Plugin-Type: t0013s07input' \
  'Embulk-Plugin-Spi-Version: 0' > "$tmp/INPUT.MF"
jar cfm "$input_repo/embulk-input-t0013s07input-0.0.1.jar" "$tmp/INPUT.MF" \
  -C "$tmp/input-classes" .
printf '%s\n' 'Manifest-Version: 1.0' \
  'Embulk-Plugin-Main-Class: T0013CommitPositionOutputPlugin' \
  'Embulk-Plugin-Category: output' \
  'Embulk-Plugin-Type: t0013s07output' \
  'Embulk-Plugin-Spi-Version: 0' > "$tmp/OUTPUT.MF"
jar cfm "$output_repo/embulk-output-t0013s07output-0.0.1.jar" "$tmp/OUTPUT.MF" \
  -C "$tmp/output-classes" .

shasum -a 256 "$input_repo/embulk-input-t0013s07input-0.0.1.jar" \
  | awk '{print $1}' > "$evidence/input-jar.sha256"
shasum -a 256 "$output_repo/embulk-output-t0013s07output-0.0.1.jar" \
  | awk '{print $1}' > "$evidence/output-jar.sha256"
printf '%s\n' \
  'source=maven|group=org.embulk.t0013.s07|name=t0013s07input|version=0.0.1|artifact=embulk-input-t0013s07input|category=input|local-only' \
  > "$evidence/input-coordinate.txt"
printf '%s\n' \
  'source=maven|group=org.embulk.t0013.s07|name=t0013s07output|version=0.0.1|artifact=embulk-output-t0013s07output|category=output|local-only' \
  > "$evidence/output-coordinate.txt"
printf '%s' '<project><modelVersion>4.0.0</modelVersion></project>' \
  > "$input_repo/embulk-input-t0013s07input-0.0.1.pom"
printf '%s' '<project><modelVersion>4.0.0</modelVersion></project>' \
  > "$output_repo/embulk-output-t0013s07output-0.0.1.pom"

: > "$evidence/traces.raw"
: > "$evidence/cases.raw"
for fixture in normal commit-first commit-middle; do
  requested=1
  log="$evidence/$fixture.raw.log"
  config="$tmp/$fixture.yml"
  case_trace="$tmp/$fixture.trace"
  printf '%s\n' \
    'in:' \
    '  type:' \
    '    source: maven' \
    '    group: org.embulk.t0013.s07' \
    '    name: t0013s07input' \
    '    version: 0.0.1' \
    'out:' \
    '  type:' \
    '    source: maven' \
    '    group: org.embulk.t0013.s07' \
    '    name: t0013s07output' \
    '    version: 0.0.1' > "$config"
  if T0013_FIXTURE="$fixture" T0013_TASK_COUNT="$requested" \
      java -jar "$jarfile" "-Xembulk_home=$tmp/home" run "$config" \
      > "$log" 2>&1; then
    process_exit=0
  else
    process_exit=$?
  fi
  awk '/^(FAILTRACE|POSITIONOUTTRACE)\|/' "$log" > "$case_trace"
  cat "$case_trace" >> "$evidence/traces.raw"
  digest=$(shasum -a 256 "$case_trace" | awk '{print $1}')
  total=$(wc -l < "$case_trace" | tr -d ' ')
  input_count=$(awk '/^FAILTRACE\|/ {count++} END {print count + 0}' "$case_trace")
  output_count=$(awk '/^POSITIONOUTTRACE\|/ {count++} END {print count + 0}' "$case_trace")
  printf 'POSITIONCASE|%s|%s|%s|%s:%s:%s:%s\n' \
    "$fixture" "$requested" "$process_exit" \
    "$total" "$input_count" "$output_count" "$digest" >> "$evidence/cases.raw"
done
cat "$evidence/cases.raw"

#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
input_src="$root/tools/t0013-input-lifecycle/src/T0013InputPlugin.java"
output_src="$root/tools/t0013-output-lifecycle/src/T0013OutputPlugin.java"
url=https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar
expected_sha=e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47
tmp=$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-output-lifecycle.XXXXXX")
evidence="$tmp/evidence"
input_repo="$tmp/home/lib/m2/repository/org/embulk/t0013/s02/embulk-input-t0013s02input/0.0.1"
output_repo="$tmp/home/lib/m2/repository/org/embulk/t0013/s02/embulk-output-t0013s02output/0.0.1"
mkdir -p "$evidence" "$tmp/input-classes" "$tmp/output-classes" "$input_repo" "$output_repo"
trap 'printf "T0013_OUTPUT_EVIDENCE_DIR=%s\n" "$evidence"' EXIT

jarfile="$tmp/embulk.jar"
if [[ ${T0013_OUTPUT_NEGATIVE:-} == unavailable-asset ]]; then
  url=https://github.com/embulk/embulk/releases/download/v0.11.5/unavailable.jar
fi
printf '%s\n' "$url" > "$evidence/executable-url.txt"
if ! curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error -o "$jarfile" "$url"; then
  if [[ ${T0013_OUTPUT_NEGATIVE:-} == unavailable-asset ]]; then
    printf '%s\n' unavailable-asset-request-failed > "$evidence/negative-control.txt"
  fi
  exit 56
fi
if [[ ${T0013_OUTPUT_NEGATIVE:-} == corrupt-copy ]]; then
  printf corrupt >> "$jarfile"
  printf '%s\n' corrupt-copy-injected > "$evidence/negative-control.txt"
fi
actual_sha=$(shasum -a 256 "$jarfile" | awk '{print $1}')
printf '%s\n' "$actual_sha" > "$evidence/executable.sha256"
[[ "$actual_sha" == "$expected_sha" ]] || exit 3

shasum -a 256 "$input_src" | awk '{print $1}' > "$evidence/input-source.sha256"
shasum -a 256 "$output_src" | awk '{print $1}' > "$evidence/output-source.sha256"
unzip -p "$jarfile" META-INF/LICENSE > "$evidence/LICENSE-executable" || [[ -s "$evidence/LICENSE-executable" ]]
unzip -p "$jarfile" META-INF/NOTICE > "$evidence/NOTICE-executable" || [[ -s "$evidence/NOTICE-executable" ]]
java -XshowSettings:properties -version > "$evidence/java-version.txt" 2>&1

javac -cp "$jarfile" -d "$tmp/input-classes" "$input_src"
javac -cp "$jarfile" -d "$tmp/output-classes" "$output_src"

printf '%s\n' 'Manifest-Version: 1.0' 'Embulk-Plugin-Main-Class: T0013InputPlugin' \
  'Embulk-Plugin-Category: input' 'Embulk-Plugin-Type: t0013s02input' \
  'Embulk-Plugin-Spi-Version: 0' > "$tmp/INPUT.MF"
jar cfm "$input_repo/embulk-input-t0013s02input-0.0.1.jar" "$tmp/INPUT.MF" -C "$tmp/input-classes" .
printf '%s\n' 'Manifest-Version: 1.0' 'Embulk-Plugin-Main-Class: T0013OutputPlugin' \
  'Embulk-Plugin-Category: output' 'Embulk-Plugin-Type: t0013s02output' \
  'Embulk-Plugin-Spi-Version: 0' > "$tmp/OUTPUT.MF"
jar cfm "$output_repo/embulk-output-t0013s02output-0.0.1.jar" "$tmp/OUTPUT.MF" -C "$tmp/output-classes" .

shasum -a 256 "$input_repo/embulk-input-t0013s02input-0.0.1.jar" | awk '{print $1}' > "$evidence/input-jar.sha256"
shasum -a 256 "$output_repo/embulk-output-t0013s02output-0.0.1.jar" | awk '{print $1}' > "$evidence/output-jar.sha256"
printf '%s\n' 'source=maven|group=org.embulk.t0013.s02|name=t0013s02input|version=0.0.1|artifact=embulk-input-t0013s02input|category=input|local-only' > "$evidence/input-coordinate.txt"
printf '%s\n' 'source=maven|group=org.embulk.t0013.s02|name=t0013s02output|version=0.0.1|artifact=embulk-output-t0013s02output|category=output|local-only' > "$evidence/output-coordinate.txt"
printf '%s' '<project><modelVersion>4.0.0</modelVersion></project>' > "$input_repo/embulk-input-t0013s02input-0.0.1.pom"
printf '%s' '<project><modelVersion>4.0.0</modelVersion></project>' > "$output_repo/embulk-output-t0013s02output-0.0.1.pom"

: > "$evidence/traces.raw"
: > "$evidence/cases.raw"
for spec in zero:0 one:1; do
  fixture=${spec%%:*}
  count=${spec##*:}
  log="$evidence/$fixture.raw.log"
  config="$tmp/$fixture.yml"
  case_trace="$tmp/$fixture.trace"
  printf '%s\n' \
    'in:' \
    '  type:' \
    '    source: maven' \
    '    group: org.embulk.t0013.s02' \
    '    name: t0013s02input' \
    '    version: 0.0.1' \
    'out:' \
    '  type:' \
    '    source: maven' \
    '    group: org.embulk.t0013.s02' \
    '    name: t0013s02output' \
    '    version: 0.0.1' > "$config"
  if T0013_FIXTURE="$fixture" T0013_TASK_COUNT="$count" \
    java -jar "$jarfile" "-Xembulk_home=$tmp/home" run "$config" > "$log" 2>&1; then
    code=0
  else
    code=$?
  fi
  awk '/^(TRACE|OUTTRACE)\|/' "$log" > "$case_trace"
  cat "$case_trace" >> "$evidence/traces.raw"
  digest=$(shasum -a 256 "$case_trace" | awk '{print $1}')
  total=$(wc -l < "$case_trace" | tr -d ' ')
  input_count=$(awk '/^TRACE\|/ {count++} END {print count + 0}' "$case_trace")
  output_count=$(awk '/^OUTTRACE\|/ {count++} END {print count + 0}' "$case_trace")
  printf 'CASE|%s|%s|%s|%s:%s:%s:%s\n' "$fixture" "$count" "$code" \
    "$total" "$input_count" "$output_count" "$digest" >> "$evidence/cases.raw"
done
cat "$evidence/cases.raw"

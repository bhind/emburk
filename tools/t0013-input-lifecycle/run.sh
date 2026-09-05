#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
src="$root/tools/t0013-input-lifecycle/src/T0013InputPlugin.java"
url=https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar
sha=e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47
tmp=$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-input-lifecycle.XXXXXX")
evidence="$tmp/evidence"
mkdir -p "$evidence" "$tmp/classes" "$tmp/home/lib/m2/repository/org/embulk/t0013/embulk-input-t0013/0.0.1"
trap 'printf "T0013_EVIDENCE_DIR=%s\n" "$evidence"' EXIT
jarfile="$tmp/embulk.jar"
if [[ ${T0013_NEGATIVE:-} == unavailable-asset ]]; then url=https://github.com/embulk/embulk/releases/download/v0.11.5/unavailable.jar; fi
printf '%s\n' "$url" > "$evidence/executable-url.txt"
if ! curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error -o "$jarfile" "$url"; then
  if [[ ${T0013_NEGATIVE:-} == unavailable-asset ]]; then
    printf '%s\n' unavailable-asset-request-failed > "$evidence/negative-control.txt"
  fi
  exit 56
fi
if [[ ${T0013_NEGATIVE:-} == corrupt-copy ]]; then
  printf corrupt >> "$jarfile"
  printf '%s\n' corrupt-copy-injected > "$evidence/negative-control.txt"
fi
actual_sha=$(shasum -a 256 "$jarfile" | awk '{print $1}')
printf '%s\n' "$actual_sha" > "$evidence/executable.sha256"
[[ "$actual_sha" == "$sha" ]] || exit 3
shasum -a 256 "$src" | awk '{print $1}' > "$evidence/plugin-source.sha256"
unzip -p "$jarfile" META-INF/LICENSE > "$evidence/LICENSE-executable" || [[ -s "$evidence/LICENSE-executable" ]]
unzip -p "$jarfile" META-INF/NOTICE > "$evidence/NOTICE-executable" || [[ -s "$evidence/NOTICE-executable" ]]
java -XshowSettings:properties -version > "$evidence/java-version.txt" 2>&1
javac -cp "$jarfile" -d "$tmp/classes" "$src"
repo="$tmp/home/lib/m2/repository/org/embulk/t0013/embulk-input-t0013/0.0.1"
printf '%s\n' 'Manifest-Version: 1.0' 'Embulk-Plugin-Main-Class: T0013InputPlugin' 'Embulk-Plugin-Category: input' 'Embulk-Plugin-Type: t0013' 'Embulk-Plugin-Spi-Version: 0' > "$tmp/MANIFEST.MF"
jar cfm "$repo/embulk-input-t0013-0.0.1.jar" "$tmp/MANIFEST.MF" -C "$tmp/classes" .
shasum -a 256 "$repo/embulk-input-t0013-0.0.1.jar" | awk '{print $1}' > "$evidence/plugin-jar.sha256"
printf '%s\n' 'source=maven|group=org.embulk.t0013|name=t0013|version=0.0.1|artifact=embulk-input-t0013|local-only' > "$evidence/plugin-coordinate.txt"
printf '%s' '<project><modelVersion>4.0.0</modelVersion></project>' > "$repo/embulk-input-t0013-0.0.1.pom"
: > "$evidence/traces.raw"
: > "$evidence/cases.raw"
for spec in zero:0 one:1; do
  fixture=${spec%%:*}
  count=${spec##*:}
  log="$evidence/$fixture.raw.log"
  config="$tmp/$fixture.yml"
  case_trace="$tmp/$fixture.trace"
  printf '%s\n' 'in:' '  type:' '    source: maven' '    group: org.embulk.t0013' '    name: t0013' '    version: 0.0.1' 'out:' '  type: "null"' > "$config"
  if T0013_FIXTURE="$fixture" T0013_TASK_COUNT="$count" java -jar "$jarfile" "-Xembulk_home=$tmp/home" run "$config" > "$log" 2>&1; then code=0; else code=$?; fi
  awk '/^TRACE\|/' "$log" > "$case_trace"
  cat "$case_trace" >> "$evidence/traces.raw"
  digest=$(shasum -a 256 "$case_trace" | awk '{print $1}')
  rows=$(wc -l < "$case_trace" | tr -d ' ')
  printf 'CASE|%s|%s|%s|%s\n' "$fixture" "$count" "$code" "$rows:$digest" >> "$evidence/cases.raw"
done
cat "$evidence/cases.raw"

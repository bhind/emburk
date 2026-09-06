#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$script_dir/../.." && pwd)
source_file="$script_dir/src/T0012SchemaValueCouplingInputPlugin.java"
wrapper_file="$root/tests/t0012_schema_value_coupling_probe_test.sh"
mode=${T0012_COUPLING_MODE:-capture}
if [[ "$mode" != capture ]]; then
  printf '%s\n' 'T-0012/S11 Stage B is not authorized; capture mode only' >&2
  exit 2
fi

temporary_root=${T0012_COUPLING_TEMP_ROOT:-"${TMPDIR:-/private/tmp}/t0012-schema-value-coupling"}
resolved_root=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve())' "$temporary_root")
resolved_repository=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve())' "$root")
case "$resolved_root" in
  /tmp/* | /private/tmp/* | /var/folders/* | /private/var/folders/*) ;;
  *) printf '%s\n' 'T0012_COUPLING_TEMP_ROOT must be external' >&2; exit 2 ;;
esac
case "$resolved_root/" in
  "$resolved_repository/"*) printf '%s\n' 'temporary root resolves inside repository' >&2; exit 2 ;;
esac
[[ ! -L "$temporary_root" && -f "$source_file" && -f "$wrapper_file" ]] || exit 2
temporary_root=$resolved_root
mkdir -p -- "$temporary_root"
run_dir=$(mktemp -d "$temporary_root/run.XXXXXX")
evidence="$run_dir/evidence"
plugin="$run_dir/plugin"
export EMBULK_HOME="$run_dir/embulk-home"
repository="$EMBULK_HOME/lib/m2/repository/org/embulk/t0012/embulk-input-t0012_coupling/0.0.1"
mkdir -p "$evidence" "$plugin/classes" "$repository"
trap 'printf "T0012_COUPLING_EVIDENCE_DIR=%s\n" "$evidence"' EXIT

executable="$run_dir/embulk.jar"
url=https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar
expected=e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47
if ! curl --connect-timeout 15 --max-time 120 --fail --location --proto '=https' \
  --tlsv1.2 --silent --show-error --output "$executable" "$url"
then
  printf 'unable to retrieve pinned executable: %s\n' "$url" >&2
  exit 56
fi
actual=$(shasum -a 256 "$executable" | awk '{print $1}')
[[ "$actual" == "$expected" ]] || { printf '%s\n' 'pinned executable checksum mismatch' >&2; exit 3; }

printf '%s\n' "$url" > "$evidence/executable-url.txt"
printf '%s\n' "$actual" > "$evidence/executable.sha256"
unzip -p "$executable" META-INF/MANIFEST.MF > "$evidence/executable-manifest.txt" || [[ -s "$evidence/executable-manifest.txt" ]]
unzip -p "$executable" META-INF/LICENSE > "$evidence/LICENSE-executable" || [[ -s "$evidence/LICENSE-executable" ]]
unzip -p "$executable" META-INF/NOTICE > "$evidence/NOTICE-executable" || [[ -s "$evidence/NOTICE-executable" ]]
printf '%s\n' 'META-INF/LICENSE|META-INF/NOTICE' > "$evidence/executable-license-notice-locators.txt"
java -XshowSettings:properties -version > "$evidence/java-version.txt" 2>&1
javac -version > "$evidence/javac-version.txt" 2>&1
jar --version > "$evidence/jar-version.txt" 2>&1
python3 --version > "$evidence/python-version.txt" 2>&1
bash --version > "$evidence/bash-version.txt" 2>&1
uname -a > "$evidence/os-version.txt"
git -C "$root" rev-parse HEAD > "$evidence/source-revision.txt"
for item in \
  "plugin:tools/t0012-schema-value-coupling-probe/src/T0012SchemaValueCouplingInputPlugin.java" \
  "runner:tools/t0012-schema-value-coupling-probe/run.sh" \
  "wrapper:tests/t0012_schema_value_coupling_probe_test.sh"
do
  label=${item%%:*}
  relative=${item#*:}
  printf '%s\n' "$relative" > "$evidence/$label-source-path.txt"
  shasum -a 256 "$root/$relative" | awk '{print $1}' > "$evidence/$label-source.sha256"
done
printf '%s\n' capture > "$evidence/stage.txt"

javac -cp "$executable" -d "$plugin/classes" "$source_file"
printf '%s\n' \
  'Manifest-Version: 1.0' \
  'Embulk-Plugin-Main-Class: T0012SchemaValueCouplingInputPlugin' \
  'Embulk-Plugin-Category: input' \
  'Embulk-Plugin-Type: t0012_coupling' \
  'Embulk-Plugin-Spi-Version: 0' > "$plugin/MANIFEST.MF"
jar_file="$repository/embulk-input-t0012_coupling-0.0.1.jar"
jar cfm "$jar_file" "$plugin/MANIFEST.MF" -C "$plugin/classes" .
cp "$jar_file" "$evidence/plugin-under-test.jar"
shasum -a 256 "$evidence/plugin-under-test.jar" | awk '{print $1}' > "$evidence/plugin-jar.sha256"
printf '%s\n' 'plugin-under-test.jar' > "$evidence/plugin-jar-path.txt"
printf '%s\n' '<project><modelVersion>4.0.0</modelVersion><groupId>org.embulk.t0012</groupId><artifactId>embulk-input-t0012_coupling</artifactId><version>0.0.1</version></project>' > "$repository/embulk-input-t0012_coupling-0.0.1.pom"
printf '%s\n' 'source=maven|group=org.embulk.t0012|name=t0012_coupling|version=0.0.1|artifact=embulk-input-t0012_coupling|local-only' > "$evidence/plugin-coordinate.txt"

: > "$evidence/coupling-cases.raw"
: > "$evidence/coupling-traces.raw"
for fixture in matching explicit-null unset-text wrong-setter duplicate-name; do
  config="$run_dir/$fixture.yml"
  stdout="$evidence/$fixture.stdout.log"
  stderr="$evidence/$fixture.stderr.log"
  trace_file="$evidence/$fixture.trace.raw"
  printf '%s\n' 'in:' '  type:' '    source: maven' '    group: org.embulk.t0012' \
    '    name: t0012_coupling' '    version: 0.0.1' 'out:' '  type: "null"' > "$config"
  status=0
  T0012_COUPLING_FIXTURE="$fixture" java -jar "$executable" \
    "-Xembulk_home=$EMBULK_HOME" run "$config" > "$stdout" 2> "$stderr" || status=$?
  printf '%s\n' "$status" > "$evidence/$fixture.exit.txt"
  awk -v prefix="COUPLINGTRACE|$fixture|" 'index($0, prefix) == 1' "$stdout" > "$trace_file"
  count=$(wc -l < "$trace_file" | tr -d ' ')
  hash=$(shasum -a 256 "$trace_file" | awk '{print $1}')
  printf 'COUPLINGCASE|%s|%s|%s|%s\n' "$fixture" "$status" "$count" "$hash" >> "$evidence/coupling-cases.raw"
  cat "$trace_file" >> "$evidence/coupling-traces.raw"
done

python3 - "$evidence" <<'PY'
import pathlib
import sys
import uuid

root = pathlib.Path(sys.argv[1])
fixtures = ("matching", "explicit-null", "unset-text", "wrong-setter", "duplicate-name")
for fixture in fixtures:
    lines = (root / f"{fixture}.trace.raw").read_text(encoding="utf-8").splitlines()
    if not lines:
        raise SystemExit("missing trace for " + fixture)
    capture = None
    terminals = 0
    for sequence, line in enumerate(lines, 1):
        fields = line.split("|")
        if len(fields) < 5 or fields[:2] != ["COUPLINGTRACE", fixture] or fields[3] != str(sequence):
            raise SystemExit("invalid capture transport for " + fixture)
        parsed = uuid.UUID(fields[2])
        if str(parsed) != fields[2] or parsed.version != 4:
            raise SystemExit("invalid capture id for " + fixture)
        capture = capture or fields[2]
        if fields[2] != capture:
            raise SystemExit("multiple capture ids for " + fixture)
        terminals += fields[4] == "terminal"
    if terminals != 1:
        raise SystemExit("terminal count for " + fixture)
PY

for file in coupling-cases.raw coupling-traces.raw \
  matching.stdout.log matching.stderr.log matching.trace.raw matching.exit.txt \
  explicit-null.stdout.log explicit-null.stderr.log explicit-null.trace.raw explicit-null.exit.txt \
  unset-text.stdout.log unset-text.stderr.log unset-text.trace.raw unset-text.exit.txt \
  wrong-setter.stdout.log wrong-setter.stderr.log wrong-setter.trace.raw wrong-setter.exit.txt \
  duplicate-name.stdout.log duplicate-name.stderr.log duplicate-name.trace.raw duplicate-name.exit.txt
do
  shasum -a 256 "$evidence/$file" | awk -v name="$file" '{print name "=" $1}'
done > "$evidence/raw-evidence-hashes.txt"

cat "$evidence/coupling-cases.raw"
printf 'T0012_COUPLING_CAPTURE_ONLY=collected|evidence=%s\n' "$evidence"

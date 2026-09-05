#!/usr/bin/env bash
set -euo pipefail

# Independently authored T-0012/S01 reference-observation runner. It downloads
# no source, builds no upstream project, and keeps all runtime material outside
# the repository.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
probe_source="$script_dir/src/T0012InputPlugin.java"
executable_url=${T0012_EXECUTABLE_URL:-https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar}
expected_executable_sha256=e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47
temporary_root=${T0012_TEMP_ROOT:-"${TMPDIR:-/private/tmp}/t0012-config-presence-executable"}

case "$temporary_root" in
  /tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*) ;;
  *)
    printf '%s\n' 'T0012_TEMP_ROOT must be a temporary directory outside the repository' >&2
    exit 2
    ;;
esac
mkdir -p -- "$temporary_root"
if [[ -L "$temporary_root" ]]; then
  printf '%s\n' 'T0012_TEMP_ROOT must not be a symlink' >&2
  exit 2
fi
if [[ ! -f "$probe_source" ]]; then
  printf 'missing probe source: %s\n' "$probe_source" >&2
  exit 2
fi

validate_schema_evidence() {
  PYTHONOPTIMIZE= python3 - "$1" <<'PY'
import base64, hashlib, pathlib, sys
d = pathlib.Path(sys.argv[1]); fixtures = {"empty", "ordered6types", "duplicate-name-differing-types"}
def require(value):
    if not value: raise ValueError()
try:
    cases = (d / "schema-cases.raw").read_text().splitlines()
    rows = (d / "schema-results.raw").read_text().splitlines()
    require(len(cases) == 3)
    parsed = {}
    for row in cases:
        tag, fixture, code, outcome, entered = row.split("|")
        require(tag == "SCHEMA_CASE" and fixture in fixtures and fixture not in parsed)
        require(code.isdigit() and outcome in {"SUCCESS", "EXCEPTION"} and entered in {"0", "1"})
        parsed[fixture] = (code, outcome, entered)
    require(set(parsed) == fixtures)
    data = {
        fixture: {
            "field": {"transaction": [], "run": []},
            "phase": {}, "exception": [], "entered": [],
        }
        for fixture in fixtures
    }

    def b64(value):
        decoded = base64.b64decode(value, validate=True)
        decoded.decode("utf-8")
        require(base64.b64encode(decoded).decode() == value)

    for row in rows:
        parts = row.split("|")
        require(len(parts) >= 2)
        tag = parts[0]
        fixture = parts[1]
        require(fixture in fixtures)
        if tag == "SCHEMA_FIELD" and len(parts) == 6:
            _, _, phase, index, name, type_name = parts
            require(phase in {"transaction", "run"} and index.isdigit())
            b64(name)
            b64(type_name)
            data[fixture]["field"][phase].append((int(index), name, type_name))
        elif tag == "SCHEMA_PHASE" and len(parts) == 5:
            _, _, phase, count, digest = parts
            require(phase in {"transaction", "run"})
            require(count.isdigit())
            require(len(digest) == 64)
            require(all(c in "0123456789abcdef" for c in digest))
            require(phase not in data[fixture]["phase"])
            data[fixture]["phase"][phase] = (int(count), digest)
        elif tag == "SCHEMA_EXCEPTION" and len(parts) == 5:
            _, _, phase, kind, message = parts
            require(phase == "transaction")
            require(kind != "")
            b64(kind)
            if message != "-":
                b64(message)
            data[fixture]["exception"].append(row)
        elif tag == "CONTROL_RUN_ENTERED" and len(parts) == 2:
            data[fixture]["entered"].append(row)
        else:
            raise ValueError(row)
    for fixture, (code, outcome, entered) in parsed.items():
        entry = data[fixture]
        if outcome == "SUCCESS":
            require(code == "0" and entered == "1" and not entry["exception"] and len(entry["entered"]) == 1 and set(entry["phase"]) == {"transaction", "run"})
            for phase, (count, digest) in entry["phase"].items():
                fields = entry["field"][phase]; require([field[0] for field in fields] == list(range(count)))
                material = "".join(f"{i}|{name}|{type_name}\n" for i, name, type_name in fields)
                require(hashlib.sha256(material.encode()).hexdigest() == digest)
            require(entry["phase"]["transaction"] == entry["phase"]["run"])
        else:
            require(code == "0" and entered == "0")
            require(len(entry["exception"]) == 1)
            require(not entry["entered"] and not entry["phase"])
            require(not entry["field"]["transaction"])
            require(not entry["field"]["run"])
    require(parsed["empty"][1] == "SUCCESS" and parsed["ordered6types"][1] == "SUCCESS")
except (OSError, UnicodeError, ValueError, IndexError, base64.binascii.Error): sys.exit(4)
PY
}

if [[ ${T0012_MODE:-presence} == schema-validate ]]; then
  validate_schema_evidence "${T0012_SCHEMA_EVIDENCE_DIR:-}"
  exit $?
fi

run_dir=$(mktemp -d "$temporary_root/run.XXXXXX")
evidence_dir="$run_dir/evidence"
plugin_dir="$run_dir/plugin"
export EMBULK_HOME="$run_dir/embulk-home"
plugin_repository="$EMBULK_HOME/lib/m2/repository/org/embulk/t0012/embulk-input-t0012/0.0.1"
mkdir -p -- "$evidence_dir" "$plugin_dir/classes" "$plugin_repository"
trap 'printf "T0012_EVIDENCE_DIR=%s\n" "$evidence_dir"' EXIT

if [[ ${T0012_NEGATIVE:-} == unavailable-runtime ]]; then
  executable_url=https://github.com/embulk/embulk/releases/download/v0.11.5/unavailable.jar
fi
executable="$run_dir/embulk-0.11.5.jar"
if ! curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error \
  --output "$executable" "$executable_url"; then
  printf 'unable to retrieve pinned executable: %s\n' "$executable_url" >&2
  exit 56
fi
if [[ ${T0012_NEGATIVE:-} == corrupt-hash ]]; then
  printf '%s' 'corrupt' >> "$executable"
  printf '%s\n' 'corrupt-copy-injected' > "$evidence_dir/negative-control.txt"
fi
actual_executable_sha256=$(shasum -a 256 "$executable" | awk '{print $1}')
if [[ "$actual_executable_sha256" != "$expected_executable_sha256" ]]; then
  printf '%s\n' 'pinned executable checksum mismatch' >&2
  exit 3
fi

printf '%s\n' "$executable_url" > "$evidence_dir/executable-url.txt"
printf '%s\n' "$actual_executable_sha256" > "$evidence_dir/executable.sha256"
unzip -p "$executable" META-INF/MANIFEST.MF > "$evidence_dir/executable-manifest.txt" \
  || [[ -s "$evidence_dir/executable-manifest.txt" ]]
unzip -p "$executable" META-INF/LICENSE > "$evidence_dir/LICENSE-executable" \
  || [[ -s "$evidence_dir/LICENSE-executable" ]]
unzip -p "$executable" META-INF/NOTICE > "$evidence_dir/NOTICE-executable" \
  || [[ -s "$evidence_dir/NOTICE-executable" ]]
printf '%s\n' 'META-INF/LICENSE|META-INF/NOTICE' > "$evidence_dir/executable-license-notice-locators.txt"
java -XshowSettings:properties -version > "$evidence_dir/java-version.txt" 2>&1
uname -s > "$evidence_dir/os-family.txt"

shasum -a 256 "$probe_source" | awk '{print $1}' > "$evidence_dir/plugin-source.sha256"
javac -cp "$executable" -d "$plugin_dir/classes" "$probe_source"
plugin_manifest="$plugin_dir/MANIFEST.MF"
printf '%s\n' \
  'Manifest-Version: 1.0' \
  'Embulk-Plugin-Main-Class: T0012InputPlugin' \
  'Embulk-Plugin-Category: input' \
  'Embulk-Plugin-Type: t0012' \
  'Embulk-Plugin-Spi-Version: 0' > "$plugin_manifest"
plugin_jar="$plugin_repository/embulk-input-t0012-0.0.1.jar"
jar cfm "$plugin_jar" "$plugin_manifest" -C "$plugin_dir/classes" .
printf '%s\n' '<project><modelVersion>4.0.0</modelVersion><groupId>org.embulk.t0012</groupId><artifactId>embulk-input-t0012</artifactId><version>0.0.1</version></project>' > "$plugin_repository/embulk-input-t0012-0.0.1.pom"
shasum -a 256 "$plugin_jar" | awk '{print $1}' > "$evidence_dir/plugin-jar.sha256"
printf '%s\n' 'source=maven|group=org.embulk.t0012|name=t0012|version=0.0.1|artifact=embulk-input-t0012|local-only' > "$evidence_dir/plugin-coordinate.txt"

run_presence() {
  : > "$evidence_dir/observations.raw.bin"
  : > "$evidence_dir/probe-output.raw"
  for declaration in required defaulted optional; do
    for state in absent null value; do
      config_file="$run_dir/$declaration-$state.yml"
      {
        printf '%s\n' 'in:' '  type:' '    source: maven' '    group: org.embulk.t0012' '    name: t0012' '    version: 0.0.1'
        if [[ "$state" != absent ]]; then
          [[ "$state" == null ]] && printf '%s\n' '  field: null' || printf '%s\n' '  field: observed-value'
        fi
        printf '%s\n' 'out:' '  type: "null"'
      } > "$config_file"
      T0012_DECLARATION="$declaration" T0012_STATE="$state" T0012_RAW_FILE="$evidence_dir/observations.raw.bin" \
        java -jar "$executable" "-Xembulk_home=$EMBULK_HOME" run "$config_file" >> "$evidence_dir/probe-output.raw" 2>&1
    done
  done

  grep '^CASE|' "$evidence_dir/probe-output.raw" > "$evidence_dir/cases.raw" || true
  case_count=$(wc -l < "$evidence_dir/cases.raw" | tr -d ' ')
  if [[ "$case_count" != 9 ]]; then
    printf 'expected 9 complete runtime case rows, found %s\n' "$case_count" >&2
    exit 4
  fi
  if grep -Ev '^CASE\|(required|defaulted|optional)\|(absent|null|value)\|(SUCCESS|EXCEPTION)\|([A-Za-z0-9+/=]*|-)\|([A-Za-z0-9+/=]*|-)$' "$evidence_dir/cases.raw" > /dev/null; then
    printf '%s\n' 'one or more case rows is incomplete' >&2
    exit 4
  fi
  for key in required:absent required:null required:value defaulted:absent defaulted:null defaulted:value optional:absent optional:null optional:value; do
    declaration=${key%%:*}
    state=${key##*:}
    if [[ $(grep -Ec "^CASE\\|$declaration\\|$state\\|" "$evidence_dir/cases.raw") != 1 ]]; then
      printf 'missing or duplicate case key: %s\n' "$key" >&2
      exit 4
    fi
  done
  grep -Fqx 'CASE|required|value|SUCCESS|b2JzZXJ2ZWQtdmFsdWU=|' "$evidence_dir/cases.raw"
  grep -Fqx 'CASE|defaulted|value|SUCCESS|b2JzZXJ2ZWQtdmFsdWU=|' "$evidence_dir/cases.raw"
  grep -Fqx 'CASE|optional|value|SUCCESS|cHJlc2VudDpvYnNlcnZlZC12YWx1ZQ==|' "$evidence_dir/cases.raw"
  [[ -s "$evidence_dir/observations.raw.bin" ]] || exit 4
  cat "$evidence_dir/cases.raw"
}

run_conversion() {
  : > "$evidence_dir/observations.raw.bin"
  : > "$evidence_dir/conversion-cases.raw"
  local cases=(
    'boolean|boolean-true|true'
    'boolean|boolean-false|false'
    'boolean|boolean-quoted-true|"true"'
    'boolean|boolean-invalid|not-boolean'
    'long|long-37|37'
    'long|long-quoted-37|"37"'
    'long|long-max|9223372036854775807'
    'long|long-fractional|37.5'
    'long|long-overflow|9223372036854775808'
  )
  local entry type case_name value config_file raw_log exit_code marker row phase
  for entry in "${cases[@]}"; do
    IFS='|' read -r type case_name value <<< "$entry"
    config_file="$run_dir/$case_name.yml"
    raw_log="$evidence_dir/$case_name.raw.log"
    {
      printf '%s\n' 'in:' '  type:' '    source: maven' '    group: org.embulk.t0012' '    name: t0012' '    version: 0.0.1'
      printf '  field: %s\n' "$value"
      printf '%s\n' 'out:' '  type: "null"'
    } > "$config_file"
    printf '%s\n' "$value" > "$evidence_dir/$case_name.input.yml-value"
    if T0012_MODE=conversion T0012_TYPE="$type" T0012_CASE="$case_name" T0012_RAW_FILE="$evidence_dir/observations.raw.bin" \
      java -jar "$executable" "-Xembulk_home=$EMBULK_HOME" run "$config_file" > "$raw_log" 2>&1; then
      exit_code=0
    else
      exit_code=$?
    fi
    marker=$(grep -Ec '^probe config load$' "$raw_log" || true)
    row=$(grep '^CONVERSION_CASE|' "$raw_log" || true)
    if [[ "$marker" == 1 && "$exit_code" == 0 \
      && $(printf '%s\n' "$row" | sed '/^$/d' | wc -l | tr -d ' ') == 1 \
      && "$row" =~ ^CONVERSION_CASE\|$type\|$case_name\|(SUCCESS\|([A-Za-z0-9+/=]*|-)\|([A-Za-z0-9+/=]*|-)|EXCEPTION\|([A-Za-z0-9+/=]+|-)\|([A-Za-z0-9+/=]*|-))$ ]]; then
      phase='probe config load'
      printf 'CONVERSION_CASE|%s|%s|%s|%s\n' "$case_name" "$type" "$phase" "$exit_code" >> "$evidence_dir/conversion-cases.raw"
      printf '%s\n' "$row" >> "$evidence_dir/conversion-results.raw"
    elif [[ "$case_name" == long-overflow && "$marker" == 0 && "$exit_code" != 0 ]]; then
      phase='before probe callback'
      printf 'CONVERSION_CASE|%s|%s|%s|%s\n' "$case_name" "$type" "$phase" "$exit_code" >> "$evidence_dir/conversion-cases.raw"
      printf 'NO_PLUGIN_RESULT|%s\n' "$case_name" >> "$evidence_dir/conversion-results.raw"
    else
      printf 'invalid conversion observation for %s (marker=%s exit=%s rows=%s)\n' \
        "$case_name" "$marker" "$exit_code" "$(printf '%s\n' "$row" | sed '/^$/d' | wc -l | tr -d ' ')" >&2
      exit 4
    fi
  done
  if [[ $(wc -l < "$evidence_dir/conversion-cases.raw" | tr -d ' ') != 9 ]]; then
    printf '%s\n' 'expected 9 complete conversion case rows' >&2
    exit 4
  fi
  for case_name in boolean-true boolean-false boolean-quoted-true boolean-invalid long-37 long-quoted-37 long-max long-fractional long-overflow; do
    [[ $(grep -Ec "^CONVERSION_CASE\\|$case_name\\|" "$evidence_dir/conversion-cases.raw") == 1 ]] || exit 4
  done
  [[ $(wc -l < "$evidence_dir/conversion-results.raw" | tr -d ' ') == 9 ]] || exit 4
  grep -Fqx 'CONVERSION_CASE|boolean-true|boolean|probe config load|0' "$evidence_dir/conversion-cases.raw"
  grep -Fqx 'CONVERSION_CASE|long-37|long|probe config load|0' "$evidence_dir/conversion-cases.raw"
  grep -Fqx 'CONVERSION_CASE|boolean|boolean-true|SUCCESS|dHJ1ZQ==|' "$evidence_dir/conversion-results.raw"
  grep -Fqx 'CONVERSION_CASE|long|long-37|SUCCESS|Mzc=|' "$evidence_dir/conversion-results.raw"
  [[ -s "$evidence_dir/observations.raw.bin" ]] || exit 4
  cat "$evidence_dir/conversion-cases.raw"
}

run_schema() {
  : > "$evidence_dir/observations.raw.bin"
  : > "$evidence_dir/schema-cases.raw"
  : > "$evidence_dir/schema-results.raw"
  local fixture config_file raw_log exit_code rows exception phase_rows control_rows outcome
  for fixture in empty ordered6types duplicate-name-differing-types; do
    config_file="$run_dir/schema-$fixture.yml"
    raw_log="$evidence_dir/schema-$fixture.raw.log"
    printf '%s\n' 'in:' '  type:' '    source: maven' '    group: org.embulk.t0012' '    name: t0012' '    version: 0.0.1' 'out:' '  type: "null"' > "$config_file"
    if T0012_MODE=schema T0012_SCHEMA_FIXTURE="$fixture" T0012_RAW_FILE="$evidence_dir/observations.raw.bin" \
      java -jar "$executable" "-Xembulk_home=$EMBULK_HOME" run "$config_file" > "$raw_log" 2>&1; then exit_code=0; else exit_code=$?; fi
    rows=$(grep -E '^(SCHEMA_(FIELD|PHASE|EXCEPTION)|CONTROL_RUN_ENTERED)\|' "$raw_log" || true)
    printf '%s\n' "$rows" >> "$evidence_dir/schema-results.raw"
    exception=$(grep -Ec "^SCHEMA_EXCEPTION\\|$fixture\\|transaction\\|" "$raw_log" || true)
    phase_rows=$(grep -Ec "^SCHEMA_PHASE\\|$fixture\\|" "$raw_log" || true)
    control_rows=$(grep -Ec "^CONTROL_RUN_ENTERED\\|$fixture$" "$raw_log" || true)
    if [[ "$exception" == 1 && "$phase_rows" == 0 && "$control_rows" == 0 ]]; then outcome=EXCEPTION
    elif [[ "$exception" == 0 && "$phase_rows" == 2 && "$control_rows" == 1 ]]; then outcome=SUCCESS
    else printf 'invalid schema observation for %s (exit=%s exception=%s phase=%s control=%s)\n' "$fixture" "$exit_code" "$exception" "$phase_rows" "$control_rows" >&2; exit 4; fi
    printf 'SCHEMA_CASE|%s|%s|%s|%s\n' "$fixture" "$exit_code" "$outcome" "$control_rows" >> "$evidence_dir/schema-cases.raw"
  done
  validate_schema_evidence "$evidence_dir" || { printf '%s\n' 'schema evidence validation failed' >&2; exit 4; }
  [[ -s "$evidence_dir/observations.raw.bin" ]] || exit 4
  cat "$evidence_dir/schema-cases.raw"
}

case ${T0012_MODE:-presence} in
  presence) run_presence ;;
  conversion) run_conversion ;;
  schema) run_schema ;;
  *) printf 'unknown T0012_MODE: %s\n' "${T0012_MODE}" >&2; exit 2 ;;
esac

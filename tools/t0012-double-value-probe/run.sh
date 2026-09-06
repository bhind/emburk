#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$script_dir/../.." && pwd)
source_file="$script_dir/src/T0012DoubleValueInputPlugin.java"
mode=${T0012_DOUBLE_MODE:-full}
if [[ "$mode" != capture && "$mode" != full && "$mode" != validate ]]; then printf '%s\n' 'T0012_DOUBLE_MODE must be capture, full, or validate' >&2; exit 2; fi
if [[ "$mode" == full ]]; then printf '%s\n' 'T0012_DOUBLE_STAGE_B_REQUIRED' >&2; exit 2; fi
temporary_root=${T0012_DOUBLE_TEMP_ROOT:-"${TMPDIR:-/private/tmp}/t0012-double-value-probe"}
resolved_root=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "$temporary_root")
resolved_repository=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "$root")
case "$resolved_root" in /tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*) ;; *) printf '%s\n' 'T0012_DOUBLE_TEMP_ROOT must be external' >&2; exit 2;; esac
case "$resolved_root/" in "$resolved_repository/"*) printf '%s\n' 'T0012_DOUBLE_TEMP_ROOT resolves inside repository' >&2; exit 2;; esac
[[ ! -L "$temporary_root" && -f "$source_file" ]] || { printf '%s\n' 'invalid double probe path' >&2; exit 2; }

validate_evidence() {
  PYTHONDONTWRITEBYTECODE=1 python3 - "$1" <<'PY'
import base64, hashlib, pathlib, sys, uuid
root=pathlib.Path(sys.argv[1]); fixtures=("finite-null","nonfinite"); required=("double-cases.raw","double-traces.raw")
class Bad(Exception): pass
def need(label, condition):
    if not condition: raise Bad(label)
def dec(label, text):
    need(label, text.isascii() and text.isdigit() and len(text)<=6 and (text=="0" or not text.startswith("0"))); return int(text)
try:
    for name in required: need("missing-artifact", root.joinpath(name).is_file())
    cases=root.joinpath("double-cases.raw").read_text(encoding="utf-8").splitlines(); need("case-count",len(cases)==2)
    case_fields = [row.split("|") for row in cases]
    need("case-order", [row[1] if len(row) > 1 else None for row in case_fields] == list(fixtures))
    for fields in case_fields:
        need("case-grammar", len(fields) == 5 and fields[0] == "DOUBLECASE")
        need("case-event-cap", dec("case-count", fields[3]) <= 1024)
    traces=root.joinpath("double-traces.raw").read_text(encoding="utf-8").splitlines(); grouped={x:[] for x in fixtures}; captures={x:set() for x in fixtures}; last={x:0 for x in fixtures}
    need("combined-event-cap", len(traces) <= 2048)
    parsed={}
    for row in traces:
        parts=row.split("|"); need("trace-grammar",len(parts)>=5 and parts[0]=="DOUBLETRACE" and parts[1] in grouped)
        fixture,capture,sequence=parts[1:4]; parsed_uuid=uuid.UUID(capture); need("capture-id",str(parsed_uuid)==capture and parsed_uuid.version==4)
        value=dec("sequence",sequence); need("sequence",value==last[fixture]+1); last[fixture]=value; captures[fixture].add(capture)
        event_name = parts[4]
        arities = {
            "transaction-entry": 1, "schema-column": 4, "control-run-entry": 1,
            "run-entry": 2, "reader-construct-entry": 0, "reader-construct-return": 0,
            "builder-construct-entry": 0, "builder-construct-return": 0,
            "input-row-count": 1, "input-cell": 4, "builder-set-double-entry": 3,
            "builder-set-double-return": 3, "builder-set-null-entry": 2,
            "builder-set-null-return": 2, "builder-add-record-entry": 1,
            "builder-add-record-return": 1, "builder-finish-entry": 0,
            "collector-add-entry": 1, "reader-set-page-entry": 1,
            "reader-set-page-return": 1, "reader-next-record-entry": 2,
            "reader-next-record-return": 3, "reader-is-null-entry": 4,
            "reader-is-null-return": 5, "reader-get-double-entry": 4,
            "reader-get-double-return": 5, "cell-null": 4, "collector-add-return": 3,
            "collector-finish-entry": 2, "collector-finish-return": 2,
            "builder-finish-return": 0, "builder-close-entry": 0,
            "reader-close-entry": 2, "reader-close-return": 2,
            "collector-close-entry": 2, "collector-close-return": 2,
            "builder-close-return": 0, "runtime-output-finish-entry": 0,
            "runtime-output-finish-return": 0, "run-return": 1,
            "control-run-return": 1, "transaction-return": 1, "terminal": 3,
            "cleanup-entry": 2, "cleanup-return": 2, "run-exception": 2,
            "transaction-exception": 2, "collector-add-exception": 3,
            "reader-close-exception": 2, "collector-close-exception": 2,
        }
        need("event-known", event_name in arities)
        need("event-arity", len(parts) - 5 == arities[event_name])
        for field in parts[5:]:
            if field == "-": continue
            decoded=base64.b64decode(field,validate=True); need("canonical-base64",base64.b64encode(decoded).decode()==field)
            decoded.decode("utf-8")
        grouped[fixture].append(row)
    need("combined-order",traces==grouped[fixtures[0]]+grouped[fixtures[1]])
    for fixture in fixtures:
        values=[x.split("|") for x in cases if x.startswith("DOUBLECASE|"+fixture+"|")]; need("case-fixture",len(values)==1)
        fields=values[0]; need("case-grammar",len(fields)==5); exit_code=dec("case-exit",fields[2]); count=dec("case-count",fields[3]); need("case-event-cap",count<=1024); need("single-capture",len(captures[fixture])==1); need("case-count-match",count==len(grouped[fixture]))
        material=("\n".join(grouped[fixture])+"\n").encode(); need("case-digest",hashlib.sha256(material).hexdigest()==fields[4]); need("trace-copy",root.joinpath(fixture+".trace.raw").read_bytes()==material)
        extracted=[x for x in root.joinpath(fixture+".raw.log").read_text(encoding="utf-8").splitlines() if x.startswith("DOUBLETRACE|")]; need("raw-log",extracted==grouped[fixture])
        observed = {line.split("|")[4] for line in grouped[fixture]}
        need("capture-complete", "transaction-entry" in observed and "terminal" in observed)
except (Bad,OSError,UnicodeError,ValueError) as error:
    print("T0012_DOUBLE_VALIDATION_ERROR|"+(error.args[0] if error.args else "unclassified"),file=sys.stderr); raise SystemExit(4)
PY
}
if [[ "$mode" == validate ]]; then validate_evidence "${T0012_DOUBLE_EVIDENCE_DIR:-}"; printf '%s\n' 'T0012_DOUBLE_VALIDATE_ONLY=passed'; exit 0; fi

mkdir -p -- "$temporary_root"; run_dir=$(mktemp -d "$temporary_root/run.XXXXXX"); evidence="$run_dir/evidence"; plugin="$run_dir/plugin"; export EMBULK_HOME="$run_dir/embulk-home"; repository="$EMBULK_HOME/lib/m2/repository/org/embulk/t0012/embulk-input-t0012_double/0.0.1"; mkdir -p "$evidence" "$plugin/classes" "$repository"; trap 'printf "T0012_DOUBLE_EVIDENCE_DIR=%s\n" "$evidence"' EXIT
executable="$run_dir/embulk.jar"; executable_url=${T0012_EXECUTABLE_URL:-https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar}; expected=e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47
if ! curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error --output "$executable" "$executable_url"; then printf 'unable to retrieve pinned executable: %s\n' "$executable_url" >&2; exit 56; fi
actual=$(shasum -a 256 "$executable" | awk '{print $1}'); [[ "$actual" == "$expected" ]] || { printf '%s\n' 'pinned executable checksum mismatch' >&2; exit 3; }
printf '%s\n' "$executable_url" > "$evidence/executable-url.txt"
printf '%s\n' "$actual" > "$evidence/executable.sha256"
unzip -p "$executable" META-INF/MANIFEST.MF > "$evidence/executable-manifest.txt" || [[ -s "$evidence/executable-manifest.txt" ]]
unzip -p "$executable" META-INF/LICENSE > "$evidence/LICENSE-executable" || [[ -s "$evidence/LICENSE-executable" ]]
unzip -p "$executable" META-INF/NOTICE > "$evidence/NOTICE-executable" || [[ -s "$evidence/NOTICE-executable" ]]
printf '%s\n' 'META-INF/LICENSE|META-INF/NOTICE' > "$evidence/executable-license-notice-locators.txt"
java -XshowSettings:properties -version > "$evidence/java-version.txt" 2>&1
uname -s > "$evidence/os-family.txt"
git -C "$root" rev-parse HEAD > "$evidence/source-revision.txt"
printf '%s\n' "$source_file" > "$evidence/plugin-source-path.txt"
shasum -a 256 "$source_file" | awk '{print $1}' > "$evidence/plugin-source.sha256"
printf '%s\n' "$script_dir/run.sh" > "$evidence/runner-source-path.txt"
shasum -a 256 "$script_dir/run.sh" | awk '{print $1}' > "$evidence/runner-source.sha256"
printf '%s\n' "$root/tests/t0012_double_value_probe_test.sh" > "$evidence/wrapper-source-path.txt"
shasum -a 256 "$root/tests/t0012_double_value_probe_test.sh" | awk '{print $1}' > "$evidence/wrapper-source.sha256"
printf '%s\n' capture > "$evidence/stage.txt"
javac -cp "$executable" -d "$plugin/classes" "$source_file"
printf '%s\n' 'Manifest-Version: 1.0' 'Embulk-Plugin-Main-Class: T0012DoubleValueInputPlugin' 'Embulk-Plugin-Category: input' 'Embulk-Plugin-Type: t0012_double' 'Embulk-Plugin-Spi-Version: 0' > "$plugin/MANIFEST.MF"
jar_file="$repository/embulk-input-t0012_double-0.0.1.jar"
jar cfm "$jar_file" "$plugin/MANIFEST.MF" -C "$plugin/classes" .
shasum -a 256 "$jar_file" | awk '{print $1}' > "$evidence/plugin-jar.sha256"
printf '%s\n' '<project><modelVersion>4.0.0</modelVersion><groupId>org.embulk.t0012</groupId><artifactId>embulk-input-t0012_double</artifactId><version>0.0.1</version></project>' > "$repository/embulk-input-t0012_double-0.0.1.pom"
printf '%s\n' 'source=maven|group=org.embulk.t0012|name=t0012_double|version=0.0.1|artifact=embulk-input-t0012_double|local-only' > "$evidence/plugin-coordinate.txt"
: > "$evidence/double-cases.raw"; : > "$evidence/double-traces.raw"
for fixture in finite-null nonfinite; do
  config="$run_dir/$fixture.yml"; raw="$evidence/$fixture.raw.log"; printf '%s\n' 'in:' '  type:' '    source: maven' '    group: org.embulk.t0012' '    name: t0012_double' '    version: 0.0.1' 'out:' '  type: "null"' > "$config"
  if T0012_DOUBLE_FIXTURE="$fixture" java -jar "$executable" "-Xembulk_home=$EMBULK_HOME" run "$config" > "$raw" 2>&1; then status=0; else status=$?; fi
  grep "^DOUBLETRACE|$fixture|" "$raw" > "$evidence/$fixture.trace.raw" || true; count=$(wc -l < "$evidence/$fixture.trace.raw" | tr -d ' '); digest=$(shasum -a 256 "$evidence/$fixture.trace.raw" | awk '{print $1}'); printf 'DOUBLECASE|%s|%s|%s|%s\n' "$fixture" "$status" "$count" "$digest" >> "$evidence/double-cases.raw"; cat "$evidence/$fixture.trace.raw" >> "$evidence/double-traces.raw"
done
validate_evidence "$evidence"
for file in double-cases.raw double-traces.raw finite-null.raw.log nonfinite.raw.log finite-null.trace.raw nonfinite.trace.raw; do shasum -a 256 "$evidence/$file" | awk -v name="$file" '{print name "=" $1}'; done > "$evidence/raw-evidence-hashes.txt"
cat "$evidence/double-cases.raw"; printf 'T0012_DOUBLE_CAPTURE_ONLY=collected|evidence=%s\n' "$evidence"

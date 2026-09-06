#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$script_dir/../.." && pwd)
source_file="$script_dir/src/T0012DoubleValueInputPlugin.java"
wrapper_file="$root/tests/t0012_double_value_probe_test.sh"
mode=${T0012_DOUBLE_MODE:-full}

if [[ "$mode" != capture && "$mode" != full && "$mode" != validate ]]; then
  printf '%s\n' 'T0012_DOUBLE_MODE must be capture, full, or validate' >&2
  exit 2
fi

temporary_root=${T0012_DOUBLE_TEMP_ROOT:-"${TMPDIR:-/private/tmp}/t0012-double-value-probe"}
resolved_root=$(python3 -c 'import pathlib, sys
print(pathlib.Path(sys.argv[1]).resolve())' "$temporary_root")
resolved_repository=$(python3 -c 'import pathlib, sys
print(pathlib.Path(sys.argv[1]).resolve())' "$root")
case "$resolved_root" in
  /tmp/* | /private/tmp/* | /var/folders/* | /private/var/folders/*) ;;
  *)
    printf '%s\n' 'T0012_DOUBLE_TEMP_ROOT must be external' >&2
    exit 2
    ;;
esac
case "$resolved_root/" in
  "$resolved_repository/"*)
    printf '%s\n' 'T0012_DOUBLE_TEMP_ROOT resolves inside repository' >&2
    exit 2
    ;;
esac
if [[ -L "$temporary_root" || ! -f "$source_file" || ! -f "$wrapper_file" ]]; then
  printf '%s\n' 'invalid double probe path' >&2
  exit 2
fi

validate_evidence() {
  PYTHONDONTWRITEBYTECODE=1 python3 - "$1" "$source_file" "$script_dir/run.sh" "$wrapper_file" "$2" <<'PY'
import base64
import binascii
import hashlib
import pathlib
import re
import sys
import uuid

evidence = pathlib.Path(sys.argv[1])
sources = [pathlib.Path(value) for value in sys.argv[2:5]]
fixtures = ("finite-null", "nonfinite")
validation_level = sys.argv[5]
strict = validation_level == "strict"
hex16 = re.compile(r"[0-9a-f]{16}")
hex64 = re.compile(r"[0-9a-f]{64}")

class Bad(Exception):
    pass

def need(label, condition):
    if not condition:
        raise Bad(label)

def number(label, text, cap):
    canonical = text.isascii() and text.isdigit()
    canonical = canonical and (text == "0" or not text.startswith("0"))
    need(label, canonical and len(text) <= 6)
    value = int(text)
    need(label, value <= cap)
    return value

def decode(field):
    if field == "-":
        return None
    try:
        raw = base64.b64decode(field, validate=True)
    except binascii.Error as error:
        raise Bad("canonical-base64") from error
    need("canonical-base64", base64.b64encode(raw).decode() == field)
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError as error:
        raise Bad("utf8") from error

def bounded_bytes(path, cap):
    if path not in sources:
        need("evidence-path", evidence.is_dir() and not evidence.is_symlink())
        need("evidence-path", path.parent == evidence and not path.is_symlink())
    else:
        need("source-path", path.is_absolute() and not path.is_symlink())
    need("artifact-size", path.is_file() and path.stat().st_size <= cap)
    return path.read_bytes()

def bounded_text(path, cap):
    return bounded_bytes(path, cap).decode("utf-8")

def digest(path, cap):
    return hashlib.sha256(bounded_bytes(path, cap)).hexdigest()

# entry arity, return arity. Exceptions always repeat entry fields plus class/message.
operations = {
    "transaction": (1, 1), "schema-construct": (0, 0), "control-run": (1, 1),
    "resume": (1, 1), "cleanup": (2, 2), "run": (2, 1),
    "collector-construct": (0, 0), "reader-construct": (0, 0),
    "builder-construct": (0, 0), "builder-set-double": (3, 3),
    "builder-set-null": (2, 2), "builder-add-record": (1, 1),
    "builder-finish": (0, 0), "builder-close": (0, 0),
    "runtime-output-finish": (0, 0), "collector-add": (1, 3),
    "reader-set-page": (1, 1), "reader-next-record": (2, 3),
    "reader-is-null": (4, 5), "reader-get-double": (4, 5),
    "collector-finish": (2, 2), "collector-close": (2, 2),
    "reader-close": (2, 2), "guess": (0, 0),
}
plain = {"schema-column": 4, "input-row-count": 1, "input-cell": 4,
         "cell-null": 4, "terminal": 3}

def typed(event, values):
    numeric = {
        "transaction": (0,), "control-run": (0,), "resume": (0,),
        "cleanup": (0, 1), "run": (0,), "builder-set-double": (0, 1),
        "builder-set-null": (0, 1), "builder-add-record": (0,),
        "collector-add": (0,), "reader-set-page": (0,),
        "reader-next-record": (0, 1), "reader-is-null": (0, 1, 2, 3),
        "reader-get-double": (0, 1, 2, 3), "collector-finish": (0, 1),
        "collector-close": (0, 1), "reader-close": (0, 1),
    }
    base = event.removesuffix("-entry").removesuffix("-return").removesuffix("-exception")
    for position in numeric.get(base, ()):
        if position < len(values) - (2 if event.endswith("-exception") else 0):
            number("numeric-payload", values[position], 2048)
    if event == "schema-column":
        number("column-index", values[1], 64)
    if event == "input-row-count":
        number("input-row-count", values[0], 2048)
    if event == "run-entry":
        number("column-count", values[1], 64)
    if event == "collector-add-return":
        number("page-row-count", values[1], 2048)
        number("total-row-count", values[2], 2048)
    if event == "input-cell":
        number("row", values[0], 2048)
        number("column", values[1], 64)
    if event == "cell-null":
        for value in values:
            number("cell-position", value, 2048)
    if event == "reader-next-record-return":
        need("boolean-payload", values[2] in ("true", "false"))
    if event == "reader-is-null-return":
        need("boolean-payload", values[4] in ("true", "false"))
    if event in ("builder-set-double-entry", "builder-set-double-return"):
        need("double-bits", hex16.fullmatch(values[2] or "") is not None)
    if event == "reader-get-double-return":
        need("double-bits", hex16.fullmatch(values[4] or "") is not None)
    if event == "input-cell":
        need("cell-tag", values[2] in ("double-bits", "null"))
        valid = values[3] is None if values[2] == "null" else hex16.fullmatch(values[3] or "") is not None
        need("input-value", valid)

def parse(line, fixture, capture, sequence, stack):
    fields = line.split("|")
    need("trace-grammar", len(fields) >= 5 and fields[:2] == ["DOUBLETRACE", fixture])
    try:
        parsed_uuid = uuid.UUID(fields[2])
    except ValueError as error:
        raise Bad("capture-id") from error
    need("capture-id", str(parsed_uuid) == fields[2] and parsed_uuid.version == 4)
    need("single-capture", capture is None or capture == fields[2])
    need("sequence", number("sequence", fields[3], 2048) == sequence)
    event = fields[4]
    values = [decode(field) for field in fields[5:]]
    if event.endswith("-entry"):
        name = event[:-6]
        need("event-known", name in operations)
        need("event-arity", len(values) == operations[name][0])
        stack.append((name, values))
    elif event.endswith("-return") or event.endswith("-exception"):
        suffix = "-return" if event.endswith("-return") else "-exception"
        name = event[:-len(suffix)]
        need("event-known", name in operations)
        need("operation-pair", bool(stack) and stack[-1][0] == name)
        entry = stack.pop()[1]
        arity = operations[name][1] if suffix == "-return" else operations[name][0] + 2
        need("event-arity", len(values) == arity)
        if suffix == "-exception":
            need("exception-class", values[-2] not in (None, ""))
        shared = len(entry) if suffix == "-exception" else min(len(entry), operations[name][1])
        need("operation-identity", values[:shared] == entry[:shared])
    else:
        need("event-known", event in plain)
        need("event-arity", len(values) == plain[event])
        if event == "terminal":
            need("terminal-with-open-operation", not stack)
    typed(event, values)
    return fields[2], event, values

def encoded(value):
    if value is None:
        return "-"
    return base64.b64encode(value.encode("utf-8")).decode("ascii")

def parser_self_check():
    capture = "12345678-1234-4234-9234-123456789abc"
    defaults = {
        "transaction": ["1"], "control-run": ["1"], "resume": ["1"],
        "cleanup": ["1", "1"], "run": ["0", "1"],
        "builder-set-double": ["0", "0", "0000000000000000"],
        "builder-set-null": ["0", "0"], "builder-add-record": ["0"],
        "collector-add": ["0"], "reader-set-page": ["0"],
        "reader-next-record": ["0", "0"],
        "reader-is-null": ["0", "0", "0", "0"],
        "reader-get-double": ["0", "0", "0", "0"],
        "collector-finish": ["0", "0"], "collector-close": ["0", "0"],
        "reader-close": ["0", "0"],
    }
    for name, (entry_arity, _) in operations.items():
        values = defaults.get(name, [])
        need("self-check-entry-arity", len(values) == entry_arity)
        stack = []
        entry = "|".join(["DOUBLETRACE", "finite-null", capture, "1", name + "-entry"] + [encoded(value) for value in values])
        exception_values = values + ["java.lang.RuntimeException", None]
        exception = "|".join(["DOUBLETRACE", "finite-null", capture, "2", name + "-exception"] + [encoded(value) for value in exception_values])
        current, _, _ = parse(entry, "finite-null", None, 1, stack)
        parse(exception, "finite-null", current, 2, stack)
        need("self-check-pair", not stack)
        malformed = "|".join(exception.split("|")[:-1])
        rejected = False
        try:
            probe_stack = [(name, values)]
            parse(malformed, "finite-null", capture, 2, probe_stack)
        except Bad:
            rejected = True
        need("self-check-rejection", rejected)

def expected_vector(fixture):
    bits = {
        "finite-null": [
            "7fefffffffffffff", "ffefffffffffffff", "0000000000000001",
            "8000000000000001", "0000000000000000", "8000000000000000",
            None,
        ],
        "nonfinite": [
            "7ff0000000000000", "fff0000000000000", "7ff8000000000000",
            "7ff8000000000042", "fff8000000000042",
        ],
    }[fixture]
    events = [
        ("transaction-entry", ["1"]),
        ("schema-construct-entry", []),
        ("schema-construct-return", []),
        ("schema-column", ["transaction", "0", "number", "double"]),
        ("control-run-entry", ["1"]),
        ("run-entry", ["0", "1"]),
        ("schema-column", ["run", "0", "number", "double"]),
        ("collector-construct-entry", []),
        ("reader-construct-entry", []),
        ("reader-construct-return", []),
        ("collector-construct-return", []),
        ("builder-construct-entry", []),
        ("builder-construct-return", []),
        ("input-row-count", [str(len(bits))]),
    ]
    for row, value in enumerate(bits):
        position = [str(row), "0"]
        if value is None:
            events.append(("input-cell", position + ["null", None]))
            events.append(("builder-set-null-entry", position))
            events.append(("builder-set-null-return", position))
        else:
            events.append(("input-cell", position + ["double-bits", value]))
            events.append(("builder-set-double-entry", position + [value]))
            events.append(("builder-set-double-return", position + [value]))
        events.append(("builder-add-record-entry", [str(row)]))
        events.append(("builder-add-record-return", [str(row)]))
    events.extend([
        ("builder-finish-entry", []),
        ("collector-add-entry", ["0"]),
        ("reader-set-page-entry", ["0"]),
        ("reader-set-page-return", ["0"]),
    ])
    for row, value in enumerate(bits):
        position = ["0", str(row), str(row), "0"]
        events.append(("reader-next-record-entry", ["0", str(row)]))
        events.append(("reader-next-record-return", ["0", str(row), "true"]))
        events.append(("reader-is-null-entry", position))
        events.append(("reader-is-null-return", position + ["true" if value is None else "false"]))
        if value is None:
            events.append(("cell-null", position))
        else:
            events.append(("reader-get-double-entry", position))
            events.append(("reader-get-double-return", position + [value]))
    rows = str(len(bits))
    events.extend([
        ("reader-next-record-entry", ["0", rows]),
        ("reader-next-record-return", ["0", rows, "false"]),
        ("collector-add-return", ["0", rows, rows]),
        ("collector-finish-entry", ["1", rows]),
        ("collector-finish-return", ["1", rows]),
        ("builder-finish-return", []),
        ("builder-close-entry", []),
        ("collector-close-entry", ["1", rows]),
        ("reader-close-entry", ["1", rows]),
        ("reader-close-return", ["1", rows]),
        ("collector-close-return", ["1", rows]),
        ("builder-close-return", []),
        ("runtime-output-finish-entry", []),
        ("runtime-output-finish-return", []),
        ("run-return", ["0"]),
        ("control-run-return", ["1"]),
        ("transaction-return", ["1"]),
        ("terminal", ["success", None, None]),
        ("cleanup-entry", ["1", "1"]),
        ("cleanup-return", ["1", "1"]),
    ])
    return events

def vector_label(fixture, expected, actual):
    event, values = expected
    if event == "schema-column":
        return "expected-schema"
    if event.startswith("builder-set") or event.startswith("builder-add"):
        return "expected-setters"
    if event == "input-cell":
        row = int(values[0])
        if fixture == "finite-null" and row in (4, 5):
            return "expected-zero-sign"
        if fixture == "nonfinite" and row in (0, 1):
            return "expected-infinity-sign"
        if fixture == "nonfinite" and row >= 2:
            return "expected-nan-bits"
        return "expected-finite-bits"
    if event.startswith("reader-get-double"):
        return "expected-input-getter"
    if event.startswith("reader-is-null") or event == "cell-null":
        return "expected-getter-null-pairing"
    if event.startswith("reader-next-record"):
        return "expected-reader-exhaustion"
    lifecycle = ("finish", "close", "return", "terminal", "cleanup")
    if any(part in event for part in lifecycle):
        return "expected-lifecycle"
    return "expected-event-vector"

try:
    parser_self_check()
    required = (
        "executable.sha256",
        "double-cases.raw", "double-traces.raw", "raw-evidence-hashes.txt",
        "finite-null.raw.log", "nonfinite.raw.log", "finite-null.trace.raw",
        "nonfinite.trace.raw", "plugin-source.sha256", "runner-source.sha256",
        "wrapper-source.sha256", "plugin-jar.sha256", "plugin-jar-path.txt",
        "plugin-coordinate.txt", "stage.txt",
    )
    for name in required:
        need("missing-artifact", evidence.joinpath(name).is_file())
    executable_hash = bounded_text(evidence.joinpath("executable.sha256"), 1024).strip()
    need("executable-pin", executable_hash == "e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47")
    for name, source in zip(("plugin-source.sha256", "runner-source.sha256", "wrapper-source.sha256"), sources):
        recorded = bounded_text(evidence.joinpath(name), 1024).strip()
        need("source-hash", recorded == digest(source, 1024 * 1024))
    jar_hash = bounded_text(evidence.joinpath("plugin-jar.sha256"), 1024).strip()
    need("jar-hash", hex64.fullmatch(jar_hash) is not None)
    artifact = pathlib.Path(bounded_text(evidence.joinpath("plugin-jar-path.txt"), 4096).strip())
    need("jar-path", artifact.is_absolute() and artifact.is_file() and not artifact.is_symlink())
    need("jar-path", evidence.parent in artifact.parents)
    need("jar-size", artifact.stat().st_size <= 4 * 1024 * 1024)
    need("jar-hash", hashlib.sha256(artifact.read_bytes()).hexdigest() == jar_hash)
    recorded_stage = bounded_text(evidence.joinpath("stage.txt"), 1024)
    need("stage", recorded_stage == "full\n" if strict else recorded_stage in ("capture\n", "full\n"))
    coordinate = "source=maven|group=org.embulk.t0012|name=t0012_double|version=0.0.1|artifact=embulk-input-t0012_double|local-only\n"
    need("coordinate", bounded_text(evidence.joinpath("plugin-coordinate.txt"), 4096) == coordinate)
    cases = bounded_text(evidence.joinpath("double-cases.raw"), 65536).splitlines()
    need("case-count", len(cases) == 2)
    combined = []
    for index, fixture in enumerate(fixtures):
        case = cases[index].split("|")
        need("case-grammar", len(case) == 5 and case[:2] == ["DOUBLECASE", fixture])
        exit_code = number("case-exit", case[2], 255)
        count = number("case-count", case[3], 1024)
        need("case-digest-format", hex64.fullmatch(case[4]) is not None)
        trace_path = evidence.joinpath(fixture + ".trace.raw")
        trace_bytes = bounded_bytes(trace_path, 1024 * 1024)
        need("trace-final-newline", trace_bytes.endswith(b"\n"))
        lines = trace_bytes.decode("utf-8").splitlines()
        need("case-count-match", count == len(lines) and count > 0)
        need("case-digest", hashlib.sha256(trace_bytes).hexdigest() == case[4])
        raw = bounded_text(evidence.joinpath(fixture + ".raw.log"), 8 * 1024 * 1024).splitlines()
        need("raw-log", [line for line in raw if line.startswith("DOUBLETRACE|")] == lines)
        capture = None
        stack = []
        parsed = []
        for sequence, line in enumerate(lines, 1):
            capture, event, values = parse(line, fixture, capture, sequence, stack)
            parsed.append((event, values))
        need("unpaired-operation", not stack)
        need("capture-start", parsed[0][0] == "transaction-entry")
        need("single-terminal", sum(event == "terminal" for event, _ in parsed) == 1)
        terminal_index = next(i for i, item in enumerate(parsed) if item[0] == "terminal")
        terminal = parsed[terminal_index][1]
        need("terminal-outcome", terminal[0] in ("success", "exception"))
        if terminal[0] == "success":
            need("terminal-success", terminal[1:] == [None, None] and exit_code == 0)
            need("transaction-result", parsed[terminal_index - 1][0] == "transaction-return")
        else:
            need("terminal-exception", terminal[1] not in (None, "") and exit_code != 0)
            need("transaction-result", parsed[terminal_index - 1][0] == "transaction-exception")
            need("terminal-exception-match", terminal[1:] == parsed[terminal_index - 1][1][-2:])
        if strict:
            expected = expected_vector(fixture)
            need("expected-event-count", len(parsed) == len(expected))
            for expected_item, actual_item in zip(expected, parsed):
                if expected_item != actual_item:
                    raise Bad(vector_label(fixture, expected_item, actual_item))
        combined.extend(lines)
    all_lines = bounded_text(evidence.joinpath("double-traces.raw"), 2 * 1024 * 1024).splitlines()
    need("combined-event-cap", len(all_lines) <= 2048)
    need("combined-order", all_lines == combined)
    hashes = {}
    manifest = bounded_text(evidence.joinpath("raw-evidence-hashes.txt"), 65536)
    for line in manifest.splitlines():
        pair = line.split("=")
        need("hash-manifest-grammar", len(pair) == 2 and hex64.fullmatch(pair[1]) is not None)
        need("hash-manifest-duplicate", pair[0] not in hashes)
        hashes[pair[0]] = pair[1]
    hashed = {"double-cases.raw", "double-traces.raw", "finite-null.raw.log", "nonfinite.raw.log", "finite-null.trace.raw", "nonfinite.trace.raw"}
    need("hash-manifest-membership", set(hashes) == hashed)
    for name, value in hashes.items():
        cap = 8 * 1024 * 1024 if name.endswith(".raw.log") else 2 * 1024 * 1024
        need("hash-manifest-value", digest(evidence.joinpath(name), cap) == value)
except (Bad, OSError, UnicodeError, ValueError) as error:
    label = error.args[0] if error.args else "unclassified"
    print("T0012_DOUBLE_VALIDATION_ERROR|" + label, file=sys.stderr)
    raise SystemExit(4)
PY
}

if [[ "$mode" == validate ]]; then
  validation_level=transport
  if [[ ${T0012_DOUBLE_STRICT_VALIDATE:-0} == 1 ]]; then
    validation_level=strict
  fi
  validate_evidence "${T0012_DOUBLE_EVIDENCE_DIR:-}" "$validation_level"
  printf '%s\n' 'T0012_DOUBLE_VALIDATE_ONLY=passed'
  exit 0
fi

mkdir -p -- "$temporary_root"
run_dir=$(mktemp -d "$temporary_root/run.XXXXXX")
evidence="$run_dir/evidence"
plugin="$run_dir/plugin"
export EMBULK_HOME="$run_dir/embulk-home"
repository="$EMBULK_HOME/lib/m2/repository/org/embulk/t0012/embulk-input-t0012_double/0.0.1"
mkdir -p "$evidence" "$plugin/classes" "$repository"
trap 'printf "T0012_DOUBLE_EVIDENCE_DIR=%s\n" "$evidence"' EXIT

executable="$run_dir/embulk.jar"
url=${T0012_EXECUTABLE_URL:-https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar}
expected=e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47
if [[ ${T0012_DOUBLE_NEGATIVE:-} == unavailable-runtime ]]; then
  url=https://127.0.0.1:1/t0012-unavailable.jar
fi
if ! curl --connect-timeout 2 --max-time 5 --fail --location --proto '=https' --tlsv1.2 --silent --show-error --output "$executable" "$url"; then
  printf 'unable to retrieve pinned executable: %s\n' "$url" >&2
  exit 56
fi
if [[ ${T0012_DOUBLE_NEGATIVE:-} == corrupt-hash ]]; then
  printf '%s\n' 'corrupt-copy-injected' >> "$executable"
  printf '%s\n' 'corrupt-copy-injected' > "$evidence/negative-control.txt"
fi
actual=$(shasum -a 256 "$executable" | awk '{print $1}')
if [[ "$actual" != "$expected" ]]; then
  printf '%s\n' 'pinned executable checksum mismatch' >&2
  exit 3
fi

printf '%s\n' "$url" > "$evidence/executable-url.txt"
printf '%s\n' "$actual" > "$evidence/executable.sha256"
unzip -p "$executable" META-INF/MANIFEST.MF > "$evidence/executable-manifest.txt" || [[ -s "$evidence/executable-manifest.txt" ]]
unzip -p "$executable" META-INF/LICENSE > "$evidence/LICENSE-executable" || [[ -s "$evidence/LICENSE-executable" ]]
unzip -p "$executable" META-INF/NOTICE > "$evidence/NOTICE-executable" || [[ -s "$evidence/NOTICE-executable" ]]
printf '%s\n' 'META-INF/LICENSE|META-INF/NOTICE' > "$evidence/executable-license-notice-locators.txt"
java -XshowSettings:properties -version > "$evidence/java-version.txt" 2>&1
uname -s > "$evidence/os-family.txt"
git -C "$root" rev-parse HEAD > "$evidence/source-revision.txt"
for item in "plugin:$source_file" "runner:$script_dir/run.sh" "wrapper:$wrapper_file"; do
  label=${item%%:*}
  path=${item#*:}
  printf '%s\n' "$path" > "$evidence/$label-source-path.txt"
  shasum -a 256 "$path" | awk '{print $1}' > "$evidence/$label-source.sha256"
done
printf '%s\n' "$mode" > "$evidence/stage.txt"

javac -cp "$executable" -d "$plugin/classes" "$source_file"
printf '%s\n' 'Manifest-Version: 1.0' 'Embulk-Plugin-Main-Class: T0012DoubleValueInputPlugin' 'Embulk-Plugin-Category: input' 'Embulk-Plugin-Type: t0012_double' 'Embulk-Plugin-Spi-Version: 0' > "$plugin/MANIFEST.MF"
jar_file="$repository/embulk-input-t0012_double-0.0.1.jar"
jar cfm "$jar_file" "$plugin/MANIFEST.MF" -C "$plugin/classes" .
shasum -a 256 "$jar_file" | awk '{print $1}' > "$evidence/plugin-jar.sha256"
printf '%s\n' "$jar_file" > "$evidence/plugin-jar-path.txt"
printf '%s\n' '<project><modelVersion>4.0.0</modelVersion><groupId>org.embulk.t0012</groupId><artifactId>embulk-input-t0012_double</artifactId><version>0.0.1</version></project>' > "$repository/embulk-input-t0012_double-0.0.1.pom"
printf '%s\n' 'source=maven|group=org.embulk.t0012|name=t0012_double|version=0.0.1|artifact=embulk-input-t0012_double|local-only' > "$evidence/plugin-coordinate.txt"

: > "$evidence/double-cases.raw"
: > "$evidence/double-traces.raw"
for fixture in finite-null nonfinite; do
  config="$run_dir/$fixture.yml"
  raw="$evidence/$fixture.raw.log"
  printf '%s\n' 'in:' '  type:' '    source: maven' '    group: org.embulk.t0012' '    name: t0012_double' '    version: 0.0.1' 'out:' '  type: "null"' > "$config"
  status=0
  T0012_DOUBLE_FIXTURE="$fixture" java -jar "$executable" "-Xembulk_home=$EMBULK_HOME" run "$config" > "$raw" 2>&1 || status=$?
  awk -v prefix="DOUBLETRACE|$fixture|" 'index($0, prefix) == 1' "$raw" > "$evidence/$fixture.trace.raw"
  count=$(wc -l < "$evidence/$fixture.trace.raw" | tr -d ' ')
  hash=$(shasum -a 256 "$evidence/$fixture.trace.raw" | awk '{print $1}')
  printf 'DOUBLECASE|%s|%s|%s|%s\n' "$fixture" "$status" "$count" "$hash" >> "$evidence/double-cases.raw"
  cat "$evidence/$fixture.trace.raw" >> "$evidence/double-traces.raw"
done
for file in double-cases.raw double-traces.raw finite-null.raw.log nonfinite.raw.log finite-null.trace.raw nonfinite.trace.raw; do
  shasum -a 256 "$evidence/$file" | awk -v name="$file" '{print name "=" $1}'
done > "$evidence/raw-evidence-hashes.txt"

validation_level=transport
if [[ "$mode" == full ]]; then
  validation_level=strict
fi
validate_evidence "$evidence" "$validation_level"
cat "$evidence/double-cases.raw"
if [[ "$mode" == capture ]]; then
  printf 'T0012_DOUBLE_CAPTURE_ONLY=collected|evidence=%s\n' "$evidence"
else
  printf 'T0012_DOUBLE_FULL_RUN=passed|evidence=%s\n' "$evidence"
fi

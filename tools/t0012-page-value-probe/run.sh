#!/usr/bin/env bash
set -euo pipefail

# Original T-0012/S07 capture runner. It downloads no source, builds no upstream
# project, and keeps the pinned runtime and generated plugin outside the repo.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$script_dir/../.." && pwd)
source_file="$script_dir/src/T0012PageValueInputPlugin.java"
executable_url=${T0012_EXECUTABLE_URL:-https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar}
expected_executable_sha256=e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47
temporary_root=${T0012_PAGE_TEMP_ROOT:-"${TMPDIR:-/private/tmp}/t0012-page-value-probe"}

mode=${T0012_PAGE_MODE:-full}
[[ "$mode" == capture || "$mode" == full || "$mode" == validate ]] || {
  printf '%s\n' 'T0012_PAGE_MODE must be capture, validate, or full' >&2
  exit 2
}
resolved_root=$(python3 - "$temporary_root" <<'PY'
import pathlib, sys
print(pathlib.Path(sys.argv[1]).resolve())
PY
)
resolved_repository=$(python3 - "$root" <<'PY'
import pathlib, sys
print(pathlib.Path(sys.argv[1]).resolve())
PY
)
case "$resolved_root" in
  /tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*) ;;
  *)
    printf '%s\n' 'T0012_PAGE_TEMP_ROOT must be an external temporary directory' >&2
    exit 2
    ;;
esac
case "$resolved_root/" in
  "$resolved_repository/"*)
    printf '%s\n' 'T0012_PAGE_TEMP_ROOT resolves inside the repository' >&2
    exit 2
    ;;
esac
[[ ! -L "$temporary_root" ]] || {
  printf '%s\n' 'T0012_PAGE_TEMP_ROOT must not be a symlink' >&2
  exit 2
}
[[ -f "$source_file" ]] || {
  printf 'missing probe source: %s\n' "$source_file" >&2
  exit 2
}

validate_page_evidence() {
  PYTHONDONTWRITEBYTECODE=1 python3 - "$1" "$2" <<'PY'
import base64
import binascii
import hashlib
import pathlib
import sys
import uuid

root = pathlib.Path(sys.argv[1])
stage = sys.argv[2]
require_stage = stage in {"capture", "full", "validate"}
fixtures = ("empty", "typed-null")
caps = {"cases": 2, "events": 512, "combined": 1024}

class InvalidEvidence(Exception):
    pass

def require(label, condition):
    if not condition:
        raise InvalidEvidence(label)

def decimal(label, value, *, digits=6):
    require(label, value.isascii() and value.isdigit() and len(value) <= digits)
    require(label, value == "0" or not value.startswith("0"))
    try:
        return int(value)
    except ValueError as error:
        raise InvalidEvidence(label) from error

def event(name, *values):
    return (name, list(values))

def prefix():
    return [
        event("transaction-entry", "3"),
        event("schema-column", "transaction", "0", "flag", "boolean"),
        event("schema-column", "transaction", "1", "number", "long"),
        event("schema-column", "transaction", "2", "text", "string"),
        event("control-run-entry", "1"),
        event("run-entry", "0", "3"),
        event("schema-column", "run", "0", "flag", "boolean"),
        event("schema-column", "run", "1", "number", "long"),
        event("schema-column", "run", "2", "text", "string"),
        event("reader-construct-entry"),
        event("reader-construct-return"),
        event("builder-construct-entry"),
        event("builder-construct-return"),
    ]

def suffix(pages, rows):
    return [
        event("collector-finish-entry", str(pages), str(rows)),
        event("collector-finish-return", str(pages), str(rows)),
        event("builder-finish-return"),
        event("builder-close-entry"),
        event("collector-close-entry", str(pages), str(rows)),
        event("reader-close-entry", str(pages), str(rows)),
        event("reader-close-return", str(pages), str(rows)),
        event("collector-close-return", str(pages), str(rows)),
        event("builder-close-return"),
        event("runtime-output-finish-entry"),
        event("runtime-output-finish-return"),
        event("run-return", "0"),
        event("control-run-return", "1"),
        event("transaction-return", "1"),
        event("terminal", "success", None, None),
        event("cleanup-entry", "1", "1"),
        event("cleanup-return", "1", "1"),
    ]

def assignment(row, column, kind, value):
    if kind == "null":
        return [
            event("input-cell", str(row), str(column), "null", None),
            event("builder-set-null-entry", str(row), str(column)),
            event("builder-set-null-return", str(row), str(column)),
        ]
    title = kind
    return [
        event("input-cell", str(row), str(column), kind, value),
        event(f"builder-set-{title}-entry", str(row), str(column), value),
        event(f"builder-set-{title}-return", str(row), str(column), value),
    ]

def read_cell(page_row, total_row, column, kind, value):
    position = ["0", str(page_row), str(total_row), str(column)]
    rows = [
        event("reader-is-null-entry", *position),
        event("reader-is-null-return", *position, "true" if kind == "null" else "false"),
    ]
    if kind == "null":
        rows.append(event("cell-null", *position))
    else:
        rows.extend([
            event(f"reader-get-{kind}-entry", *position),
            event(f"reader-get-{kind}-return", *position, value),
        ])
    return rows

def expected(fixture):
    rows = prefix()
    if fixture == "empty":
        rows.extend([event("input-row-count", "0"), event("builder-finish-entry")])
        rows.extend(suffix(0, 0))
        return rows
    rows.append(event("input-row-count", "3"))
    supplied = [
        [("boolean", "true"), ("long", "9223372036854775807"), ("string", "")],
        [("boolean", "false"), ("long", "-9223372036854775808"), ("string", "A|B\nλ")],
        [("null", None), ("null", None), ("null", None)],
    ]
    for row, cells in enumerate(supplied):
        for column, (kind, value) in enumerate(cells):
            rows.extend(assignment(row, column, kind, value))
        rows.extend([
            event("builder-add-record-entry", str(row)),
            event("builder-add-record-return", str(row)),
        ])
    rows.extend([
        event("builder-finish-entry"),
        event("collector-add-entry", "0"),
        event("reader-set-page-entry", "0"),
        event("reader-set-page-return", "0"),
    ])
    for row, cells in enumerate(supplied):
        rows.extend([
            event("reader-next-record-entry", "0", str(row)),
            event("reader-next-record-return", "0", str(row), "true"),
        ])
        for column, (kind, value) in enumerate(cells):
            rows.extend(read_cell(row, row, column, kind, value))
    rows.extend([
        event("reader-next-record-entry", "0", "3"),
        event("reader-next-record-return", "0", "3", "false"),
        event("collector-add-return", "0", "3", "3"),
    ])
    rows.extend(suffix(1, 3))
    return rows

arity = {}
for fixture in fixtures:
    for name, values in expected(fixture):
        prior = arity.setdefault(name, len(values))
        require("internal-event-arity", prior == len(values))
arity.update({
    "transaction-exception": 2,
    "run-exception": 2,
    "builder-close-exception": 2,
    "collector-add-exception": 3,
    "reader-close-exception": 2,
    "collector-close-exception": 2,
    "resume-entry": 1,
    "resume-return": 1,
    "guess-entry": 0,
    "guess-return": 0,
})

def semantic_label(actual, wanted):
    names = {actual[0] if actual else "", wanted[0] if wanted else ""}
    if any(name == "schema-column" for name in names):
        return "schema-order-values"
    if any(name.startswith(("input-", "builder-set-", "builder-add-record")) for name in names):
        return "assignment-order-values"
    if any(name.startswith(("collector-add", "reader-set-page", "reader-next-record", "reader-is-null", "reader-get-", "cell-null")) for name in names):
        return "page-read-order-values"
    if any(name.startswith(("builder-finish", "builder-close", "collector-finish", "collector-close", "reader-close")) for name in names):
        return "finish-close-order"
    return "terminal-cleanup-order"

try:
    require("validation-stage", require_stage)
    case_lines = root.joinpath("page-cases.raw").read_text(encoding="utf-8").splitlines()
    trace_lines = root.joinpath("page-traces.raw").read_text(encoding="utf-8").splitlines()
    require("case-count", len(case_lines) == caps["cases"])
    require("combined-event-cap", len(trace_lines) <= caps["combined"])
    cases = {}
    for expected_fixture, line in zip(fixtures, case_lines, strict=True):
        fields = line.split("|")
        require("case-grammar", len(fields) == 5 and fields[0] == "PAGECASE")
        _, fixture, exit_code, count_text, digest = fields
        require("case-fixture", fixture == expected_fixture and fixture not in cases)
        parsed_exit = decimal("case-exit", exit_code, digits=3)
        count = decimal("case-event-count", count_text)
        require("case-event-cap", 0 < count <= caps["events"])
        require("case-digest-format", len(digest) == 64 and all(c in "0123456789abcdef" for c in digest))
        cases[fixture] = (parsed_exit, count, digest)

    grouped = {fixture: [] for fixture in fixtures}
    decoded = {fixture: [] for fixture in fixtures}
    captures = {fixture: set() for fixture in fixtures}
    sequences = {}
    for line in trace_lines:
        fields = line.split("|")
        require("trace-grammar", len(fields) >= 5 and fields[0] == "PAGETRACE")
        _, fixture, capture, sequence_text, name, *encoded = fields
        require("trace-fixture", fixture in grouped)
        try:
            parsed = uuid.UUID(capture)
        except ValueError as error:
            raise InvalidEvidence("capture-id") from error
        require("capture-id", str(parsed) == capture and parsed.version == 4)
        captures[fixture].add(capture)
        sequence = decimal("sequence-grammar", sequence_text)
        require("sequence-grammar", sequence > 0)
        key = (fixture, capture)
        require("sequence-contiguous", sequence == sequences.get(key, 0) + 1)
        sequences[key] = sequence
        require("event-known", name in arity)
        require("event-arity", len(encoded) == arity[name])
        values = []
        for value in encoded:
            if value == "-":
                values.append(None)
                continue
            try:
                raw = base64.b64decode(value, validate=True)
                text = raw.decode("utf-8")
            except (binascii.Error, UnicodeDecodeError) as error:
                raise InvalidEvidence("canonical-base64") from error
            require("canonical-base64", base64.b64encode(raw).decode("ascii") == value)
            values.append(text)
        grouped[fixture].append(line)
        decoded[fixture].append(event(name, *values))

    require(
        "combined-trace-order",
        trace_lines == grouped["empty"] + grouped["typed-null"],
    )
    for fixture in fixtures:
        exit_code, count, digest = cases[fixture]
        rows = grouped[fixture]
        require("single-capture", len(captures[fixture]) == 1)
        require("case-count-match", len(rows) == count)
        material = ("\n".join(rows) + "\n").encode("utf-8")
        require("case-digest-match", hashlib.sha256(material).hexdigest() == digest)
        require("trace-copy-match", root.joinpath(f"{fixture}.trace.raw").read_bytes() == material)
        raw_log = root.joinpath(f"{fixture}.raw.log")
        extracted = [line for line in raw_log.read_text(encoding="utf-8").splitlines() if line.startswith("PAGETRACE|")]
        require("raw-log-trace-match", extracted == rows)
        if stage == "capture":
            continue
        require("process-success", exit_code == 0)
        wanted = expected(fixture)
        if decoded[fixture] != wanted:
            mismatch = next((index for index, pair in enumerate(zip(decoded[fixture], wanted)) if pair[0] != pair[1]), min(len(decoded[fixture]), len(wanted)))
            actual = decoded[fixture][mismatch] if mismatch < len(decoded[fixture]) else None
            selected = wanted[mismatch] if mismatch < len(wanted) else None
            raise InvalidEvidence(semantic_label(actual, selected))
except (InvalidEvidence, OSError, UnicodeError) as error:
    label = error.args[0] if error.args else "unclassified"
    print(f"T0012_PAGE_VALIDATION_ERROR|{label}", file=sys.stderr)
    raise SystemExit(4)
PY
}

if [[ "$mode" == validate ]]; then
  validate_page_evidence "${T0012_PAGE_EVIDENCE_DIR:-}" validate
  printf '%s\n' 'T0012_PAGE_VALIDATE_ONLY=passed'
  exit 0
fi

mkdir -p -- "$temporary_root"
run_dir=$(mktemp -d "$temporary_root/run.XXXXXX")
evidence="$run_dir/evidence"
plugin="$run_dir/plugin"
export EMBULK_HOME="$run_dir/embulk-home"
repository="$EMBULK_HOME/lib/m2/repository/org/embulk/t0012/embulk-input-t0012_page_value/0.0.1"
mkdir -p -- "$evidence" "$plugin/classes" "$repository"
trap 'printf "T0012_PAGE_EVIDENCE_DIR=%s\n" "$evidence"' EXIT

executable="$run_dir/embulk.jar"
if [[ ${T0012_PAGE_NEGATIVE:-} == unavailable-runtime ]]; then
  executable_url=https://github.com/embulk/embulk/releases/download/v0.11.5/unavailable.jar
fi
if ! curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error \
  --output "$executable" "$executable_url"; then
  printf 'unable to retrieve pinned executable: %s\n' "$executable_url" >&2
  exit 56
fi
if [[ ${T0012_PAGE_NEGATIVE:-} == corrupt-hash ]]; then
  printf '%s' 'corrupt' >> "$executable"
  printf '%s\n' 'corrupt-copy-injected' > "$evidence/negative-control.txt"
fi
actual_sha=$(shasum -a 256 "$executable" | awk '{print $1}')
[[ "$actual_sha" == "$expected_executable_sha256" ]] || {
  printf '%s\n' 'pinned executable checksum mismatch' >&2
  exit 3
}

printf '%s\n' "$executable_url" > "$evidence/executable-url.txt"
printf '%s\n' "$actual_sha" > "$evidence/executable.sha256"
unzip -p "$executable" META-INF/MANIFEST.MF > "$evidence/executable-manifest.txt" \
  || [[ -s "$evidence/executable-manifest.txt" ]]
unzip -p "$executable" META-INF/LICENSE > "$evidence/LICENSE-executable" \
  || [[ -s "$evidence/LICENSE-executable" ]]
unzip -p "$executable" META-INF/NOTICE > "$evidence/NOTICE-executable" \
  || [[ -s "$evidence/NOTICE-executable" ]]
printf '%s\n' 'META-INF/LICENSE|META-INF/NOTICE' \
  > "$evidence/executable-license-notice-locators.txt"
java -XshowSettings:properties -version > "$evidence/java-version.txt" 2>&1
uname -s > "$evidence/os-family.txt"
git -C "$root" rev-parse HEAD > "$evidence/source-revision.txt"
printf '%s\n' "$source_file" > "$evidence/plugin-source-path.txt"
shasum -a 256 "$source_file" | awk '{print $1}' > "$evidence/plugin-source.sha256"
printf '%s\n' "$script_dir/run.sh" > "$evidence/runner-source-path.txt"
shasum -a 256 "$script_dir/run.sh" | awk '{print $1}' > "$evidence/runner-source.sha256"
printf '%s\n' "$root/tests/t0012_page_value_probe_test.sh" \
  > "$evidence/wrapper-source-path.txt"
shasum -a 256 "$root/tests/t0012_page_value_probe_test.sh" | awk '{print $1}' \
  > "$evidence/wrapper-source.sha256"

javac -cp "$executable" -d "$plugin/classes" "$source_file"
manifest="$plugin/MANIFEST.MF"
printf '%s\n' \
  'Manifest-Version: 1.0' \
  'Embulk-Plugin-Main-Class: T0012PageValueInputPlugin' \
  'Embulk-Plugin-Category: input' \
  'Embulk-Plugin-Type: t0012_page_value' \
  'Embulk-Plugin-Spi-Version: 0' > "$manifest"
jar_file="$repository/embulk-input-t0012_page_value-0.0.1.jar"
jar cfm "$jar_file" "$manifest" -C "$plugin/classes" .
printf '%s\n' '<project><modelVersion>4.0.0</modelVersion><groupId>org.embulk.t0012</groupId><artifactId>embulk-input-t0012_page_value</artifactId><version>0.0.1</version></project>' \
  > "$repository/embulk-input-t0012_page_value-0.0.1.pom"
shasum -a 256 "$jar_file" | awk '{print $1}' > "$evidence/plugin-jar.sha256"
printf '%s\n' 'source=maven|group=org.embulk.t0012|name=t0012_page_value|version=0.0.1|artifact=embulk-input-t0012_page_value|local-only' \
  > "$evidence/plugin-coordinate.txt"
printf '%s\n' "$mode" > "$evidence/stage.txt"

: > "$evidence/page-cases.raw"
: > "$evidence/page-traces.raw"
for fixture in empty typed-null; do
  config="$run_dir/$fixture.yml"
  raw_log="$evidence/$fixture.raw.log"
  printf '%s\n' \
    'in:' \
    '  type:' \
    '    source: maven' \
    '    group: org.embulk.t0012' \
    '    name: t0012_page_value' \
    '    version: 0.0.1' \
    'out:' \
    '  type: "null"' > "$config"
  if T0012_PAGE_FIXTURE="$fixture" \
    java -jar "$executable" "-Xembulk_home=$EMBULK_HOME" run "$config" \
      > "$raw_log" 2>&1; then
    exit_code=0
  else
    exit_code=$?
  fi
  grep "^PAGETRACE|$fixture|" "$raw_log" > "$evidence/$fixture.trace.raw" || true
  count=$(wc -l < "$evidence/$fixture.trace.raw" | tr -d ' ')
  digest=$(shasum -a 256 "$evidence/$fixture.trace.raw" | awk '{print $1}')
  printf 'PAGECASE|%s|%s|%s|%s\n' "$fixture" "$exit_code" "$count" "$digest" \
    >> "$evidence/page-cases.raw"
  cat "$evidence/$fixture.trace.raw" >> "$evidence/page-traces.raw"
done

validate_page_evidence "$evidence" "$mode"

for file in page-cases.raw page-traces.raw empty.raw.log typed-null.raw.log \
  empty.trace.raw typed-null.trace.raw; do
  shasum -a 256 "$evidence/$file" | awk -v name="$file" '{print name "=" $1}'
done > "$evidence/raw-evidence-hashes.txt"

cat "$evidence/page-cases.raw"
if [[ "$mode" == capture ]]; then
  printf 'T0012_PAGE_CAPTURE_ONLY=collected|evidence=%s\n' "$evidence"
else
  printf 'T0012_PAGE_VALIDATED_CASES=2|evidence=%s\n' "$evidence"
fi

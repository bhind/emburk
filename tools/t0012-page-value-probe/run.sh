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

[[ ${T0012_PAGE_MODE:-} == capture ]] || {
  printf '%s\n' 'T0012_PAGE_MODE must be capture during Stage A' >&2
  exit 2
}
case "$temporary_root" in
  /tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*) ;;
  *)
    printf '%s\n' 'T0012_PAGE_TEMP_ROOT must be an external temporary directory' >&2
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

mkdir -p -- "$temporary_root"
run_dir=$(mktemp -d "$temporary_root/run.XXXXXX")
evidence="$run_dir/evidence"
plugin="$run_dir/plugin"
export EMBULK_HOME="$run_dir/embulk-home"
repository="$EMBULK_HOME/lib/m2/repository/org/embulk/t0012/embulk-input-t0012_page_value/0.0.1"
mkdir -p -- "$evidence" "$plugin/classes" "$repository"
trap 'printf "T0012_PAGE_EVIDENCE_DIR=%s\n" "$evidence"' EXIT

executable="$run_dir/embulk.jar"
if ! curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error \
  --output "$executable" "$executable_url"; then
  printf 'unable to retrieve pinned executable: %s\n' "$executable_url" >&2
  exit 56
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
printf '%s\n' 'capture' > "$evidence/stage.txt"

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

PYTHONDONTWRITEBYTECODE=1 python3 - "$evidence" <<'PY'
import base64
import binascii
import hashlib
import pathlib
import sys
import uuid

root = pathlib.Path(sys.argv[1])
fixtures = ("empty", "typed-null")

def require(condition, label):
    if not condition:
        raise ValueError(label)

try:
    case_lines = root.joinpath("page-cases.raw").read_text(encoding="utf-8").splitlines()
    trace_lines = root.joinpath("page-traces.raw").read_text(encoding="utf-8").splitlines()
    require(len(case_lines) == 2, "case-count")
    cases = {}
    for expected, line in zip(fixtures, case_lines, strict=True):
        fields = line.split("|")
        require(len(fields) == 5 and fields[0] == "PAGECASE", "case-grammar")
        _, fixture, exit_code, count, digest = fields
        require(fixture == expected and fixture not in cases, "case-fixture")
        require(exit_code.isascii() and exit_code.isdigit(), "case-exit")
        require(count.isascii() and count.isdigit(), "case-count-field")
        require(len(digest) == 64 and all(c in "0123456789abcdef" for c in digest), "case-digest")
        cases[fixture] = (int(exit_code), int(count), digest)

    grouped = {fixture: [] for fixture in fixtures}
    sequences = {}
    for line in trace_lines:
        fields = line.split("|")
        require(len(fields) >= 5 and fields[0] == "PAGETRACE", "trace-grammar")
        _, fixture, capture, sequence, event, *values = fields
        require(fixture in grouped, "trace-fixture")
        parsed = uuid.UUID(capture)
        require(str(parsed) == capture and parsed.version == 4, "capture-id")
        require(sequence.isascii() and sequence.isdigit(), "sequence-grammar")
        key = (fixture, capture)
        next_sequence = sequences.get(key, 0) + 1
        require(int(sequence) == next_sequence, "sequence-contiguous")
        sequences[key] = next_sequence
        require(event and event.isascii(), "event-name")
        for value in values:
            if value == "-":
                continue
            decoded = base64.b64decode(value, validate=True)
            decoded.decode("utf-8")
            require(base64.b64encode(decoded).decode("ascii") == value, "canonical-base64")
        grouped[fixture].append(line)

    for fixture, (_, count, digest) in cases.items():
        rows = grouped[fixture]
        require(rows and len(rows) == count, "trace-count")
        material = ("\n".join(rows) + "\n").encode("utf-8")
        require(hashlib.sha256(material).hexdigest() == digest, "trace-digest")
        require(root.joinpath(f"{fixture}.trace.raw").read_bytes() == material, "trace-copy")
        names = [row.split("|")[4] for row in rows]
        require(names.count("transaction-entry") == 1, "transaction-entry")
        require(names.count("run-entry") <= 1, "run-entry-count")
        require(names.count("terminal") == 1, "terminal-count")
        require(names[-1] in {"terminal", "cleanup-return"}, "terminal-envelope")
except (OSError, UnicodeError, ValueError, IndexError, binascii.Error) as error:
    print(f"T0012_PAGE_CAPTURE_ERROR|{error}", file=sys.stderr)
    raise SystemExit(4)
PY

for file in page-cases.raw page-traces.raw empty.raw.log typed-null.raw.log \
  empty.trace.raw typed-null.trace.raw; do
  shasum -a 256 "$evidence/$file" | awk -v name="$file" '{print name "=" $1}'
done > "$evidence/raw-evidence-hashes.txt"

cat "$evidence/page-cases.raw"
printf 'T0012_PAGE_CAPTURE_ONLY=collected|evidence=%s\n' "$evidence"

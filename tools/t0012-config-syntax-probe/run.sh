#!/usr/bin/env bash
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/../.." && pwd)
source="$here/src/T0012ConfigSyntaxInputPlugin.java"
wrapper="$root/tests/t0012_config_syntax_probe_test.sh"
base=${T0012_SYNTAX_TEMP_ROOT:-/private/tmp/t0012-syntax}

if [[ $# != 1 || $1 != --capture ]]; then
  printf '%s\n' 'usage: --capture' >&2
  exit 2
fi

# Reject repository paths, spelling aliases, and symlinked ancestors before writing.
python3 - "$base" "$root" <<'PY'
from pathlib import Path
import sys

requested, repository = map(Path, sys.argv[1:])
allowed = (Path('/private/tmp'), Path('/private/var/folders'))
if not requested.is_absolute() or str(requested) != sys.argv[1] or '..' in requested.parts:
    raise SystemExit('noncanonical, symlinked or repository evidence path')
existing = requested
while not existing.exists() and existing != existing.parent:
    existing = existing.parent
if existing.is_symlink() or existing.resolve() != existing:
    raise SystemExit('noncanonical, symlinked or repository evidence path')
canonical = existing.joinpath(*requested.relative_to(existing).parts)
if str(canonical) != str(requested) or not any(requested != item and requested.is_relative_to(item) for item in allowed):
    raise SystemExit('noncanonical, symlinked or repository evidence path')
if requested.is_relative_to(repository.resolve()):
    raise SystemExit('noncanonical, symlinked or repository evidence path')
PY

mkdir -p "$base"
run=$(mktemp -d "$base/run.XXXXXX")
run=$(cd "$run" && pwd -P)
evidence="$run/evidence"
mkdir -p "$evidence" "$run/classes"

finish() {
  code=$?
  printf '%s\n' "$code" > "$evidence/capture.exit"
  printf 'T0012_S13_EVIDENCE_DIR=%s\n' "$evidence"
}
trap finish EXIT

paths=("$source" "$here/run.sh" "$wrapper")
git -C "$root" rev-parse HEAD > "$evidence/source-revision.txt"
shasum -a 256 "${paths[@]}" > "$evidence/source-before.sha256"
python3 - "$root" "$evidence/source-revision.txt" "$evidence/source-before.sha256" \
  'tools/t0012-config-syntax-probe/src/T0012ConfigSyntaxInputPlugin.java' \
  'tools/t0012-config-syntax-probe/run.sh' 'tests/t0012_config_syntax_probe_test.sh' <<'PY'
import hashlib
from pathlib import Path
import subprocess
import sys

root, revision_file, digest_file, *relative = sys.argv[1:]
revision = Path(revision_file).read_text().strip()
lines = Path(digest_file).read_text().splitlines()
if len(lines) != len(relative):
    raise SystemExit('source hash framing failed')
for line, path in zip(lines, relative):
    digest, _ = line.split('  ', 1)
    result = subprocess.run(['git', '-C', root, 'show', f'{revision}:{path}'], capture_output=True)
    if result.returncode or hashlib.sha256(result.stdout).hexdigest() != digest:
        raise SystemExit('source files must be committed before capture')
PY
cp "$evidence/source-before.sha256" "$evidence/source.sha256"

jar="$run/embulk.jar"
url=https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar
printf '%s\n' "$url" > "$evidence/executable-url.txt"
download_code=0
curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error -o "$jar" "$url" > "$evidence/download.stdout" 2> "$evidence/download.stderr" || download_code=$?
printf '%s\n' "$download_code" > "$evidence/download.exit"
[[ $download_code == 0 ]] || { printf 'unable to retrieve pinned executable: %s\n' "$url" >&2; exit 56; }
[[ $(shasum -a 256 "$jar" | awk '{print $1}') == e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47 ]] || { printf '%s\n' 'pinned executable checksum mismatch' >&2; exit 3; }
shasum -a 256 "$jar" | awk '{print $1}' > "$evidence/executable.sha256"
unzip -p "$jar" META-INF/LICENSE > "$evidence/LICENSE-executable" || [[ -s "$evidence/LICENSE-executable" ]]
unzip -p "$jar" META-INF/NOTICE > "$evidence/NOTICE-executable" || [[ -s "$evidence/NOTICE-executable" ]]
[[ $(shasum -a 256 "$evidence/LICENSE-executable" | awk '{print $1}') == cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30 ]] || exit 3
[[ $(shasum -a 256 "$evidence/NOTICE-executable" | awk '{print $1}') == 27f0e45afdf10e406ee8bf478bfce38279e9087338a7981942a4a2762bcd5be8 ]] || exit 3
unzip -p "$jar" META-INF/MANIFEST.MF > "$evidence/executable-manifest.txt" || [[ -s "$evidence/executable-manifest.txt" ]]
grep -Fq 'Main-Class: org.embulk.cli.Main' "$evidence/executable-manifest.txt"
java -version > "$evidence/java-version.txt" 2>&1
javac -version > "$evidence/javac-version.txt" 2>&1
python3 --version > "$evidence/python-version.txt" 2>&1
uname -a > "$evidence/os.txt"

javac -cp "$jar" -d "$run/classes" "$source"
manifest="$run/MANIFEST.MF"
printf '%s\n' 'Manifest-Version: 1.0' 'Embulk-Plugin-Main-Class: T0012ConfigSyntaxInputPlugin' 'Embulk-Plugin-Category: input' 'Embulk-Plugin-Type: t0012_syntax' 'Embulk-Plugin-Spi-Version: 0' > "$manifest"
plugin="$run/embulk-input-t0012_syntax-0.0.1.jar"
jar cfm "$plugin" "$manifest" -C "$run/classes" .
printf '%s' '<project><modelVersion>4.0.0</modelVersion><groupId>org.embulk.t0012</groupId><artifactId>embulk-input-t0012_syntax</artifactId><version>0.0.1</version></project>' > "${plugin%.jar}.pom"
shasum -a 256 "$plugin" > "$evidence/plugin.sha256"
printf '%s\n' 'org.embulk.t0012:embulk-input-t0012_syntax:0.0.1|local-only' > "$evidence/plugin-coordinate.txt"

python3 - "$evidence" <<'PY'
from pathlib import Path
import sys

d = Path(sys.argv[1])
prefix = b'in:\n  type:\n    source: maven\n    group: org.embulk.t0012\n    name: t0012_syntax\n    version: 0.0.1\n'
suffix = b'out:\n  type: "null"\n'
fixtures = {
    'control': prefix + b'  field: syntax-value\n' + suffix,
    'quoted': prefix + b'  field: "syntax-value"\n' + suffix,
    'duplicate-field': prefix + b'  field: first-value\n  field: second-value\n' + suffix,
    'malformed-flow': prefix + b'  field: [unterminated\n' + suffix,
    'scalar-alias': b'seed: &v syntax-value\n' + prefix + b'  field: *v\n' + suffix,
    'invalid-utf8': prefix + b'  field: bad-\xff-value\n' + suffix,
}
for name, data in fixtures.items():
    if not data.endswith(b'\n'):
        raise SystemExit('fixture LF missing')
    (d / f'{name}.yml').write_bytes(data)
PY

for name in control quoted duplicate-field malformed-flow scalar-alias invalid-utf8; do
  case_home="$run/home/$name"
  destination="$case_home/lib/m2/repository/org/embulk/t0012/embulk-input-t0012_syntax/0.0.1"
  mkdir -p "$destination"
  cp "$plugin" "${plugin%.jar}.pom" "$destination/"
  invocation=$(python3 -c 'import uuid; print(uuid.uuid4())')
  status=0
  EMBULK_HOME="$case_home" T0012_SYNTAX_CASE="$name" T0012_SYNTAX_INVOCATION="$invocation" \
    java -jar "$jar" "-Xembulk_home=$case_home" run "$evidence/$name.yml" > "$evidence/$name.stdout.log" 2> "$evidence/$name.stderr.log" || status=$?
  printf '%s\n' "$status" > "$evidence/$name.exit.txt"
  grep '^SYNTAXTRACE|' "$evidence/$name.stdout.log" > "$evidence/$name.events.raw" || :
  printf '%s\n' "$invocation" > "$evidence/$name.invocation.txt"
  shasum -a 256 "$evidence/$name.yml" "$evidence/$name.stdout.log" "$evidence/$name.stderr.log" "$evidence/$name.events.raw" > "$evidence/$name.sha256"
done
shasum -a 256 "${paths[@]}" > "$evidence/source-after.sha256"
cmp "$evidence/source-before.sha256" "$evidence/source-after.sha256"

# Stage A intentionally checks framing and the known-good control only; it records no selected outcome vectors.
python3 - "$evidence" <<'PY'
import base64
import hashlib
import json
import re
from pathlib import Path
import sys
import uuid

d = Path(sys.argv[1])
cases = ('control', 'quoted', 'duplicate-field', 'malformed-flow', 'scalar-alias', 'invalid-utf8')
arity = {'transaction-entry': 0, 'config-load-entry': 0, 'config-value': 1, 'config-exception': 2,
         'control-entry': 0, 'control-return': 0, 'callback-exception': 2, 'transaction-return': 0,
         'run-entry': 0, 'finish-entry': 0, 'finish-return': 0, 'run-return': 0, 'cleanup-entry': 0, 'cleanup-return': 0}
def fail(message): raise ValueError(message)
def raw(path):
    if not path.is_file() or path.is_symlink(): fail('file-kind')
    with path.open('rb') as stream:
        data = stream.read(1048577)
    if len(data) > 1048576: fail('file-cap')
    return data
seen = set()
outcomes = {}
for name in cases:
    fixture = raw(d / f'{name}.yml')
    if not fixture.endswith(b'\n'): fail('fixture-lf')
    invocation = raw(d / f'{name}.invocation.txt').decode('ascii').strip()
    if str(uuid.UUID(invocation)) != invocation: fail('invocation')
    if invocation in seen or raw(d / f'{name}.invocation.txt') != (invocation + '\n').encode(): fail('invocation-duplicate')
    seen.add(invocation)
    exit_text = raw(d / f'{name}.exit.txt').decode('ascii')
    if not re.fullmatch(r'-?[0-9]+\n', exit_text): fail('exit')
    stdout, events = raw(d / f'{name}.stdout.log'), raw(d / f'{name}.events.raw')
    if events != b''.join(line for line in stdout.splitlines(keepends=True) if line.startswith(b'SYNTAXTRACE|')): fail('event-stdout')
    counters = {}
    parsed = []
    if events and (not events.endswith(b'\n') or b'\r' in events): fail('event-transport')
    for line in events.decode('utf-8').splitlines():
        parts = line.split('|')
        if len(parts) < 6 or parts[0] != 'SYNTAXTRACE' or parts[1] != name or parts[2] != invocation: fail('event-identity')
        if str(uuid.UUID(parts[3])) != parts[3] or parts[4] != str(counters.get(parts[3], 0) + 1): fail('event-sequence')
        counters[parts[3]] = int(parts[4])
        if parts[5] not in arity or len(parts) != 6 + arity[parts[5]]: fail('event-vocabulary')
        payload = []
        for value in parts[6:]:
            if value != '-':
                decoded = base64.b64decode(value, validate=True)
                if base64.b64encode(decoded).decode() != value: fail('event-base64')
                payload.append(decoded.decode('utf-8'))
            else:
                payload.append(None)
        parsed.append([parts[5], payload])
    outcomes[name] = {'exit': int(exit_text), 'events': parsed}
    lines = raw(d / f'{name}.sha256').decode('ascii').splitlines()
    if len(lines) != 4: fail('case-hash-count')
    for line, suffix in zip(lines, ('yml', 'stdout.log', 'stderr.log', 'events.raw')):
        digest, path = line.split('  ', 1)
        if Path(path).name != f'{name}.{suffix}' or digest != hashlib.sha256(raw(d / f'{name}.{suffix}')).hexdigest(): fail('case-hash')
control = outcomes['control']
if control['exit'] != 0 or ['config-value', ['syntax-value']] not in control['events'] or ['run-return', []] not in control['events']:
    fail('control-result')
with (d / 'stage-a-outcomes.json').open('x') as stream:
    stream.write(json.dumps(outcomes, sort_keys=True) + '\n')
hashes = {p.name: hashlib.sha256(raw(p)).hexdigest() for p in sorted(d.iterdir()) if p.is_file()}
with (d / 'integrity.json').open('x') as stream:
    stream.write(json.dumps(hashes, sort_keys=True) + '\n')
PY

printf 'T0012_S13_STAGE_A_CAPTURED=6|evidence=%s\n' "$evidence"

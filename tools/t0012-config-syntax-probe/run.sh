#!/usr/bin/env bash
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/../.." && pwd)
source="$here/src/T0012ConfigSyntaxInputPlugin.java"
wrapper="$root/tests/t0012_config_syntax_probe_test.sh"
base=${T0012_SYNTAX_TEMP_ROOT:-/private/tmp/t0012-syntax}

mode=${1:---full}
case "$mode" in
  --capture|--full) [[ $# -le 1 ]] || exit 2 ;;
  --validate) [[ $# == 2 ]] || exit 2; base=$2 ;;
  *) printf '%s\n' 'usage: [--full|--capture|--validate EVIDENCE]' >&2; exit 2 ;;
esac

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

if [[ $mode != --validate ]]; then
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
printf '%s  %s\n' \
  '5f29ac5bef4ffa52dead57f7bf13b6f40dfd444384bbb7d775f40998d39859b3' "$source" \
  '0561850fd53275a31231c6913fad55ffe977ffbba8a4600633acddbfd6fc11fe' "$here/run.sh" \
  '3be9134aadf5f0b87fc9a1605fdf8bfd21d46e484a68c68c687db135f5ee8a88' "$wrapper" > "$evidence/source-historical.sha256"

jar="$run/embulk.jar"
url=https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar
case ${T0012_SYNTAX_NEGATIVE:-} in
  '') ;;
  unavailable-runtime) url=https://github.com/embulk/embulk/releases/download/v0.11.5/unavailable-s13.jar ;;
  corrupt-hash) ;;
  *) printf '%s\n' 'unknown artifact control' >&2; exit 2 ;;
esac
printf '%s\n' "$url" > "$evidence/executable-url.txt"
download_code=0
curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error -o "$jar" "$url" > "$evidence/download.stdout" 2> "$evidence/download.stderr" || download_code=$?
printf '%s\n' "$download_code" > "$evidence/download.exit"
[[ $download_code == 0 ]] || { printf 'unable to retrieve pinned executable: %s\n' "$url" >&2; exit 56; }
if [[ ${T0012_SYNTAX_NEGATIVE:-} == corrupt-hash ]]; then
  printf '%s' 'corrupt' >> "$jar"
  printf '%s\n' 'corrupt-copy-injected' > "$evidence/negative-control.txt"
fi
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

else
evidence=$base
fi

# Capture preserves Stage A's framing-only behavior; full/validate bind the reviewed vectors.
python3 - "$evidence" "$root" "$mode" <<'PY'
import base64
import hashlib
import json
import re
from pathlib import Path
import subprocess
import sys
import uuid

d, root, mode = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
cases = ('control', 'quoted', 'duplicate-field', 'malformed-flow', 'scalar-alias', 'invalid-utf8')
input_hashes = dict(zip(cases, ('b6529ab10a9be386b12e6e26c75344ee4903e85464df1863e4e638398e4bee14',
    'ad50b4ddf3864a4cebc2c88ca562e5fb3a94105f5d30bda41be9ab14c87ba2c5',
    '7a8659ae16b67e5a909c906477f511d6aa319c79d8c9ec0aad9fa661d398f257',
    '6f2b75feeb5f1df992e3f2472b7f1df53752fe4ee6bb3d9781cde2dfa3767cea',
    'f76fb799c7228956d07f25d340bb5325176c060073cc88f726a253e1dba9c4bf',
    '6856e72333e988149d1fe972c6c7790bf01893790bccaf86f7b496b0e9d1f056')))
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
def pairs(items):
    value = {}
    for key, item in items:
        if key in value: fail('json-duplicate')
        value[key] = item
    return value
def text(path): return raw(path).decode('utf-8')
def read_json(path):
    value = json.loads(text(path), object_pairs_hook=pairs)
    if text(path) != json.dumps(value, sort_keys=True) + '\n': fail('json-transport')
    return value
try:
    metadata = {'LICENSE-executable', 'NOTICE-executable', 'download.exit', 'download.stderr', 'download.stdout',
        'executable-manifest.txt', 'executable.sha256', 'executable-url.txt', 'java-version.txt', 'javac-version.txt',
        'os.txt', 'plugin-coordinate.txt', 'plugin.sha256', 'python-version.txt', 'source-after.sha256', 'source-before.sha256',
        'source-historical.sha256', 'source-revision.txt', 'source.sha256'}
    expected_files = metadata | {f'{name}.{suffix}' for name in cases for suffix in ('yml', 'exit.txt', 'events.raw', 'stdout.log', 'stderr.log', 'invocation.txt', 'sha256')}
    if mode == '--validate': expected_files |= {'capture.exit', 'integrity.json', 'stage-a-outcomes.json'}
    if set(p.name for p in d.iterdir()) != expected_files: fail('file-set')
    for filename in expected_files: raw(d / filename)
    if mode == '--validate':
        if text(d / 'capture.exit') != '0\n': fail('capture-exit')
        integrity = read_json(d / 'integrity.json')
        if set(integrity) != expected_files - {'integrity.json', 'capture.exit'} or any(integrity[k] != hashlib.sha256(raw(d / k)).hexdigest() for k in integrity): fail('integrity-hash')
    revision = text(d / 'source-revision.txt').strip()
    if not re.fullmatch('[0-9a-f]{40}', revision) or text(d / 'source-revision.txt') != revision + '\n': fail('source-revision')
    if text(d / 'source-before.sha256') != text(d / 'source-after.sha256') or text(d / 'source-before.sha256') != text(d / 'source.sha256'): fail('source-changed')
    relative = ('tools/t0012-config-syntax-probe/src/T0012ConfigSyntaxInputPlugin.java', 'tools/t0012-config-syntax-probe/run.sh', 'tests/t0012_config_syntax_probe_test.sh')
    source_lines = text(d / 'source.sha256').splitlines()
    if len(source_lines) != 3: fail('source-count')
    for line, path in zip(source_lines, relative):
        digest, recorded = line.split('  ', 1)
        result = subprocess.run(['git', '-C', str(root), 'show', f'{revision}:{path}'], capture_output=True)
        if not re.fullmatch('[0-9a-f]{64}', digest) or not recorded.endswith('/' + path) or result.returncode or hashlib.sha256(result.stdout).hexdigest() != digest: fail('source-identity')
    historical_hashes = ('5f29ac5bef4ffa52dead57f7bf13b6f40dfd444384bbb7d775f40998d39859b3', '0561850fd53275a31231c6913fad55ffe977ffbba8a4600633acddbfd6fc11fe', '3be9134aadf5f0b87fc9a1605fdf8bfd21d46e484a68c68c687db135f5ee8a88')
    historical = text(d / 'source-historical.sha256').splitlines()
    if len(historical) != 3 or any(
        len(line.split('  ', 1)) != 2 or line.split('  ', 1)[0] != digest or not line.split('  ', 1)[1].endswith('/' + path)
        for line, digest, path in zip(historical, historical_hashes, relative)
    ): fail('source-historical')
    if text(d / 'executable.sha256') != 'e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47\n' or text(d / 'executable-url.txt') != 'https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar\n': fail('artifact-identity')
    if hashlib.sha256(raw(d / 'LICENSE-executable')).hexdigest() != 'cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30' or hashlib.sha256(raw(d / 'NOTICE-executable')).hexdigest() != '27f0e45afdf10e406ee8bf478bfce38279e9087338a7981942a4a2762bcd5be8': fail('artifact-notice')
    expected_names = ['transaction-entry', 'config-load-entry', 'config-value', 'control-entry', 'run-entry', 'finish-entry', 'finish-return', 'run-return', 'control-return', 'transaction-return', 'cleanup-entry', 'cleanup-return']
    values = {'control': 'syntax-value', 'quoted': 'syntax-value', 'duplicate-field': 'second-value', 'scalar-alias': 'syntax-value', 'invalid-utf8': 'bad-\ufffd-value'}
    seen, contexts, outcomes = set(), set(), {}
    for name in cases:
        fixture = raw(d / f'{name}.yml')
        if not fixture.endswith(b'\n'): fail('fixture-lf')
        invocation = text(d / f'{name}.invocation.txt').strip()
        if str(uuid.UUID(invocation)) != invocation or invocation in seen or text(d / f'{name}.invocation.txt') != invocation + '\n': fail('invocation-duplicate')
        seen.add(invocation)
        exit_text = text(d / f'{name}.exit.txt')
        if not re.fullmatch(r'-?[0-9]+\n', exit_text): fail('exit')
        stdout, stderr, events = raw(d / f'{name}.stdout.log'), raw(d / f'{name}.stderr.log'), raw(d / f'{name}.events.raw')
        if events != b''.join(line for line in stdout.splitlines(keepends=True) if line.startswith(b'SYNTAXTRACE|')): fail('event-stdout')
        if events and (not events.endswith(b'\n') or b'\r' in events): fail('event-transport')
        parsed, counters = [], {}
        for line in events.decode('utf-8').splitlines():
            fields = line.split('|')
            if len(fields) < 6 or fields[0] != 'SYNTAXTRACE' or fields[1] != name or fields[2] != invocation: fail('event-identity')
            if str(uuid.UUID(fields[3])) != fields[3] or fields[4] != str(counters.get(fields[3], 0) + 1): fail('event-sequence')
            counters[fields[3]] = int(fields[4])
            if fields[5] not in arity or len(fields) != 6 + arity[fields[5]]: fail('event-vocabulary')
            payload = []
            for value in fields[6:]:
                if value == '-':
                    payload.append(None)
                else:
                    decoded = base64.b64decode(value, validate=True)
                    if base64.b64encode(decoded).decode() != value: fail('event-base64')
                    payload.append(decoded.decode('utf-8'))
            parsed.append([fields[5], payload])
        outcomes[name] = {'exit': int(exit_text), 'events': parsed}
        lines = text(d / f'{name}.sha256').splitlines()
        suffixes = ('yml','stdout.log','stderr.log','events.raw')
        if len(lines) != 4 or any(
            len(part.split('  ', 1)) != 2 or Path(part.split('  ', 1)[1]).name != f'{name}.{suffix}'
            or part.split('  ', 1)[0] != hashlib.sha256(raw(d / f'{name}.{suffix}')).hexdigest()
            for part, suffix in zip(lines, suffixes)
        ): fail('case-hash')
        if mode != '--capture':
            if hashlib.sha256(fixture).hexdigest() != input_hashes[name]: fail('input-vector')
            if name == 'malformed-flow':
                if exit_text != '1\n': fail('exit-vector')
                if parsed: fail('event-vector')
                if hashlib.sha256(stderr).hexdigest() != '480dfb5bc6be8e8e567869545710d73db2ce87b80882b372e735021606e3c950': fail('stderr-vector')
            else:
                if exit_text != '0\n': fail('exit-vector')
                if stderr: fail('stderr-vector')
                if len(counters) != 1 or set(counters) & contexts: fail('context-vector')
                if [event[0] for event in parsed] != expected_names or parsed[2] != ['config-value', [values[name]]]: fail('event-vector')
                contexts.update(counters)
    if mode == '--validate':
        if len(seen) != 6 or len(contexts) != 5 or read_json(d / 'stage-a-outcomes.json') != outcomes: fail('outcome-vector')
    control = outcomes['control']
    if control['exit'] != 0 or ['config-value', ['syntax-value']] not in control['events'] or ['run-return', []] not in control['events']:
        fail('control-result')
except (OSError, ValueError, UnicodeError, subprocess.SubprocessError) as failure:
    print(f'T0012_S13_VALIDATION_ERROR={failure}', file=sys.stderr)
    sys.exit(4)
if mode != '--validate':
    # Capture records raw values; only --full emits a reviewed success marker.
    with (d / 'stage-a-outcomes.json').open('x') as stream: stream.write(json.dumps(outcomes, sort_keys=True) + '\n')
    hashes = {p.name: hashlib.sha256(raw(p)).hexdigest() for p in sorted(d.iterdir()) if p.is_file()}
    with (d / 'integrity.json').open('x') as stream: stream.write(json.dumps(hashes, sort_keys=True) + '\n')
PY

case "$mode" in
  --capture) printf 'T0012_S13_STAGE_A_CAPTURED=6|evidence=%s\n' "$evidence" ;;
  --full) printf 'T0012_S13_FULL_VALIDATED=6|evidence=%s\n' "$evidence" ;;
  --validate) printf '%s\n' 'T0012_S13_VALIDATE_ONLY=6' ;;
esac

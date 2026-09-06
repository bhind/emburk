#!/usr/bin/env bash
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); root=$(cd -- "$here/../.." && pwd)
source="$here/src/T0012ConfigEnvelopeInputPlugin.java"
base=${T0012_ENVELOPE_TEMP_ROOT:-/private/tmp/t0012-envelope}
mode=${1:---full}
case "$mode" in
  --capture|--full) [[ $# -le 1 ]] || exit 2 ;;
  --validate) [[ $# == 2 ]] || exit 2; base=$2 ;;
  *) echo 'usage: [--full|--capture|--validate EVIDENCE]' >&2; exit 2 ;;
esac
# Validate the spelling and every ancestor before creating any directory.
python3 - "$base" "$root" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
ok = (p.is_absolute() and str(p) == sys.argv[1] and '..' not in p.parts
      and any(p != b and p.is_relative_to(b) for b in (Path('/private/tmp'), Path('/private/var/folders')))
      and not p.is_relative_to(Path(sys.argv[2]).resolve())
      and not any(a.is_symlink() for a in (p, *p.parents)))
if not ok:
    sys.exit('noncanonical, symlinked or repository evidence path')
PY
if [[ $mode != --validate ]]; then
mkdir -p "$base"
run=$(mktemp -d "$base/run.XXXXXX"); run=$(cd "$run" && pwd -P); evidence="$run/evidence"; mkdir -p "$evidence" "$run/classes" "$run/home/lib/m2/repository/org/embulk/t0012/embulk-input-t0012_envelope/0.0.1"
capture_finished() {
  capture_code=$?
  printf '%s\n' "$capture_code" > "$evidence/capture.exit"
  printf 'T0012_S12_EVIDENCE_DIR=%s\n' "$evidence"
}
trap capture_finished EXIT
git -C "$root" rev-parse HEAD > "$evidence/source-revision.txt"
shasum -a 256 "$source" "$here/run.sh" "$root/tests/t0012_config_envelope_probe_test.sh" > "$evidence/source-before.sha256"
for p in "$run" "$evidence"; do [[ ! -L "$p" ]] || exit 2; done
jar="$run/embulk.jar"; url=https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar
case ${T0012_ENVELOPE_NEGATIVE:-} in
  '') ;;
  unavailable-runtime) url=https://github.com/embulk/embulk/releases/download/v0.11.5/unavailable-s12.jar ;;
  corrupt-hash) ;;
  *) echo 'unknown artifact control' >&2; exit 2 ;;
esac
printf '%s\n' "$url" > "$evidence/executable-url.txt"
download_code=0
curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error -o "$jar" "$url" > "$evidence/download.stdout" 2> "$evidence/download.stderr" || download_code=$?
printf '%s\n' "$download_code" > "$evidence/download.exit"
[[ $download_code == 0 ]] || { echo "unable to retrieve pinned executable: $url" >&2; exit 56; }
if [[ ${T0012_ENVELOPE_NEGATIVE:-} == corrupt-hash ]]; then
  printf '%s' 'corrupt' >> "$jar"
  printf '%s\n' 'corrupt-copy-injected' > "$evidence/negative-control.txt"
fi
[[ $(shasum -a 256 "$jar" | awk '{print $1}') == e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47 ]] || { echo 'pinned executable checksum mismatch' >&2; exit 3; }
printf '%s\n' "$url" > "$evidence/executable-url.txt"; shasum -a 256 "$jar" | awk '{print $1}' > "$evidence/executable.sha256"; unzip -p "$jar" META-INF/LICENSE > "$evidence/LICENSE-executable" || [[ -s "$evidence/LICENSE-executable" ]]; unzip -p "$jar" META-INF/NOTICE > "$evidence/NOTICE-executable" || [[ -s "$evidence/NOTICE-executable" ]]; shasum -a 256 "$source" "$here/run.sh" "$root/tests/t0012_config_envelope_probe_test.sh" > "$evidence/source.sha256"; git -C "$root" rev-parse HEAD > "$evidence/source-revision.txt"; java -version > "$evidence/java-version.txt" 2>&1
[[ $(shasum -a 256 "$evidence/LICENSE-executable" | awk '{print $1}') == cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30 ]] || exit 3
[[ $(shasum -a 256 "$evidence/NOTICE-executable" | awk '{print $1}') == 27f0e45afdf10e406ee8bf478bfce38279e9087338a7981942a4a2762bcd5be8 ]] || exit 3
unzip -p "$jar" META-INF/MANIFEST.MF > "$evidence/executable-manifest.txt" || [[ -s "$evidence/executable-manifest.txt" ]]
grep -Fq 'Main-Class: org.embulk.cli.Main' "$evidence/executable-manifest.txt"
uname -a > "$evidence/os.txt"
python3 --version > "$evidence/python-version.txt" 2>&1
javac -version > "$evidence/javac-version.txt" 2>&1
javac -cp "$jar" -d "$run/classes" "$source"; manifest="$run/MANIFEST.MF"; printf '%s\n' 'Manifest-Version: 1.0' 'Embulk-Plugin-Main-Class: T0012ConfigEnvelopeInputPlugin' 'Embulk-Plugin-Category: input' 'Embulk-Plugin-Type: t0012_envelope' 'Embulk-Plugin-Spi-Version: 0' > "$manifest"; plugin="$run/home/lib/m2/repository/org/embulk/t0012/embulk-input-t0012_envelope/0.0.1/embulk-input-t0012_envelope-0.0.1.jar"; jar cfm "$plugin" "$manifest" -C "$run/classes" .; printf '%s' '<project><modelVersion>4.0.0</modelVersion><groupId>org.embulk.t0012</groupId><artifactId>embulk-input-t0012_envelope</artifactId><version>0.0.1</version></project>' > "${plugin%.jar}.pom"
shasum -a 256 "$plugin" > "$evidence/plugin.sha256"
printf '%s\n' 'org.embulk.t0012:embulk-input-t0012_envelope:0.0.1|local-only' > "$evidence/plugin-coordinate.txt"
for name in control in-absent in-null out-absent out-null unknown-root unknown-input; do
  y="$evidence/$name.yml"
  {
    if [[ "$name" == in-null ]]; then echo 'in: null';
    elif [[ "$name" != in-absent ]]; then
      echo in:; echo '  type:'; echo '    source: maven'; echo '    group: org.embulk.t0012'; echo '    name: t0012_envelope'; echo '    version: 0.0.1'; echo '  field: envelope-value'
      if [[ "$name" == unknown-input ]]; then echo '  extra:'; echo '    nested: envelope-extra'; fi
    fi
    if [[ "$name" == out-null ]]; then echo 'out: null';
    elif [[ "$name" != out-absent ]]; then echo out:; echo '  type: "null"'; fi
    if [[ "$name" == unknown-root ]]; then echo extra:; echo '  nested: envelope-extra'; fi
  } > "$y"
  case_home="$run/home/$name"; destination="$case_home/lib/m2/repository/org/embulk/t0012/embulk-input-t0012_envelope/0.0.1"; mkdir -p "$destination"; cp "$plugin" "${plugin%.jar}.pom" "$destination/"
  id=$(python3 -c 'import uuid; print(uuid.uuid4())'); status=0
  EMBULK_HOME="$case_home" T0012_ENVELOPE_CASE="$name" T0012_ENVELOPE_INVOCATION="$id" java -jar "$jar" "-Xembulk_home=$case_home" run "$y" > "$evidence/$name.stdout.log" 2> "$evidence/$name.stderr.log" || status=$?
  printf '%s\n' "$status" > "$evidence/$name.exit.txt"; grep '^ENVELOPETRACE|' "$evidence/$name.stdout.log" > "$evidence/$name.events.raw" || :; printf '%s\n' "$id" > "$evidence/$name.invocation.txt"; shasum -a 256 "$y" "$evidence/$name.stdout.log" "$evidence/$name.stderr.log" "$evidence/$name.events.raw" > "$evidence/$name.sha256"
done
else
  evidence=$base
fi
python3 - "$evidence" "$root" "$mode" <<'PY'
import base64
import hashlib
import json
import re
from pathlib import Path
import subprocess
import sys
import uuid

d, root = map(Path, sys.argv[1:3])
mode = sys.argv[3]
cases = ('control', 'in-absent', 'in-null', 'out-absent', 'out-null', 'unknown-root', 'unknown-input')
arity = dict.fromkeys(('transaction-entry', 'config-load-entry', 'control-entry', 'control-return',
                      'run-entry', 'finish-entry', 'finish-return', 'run-return', 'transaction-return',
                      'cleanup-entry', 'cleanup-return'), 0)
arity.update({'config-value': 1, 'config-exception': 2, 'callback-exception': 2})
input_hashes = dict(zip(cases, (
    '7c9ada0e4980778337fd8f6bd2cbbecbd5c272639c7ed4769578e379457e352a',
    '8a78b8bbe035efdad6a3720ae8e876230eafa40c7e81b58e79e0535665da2537',
    '3aa644cca147381a85b544ad83268f961fe4f1f1b05b0cb083bc0d252138242e',
    '0a38b49f8dbb4ed56c3646051b9b603b3eaef245c90cd345a071144674fc3b45',
    '0f15af301b5f5d35a4eb11b473e3fb0a9b3635af3e9c0b9161ac07ff9bed50e1',
    '6b57e54900c5284402ee433ad44f47ee875a10c1c17f12f49f7a1b4ecdda8ffb',
    'bf5850e7e14376e6448af61b0f471cf2ba00e2c6b47d4e8554c27ae21b46defa',
)))
failure_hashes = {
    'in-absent': '50bb1f14e8c2c4f2febd4654047759d0ea536dddd7657393ee639634c29f777e',
    'out-absent': '2c65acdc27b8590701eb8c8c94f4e266b1b4f80115f88fa922b1d652d4861e85',
    'in-null': '2534ee6510f7d3b8c233d783c2b36b60ad09e235d58b0e04b1242094df4c7289',
    'out-null': '2534ee6510f7d3b8c233d783c2b36b60ad09e235d58b0e04b1242094df4c7289',
}
expected_events = [[name, ['envelope-value'] if name == 'config-value' else []] for name in (
    'transaction-entry', 'config-load-entry', 'config-value', 'control-entry',
    'run-entry', 'finish-entry', 'finish-return', 'run-return', 'control-return',
    'transaction-return', 'cleanup-entry', 'cleanup-return')]
source_paths = ('tools/t0012-config-envelope-probe/src/T0012ConfigEnvelopeInputPlugin.java',
                'tools/t0012-config-envelope-probe/run.sh', 'tests/t0012_config_envelope_probe_test.sh')

def require(value, diagnostic):
    if not value:
        raise ValueError(diagnostic)

def raw(path):
    require(path.is_file() and not path.is_symlink(), 'file-kind')
    with path.open('rb') as stream:
        data = stream.read(1048577)
    require(len(data) <= 1048576, 'file-cap')
    return data

def text(path):
    return raw(path).decode('utf-8')

def identifier(value):
    require(str(uuid.UUID(value)) == value, 'uuid')

def digest(path):
    return hashlib.sha256(raw(path)).hexdigest()

def pairs(entries):
    result = {}
    for key, value in entries:
        require(key not in result, 'json-duplicate')
        result[key] = value
    return result

def read_json(path):
    value = json.loads(text(path), object_pairs_hook=pairs)
    require(text(path) == json.dumps(value, sort_keys=True) + '\n', 'json-transport')
    return value

try:
    metadata = set(('LICENSE-executable NOTICE-executable javac-version.txt executable-manifest.txt '
                    'download.exit source-revision.txt java-version.txt source.sha256 os.txt '
                    'download.stderr plugin.sha256 plugin-coordinate.txt python-version.txt '
                    'source-before.sha256 download.stdout executable.sha256 executable-url.txt').split())
    expected_files = metadata | {f'{name}.{suffix}' for name in cases for suffix in (
        'yml', 'exit.txt', 'events.raw', 'stdout.log', 'stderr.log', 'invocation.txt', 'sha256')}
    if mode == '--validate':
        expected_files |= {'stage-a-outcomes.json', 'integrity.json', 'capture.exit'}
    require({p.name for p in d.iterdir()} == expected_files, 'file-set')
    for filename in expected_files:
        raw(d / filename)
    if mode == '--validate':
        require(text(d / 'capture.exit') == '0\n', 'capture-exit')
        integrity = read_json(d / 'integrity.json')
        require(isinstance(integrity, dict) and set(integrity) == expected_files - {'integrity.json', 'capture.exit'}, 'integrity-set')
        require(all(integrity[name] == digest(d / name) for name in integrity), 'integrity-hash')
    revision = text(d / 'source-revision.txt').strip()
    require(re.fullmatch('[0-9a-f]{40}', revision) and text(d / 'source-revision.txt') == revision + '\n', 'source-revision')
    require(text(d / 'source-before.sha256') == text(d / 'source.sha256'), 'source-changed')
    source_lines = text(d / 'source.sha256').splitlines()
    require(len(source_lines) == 3, 'source-count')
    for line, relative in zip(source_lines, source_paths):
        source_digest, path = line.split('  ', 1)
        require(re.fullmatch('[0-9a-f]{64}', source_digest) and Path(path).is_absolute()
                and path.endswith('/' + relative), 'source-path')
        result = subprocess.run(['git', '-C', str(root), 'show', f'{revision}:{relative}'], capture_output=True)
        require(result.returncode == 0 and hashlib.sha256(result.stdout).hexdigest() == source_digest, 'source-identity')
        if relative.endswith('.java'):
            require(source_digest == 'fda93051323c91e42d504f3e915b1c3421c32ecb5dacdfcc6116a91d5c9593c6', 'fixture-source')
    require(text(d / 'executable-url.txt') == 'https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar\n'
            and text(d / 'executable.sha256') == 'e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47\n', 'artifact-identity')
    require(hashlib.sha256(raw(d / 'LICENSE-executable')).hexdigest() == 'cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30'
            and hashlib.sha256(raw(d / 'NOTICE-executable')).hexdigest() == '27f0e45afdf10e406ee8bf478bfce38279e9087338a7981942a4a2762bcd5be8', 'artifact-notice')
    require('Main-Class: org.embulk.cli.Main' in text(d / 'executable-manifest.txt')
            and text(d / 'download.exit') == '0\n', 'artifact-setup')
    require(text(d / 'plugin-coordinate.txt') == 'org.embulk.t0012:embulk-input-t0012_envelope:0.0.1|local-only\n'
            and re.fullmatch(r'[0-9a-f]{64}  /[^\n]+\.jar\n', text(d / 'plugin.sha256')), 'plugin-identity')
    seen = set()
    contexts_seen = set()
    outcomes = {}
    for name in cases:
        invocation = text(d / f'{name}.invocation.txt').removesuffix('\n')
        identifier(invocation)
        require(invocation not in seen, 'invocation-duplicate')
        seen.add(invocation)
        code = text(d / f'{name}.exit.txt')
        require(code.endswith('\n') and code == str(int(code)) + '\n', 'exit-transport')
        stdout = raw(d / f'{name}.stdout.log')
        stderr = raw(d / f'{name}.stderr.log')
        event_bytes = raw(d / f'{name}.events.raw')
        require(event_bytes == b''.join(line for line in stdout.splitlines(keepends=True)
                                       if line.startswith(b'ENVELOPETRACE|')), 'event-stdout')
        event_text = event_bytes.decode('utf-8')
        require(not event_text or (event_text.endswith('\n') and '\r' not in event_text), 'event-transport')
        counters = {}
        parsed = []
        for line in event_text.splitlines():
            fields = line.split('|')
            require(len(fields) >= 6, 'event-arity')
            tag, case, invocation_id, context, sequence, event = fields[:6]
            require(tag == 'ENVELOPETRACE' and case == name and invocation_id == invocation, 'event-identity')
            identifier(context)
            require(sequence == str(counters.get(context, 0) + 1), 'event-sequence')
            counters[context] = int(sequence)
            require(event in arity and len(fields) == 6 + arity[event], 'event-vocabulary')
            payload = []
            for field in fields[6:]:
                if field == '-':
                    payload.append(None)
                else:
                    value = base64.b64decode(field, validate=True)
                    require(base64.b64encode(value).decode() == field, 'event-base64')
                    payload.append(value.decode('utf-8'))
            parsed.append([event, payload])
        outcomes[name] = {'exit': int(code), 'events': parsed}
        if mode != '--capture':
            require(hashlib.sha256(raw(d / f'{name}.yml')).hexdigest() == input_hashes[name], 'input-vector')
            success = name not in failure_hashes
            require(code == ('0\n' if success else '1\n'), 'exit-vector')
            require(parsed == (expected_events if success else []), 'event-vector')
            require(len(counters) == (1 if success else 0)
                    and not set(counters) & contexts_seen, 'context-vector')
            contexts_seen.update(counters)
            expected_stderr = failure_hashes.get(name, hashlib.sha256(b'').hexdigest())
            require(hashlib.sha256(stderr).hexdigest() == expected_stderr, 'stderr-vector')
        case_lines = text(d / f'{name}.sha256').splitlines()
        require(len(case_lines) == 4, 'case-hash-count')
        for line, suffix in zip(case_lines, ('yml', 'stdout.log', 'stderr.log', 'events.raw')):
            expected_hash, path = line.split('  ', 1)
            require(Path(path).name == f'{name}.{suffix}'
                    and expected_hash == hashlib.sha256(raw(d / f'{name}.{suffix}')).hexdigest(), 'case-hash')
        if name == 'control':
            require(code == '0\n' and ['config-value', ['envelope-value']] in parsed
                    and ['run-return', []] in parsed, 'control-result')
    if mode == '--validate':
        require(read_json(d / 'stage-a-outcomes.json') == outcomes, 'outcome-vector')
    else:
        with (d / 'stage-a-outcomes.json').open('x') as stream:
            json.dump(outcomes, stream, sort_keys=True)
            stream.write('\n')
        hashes = {p.name: hashlib.sha256(raw(p)).hexdigest() for p in sorted(d.iterdir()) if p.is_file()}
        with (d / 'integrity.json').open('x') as stream:
            json.dump(hashes, stream, sort_keys=True)
            stream.write('\n')
except (OSError, ValueError, subprocess.SubprocessError) as failure:
    print(f'T0012_S12_VALIDATION_ERROR={failure}', file=sys.stderr)
    sys.exit(4)
PY
case "$mode" in
  --capture) printf 'T0012_S12_STAGE_A_CAPTURED=7|evidence=%s\n' "$evidence" ;;
  --full) printf 'T0012_S12_FULL_VALIDATED=7|evidence=%s\n' "$evidence" ;;
  --validate) printf '%s\n' 'T0012_S12_VALIDATE_ONLY=7' ;;
esac

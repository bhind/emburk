#!/usr/bin/env bash
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); root=$(cd -- "$here/../.." && pwd)
source="$here/src/T0012ConfigEnvelopeInputPlugin.java"
base=${T0012_ENVELOPE_TEMP_ROOT:-/private/tmp/t0012-envelope}
[[ $# == 1 && $1 == --capture ]] || { echo 'Stage A requires --capture; Stage B is unavailable' >&2; exit 2; }
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
printf '%s\n' "$url" > "$evidence/executable-url.txt"
download_code=0
curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error -o "$jar" "$url" > "$evidence/download.stdout" 2> "$evidence/download.stderr" || download_code=$?
printf '%s\n' "$download_code" > "$evidence/download.exit"
[[ $download_code == 0 ]] || { echo "unable to retrieve pinned executable: $url" >&2; exit 56; }
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
python3 - "$evidence" "$root" <<'PY'
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import uuid

d, root = map(Path, sys.argv[1:])
cases = ('control', 'in-absent', 'in-null', 'out-absent', 'out-null', 'unknown-root', 'unknown-input')
arity = dict.fromkeys(('transaction-entry', 'config-load-entry', 'control-entry', 'control-return',
                      'run-entry', 'finish-entry', 'finish-return', 'run-return', 'transaction-return',
                      'cleanup-entry', 'cleanup-return'), 0)
arity.update({'config-value': 1, 'config-exception': 2, 'callback-exception': 2})

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

try:
    revision = text(d / 'source-revision.txt').strip()
    require(text(d / 'source-before.sha256') == text(d / 'source.sha256'), 'source-changed')
    for line in text(d / 'source.sha256').splitlines():
        digest, path = line.split('  ', 1)
        relative = str(Path(path).relative_to(root))
        committed = subprocess.check_output(['git', '-C', str(root), 'show', f'{revision}:{relative}'])
        require(hashlib.sha256(committed).hexdigest() == digest == hashlib.sha256(raw(Path(path))).hexdigest(), 'source-uncommitted')
    seen = set()
    outcomes = {}
    for name in cases:
        invocation = text(d / f'{name}.invocation.txt').removesuffix('\n')
        identifier(invocation)
        require(invocation not in seen, 'invocation-duplicate')
        seen.add(invocation)
        code = text(d / f'{name}.exit.txt')
        require(code.endswith('\n') and code == str(int(code)) + '\n', 'exit-transport')
        stdout = raw(d / f'{name}.stdout.log')
        raw(d / f'{name}.stderr.log')
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
        if name == 'control':
            require(code == '0\n' and ['config-value', ['envelope-value']] in parsed
                    and ['run-return', []] in parsed, 'control-result')
    with (d / 'stage-a-outcomes.json').open('x') as stream:
        json.dump(outcomes, stream, sort_keys=True)
        stream.write('\n')
    hashes = {p.name: hashlib.sha256(raw(p)).hexdigest() for p in sorted(d.iterdir()) if p.is_file()}
    with (d / 'integrity.json').open('x') as stream:
        json.dump(hashes, stream, sort_keys=True)
        stream.write('\n')
except (OSError, ValueError, subprocess.SubprocessError) as failure:
    sys.exit(f'T0012_S12_CAPTURE_ERROR={failure}')
PY
printf 'T0012_S12_STAGE_A_CAPTURED=7|evidence=%s\n' "$evidence"

#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd); runner="$root/tools/t0012-config-envelope-probe/run.sh"
if [[ $# == 1 && $1 == --capture ]]; then
  bash -n "$runner"
  "$runner" --capture
  exit $?
elif [[ $# != 0 ]]; then
  printf '%s\n' 'usage: [--capture]' >&2
  exit 2
fi
bash -n "$runner"
python3 - "$runner" <<'PY'
"""Original repaired-copy controls, separate from the runner's reference vectors."""
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import uuid

runner = sys.argv[1]
outer = Path(tempfile.mkdtemp(prefix='t0012-s12-controls.', dir='/private/tmp'))
print(f'T0012_S12_TEST_EVIDENCE_DIR={outer}', flush=True)

def check(condition, diagnostic):
    if not condition:
        raise ValueError(diagnostic)

def invoke(label, arguments, env=None):
    with (outer / f'{label}.stdout').open('xb') as out:
        with (outer / f'{label}.stderr').open('xb') as err:
            result = subprocess.run(['bash', runner, *arguments], stdout=out,
                                    stderr=err, env=env, check=False)
    (outer / f'{label}.exit').write_text(str(result.returncode) + '\n')
    return result.returncode, (outer / f'{label}.stdout').read_text(), (outer / f'{label}.stderr').read_text()

def evidence_from(stdout):
    paths = [line.split('=', 1)[1] for line in stdout.splitlines()
             if line.startswith('T0012_S12_EVIDENCE_DIR=')]
    check(len(paths) == 1, 'one evidence marker required')
    path = Path(paths[0])
    check(path.is_absolute() and path.is_relative_to('/private/tmp')
          and not any(p.is_symlink() for p in (path, *path.parents)), 'evidence path')
    return path

def repair(directory):
    # These are fresh test copies. Repair dependent hashes to reach semantic gates.
    for path in directory.glob('*.sha256'):
        if path.name in {'source.sha256', 'source-before.sha256', 'plugin.sha256', 'executable.sha256'}:
            continue
        lines = []
        for line in path.read_text().splitlines():
            _, original = line.split('  ', 1)
            target = directory / Path(original).name
            if target.exists():
                lines.append(hashlib.sha256(target.read_bytes()).hexdigest() + '  ' + original)
            else:
                lines.append(line)
        path.write_text('\n'.join(lines) + '\n')
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted(directory.iterdir())
              if p.is_file() and p.name not in {'integrity.json', 'capture.exit'}}
    (directory / 'integrity.json').write_text(json.dumps(hashes, sort_keys=True) + '\n')

def change_events(directory, transform):
    path = directory / 'control.events.raw'
    before = path.read_text().splitlines(keepends=True)
    after = transform(list(before))
    path.write_text(''.join(after))
    stdout = directory / 'control.stdout.log'
    replacements = iter(after)
    lines = [next(replacements, '') if line.startswith('ENVELOPETRACE|') else line
             for line in stdout.read_text().splitlines(keepends=True)]
    lines.extend(replacements)
    stdout.write_text(''.join(lines))

def mutate(directory, label):
    if label == 'input':
        path = directory / 'control.yml'
        path.write_text(path.read_text() + '# changed\n')
    elif label == 'missing-file':
        (directory / 'in-null.events.raw').rename(outer / 'removed-case-events.backup')
    elif label == 'extra-file':
        (directory / 'extra.txt').write_text('extra\n')
    elif label == 'event-remove':
        def remove(lines):
            lines.pop()
            return lines
        change_events(directory, remove)
    elif label == 'event-order':
        def reorder(lines):
            first, second = lines[0].split('|'), lines[1].split('|')
            first[5], second[5] = second[5], first[5]
            lines[0], lines[1] = '|'.join(first), '|'.join(second)
            return lines
        change_events(directory, reorder)
    elif label == 'event-value':
        def value(lines):
            lines[2] = lines[2].replace('ZW52ZWxvcGUtdmFsdWU=', base64.b64encode(b'changed').decode())
            return lines
        change_events(directory, value)
    elif label == 'context':
        def context(lines):
            fields = lines[-1].split('|')
            fields[3], fields[4] = str(uuid.uuid4()), '1'
            lines[-1] = '|'.join(fields)
            return lines
        change_events(directory, context)
    elif label == 'invocation':
        (directory / 'control.invocation.txt').write_text(str(uuid.uuid4()) + '\n')
    elif label == 'exit':
        (directory / 'control.exit.txt').write_text('1\n')
    elif label == 'stderr':
        (directory / 'control.stderr.log').write_text('changed\n')
    elif label == 'source':
        path = directory / 'source.sha256'
        source = path.read_text()
        source = '0' * 64 + source[64:]
        path.write_text(source)
        (directory / 'source-before.sha256').write_text(source)
    elif label == 'integrity':
        path = directory / 'integrity.json'
        data = json.loads(path.read_text())
        data['control.yml'] = '0' * 64
        path.write_text(json.dumps(data, sort_keys=True) + '\n')
    elif label == 'outcomes':
        path = directory / 'stage-a-outcomes.json'
        data = json.loads(path.read_text())
        data['control']['exit'] = 1
        path.write_text(json.dumps(data, sort_keys=True) + '\n')
    elif label == 'capture-exit':
        (directory / 'capture.exit').write_text('1\n')
    elif label == 'artifact':
        (directory / 'executable.sha256').write_text('0' * 64 + '\n')
    elif label == 'file-cap':
        (directory / 'control.stdout.log').write_bytes(b'x' * 1048577)

try:
    env = dict(os.environ)
    env.pop('T0012_ENVELOPE_NEGATIVE', None)
    env['T0012_ENVELOPE_TEMP_ROOT'] = '/private/tmp/t0012-envelope'
    code, stdout, stderr = invoke('full', ['--full'], env)
    check(code == 0, f'fresh full capture failed: {code}')
    evidence = evidence_from(stdout)
    check(stdout.splitlines() == [f'T0012_S12_FULL_VALIDATED=7|evidence={evidence}',
                                 f'T0012_S12_EVIDENCE_DIR={evidence}'], 'full marker')
    code, stdout, stderr = invoke('positive', ['--validate', str(evidence)])
    check(code == 0 and stdout == 'T0012_S12_VALIDATE_ONLY=7\n' and stderr == '', 'positive validate-only')
    controls = {
        'input': 'input-vector', 'missing-file': 'file-set', 'extra-file': 'file-set',
        'event-remove': 'event-vector', 'event-order': 'event-vector', 'event-value': 'event-vector',
        'context': 'context-vector', 'invocation': 'event-identity', 'exit': 'exit-vector',
        'stderr': 'stderr-vector', 'source': 'source-identity', 'integrity': 'integrity-hash',
        'outcomes': 'outcome-vector', 'capture-exit': 'capture-exit', 'artifact': 'artifact-identity',
        'file-cap': 'file-cap',
    }
    for label, diagnostic in controls.items():
        copy = outer / f'copy-{label}'
        shutil.copytree(evidence, copy)
        mutate(copy, label)
        if label != 'integrity':
            repair(copy)
        code, stdout, stderr = invoke(label, ['--validate', str(copy)])
        check(code == 4 and stdout == '' and stderr == f'T0012_S12_VALIDATION_ERROR={diagnostic}\n',
              f'{label}: wrong rejection ({code}, {stderr!r})')
        print(f'T0012_S12_CONTROL={label}|diagnostic={diagnostic}', flush=True)
    alias = outer / 'evidence-alias'
    alias.symlink_to(evidence, target_is_directory=True)
    code, stdout, stderr = invoke('symlink', ['--validate', str(alias)])
    check(code == 1 and stdout == '' and stderr == 'noncanonical, symlinked or repository evidence path\n', 'symlink rejection')
    for label, expected in (('corrupt-hash', 3), ('unavailable-runtime', 56)):
        code, stdout, stderr = invoke(label, ['--full'], dict(env, T0012_ENVELOPE_NEGATIVE=label))
        negative = evidence_from(stdout)
        check(code == expected and (negative / 'capture.exit').read_text() == str(expected) + '\n', 'artifact exit')
        check(not (negative / 'control.yml').exists() and not (negative / 'java-version.txt').exists(), 'artifact early stop')
        if label == 'corrupt-hash':
            check(stderr == 'pinned executable checksum mismatch\n'
                  and (negative / 'negative-control.txt').read_text() == 'corrupt-copy-injected\n'
                  and (negative / 'download.exit').read_text() == '0\n', 'corruption boundary')
        else:
            check(stderr.startswith('unable to retrieve pinned executable: https://github.com/embulk/embulk/releases/download/v0.11.5/unavailable-s12.jar')
                  and (negative / 'download.exit').read_text() != '0\n', 'retrieval boundary')
    (outer / 'exit.txt').write_text('0\n')
    print(f'T0012/S12: seven reference envelopes validated; 16 repaired controls, one path control, two artifact controls passed|evidence={outer}')
except (OSError, ValueError) as failure:
    (outer / 'exit.txt').write_text('1\n')
    print(f'T0012_S12_TEST_ERROR={failure}', file=sys.stderr)
    sys.exit(1)
PY

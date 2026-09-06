#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0012-config-syntax-probe/run.sh"

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
import base64, hashlib, json, os
from pathlib import Path
import shutil, subprocess, sys, tempfile, uuid

runner = sys.argv[1]
outer = Path(tempfile.mkdtemp(prefix='t0012-s13-controls.', dir='/private/tmp'))
print(f'T0012_S13_TEST_EVIDENCE_DIR={outer}', flush=True)
def check(value, message):
    if not value: raise ValueError(message)
def invoke(label, args, env=None):
    with (outer / f'{label}.stdout').open('xb') as out, (outer / f'{label}.stderr').open('xb') as err:
        result = subprocess.run(['bash', runner, *args], stdout=out, stderr=err, env=env, check=False)
    (outer / f'{label}.exit').write_text(str(result.returncode) + '\n')
    return result.returncode, (outer / f'{label}.stdout').read_text(), (outer / f'{label}.stderr').read_text()
def evidence_from(stdout):
    paths = [line.split('=', 1)[1] for line in stdout.splitlines() if line.startswith('T0012_S13_EVIDENCE_DIR=')]
    check(len(paths) == 1, 'evidence marker')
    return Path(paths[0])
def repair(directory):
    for path in directory.glob('*.sha256'):
        if path.name in {'source.sha256','source-before.sha256','source-after.sha256','source-historical.sha256','plugin.sha256','executable.sha256'}: continue
        lines=[]
        for line in path.read_text().splitlines():
            _, recorded = line.split('  ',1); target=directory / Path(recorded).name
            if not target.exists():
                lines.append(line)
                continue
            lines.append(hashlib.sha256(target.read_bytes()).hexdigest() + '  ' + recorded)
        path.write_text('\n'.join(lines)+'\n')
    hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(directory.iterdir()) if p.is_file() and p.name not in {'integrity.json','capture.exit'}}
    (directory/'integrity.json').write_text(json.dumps(hashes,sort_keys=True)+'\n')
def change_events(directory, transform):
    path=directory/'control.events.raw'; after=transform(path.read_text().splitlines(keepends=True)); path.write_text(''.join(after))
    replacement=iter(after); stdout=directory/'control.stdout.log'
    stdout.write_text(''.join(next(replacement,'') if line.startswith('SYNTAXTRACE|') else line for line in stdout.read_text().splitlines(keepends=True)))
def mutate(directory, label):
    if label == 'input': (directory/'control.yml').write_bytes((directory/'control.yml').read_bytes()+b'# changed\n')
    elif label == 'missing-file': (directory/'quoted.events.raw').rename(outer/'removed-events.backup')
    elif label == 'extra-file': (directory/'extra.txt').write_text('extra\n')
    elif label == 'event-remove': change_events(directory, lambda x:x[:-1])
    elif label == 'event-order':
        def f(x):
            first, second = x[0].split('|'), x[1].split('|')
            first[5], second[5] = second[5], first[5]
            x[0], x[1] = '|'.join(first), '|'.join(second)
            return x
        change_events(directory,f)
    elif label == 'event-value':
        def f(x): x[2]=x[2].replace('c3ludGF4LXZhbHVl',base64.b64encode(b'changed').decode()); return x
        change_events(directory,f)
    elif label == 'context':
        def f(x):
            a=x[-1].split('|'); a[3],a[4]=str(uuid.uuid4()),'1'; x[-1]='|'.join(a); return x
        change_events(directory,f)
    elif label == 'invocation': (directory/'control.invocation.txt').write_text(str(uuid.uuid4())+'\n')
    elif label == 'exit': (directory/'control.exit.txt').write_text('1\n')
    elif label == 'stderr': (directory/'control.stderr.log').write_text('changed\n')
    elif label == 'source':
        for name in ('source.sha256','source-before.sha256','source-after.sha256'):
            text=(directory/name).read_text(); (directory/name).write_text('0'*64+text[64:])
    elif label == 'integrity':
        data=json.loads((directory/'integrity.json').read_text()); data['control.yml']='0'*64; (directory/'integrity.json').write_text(json.dumps(data,sort_keys=True)+'\n')
    elif label == 'outcomes':
        data=json.loads((directory/'stage-a-outcomes.json').read_text()); data['control']['exit']=1; (directory/'stage-a-outcomes.json').write_text(json.dumps(data,sort_keys=True)+'\n')
    elif label == 'capture-exit': (directory/'capture.exit').write_text('1\n')
    elif label == 'artifact': (directory/'executable.sha256').write_text('0'*64+'\n')
    elif label == 'file-cap': (directory/'control.stdout.log').write_bytes(b'x'*1048577)
    elif label == 'duplicate-value':
        p=directory/'duplicate-field.events.raw'; p.write_text(p.read_text().replace('c2Vjb25kLXZhbHVl','Zmlyc3QtdmFsdWU=')); (directory/'duplicate-field.stdout.log').write_text((directory/'duplicate-field.stdout.log').read_text().replace('c2Vjb25kLXZhbHVl','Zmlyc3QtdmFsdWU='))
    elif label == 'invalid-utf8': (directory/'invalid-utf8.yml').write_bytes((directory/'invalid-utf8.yml').read_bytes().replace(b'\xff',b'\xef\xbf\xbd'))
    elif label == 'alias': (directory/'scalar-alias.yml').write_bytes((directory/'scalar-alias.yml').read_bytes().replace(b'seed: &v syntax-value\n',b'').replace(b'*v',b'syntax-value'))
try:
    env=dict(os.environ); env.pop('T0012_SYNTAX_NEGATIVE',None); env['T0012_SYNTAX_TEMP_ROOT']='/private/tmp/t0012-syntax'
    code,stdout,stderr=invoke('full',['--full'],env); check(code==0,f'fresh full capture failed: {code}')
    evidence=evidence_from(stdout); check(stdout.splitlines()==[f'T0012_S13_FULL_VALIDATED=6|evidence={evidence}',f'T0012_S13_EVIDENCE_DIR={evidence}'],'full marker')
    code,stdout,stderr=invoke('positive',['--validate',str(evidence)]); check(code==0 and stdout=='T0012_S13_VALIDATE_ONLY=6\n' and stderr=='','positive validate')
    controls={'input':'input-vector','missing-file':'file-set','extra-file':'file-set','event-remove':'event-vector','event-order':'event-vector','event-value':'event-vector','context':'context-vector','invocation':'event-identity','exit':'exit-vector','stderr':'stderr-vector','source':'source-identity','integrity':'integrity-hash','outcomes':'outcome-vector','capture-exit':'capture-exit','artifact':'artifact-identity','file-cap':'file-cap','duplicate-value':'event-vector','invalid-utf8':'input-vector','alias':'input-vector'}
    for label, diagnostic in controls.items():
        copy=outer/f'copy-{label}'; shutil.copytree(evidence,copy); mutate(copy,label)
        if label!='integrity': repair(copy)
        code,stdout,stderr=invoke(label,['--validate',str(copy)])
        check(code==4 and stdout=='' and stderr==f'T0012_S13_VALIDATION_ERROR={diagnostic}\n',f'{label}: {code}/{stderr!r}')
    alias=outer/'evidence-alias'; alias.symlink_to(evidence,target_is_directory=True)
    code,stdout,stderr=invoke('symlink',['--validate',str(alias)]); check(code==1 and stdout=='' and stderr=='noncanonical, symlinked or repository evidence path\n','symlink')
    for label,expected in (('corrupt-hash',3),('unavailable-runtime',56)):
        code,stdout,stderr=invoke(label,['--full'],dict(env,T0012_SYNTAX_NEGATIVE=label)); negative=evidence_from(stdout)
        check(code==expected and (negative/'capture.exit').read_text()==str(expected)+'\n','artifact exit')
        check(not (negative/'control.yml').exists() and not (negative/'java-version.txt').exists(),'artifact early stop')
        if label=='corrupt-hash': check(stderr=='pinned executable checksum mismatch\n' and (negative/'negative-control.txt').read_text()=='corrupt-copy-injected\n','corrupt boundary')
        else: check(stderr.startswith('unable to retrieve pinned executable: https://github.com/embulk/embulk/releases/download/v0.11.5/unavailable-s13.jar'),'unavailable boundary')
    print(f'T0012/S13: six selected syntax observations validated; 19 raw-copy controls, one path control, two artifact controls passed|evidence={outer}')
except (OSError,ValueError) as failure:
    print(f'T0012_S13_TEST_ERROR={failure}',file=sys.stderr); sys.exit(1)
PY

#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$script_dir/../.." && pwd)
source_file="$script_dir/src/T0012SchemaValueCouplingInputPlugin.java"
wrapper_file="$root/tests/t0012_schema_value_coupling_probe_test.sh"
mode=${T0012_COUPLING_MODE:-full}
if [[ "$mode" != capture && "$mode" != full && "$mode" != validate ]]; then
  printf '%s\n' 'T0012_COUPLING_MODE must be capture, full, or validate' >&2
  exit 2
fi

temporary_root=${T0012_COUPLING_TEMP_ROOT:-"${TMPDIR:-/private/tmp}/t0012-schema-value-coupling"}
resolved_root=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve())' "$temporary_root")
resolved_repository=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve())' "$root")
case "$resolved_root" in
  /tmp/* | /private/tmp/* | /var/folders/* | /private/var/folders/*) ;;
  *) printf '%s\n' 'T0012_COUPLING_TEMP_ROOT must be external' >&2; exit 2 ;;
esac
case "$resolved_root/" in
  "$resolved_repository/"*) printf '%s\n' 'temporary root resolves inside repository' >&2; exit 2 ;;
esac
[[ ! -L "$temporary_root" && -f "$source_file" && -f "$wrapper_file" ]] || exit 2
temporary_root=$resolved_root

validate_evidence() {
PYTHONDONTWRITEBYTECODE=1 python3 - "$1" "$2" "$root" <<'PY'
import base64,hashlib,json,pathlib,re,subprocess,sys,uuid
e=pathlib.Path(sys.argv[1]); level=sys.argv[2]; repo=pathlib.Path(sys.argv[3]).resolve()
fs=('matching','explicit-null','unset-text','wrong-setter','duplicate-name')
counts={'matching':(0,78),'explicit-null':(0,74),'unset-text':(1,46),'wrong-setter':(1,31),'duplicate-name':(0,60)}
vectors={'matching':'db8a49da05d479051bc36b14c5a409679d09866cf9b46fb1b686aa1068e3e7de','explicit-null':'0d24d2b54aaf18ea9dbaada67e8d16d24c6e6711346cff7162979eb7e25cbeec','unset-text':'e72894c14d5558e0b56132e9506e498507568b396e130e7fd2d728d17ce7d1d1','wrong-setter':'8cbf19bd93e6c3b69f1dc1da7275bdf3b9e60790906b4400cb6d70ae064df081','duplicate-name':'90128852fbb049c8ad82d0d788e4be85cbfac3a995f7016c770bc67685d3210e'}
paths={'plugin':'tools/t0012-schema-value-coupling-probe/src/T0012SchemaValueCouplingInputPlugin.java','runner':'tools/t0012-schema-value-coupling-probe/run.sh','wrapper':'tests/t0012_schema_value_coupling_probe_test.sh'}
class Bad(Exception):pass
def need(x,c):
 if not c: raise Bad(x)
def data(n,cap=8388608):
 p=e/n; need('artifact-path',p.parent==e and not p.is_symlink()); need('missing-artifact',p.is_file()); need('artifact-size',p.stat().st_size<=cap); return p.read_bytes()
def text(n,cap=8388608): return data(n,cap).decode()
def one(n):
 s=text(n,4096); need('metadata-line',s.endswith('\n') and s.count('\n')==1); return s[:-1]
def sha(n): return hashlib.sha256(data(n)).hexdigest()
need('evidence-path',e.is_absolute() and e.is_dir() and not e.is_symlink() and e.resolve()==e and e != repo and repo not in e.parents)
need('evidence-temp',any(pathlib.Path(p) in e.parents for p in ('/private/tmp','/private/var/folders')))
# A resolved leaf is insufficient: a symlinked ancestor can substitute the
# whole evidence tree after the caller's path check.
for ancestor in (e,)+tuple(e.parents):
 need('evidence-ancestor',not ancestor.is_symlink())
need('stage',one('stage.txt')==('full' if level in ('live','strict') else one('stage.txt')))
rev=one('source-revision.txt'); need('source-revision',re.fullmatch('[0-9a-f]{40}',rev)!=None)
for label,path in paths.items():
 need('source-path',one(label+'-source-path.txt')==path)
 try: blob=subprocess.run(['git','-C',str(repo),'show',rev+':'+path],check=True,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL).stdout
 except subprocess.CalledProcessError: raise Bad('source-revision')
 need('source-hash',one(label+'-source.sha256')==hashlib.sha256(blob).hexdigest())
need('fixture-source-hash',one('plugin-source.sha256')=='3458f499a93ad307c75395950c8ee1e3478c5eaeba706a645909124e53a305e3')
need('executable-url',one('executable-url.txt')=='https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar')
need('license-locators',one('executable-license-notice-locators.txt')=='META-INF/LICENSE|META-INF/NOTICE')
need('plugin-coordinate',one('plugin-coordinate.txt')=='source=maven|group=org.embulk.t0012|name=t0012_coupling|version=0.0.1|artifact=embulk-input-t0012_coupling|local-only')
for n in ('executable-manifest.txt','java-version.txt','javac-version.txt','jar-version.txt','python-version.txt','bash-version.txt','os-version.txt'):
 need('runtime-metadata',bool(text(n,65536).strip()))
need('executable-pin',one('executable.sha256')=='e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47')
need('license-hash',sha('LICENSE-executable')=='cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30')
need('notice-hash',sha('NOTICE-executable')=='27f0e45afdf10e406ee8bf478bfce38279e9087338a7981942a4a2762bcd5be8')
need('jar-path',one('plugin-jar-path.txt')=='plugin-under-test.jar'); need('jar-hash',one('plugin-jar.sha256')==sha('plugin-under-test.jar'))
case_bytes=data('coupling-cases.raw'); need('canonical-newline',case_bytes.endswith(b'\n') and b'\r' not in case_bytes and b'\n\n' not in case_bytes)
cases=case_bytes.decode().split('\n')[:-1]; need('case-count',len(cases)==5); combined=[]; capture_ids=set()
for i,f in enumerate(fs):
 row=cases[i].split('|'); ex,n=counts[f]; need('case-grammar',len(row)==5 and row[:2]==['COUPLINGCASE',f]); need('case-exit',row[2]==str(ex)); need('case-count',row[3]==str(n))
 trace_bytes=data(f+'.trace.raw'); need('canonical-newline',trace_bytes.endswith(b'\n') and b'\r' not in trace_bytes and b'\n\n' not in trace_bytes)
 rows=trace_bytes.decode().split('\n')[:-1]; need('event-count',len(rows)==n); ctx={}; norm=[]
 for line in rows:
  a=line.split('|'); need('trace-grammar',len(a)>=5 and a[:2]==['COUPLINGTRACE',f])
  try: u=uuid.UUID(a[2])
  except ValueError: raise Bad('capture-id')
  need('capture-id',str(u)==a[2] and u.version==4); ctx.setdefault(a[2],len(ctx)+1); o=ctx[a[2]]; capture_ids.add(a[2])
  need('sequence',a[3]==str(1+sum(x[0]==o for x in norm)))
  vals=[]
  for x in a[5:]:
   if x=='-': vals.append(None); continue
   try: raw=base64.b64decode(x,validate=True); need('canonical-base64',base64.b64encode(raw).decode()==x); vals.append(raw.decode())
   except Exception: raise Bad('payload')
  norm.append([o,int(a[3]),a[4],vals])
 need('context-segments',len(ctx)==(2 if f in ('unset-text','wrong-setter') else 1) and (len(ctx)==1 or [x[0] for x in norm[-2:]]==[2,2]))
 need('expected-vector',hashlib.sha256(json.dumps(norm,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()==vectors[f])
 material=('\n'.join(rows)+'\n').encode(); need('case-digest',row[4]==hashlib.sha256(material).hexdigest()); need('process-exit',one(f+'.exit.txt')==str(ex))
 stdout=text(f+'.stdout.log').split('\n')
 raw=[x for x in stdout if x.startswith('COUPLINGTRACE|')]
 need('foreign-trace',raw==rows); text(f+'.stderr.log'); combined+=rows
need('combined-order',text('coupling-traces.raw')=='\n'.join(combined)+'\n')
need('capture-cross-fixture-uniqueness',len(capture_ids)==sum(2 if f in ('unset-text','wrong-setter') else 1 for f in fs))
manifest={}
for line in text('raw-evidence-hashes.txt',65536).splitlines():
 a=line.split('='); need('hash-manifest-grammar',len(a)==2 and a[0] not in manifest and re.fullmatch('[0-9a-f]{64}',a[1])); manifest[a[0]]=a[1]
names=['coupling-cases.raw','coupling-traces.raw']+[f+'.'+s for f in fs for s in ('stdout.log','stderr.log','trace.raw','exit.txt')]
need('hash-manifest-count',set(names)==set(manifest))
need('hash-manifest-order',list(manifest)==sorted(names))
for n in names: need('raw-hash',manifest[n]==sha(n))
# The complete integrity manifest covers every metadata and raw artifact.  Its
# detached digest avoids a self-referential hash while still binding the list.
integrity={}
for line in text('integrity-manifest.txt',262144).splitlines():
 a=line.split('=',1); need('integrity-grammar',len(a)==2 and a[0] not in integrity and re.fullmatch('[0-9a-f]{64}',a[1])); integrity[a[0]]=a[1]
actual={p.name for p in e.iterdir() if p.is_file() and p.name not in ('integrity-manifest.txt','integrity-manifest.sha256')}
need('integrity-count',set(integrity)==actual)
need('integrity-order',list(integrity)==sorted(actual))
for n,h in integrity.items(): need('integrity-hash',h==sha(n))
need('integrity-seal',one('integrity-manifest.sha256')==hashlib.sha256(data('integrity-manifest.txt')).hexdigest())
PY
}

if [[ "$mode" == validate ]]; then
  evidence=${T0012_COUPLING_EVIDENCE_DIR:-}
  if [[ -z "$evidence" ]] || ! diagnostic=$(validate_evidence "$evidence" strict 2>&1); then
    diagnostic=${diagnostic##*$'\n'}
    diagnostic=${diagnostic##*: }
    printf 'T0012_COUPLING_VALIDATION_ERROR|%s\n' "${diagnostic:-missing-evidence}" >&2; exit 4
  fi
  printf 'T0012_COUPLING_VALIDATE_ONLY=passed|evidence=%s\n' "$evidence"; exit 0
fi
mkdir -p -- "$temporary_root"
run_dir=$(mktemp -d "$temporary_root/run.XXXXXX")
evidence="$run_dir/evidence"
plugin="$run_dir/plugin"
export EMBULK_HOME="$run_dir/embulk-home"
repository="$EMBULK_HOME/lib/m2/repository/org/embulk/t0012/embulk-input-t0012_coupling/0.0.1"
mkdir -p "$evidence" "$plugin/classes" "$repository"
trap 'printf "T0012_COUPLING_EVIDENCE_DIR=%s\n" "$evidence"' EXIT

executable="$run_dir/embulk.jar"
url=https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar
expected=e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47
timeout=120
if [[ ${T0012_COUPLING_NEGATIVE:-} == unavailable-runtime ]]; then
  url=https://127.0.0.1:1/unavailable
  timeout=2
fi
if ! curl --connect-timeout 15 --max-time "$timeout" --fail --location --proto '=https' \
  --tlsv1.2 --silent --show-error --output "$executable" "$url"
then
  printf 'unable to retrieve pinned executable: %s\n' "$url" >&2
  exit 56
fi
if [[ ${T0012_COUPLING_NEGATIVE:-} == corrupt-hash ]]; then
  printf x >> "$executable"
  printf '%s\n' corrupt-copy-injected > "$evidence/negative-control.txt"
fi
actual=$(shasum -a 256 "$executable" | awk '{print $1}')
[[ "$actual" == "$expected" ]] || { printf '%s\n' 'pinned executable checksum mismatch' >&2; exit 3; }

printf '%s\n' "$url" > "$evidence/executable-url.txt"
printf '%s\n' "$actual" > "$evidence/executable.sha256"
unzip -p "$executable" META-INF/MANIFEST.MF > "$evidence/executable-manifest.txt" || [[ -s "$evidence/executable-manifest.txt" ]]
unzip -p "$executable" META-INF/LICENSE > "$evidence/LICENSE-executable" || [[ -s "$evidence/LICENSE-executable" ]]
unzip -p "$executable" META-INF/NOTICE > "$evidence/NOTICE-executable" || [[ -s "$evidence/NOTICE-executable" ]]
printf '%s\n' 'META-INF/LICENSE|META-INF/NOTICE' > "$evidence/executable-license-notice-locators.txt"
java -XshowSettings:properties -version > "$evidence/java-version.txt" 2>&1
javac -version > "$evidence/javac-version.txt" 2>&1
jar --version > "$evidence/jar-version.txt" 2>&1
python3 --version > "$evidence/python-version.txt" 2>&1
bash --version > "$evidence/bash-version.txt" 2>&1
uname -a > "$evidence/os-version.txt"
git -C "$root" rev-parse HEAD > "$evidence/source-revision.txt"
for item in \
  "plugin:tools/t0012-schema-value-coupling-probe/src/T0012SchemaValueCouplingInputPlugin.java" \
  "runner:tools/t0012-schema-value-coupling-probe/run.sh" \
  "wrapper:tests/t0012_schema_value_coupling_probe_test.sh"
do
  label=${item%%:*}
  relative=${item#*:}
  printf '%s\n' "$relative" > "$evidence/$label-source-path.txt"
  shasum -a 256 "$root/$relative" | awk '{print $1}' > "$evidence/$label-source.sha256"
done
printf '%s\n' "$mode" > "$evidence/stage.txt"

javac -cp "$executable" -d "$plugin/classes" "$source_file"
printf '%s\n' \
  'Manifest-Version: 1.0' \
  'Embulk-Plugin-Main-Class: T0012SchemaValueCouplingInputPlugin' \
  'Embulk-Plugin-Category: input' \
  'Embulk-Plugin-Type: t0012_coupling' \
  'Embulk-Plugin-Spi-Version: 0' > "$plugin/MANIFEST.MF"
jar_file="$repository/embulk-input-t0012_coupling-0.0.1.jar"
jar cfm "$jar_file" "$plugin/MANIFEST.MF" -C "$plugin/classes" .
cp "$jar_file" "$evidence/plugin-under-test.jar"
shasum -a 256 "$evidence/plugin-under-test.jar" | awk '{print $1}' > "$evidence/plugin-jar.sha256"
printf '%s\n' 'plugin-under-test.jar' > "$evidence/plugin-jar-path.txt"
printf '%s\n' '<project><modelVersion>4.0.0</modelVersion><groupId>org.embulk.t0012</groupId><artifactId>embulk-input-t0012_coupling</artifactId><version>0.0.1</version></project>' > "$repository/embulk-input-t0012_coupling-0.0.1.pom"
printf '%s\n' 'source=maven|group=org.embulk.t0012|name=t0012_coupling|version=0.0.1|artifact=embulk-input-t0012_coupling|local-only' > "$evidence/plugin-coordinate.txt"

: > "$evidence/coupling-cases.raw"
: > "$evidence/coupling-traces.raw"
for fixture in matching explicit-null unset-text wrong-setter duplicate-name; do
  config="$run_dir/$fixture.yml"
  stdout="$evidence/$fixture.stdout.log"
  stderr="$evidence/$fixture.stderr.log"
  trace_file="$evidence/$fixture.trace.raw"
  printf '%s\n' 'in:' '  type:' '    source: maven' '    group: org.embulk.t0012' \
    '    name: t0012_coupling' '    version: 0.0.1' 'out:' '  type: "null"' > "$config"
  status=0
  T0012_COUPLING_FIXTURE="$fixture" java -jar "$executable" \
    "-Xembulk_home=$EMBULK_HOME" run "$config" > "$stdout" 2> "$stderr" || status=$?
  printf '%s\n' "$status" > "$evidence/$fixture.exit.txt"
  awk -v prefix="COUPLINGTRACE|$fixture|" 'index($0, prefix) == 1' "$stdout" > "$trace_file"
  count=$(wc -l < "$trace_file" | tr -d ' ')
  hash=$(shasum -a 256 "$trace_file" | awk '{print $1}')
  printf 'COUPLINGCASE|%s|%s|%s|%s\n' "$fixture" "$status" "$count" "$hash" >> "$evidence/coupling-cases.raw"
  cat "$trace_file" >> "$evidence/coupling-traces.raw"
done

python3 - "$evidence" <<'PY'
import pathlib
import sys
import uuid

root = pathlib.Path(sys.argv[1])
fixtures = ("matching", "explicit-null", "unset-text", "wrong-setter", "duplicate-name")
for fixture in fixtures:
    lines = (root / f"{fixture}.trace.raw").read_text(encoding="utf-8").splitlines()
    if not lines:
        raise SystemExit("missing trace for " + fixture)
    capture = None
    seen = set()
    expected_sequence = 0
    terminals = 0
    for line in lines:
        fields = line.split("|")
        if len(fields) < 5 or fields[:2] != ["COUPLINGTRACE", fixture]:
            raise SystemExit("invalid capture transport for " + fixture)
        parsed = uuid.UUID(fields[2])
        if str(parsed) != fields[2] or parsed.version != 4:
            raise SystemExit("invalid capture id for " + fixture)
        if fields[2] != capture:
            if fields[2] in seen:
                raise SystemExit("reused capture id for " + fixture)
            seen.add(fields[2])
            capture = fields[2]
            expected_sequence = 1
        else:
            expected_sequence += 1
        if fields[3] != str(expected_sequence):
            raise SystemExit("invalid capture sequence for " + fixture)
        terminals += fields[4] == "terminal"
    if terminals != 1:
        raise SystemExit("terminal count for " + fixture)
PY

for file in coupling-cases.raw coupling-traces.raw \
  matching.stdout.log matching.stderr.log matching.trace.raw matching.exit.txt \
  explicit-null.stdout.log explicit-null.stderr.log explicit-null.trace.raw explicit-null.exit.txt \
  unset-text.stdout.log unset-text.stderr.log unset-text.trace.raw unset-text.exit.txt \
  wrong-setter.stdout.log wrong-setter.stderr.log wrong-setter.trace.raw wrong-setter.exit.txt \
  duplicate-name.stdout.log duplicate-name.stderr.log duplicate-name.trace.raw duplicate-name.exit.txt
do
  shasum -a 256 "$evidence/$file" | awk -v name="$file" '{print name "=" $1}'
done | LC_ALL=C sort > "$evidence/raw-evidence-hashes.txt"

# Cover raw records and all provenance/runtime metadata without self-hashing.
# Keep the detached manifest digest separate so validation can detect edits to
# the manifest itself as well as edits to its members.
find "$evidence" -maxdepth 1 -type f ! -name integrity-manifest.txt ! -name integrity-manifest.sha256 -print | LC_ALL=C sort | while IFS= read -r file
do
  name=${file##*/}
  shasum -a 256 "$file" | awk -v name="$name" '{print name "=" $1}'
done > "$evidence/integrity-manifest.txt"
shasum -a 256 "$evidence/integrity-manifest.txt" | awk '{print $1}' > "$evidence/integrity-manifest.sha256"

cat "$evidence/coupling-cases.raw"
if [[ "$mode" == capture ]]; then
  printf 'T0012_COUPLING_CAPTURE_ONLY=collected|evidence=%s\n' "$evidence"
elif ! diagnostic=$(validate_evidence "$evidence" live 2>&1); then
  diagnostic=${diagnostic##*$'\n'}
  diagnostic=${diagnostic##*: }
  printf 'T0012_COUPLING_VALIDATION_ERROR|%s\n' "$diagnostic" >&2; exit 4
else
  printf 'T0012_COUPLING_FULL_RUN=passed|evidence=%s\n' "$evidence"
fi

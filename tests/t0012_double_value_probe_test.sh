#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0012-double-value-probe/run.sh"
[[ -x "$runner" ]] || exit 2
mode=${T0012_DOUBLE_MODE:-full}
if [[ "$mode" == capture || "$mode" == validate ]]; then T0012_DOUBLE_MODE="$mode" "$runner"; exit $?; fi
[[ "$mode" == full ]] || exit 2

artifact_control() {
  local control=$1 expected=$2 attempt status=0 evidence
  attempt=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-double-artifact.XXXXXX")
  T0012_DOUBLE_MODE=full T0012_DOUBLE_NEGATIVE="$control" "$runner" >"$attempt/stdout.log" 2>"$attempt/stderr.log" || status=$?
  printf 'T0012_DOUBLE_ARTIFACT_CONTROL=%s|exit=%s|attempt=%s\n' "$control" "$status" "$attempt"
  [[ "$status" == "$expected" ]]
  if [[ "$control" == corrupt-hash ]]; then
    grep -Fqx 'pinned executable checksum mismatch' "$attempt/stderr.log"
    evidence=$(sed -n 's/^T0012_DOUBLE_EVIDENCE_DIR=//p' "$attempt/stdout.log" | tail -1)
    grep -Fqx corrupt-copy-injected "$evidence/negative-control.txt"
  else grep -Fq 'unable to retrieve pinned executable:' "$attempt/stderr.log"; fi
}
artifact_control corrupt-hash 3
artifact_control unavailable-runtime 56

attempt=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-double-full.XXXXXX")
status=0
T0012_DOUBLE_MODE=full "$runner" >"$attempt/stdout.log" 2>"$attempt/stderr.log" || status=$?
printf 'T0012_DOUBLE_FULL_ATTEMPT=%s|exit=%s\n' "$attempt" "$status"
[[ "$status" == 0 && $(grep -c '^T0012_DOUBLE_FULL_RUN=passed|evidence=' "$attempt/stdout.log") == 1 ]]
evidence=$(sed -n 's/^T0012_DOUBLE_FULL_RUN=passed|evidence=//p' "$attempt/stdout.log")
grep -Fqx full "$evidence/stage.txt"
grep -Eq '^DOUBLECASE\|finite-null\|0\|114\|[0-9a-f]{64}$' "$evidence/double-cases.raw"
grep -Eq '^DOUBLECASE\|nonfinite\|0\|93\|[0-9a-f]{64}$' "$evidence/double-cases.raw"

mutated_copy() {
  local action=$1 fixture=$2 copy
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-double-validator.XXXXXX")
  cp -R "$evidence/." "$copy/"
  python3 - "$action" "$fixture" "$copy" <<'PY'
import base64, hashlib, pathlib, sys
action, fixture, directory = sys.argv[1:]
root=pathlib.Path(directory); fixtures=("finite-null","nonfinite")
cases=root.joinpath("double-cases.raw").read_text().splitlines()
traces=root.joinpath("double-traces.raw").read_text().splitlines()
enc=lambda x: base64.b64encode(x.encode()).decode()
def idx(event, selected=None):
    selected=selected or fixture
    return [i for i,r in enumerate(traces) if r.split("|")[1]==selected and r.split("|")[4]==event]
def change(event, field, value, occurrence=0):
    i=idx(event)[occurrence]; p=traces[i].split("|"); p[field]=value; traces[i]="|".join(p)
def remove(event, occurrence=0): traces.pop(idx(event)[occurrence])
if action=="missing-case": cases.pop(0)
elif action=="duplicate-case": cases[1]=cases[0]
elif action=="unknown-case": p=cases[0].split("|"); p[1]="unknown"; cases[0]="|".join(p)
elif action=="case-count": p=cases[0].split("|"); p[3]="9999"; cases[0]="|".join(p)
elif action=="case-digest": p=cases[0].split("|"); p[4]="0"*64; cases[0]="|".join(p)
elif action=="capture": change("transaction-entry",2,"not-a-uuid")
elif action=="capture-mismatch": change("schema-construct-entry",2,"12345678-1234-4234-9234-123456789abc")
elif action=="sequence": change("schema-construct-entry",3,"1")
elif action=="unknown-event": change("schema-column",4,"unknown-event")
elif action=="duplicate-event":
    i=idx("schema-column")[0]; traces.insert(i+1,traces[i])
elif action=="bad-base64": change("schema-column",7,"!")
elif action=="bad-utf8": change("schema-column",7,"/w==")
elif action=="raw-log":
    p=root/f"{fixture}.raw.log"; p.write_text(p.read_text().replace("DOUBLETRACE|","BROKEN|",1))
elif action=="combined-order": traces=list(reversed(traces))
elif action=="schema": change("schema-column",7,enc("changed"))
elif action=="bad-hex": change("input-cell",8,enc("ABC"))
elif action=="noncanonical-hex": change("input-cell",8,enc("7FEFFFFFFFFFFFFF"))
elif action=="null-tag": change("input-cell",7,enc("null"),0)
elif action=="null-payload": change("input-cell",8,enc("0000000000000000"),6)
elif action=="finite-bits": change("input-cell",8,enc("7feffffffffffffe"),0)
elif action=="zero-sign": change("input-cell",8,enc("0000000000000000"),5)
elif action=="infinity-sign": change("input-cell",8,enc("7ff0000000000000"),1)
elif action=="nan-bits": change("input-cell",8,enc("7ff8000000000043"),3)
elif action=="negative-nan": change("input-cell",8,enc("7ff8000000000042"),4)
elif action=="input-getter": change("reader-get-double-return",9,enc("0000000000000000"),0)
elif action=="missing-row":
    a=idx("reader-next-record-entry")[1]; b=idx("reader-next-record-entry")[2]; del traces[a:b]
elif action=="reordered-row":
    a=idx("reader-next-record-return")[0]; b=idx("reader-next-record-return")[1]; traces[a],traces[b]=traces[b],traces[a]
elif action=="getter-null": change("reader-is-null-return",9,enc("false"),6)
elif action=="exhaustion": change("reader-next-record-return",7,enc("true"),-1)
elif action=="setter": remove("builder-set-double-return")
elif action=="finish": remove("collector-finish-return")
elif action=="close": remove("reader-close-return")
elif action=="terminal": change("terminal",5,enc("exception"))
elif action=="cleanup": remove("cleanup-return")
elif action=="executable-pin": (root/"executable.sha256").write_text("0"*64+"\n")
elif action=="jar-hash": (root/"plugin-jar.sha256").write_text("0"*64+"\n")
elif action=="source-hash": (root/"runner-source.sha256").write_text("0"*64+"\n")
elif action=="event-cap":
    p=cases[0].split("|"); p[3]="1025"; cases[0]="|".join(p)
elif action=="artifact-cap": (root/f"{fixture}.raw.log").write_bytes(b"x"*(8*1024*1024+1))
elif action=="symlink":
    target=root/"stage-target.txt"; target.write_text("full\n"); (root/"stage.txt").unlink(); (root/"stage.txt").symlink_to(target)
else: raise ValueError(action)
repair=action not in {"missing-case","duplicate-case","unknown-case","case-count","case-digest","raw-log","combined-order","executable-pin","jar-hash","source-hash","event-cap","artifact-cap","symlink"}
if repair:
    for selected in fixtures:
        seq=0; rows=[]
        for i,row in enumerate(traces):
            p=row.split("|")
            if p[1]==selected:
                seq+=1; p[3]=str(seq); traces[i]="|".join(p); rows.append(traces[i])
        if action == "sequence" and selected == fixture:
            i = next(i for i, row in enumerate(traces) if row.split("|")[1] == selected and row.split("|")[4] == "schema-construct-entry")
            p = traces[i].split("|"); p[3] = "1"; traces[i] = "|".join(p)
            rows = [row for row in traces if row.split("|")[1] == selected]
        material=("\n".join(rows)+"\n").encode(); (root/f"{selected}.trace.raw").write_bytes(material)
        log=root/f"{selected}.raw.log"; other=[x for x in log.read_text().splitlines() if not x.startswith("DOUBLETRACE|")]
        log.write_text("\n".join(rows+other)+"\n")
        ci=next(i for i,x in enumerate(cases) if x.startswith("DOUBLECASE|"+selected+"|")); p=cases[ci].split("|")
        p[3]=str(len(rows)); p[4]=hashlib.sha256(material).hexdigest(); cases[ci]="|".join(p)
(root/"double-cases.raw").write_text("\n".join(cases)+"\n"); (root/"double-traces.raw").write_text("\n".join(traces)+"\n")
if repair:
    names=("double-cases.raw","double-traces.raw","finite-null.raw.log","nonfinite.raw.log","finite-null.trace.raw","nonfinite.trace.raw")
    (root/"raw-evidence-hashes.txt").write_text("".join(f"{n}={hashlib.sha256((root/n).read_bytes()).hexdigest()}\n" for n in names))
PY
  printf '%s\n' "$copy"
}

validator_fails() {
  local action=$1 fixture=$2 expected=$3 copy output status=0
  copy=$(mutated_copy "$action" "$fixture")
  output=$(T0012_DOUBLE_MODE=validate T0012_DOUBLE_STRICT_VALIDATE=1 T0012_DOUBLE_EVIDENCE_DIR="$copy" "$runner" 2>&1) || status=$?
  [[ "$status" == 4 && "$output" == "T0012_DOUBLE_VALIDATION_ERROR|$expected" ]] || { printf 'unexpected %s:%s => %s (%s)\n' "$fixture" "$action" "$output" "$status" >&2; exit 1; }
  printf 'T0012_DOUBLE_MUTATION=%s:%s|diagnostic=%s\n' "$fixture" "$action" "$expected"
}

validator_fails missing-case finite-null case-count
validator_fails duplicate-case finite-null case-grammar
validator_fails unknown-case finite-null case-grammar
validator_fails case-count finite-null case-count
validator_fails case-digest finite-null case-digest
validator_fails capture finite-null capture-id
validator_fails capture-mismatch finite-null single-capture
validator_fails sequence finite-null sequence
validator_fails unknown-event finite-null event-known
validator_fails duplicate-event finite-null expected-event-count
validator_fails bad-base64 finite-null canonical-base64
validator_fails bad-utf8 finite-null utf8
validator_fails raw-log finite-null raw-log
validator_fails combined-order finite-null combined-order
validator_fails schema finite-null expected-schema
validator_fails bad-hex finite-null input-value
validator_fails noncanonical-hex finite-null input-value
validator_fails null-tag finite-null input-value
validator_fails null-payload finite-null input-value
validator_fails finite-bits finite-null expected-finite-bits
validator_fails zero-sign finite-null expected-zero-sign
validator_fails infinity-sign nonfinite expected-infinity-sign
validator_fails nan-bits nonfinite expected-nan-bits
validator_fails negative-nan nonfinite expected-nan-bits
validator_fails input-getter finite-null expected-input-getter
validator_fails missing-row finite-null expected-event-count
validator_fails reordered-row finite-null operation-identity
validator_fails getter-null finite-null expected-getter-null-pairing
validator_fails exhaustion finite-null expected-reader-exhaustion
validator_fails setter finite-null operation-pair
validator_fails finish finite-null operation-pair
validator_fails close finite-null operation-pair
validator_fails terminal finite-null terminal-exception
validator_fails cleanup finite-null unpaired-operation
validator_fails executable-pin finite-null executable-pin
validator_fails jar-hash finite-null jar-hash
validator_fails source-hash finite-null source-hash
validator_fails event-cap finite-null case-count
validator_fails artifact-cap finite-null artifact-size
validator_fails symlink finite-null evidence-path

[[ $(T0012_DOUBLE_MODE=validate T0012_DOUBLE_EVIDENCE_DIR="$evidence" "$runner") == T0012_DOUBLE_VALIDATE_ONLY=passed ]]
[[ $(T0012_DOUBLE_MODE=validate T0012_DOUBLE_STRICT_VALIDATE=1 T0012_DOUBLE_EVIDENCE_DIR="$evidence" "$runner") == T0012_DOUBLE_VALIDATE_ONLY=passed ]]
printf 'T0012_DOUBLE_VALIDATED_CASES=2|events=207|evidence=%s\n' "$evidence"
printf 'T0012_DOUBLE_FULL_PROBE=passed|evidence=%s\n' "$evidence"

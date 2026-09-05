#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0012-page-value-probe/run.sh"
[[ -x "$runner" ]] || exit 2

run_artifact_negative() {
  local control=$1 expected=$2 attempt status
  attempt=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-page-artifact.XXXXXX")
  if T0012_PAGE_MODE=full T0012_PAGE_NEGATIVE="$control" "$runner" \
    > "$attempt/stdout.log" 2> "$attempt/stderr.log"; then
    status=0
  else
    status=$?
  fi
  printf 'T0012_PAGE_ARTIFACT_CONTROL=%s|exit=%s|attempt=%s\n' "$control" "$status" "$attempt"
  [[ "$status" == "$expected" ]]
  if [[ "$control" == corrupt-hash ]]; then
    evidence=$(sed -n 's/^T0012_PAGE_EVIDENCE_DIR=//p' "$attempt/stdout.log" | tail -1)
    [[ -s "$evidence/negative-control.txt" ]]
    grep -Fqx 'corrupt-copy-injected' "$evidence/negative-control.txt"
    grep -Fqx 'pinned executable checksum mismatch' "$attempt/stderr.log"
  else
    grep -Fq 'unable to retrieve pinned executable:' "$attempt/stderr.log"
  fi
}

run_artifact_negative corrupt-hash 3
run_artifact_negative unavailable-runtime 56

attempt=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-page-full.XXXXXX")
if T0012_PAGE_MODE=full "$runner" > "$attempt/runner.stdout.log" 2> "$attempt/runner.stderr.log"; then
  status=0
else
  status=$?
fi
printf 'T0012_PAGE_FULL_ATTEMPT=%s|exit=%s\n' "$attempt" "$status"
[[ "$status" == 0 ]]
[[ $(grep -c '^T0012_PAGE_VALIDATED_CASES=2|evidence=' "$attempt/runner.stdout.log") == 1 ]]
[[ $(grep -c '^T0012_PAGE_CAPTURE_ONLY=' "$attempt/runner.stdout.log") == 0 ]]
[[ $(grep -c '^T0012_PAGE_FULL_PROBE=passed' "$attempt/runner.stdout.log") == 0 ]]
evidence=$(sed -n 's/^T0012_PAGE_VALIDATED_CASES=2|evidence=//p' "$attempt/runner.stdout.log")
[[ -n "$evidence" && -d "$evidence" ]]
for file in executable-url.txt executable.sha256 executable-manifest.txt \
  LICENSE-executable NOTICE-executable executable-license-notice-locators.txt \
  java-version.txt os-family.txt source-revision.txt plugin-source-path.txt \
  plugin-source.sha256 runner-source-path.txt runner-source.sha256 \
  wrapper-source-path.txt wrapper-source.sha256 plugin-jar.sha256 \
  plugin-coordinate.txt stage.txt page-cases.raw page-traces.raw \
  raw-evidence-hashes.txt empty.raw.log typed-null.raw.log empty.trace.raw \
  typed-null.trace.raw; do
  [[ -s "$evidence/$file" ]]
done
grep -Fqx 'e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47' \
  "$evidence/executable.sha256"
grep -Fqx "$(shasum -a 256 "$root/tools/t0012-page-value-probe/src/T0012PageValueInputPlugin.java" | awk '{print $1}')" \
  "$evidence/plugin-source.sha256"
grep -Fqx "$(shasum -a 256 "$runner" | awk '{print $1}')" "$evidence/runner-source.sha256"
grep -Fqx "$(shasum -a 256 "$0" | awk '{print $1}')" "$evidence/wrapper-source.sha256"
grep -Fqx 'full' "$evidence/stage.txt"
grep -Eq '^PAGECASE\|empty\|0\|32\|[0-9a-f]{64}$' "$evidence/page-cases.raw"
grep -Eq '^PAGECASE\|typed-null\|0\|110\|[0-9a-f]{64}$' "$evidence/page-cases.raw"

mutated_copy() {
  local action=$1 fixture=$2 copy
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-page-validator.XXXXXX")
  cp "$evidence/page-cases.raw" "$evidence/page-traces.raw" \
    "$evidence/empty.trace.raw" "$evidence/typed-null.trace.raw" \
    "$evidence/empty.raw.log" "$evidence/typed-null.raw.log" "$copy/"
  python3 - "$action" "$fixture" "$copy" <<'PY'
import base64
import hashlib
import pathlib
import sys

action, fixture, directory = sys.argv[1:]
root = pathlib.Path(directory)
cases = root.joinpath("page-cases.raw").read_text(encoding="utf-8").splitlines()
traces = root.joinpath("page-traces.raw").read_text(encoding="utf-8").splitlines()

def enc(value):
    return base64.b64encode(value.encode()).decode()

def fields(index):
    return traces[index].split("|")

def find(event, *, selected_fixture=None, occurrence=0):
    target = selected_fixture or fixture
    matches = [index for index, row in enumerate(traces)
               if row.split("|")[1] == target and row.split("|")[4] == event]
    return matches[occurrence]

def remove(event, occurrence=0):
    traces.pop(find(event, occurrence=occurrence))

def renumber(target):
    sequence = 0
    for index, row in enumerate(traces):
        values = row.split("|")
        if values[1] == target:
            sequence += 1
            values[3] = str(sequence)
            traces[index] = "|".join(values)

if action == "missing-case":
    cases.pop(0)
elif action == "duplicate-case":
    cases[1] = cases[0]
elif action == "unknown-case":
    values = cases[0].split("|"); values[1] = "unknown"; cases[0] = "|".join(values)
elif action == "malformed-case":
    cases[0] = "|".join(cases[0].split("|")[:-1])
elif action == "huge-count":
    values = cases[0].split("|"); values[3] = "513"; cases[0] = "|".join(values)
elif action == "overlong-count":
    values = cases[0].split("|"); values[3] = "1" * 1000; cases[0] = "|".join(values)
elif action == "process-exit":
    selected = next(index for index, row in enumerate(cases) if row.startswith(f"PAGECASE|{fixture}|"))
    values = cases[selected].split("|"); values[2] = "1"; cases[selected] = "|".join(values)
elif action == "digest":
    values = cases[0].split("|"); values[4] = "0" * 64; cases[0] = "|".join(values)
elif action == "missing-event":
    remove("schema-column")
elif action == "duplicate-event":
    index = find("schema-column"); traces.insert(index + 1, traces[index])
elif action == "unknown-event":
    index = find("schema-column"); values = fields(index); values[4] = "unknown"; traces[index] = "|".join(values)
elif action == "wrong-arity":
    index = find("schema-column"); traces[index] += "|" + enc("extra")
elif action == "bad-b64":
    index = find("schema-column"); values = fields(index); values[-1] = "!"; traces[index] = "|".join(values)
elif action == "capture":
    index = find("schema-column"); values = fields(index); values[2] = "not-a-uuid"; traces[index] = "|".join(values)
elif action == "sequence":
    index = find("schema-column"); values = fields(index); values[3] = "1"; traces[index] = "|".join(values)
elif action == "leading-sequence":
    index = find("transaction-entry"); values = fields(index); values[3] = "01"; traces[index] = "|".join(values)
elif action == "overlong-sequence":
    index = find("transaction-entry"); values = fields(index); values[3] = "1" * 1000; traces[index] = "|".join(values)
elif action == "reorder-combined":
    traces = ([row for row in traces if row.split("|")[1] == "typed-null"]
              + [row for row in traces if row.split("|")[1] == "empty"])
elif action == "raw-log":
    log = root / f"{fixture}.raw.log"
    log.write_text(log.read_text(encoding="utf-8").replace("PAGETRACE|", "BROKEN|", 1), encoding="utf-8")
elif action == "schema":
    index = find("schema-column"); values = fields(index); values[-2] = enc("changed"); traces[index] = "|".join(values)
elif action in {"boolean", "long", "string"}:
    index = find(f"reader-get-{action}-return")
    values = fields(index)
    values[-1] = enc({"boolean": "false", "long": "0", "string": "changed"}[action])
    traces[index] = "|".join(values)
elif action == "null-contradiction":
    index = find("reader-is-null-return", occurrence=6)
    values = fields(index); values[-1] = enc("false"); traces[index] = "|".join(values)
elif action == "getter-for-null":
    index = find("cell-null")
    template = fields(find("reader-get-boolean-entry"))
    position = fields(index)[5:9]
    prefix = template[:4]
    traces[index + 1:index + 1] = [
        "|".join(prefix + ["reader-get-boolean-entry"] + position),
        "|".join(prefix + ["reader-get-boolean-return"] + position + [enc("false")]),
    ]
elif action == "missing-row":
    start = find("reader-next-record-entry", occurrence=1)
    end = find("reader-next-record-entry", occurrence=2)
    del traces[start:end]
elif action == "reorder-row":
    first = find("reader-next-record-return", occurrence=0)
    second = find("reader-next-record-return", occurrence=1)
    traces[first], traces[second] = traces[second], traces[first]
elif action == "page-exhaustion":
    index = find("reader-next-record-return", occurrence=3)
    values = fields(index); values[-1] = enc("true"); traces[index] = "|".join(values)
elif action == "setter":
    remove("builder-set-string-return")
elif action == "add-record":
    remove("builder-add-record-return")
elif action == "finish":
    first = find("collector-finish-entry")
    second = find("collector-finish-return")
    traces[first], traces[second] = traces[second], traces[first]
elif action == "close":
    remove("reader-close-return")
elif action == "terminal":
    index = find("terminal"); values = fields(index); values[5] = enc("changed"); traces[index] = "|".join(values)
elif action == "cleanup":
    remove("cleanup-return")
else:
    raise ValueError(action)

def synchronize():
    renumber(fixture)
    for selected in ("empty", "typed-null"):
        rows = [row for row in traces if row.split("|")[1] == selected]
        material = ("\n".join(rows) + "\n").encode()
        root.joinpath(f"{selected}.trace.raw").write_bytes(material)
        log = root / f"{selected}.raw.log"
        other = [line for line in log.read_text(encoding="utf-8").splitlines()
                 if not line.startswith("PAGETRACE|")]
        log.write_text("\n".join(rows + other) + "\n", encoding="utf-8")
        case = next(index for index, row in enumerate(cases)
                    if row.startswith(f"PAGECASE|{selected}|"))
        values = cases[case].split("|")
        values[3] = str(len(rows))
        values[4] = hashlib.sha256(material).hexdigest()
        cases[case] = "|".join(values)

if action not in {"missing-case", "duplicate-case", "unknown-case", "malformed-case",
                  "huge-count", "overlong-count", "process-exit", "digest", "raw-log",
                  "capture", "sequence", "leading-sequence", "overlong-sequence",
                  "reorder-combined"}:
    synchronize()
root.joinpath("page-cases.raw").write_text("\n".join(cases) + "\n", encoding="utf-8")
root.joinpath("page-traces.raw").write_text("\n".join(traces) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$copy"
}

validator_fails() {
  local action=$1 fixture=$2 expected=$3 copy output status
  copy=$(mutated_copy "$action" "$fixture")
  printf 'T0012_PAGE_MUTATION=%s:%s|evidence=%s\n' "$fixture" "$action" "$copy"
  if output=$(T0012_PAGE_MODE=validate T0012_PAGE_EVIDENCE_DIR="$copy" "$runner" 2>&1); then
    status=0
  else
    status=$?
  fi
  [[ "$status" == 4 ]]
  [[ "$output" == "T0012_PAGE_VALIDATION_ERROR|$expected" ]] || {
    printf 'unexpected validation result for %s:%s: %s\n' "$fixture" "$action" "$output" >&2
    exit 1
  }
}

validator_fails missing-case empty case-count
validator_fails duplicate-case empty case-fixture
validator_fails unknown-case empty case-fixture
validator_fails malformed-case empty case-grammar
validator_fails huge-count empty case-event-cap
validator_fails overlong-count empty case-event-count
validator_fails process-exit empty process-success
validator_fails digest empty case-digest-match
validator_fails missing-event empty schema-order-values
validator_fails duplicate-event empty schema-order-values
validator_fails unknown-event empty event-known
validator_fails wrong-arity empty event-arity
validator_fails bad-b64 empty canonical-base64
validator_fails capture empty capture-id
validator_fails sequence empty sequence-contiguous
validator_fails leading-sequence empty sequence-grammar
validator_fails overlong-sequence empty sequence-grammar
validator_fails reorder-combined empty combined-trace-order
validator_fails raw-log empty raw-log-trace-match
validator_fails schema empty schema-order-values
validator_fails finish empty finish-close-order
validator_fails close empty finish-close-order
validator_fails terminal empty terminal-cleanup-order
validator_fails cleanup empty terminal-cleanup-order
validator_fails schema typed-null schema-order-values
validator_fails boolean typed-null page-read-order-values
validator_fails long typed-null page-read-order-values
validator_fails string typed-null page-read-order-values
validator_fails null-contradiction typed-null page-read-order-values
validator_fails getter-for-null typed-null page-read-order-values
validator_fails missing-row typed-null page-read-order-values
validator_fails reorder-row typed-null page-read-order-values
validator_fails page-exhaustion typed-null page-read-order-values
validator_fails setter typed-null assignment-order-values
validator_fails add-record typed-null assignment-order-values
validator_fails finish typed-null finish-close-order
validator_fails close typed-null finish-close-order
validator_fails terminal typed-null terminal-cleanup-order
validator_fails cleanup typed-null terminal-cleanup-order

if output=$(T0012_PAGE_MODE=validate T0012_PAGE_EVIDENCE_DIR="$evidence" "$runner"); then
  [[ "$output" == "T0012_PAGE_VALIDATE_ONLY=passed" ]]
else
  exit 1
fi
printf 'T0012_PAGE_VALIDATED_CASES=2|evidence=%s\n' "$evidence"
printf 'T0012_PAGE_FULL_PROBE=passed|evidence=%s\n' "$evidence"

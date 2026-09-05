#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
driver="$root/tools/t0013-output-commit-differential"
evidence_dir=${T0013_S06_EVIDENCE_DIR:-$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-s06.XXXXXX")}
mkdir -p -- "$evidence_dir"
printf 'T0013_S06_EVIDENCE_DIR=%s\n' "$evidence_dir"
[[ -x "$driver" ]] || exit 2

cargo test --manifest-path "$root/Cargo.toml" -p emburk-core \
  empty_lifecycle::tests::output_commit_differential_tests \
  > "$evidence_dir/rust-negative-controls.log" 2>&1
grep -Fqx 'test empty_lifecycle::tests::output_commit_differential_tests::output_commit_manifest_rejects_mutated_execution_contracts ... ok' \
  "$evidence_dir/rust-negative-controls.log"
grep -Fqx 'test empty_lifecycle::tests::output_commit_differential_tests::rust_failure_normalization_rejects_component_and_payload_substitution ... ok' \
  "$evidence_dir/rust-negative-controls.log"
grep -Eq '^test result: ok\. 2 passed; 0 failed; 1 ignored; .* filtered out;' \
  "$evidence_dir/rust-negative-controls.log"

"$driver" --manifest "$evidence_dir/live.tsv" \
  --probe-stdout "$evidence_dir/s05-full-probe.stdout.log" \
  --probe-stderr "$evidence_dir/s05-full-probe.stderr.log" \
  --evidence-manifest "$evidence_dir/driver-evidence-manifest.txt" \
  --raw-hashes "$evidence_dir/raw-evidence-hashes.txt" \
  > "$evidence_dir/driver.stdout.log" 2> "$evidence_dir/driver.stderr.log"
grep -Fqx 'T0013_S06_PROJECTED_CASES=2' "$evidence_dir/driver.stdout.log"
[[ ! -s "$evidence_dir/driver.stderr.log" ]]
[[ $(grep -c '^T0013_COMMIT_FULL_PROBE=passed|evidence=' "$evidence_dir/s05-full-probe.stdout.log") == 1 ]]
[[ $(grep -c $'^CASE\t' "$evidence_dir/live.tsv") == 2 ]]
grep -Fqx $'T0013-S06\t1' "$evidence_dir/live.tsv"
for file in cases.raw traces.raw normal.raw.log commit-failure.raw.log; do
  grep -Eq "^${file//./\\.}=[0-9a-f]{64}$" "$evidence_dir/raw-evidence-hashes.txt"
done
for key in executable.sha256 executable-url.txt input-source.sha256 input-source-path.txt \
  output-source.sha256 input-jar.sha256 output-jar.sha256; do
  grep -Eq "^$key=.+" "$evidence_dir/driver-evidence-manifest.txt"
done
reference=$(sed -n 's/^evidence=//p' "$evidence_dir/driver-evidence-manifest.txt")
[[ -n "$reference" && -d "$reference" ]]

mutated_copy() {
  local mutation=$1 copy
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-s06-validator.XXXXXX")
  cp "$reference/cases.raw" "$reference/traces.raw" "$reference/normal.raw.log" \
    "$reference/commit-failure.raw.log" "$copy/"
  python3 - "$mutation" "$copy" <<'PY'
import base64
import hashlib
import pathlib
import sys

action, directory = sys.argv[1:]
root = pathlib.Path(directory)
cases = root.joinpath("cases.raw").read_text(encoding="utf-8").splitlines()
traces = root.joinpath("traces.raw").read_text(encoding="utf-8").splitlines()

def find(fixture, tag, event):
    return next(index for index, row in enumerate(traces)
                if row.startswith(f"{tag}|{fixture}|") and row.split("|")[4] == event)

def renumber(fixture, tag, capture):
    sequence = 0
    for index, row in enumerate(traces):
        fields = row.split("|")
        if len(fields) >= 5 and fields[0] == tag and fields[1] == fixture and fields[2] == capture:
            sequence += 1
            fields[3] = str(sequence)
            traces[index] = "|".join(fields)

def remove(fixture, tag, event):
    index = find(fixture, tag, event)
    capture = traces[index].split("|")[2]
    traces.pop(index)
    renumber(fixture, tag, capture)

def insert_after(fixture, tag, event, row):
    index = find(fixture, tag, event)
    capture = traces[index].split("|")[2]
    traces.insert(index + 1, row)
    renumber(fixture, tag, capture)

def encoded(text):
    return base64.b64encode(text.encode()).decode()

if action == "missing-injection":
    remove("commit-failure", "COMMITOUTTRACE", "commit-injection-before")
elif action == "duplicate-injection":
    index = find("commit-failure", "COMMITOUTTRACE", "commit-injection-before")
    insert_after("commit-failure", "COMMITOUTTRACE", "commit-injection-before", traces[index])
elif action == "wrong-selection":
    index = find("commit-failure", "COMMITOUTTRACE", "commit-selection")
    fields = traces[index].split("|"); fields[6] = fields[5]; traces[index] = "|".join(fields)
elif action in {"wrong-class", "wrong-message"}:
    for event in ("commit-runtime-exception", "transaction-runtime-exception"):
        tags = ("COMMITOUTTRACE",) if event == "commit-runtime-exception" else ("COMMITOUTTRACE", "FAILTRACE")
        for tag in tags:
            index = find("commit-failure", tag, event)
            fields = traces[index].split("|")
            target = -2 if action == "wrong-class" else -1
            fields[target] = encoded("java.lang.RuntimeException" if action == "wrong-class" else "changed")
            traces[index] = "|".join(fields)
elif action == "fabricated-normal-return":
    failure = traces[find("commit-failure", "COMMITOUTTRACE", "commit-runtime-exception")].split("|")
    row = "|".join(failure[:4] + ["commit-normal-return"] + failure[5:7])
    insert_after("commit-failure", "COMMITOUTTRACE", "commit-runtime-exception", row)
elif action == "missing-terminal":
    remove("commit-failure", "COMMITOUTTRACE", "commit-runtime-exception")
elif action == "missing-abort":
    remove("commit-failure", "COMMITOUTTRACE", "abort-normal-return")
elif action == "missing-close":
    remove("commit-failure", "COMMITOUTTRACE", "close-normal-return")
elif action == "reversed-successful-commit":
    entry = find("commit-failure", "COMMITOUTTRACE", "commit-entry")
    returned = find("commit-failure", "COMMITOUTTRACE", "commit-normal-return")
    row = traces.pop(returned)
    if returned < entry:
        entry -= 1
    traces.insert(entry, row)
    renumber("commit-failure", "COMMITOUTTRACE", row.split("|")[2])
elif action == "early-cleanup":
    entry = find("commit-failure", "FAILTRACE", "cleanup-entry")
    returned = find("commit-failure", "FAILTRACE", "cleanup-normal-return")
    pair = [traces[entry], traces[returned]]
    for index in sorted((entry, returned), reverse=True):
        traces.pop(index)
    target = find("commit-failure", "FAILTRACE", "transaction-runtime-exception")
    traces[target:target] = pair
elif action == "reordered-scope":
    control = find("normal", "COMMITOUTTRACE", "control-run-normal-return")
    transaction = find("normal", "COMMITOUTTRACE", "transaction-normal-return")
    row = traces.pop(transaction)
    if transaction < control:
        control -= 1
    traces.insert(control, row)
    renumber("normal", "COMMITOUTTRACE", row.split("|")[2])
elif action == "sequence":
    index = find("commit-failure", "COMMITOUTTRACE", "commit-entry")
    fields = traces[index].split("|"); fields[3] = "1"; traces[index] = "|".join(fields)
elif action == "capture":
    index = find("commit-failure", "COMMITOUTTRACE", "commit-injection-before")
    fields = traces[index].split("|"); fields[2] = "not-a-uuid"; traces[index] = "|".join(fields)
elif action == "malformed":
    index = find("normal", "COMMITOUTTRACE", "commit-entry")
    fields = traces[index].split("|"); fields[5] = "!"; traces[index] = "|".join(fields)
elif action == "unknown":
    index = find("normal", "COMMITOUTTRACE", "commit-entry")
    fields = traces[index].split("|"); fields[4] = "invented"; traces[index] = "|".join(fields)
elif action in {"add", "resume"}:
    transaction = traces[find("normal", "COMMITOUTTRACE", "transaction-entry")].split("|")
    event = "add-entry" if action == "add" else "resume-entry"
    row = "|".join(transaction[:4] + [event, encoded("0"), encoded("0")])
    insert_after("normal", "COMMITOUTTRACE", "transaction-entry", row)
elif action == "contradictory-transaction":
    error = traces[find("commit-failure", "COMMITOUTTRACE", "transaction-runtime-exception")].split("|")
    selection = traces[find("commit-failure", "COMMITOUTTRACE", "commit-selection")].split("|")
    cleanup = traces[find("commit-failure", "COMMITOUTTRACE", "cleanup-entry")].split("|")
    row = "|".join(error[:4] + ["transaction-normal-return", selection[5], encoded("0"), cleanup[-1]])
    insert_after("commit-failure", "COMMITOUTTRACE", "transaction-runtime-exception", row)

elif action == "missing-case":
    cases.pop(0)
elif action == "duplicate-case":
    cases.append(cases[0])
elif action == "unknown-case":
    fields = cases[0].split("|"); fields[1] = "unknown"; cases[0] = "|".join(fields)
elif action == "malformed-case":
    fields = cases[0].split("|"); cases[0] = "|".join(fields[:-1])
elif action == "count":
    fields = cases[0].split("|"); summary = fields[4].split(":")
    summary[0] = str(int(summary[0]) + 1); fields[4] = ":".join(summary)
    cases[0] = "|".join(fields)
elif action in {"schema", "cap"}:
    index = find("normal", "COMMITOUTTRACE", "transaction-entry")
    fields = traces[index].split("|")
    fields[6 if action == "schema" else 5] = encoded("1" if action == "schema" else "1025")
    traces[index] = "|".join(fields)
elif action == "index":
    index = find("normal", "COMMITOUTTRACE", "open-normal-return")
    transaction = traces[find("normal", "COMMITOUTTRACE", "transaction-entry")].split("|")
    fields = traces[index].split("|"); fields[5] = transaction[5]; traces[index] = "|".join(fields)
elif action in {"missing-successful-commit", "missing-normal-commit"}:
    remove("commit-failure" if action == "missing-successful-commit" else "normal",
           "COMMITOUTTRACE", "commit-normal-return")

def synchronize():
    for fixture in ("normal", "commit-failure"):
        rows = [row for row in traces if row.split("|")[1] == fixture]
        log = root / f"{fixture}.raw.log"
        other = [line for line in log.read_text(encoding="utf-8").splitlines()
                 if not line.startswith("FAILTRACE|") and not line.startswith("COMMITOUTTRACE|")]
        log.write_text("\n".join(rows + other) + "\n", encoding="utf-8")
        index = next(i for i, row in enumerate(cases) if row.startswith(f"COMMITCASE|{fixture}|"))
        fields = cases[index].split("|")
        input_count = sum(row.startswith("FAILTRACE|") for row in rows)
        output_count = sum(row.startswith("COMMITOUTTRACE|") for row in rows)
        digest = hashlib.sha256(("\n".join(rows) + "\n").encode()).hexdigest()
        fields[4] = f"{len(rows)}:{input_count}:{output_count}:{digest}"
        cases[index] = "|".join(fields)

if action == "hash":
    fields = cases[0].split("|"); summary = fields[4].split(":"); summary[3] = "0" * 64
    fields[4] = ":".join(summary); cases[0] = "|".join(fields)
elif action == "raw-log":
    log = root / "commit-failure.raw.log"
    log.write_text(log.read_text(encoding="utf-8").replace("COMMITOUTTRACE|", "BROKEN|", 1), encoding="utf-8")
elif action not in {"missing-case", "duplicate-case", "unknown-case", "malformed-case", "count"}:
    synchronize()

root.joinpath("cases.raw").write_text("\n".join(cases) + "\n", encoding="utf-8")
root.joinpath("traces.raw").write_text("\n".join(traces) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$copy"
}


validator_fails() {
  local mutation=$1 expected=$2 copy result_code
  copy=$(mutated_copy "$mutation")
  printf 'T0013_S06_RAW_MUTATION=%s|evidence=%s\n' "$mutation" "$copy"
  if "$driver" --validate-only "$copy" --manifest "$copy/rejected.tsv" \
      > "$copy/driver.stdout.log" 2> "$copy/driver.stderr.log"; then
    printf 'mutation unexpectedly accepted: %s\n' "$mutation" >&2
    exit 1
  else
    result_code=$?
  fi
  [[ "$result_code" == 4 ]] || exit 1
  grep -Fqx "T0013/S06 driver rejected evidence: $expected" "$copy/driver.stderr.log"
}

validator_fails missing-injection failure-injection
validator_fails duplicate-injection failure-injection
validator_fails wrong-selection selection-index
validator_fails wrong-class failure-exact-error
validator_fails wrong-message failure-exact-error
validator_fails fabricated-normal-return failure-other-commit-returns
validator_fails missing-terminal commit-exception
validator_fails missing-abort abort-return-indexes
validator_fails missing-close close-return-indexes
validator_fails reversed-successful-commit failure-other-commit-pair
validator_fails early-cleanup cleanup-physical-order
validator_fails reordered-scope output-main-order
validator_fails sequence output-sequence-contiguous
validator_fails capture capture-id
validator_fails malformed output-canonical-field
validator_fails hash case-digest-match
validator_fails raw-log raw-log-trace-match
validator_fails unknown output-event-known
validator_fails add unexpected-callback
validator_fails resume unexpected-callback
validator_fails contradictory-transaction failure-no-normal-scopes
validator_fails missing-case case-count
validator_fails duplicate-case case-count
validator_fails unknown-case case-fixture
validator_fails malformed-case case-arity
validator_fails count case-total-count-match
validator_fails schema empty-output-schema
validator_fails cap output-task-cap
validator_fails index output-index-range
validator_fails missing-successful-commit failure-other-commit-returns
validator_fails missing-normal-commit commit-return-indexes

T0013_S06_MANIFEST="$evidence_dir/live.tsv" cargo test --manifest-path "$root/Cargo.toml" \
  -p emburk-core empty_lifecycle::tests::output_commit_differential_tests::live_output_commit_differential \
  -- --ignored --exact > "$evidence_dir/live-rust-test.log" 2>&1
grep -Fqx 'test empty_lifecycle::tests::output_commit_differential_tests::live_output_commit_differential ... ok' \
  "$evidence_dir/live-rust-test.log"
grep -Eq '^test result: ok\. 1 passed; 0 failed; 0 ignored; .* filtered out;' \
  "$evidence_dir/live-rust-test.log"
printf '%s\n' 'T0013_S06_COMPARED_CASES=2'
printf 'T0013/S06: compared exactly 2 live output-commit projections; raw and bridge controls passed|evidence=%s\n' "$evidence_dir"

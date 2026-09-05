#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
driver="$root/tools/t0013-output-commit-position-differential"
evidence_dir=${T0013_S08_EVIDENCE_DIR:-$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-s08.XXXXXX")}
mkdir -p -- "$evidence_dir"
printf 'T0013_S08_EVIDENCE_DIR=%s\n' "$evidence_dir"
[[ -x "$driver" ]] || exit 2

cargo test --manifest-path "$root/Cargo.toml" -p emburk-core \
  empty_lifecycle::tests::output_commit_position_differential_tests \
  > "$evidence_dir/rust-contract-controls.log" 2>&1
grep -Fqx 'test empty_lifecycle::tests::output_commit_position_differential_tests::position_manifest_accepts_dynamic_three_and_eight_task_contracts ... ok' \
  "$evidence_dir/rust-contract-controls.log"
grep -Fqx 'test empty_lifecycle::tests::output_commit_position_differential_tests::position_manifest_rejects_case_report_selection_and_order_mutations ... ok' \
  "$evidence_dir/rust-contract-controls.log"
grep -Fqx 'test empty_lifecycle::tests::output_commit_position_differential_tests::actual_execution_validation_rejects_result_trace_report_and_plan_mutations ... ok' \
  "$evidence_dir/rust-contract-controls.log"
grep -Eq '^test result: ok\. 3 passed; 0 failed; 1 ignored; .* filtered out;' \
  "$evidence_dir/rust-contract-controls.log"

"$driver" --manifest "$evidence_dir/live.tsv" \
  --probe-stdout "$evidence_dir/s07-full-probe.stdout.log" \
  --probe-stderr "$evidence_dir/s07-full-probe.stderr.log" \
  --evidence-manifest "$evidence_dir/driver-evidence-manifest.txt" \
  --raw-hashes "$evidence_dir/raw-evidence-hashes.txt" \
  > "$evidence_dir/driver.stdout.log" 2> "$evidence_dir/driver.stderr.log"
grep -Fqx 'T0013_S08_PROJECTED_CASES=3' "$evidence_dir/driver.stdout.log"
[[ ! -s "$evidence_dir/driver.stderr.log" ]]
[[ $(grep -c '^T0013_POSITION_FULL_PROBE=passed|evidence=' \
  "$evidence_dir/s07-full-probe.stdout.log") == 1 ]]
grep -Fqx $'T0013-S08\t1' "$evidence_dir/live.tsv"
[[ $(grep -c $'^CASE\t' "$evidence_dir/live.tsv") == 3 ]]
for file in cases.raw traces.raw normal.raw.log commit-first.raw.log commit-middle.raw.log; do
  grep -Eq "^${file//./\\.}=[0-9a-f]{64}$" "$evidence_dir/raw-evidence-hashes.txt"
done
for key in executable.sha256 executable-url.txt input-source.sha256 input-source-path.txt \
  output-source.sha256 output-source-path.txt input-jar.sha256 output-jar.sha256 \
  input-coordinate.txt output-coordinate.txt; do
  grep -Eq "^$key=.+" "$evidence_dir/driver-evidence-manifest.txt"
done
reference=$(sed -n 's/^evidence=//p' "$evidence_dir/driver-evidence-manifest.txt")
[[ -n "$reference" && -d "$reference" ]]

mutated_copy() {
  local action=$1 fixture=$2 reference=$3 copy
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-s08-validator.XXXXXX")
  cp "$reference/cases.raw" "$reference/traces.raw" \
    "$reference/normal.raw.log" "$reference/commit-first.raw.log" \
    "$reference/commit-middle.raw.log" "$copy/"
  python3 - "$action" "$fixture" "$copy" <<'PY'
import base64
import hashlib
import pathlib
import sys

action, fixture, directory = sys.argv[1:]
root = pathlib.Path(directory)
cases = root.joinpath("cases.raw").read_text(encoding="utf-8").splitlines()
traces = root.joinpath("traces.raw").read_text(encoding="utf-8").splitlines()

def encoded(text):
    return base64.b64encode(text.encode()).decode()

def fields(index):
    return traces[index].split("|")

def find(tag, event, *, selected_fixture=None, index=None):
    target_fixture = selected_fixture or fixture
    for row_index, row in enumerate(traces):
        values = row.split("|")
        if (
            values[0] == tag
            and values[1] == target_fixture
            and values[4] == event
            and (index is None or base64.b64decode(values[5]).decode() == str(index))
        ):
            return row_index
    raise ValueError(f"mutation target absent: {tag}/{target_fixture}/{event}/{index}")

def selection():
    values = fields(find("POSITIONOUTTRACE", "commit-selection"))
    return (
        int(base64.b64decode(values[5]).decode()),
        int(base64.b64decode(values[7]).decode()),
    )

def renumber(target_fixture):
    next_sequence = {}
    for row_index, row in enumerate(traces):
        values = row.split("|")
        if values[1] != target_fixture:
            continue
        key = (values[0], values[2])
        next_sequence[key] = next_sequence.get(key, 0) + 1
        values[3] = str(next_sequence[key])
        traces[row_index] = "|".join(values)

def remove(tag, event, *, index=None):
    traces.pop(find(tag, event, index=index))

def insert_after(row_index, new_rows):
    traces[row_index + 1:row_index + 1] = new_rows

def output_row(template, event, index):
    values = fields(template)
    return "|".join(values[:4] + [event, encoded(str(index)), encoded("0")])

count, selected = selection()

if action == "missing-event":
    remove("POSITIONOUTTRACE", "open-normal-return", index=0)
elif action == "duplicate-event":
    row_index = find("FAILTRACE", "run-entry")
    traces.insert(row_index + 1, traces[row_index])
elif action == "unknown-event":
    row_index = find("POSITIONOUTTRACE", "open-entry")
    values = fields(row_index)
    values[4] = "invented"
    traces[row_index] = "|".join(values)
elif action == "malformed-event":
    row_index = find("POSITIONOUTTRACE", "open-entry")
    values = fields(row_index)
    values[5] = "!"
    traces[row_index] = "|".join(values)
elif action == "sequence":
    row_index = find("POSITIONOUTTRACE", "open-entry")
    values = fields(row_index)
    values[3] = "1"
    traces[row_index] = "|".join(values)
elif action == "capture":
    row_index = find("POSITIONOUTTRACE", "open-entry")
    values = fields(row_index)
    values[2] = "not-a-uuid"
    traces[row_index] = "|".join(values)
elif action == "fabricated-later-commit":
    terminal = find("POSITIONOUTTRACE", "commit-runtime-exception")
    template = find("POSITIONOUTTRACE", "commit-entry", index=selected)
    insert_after(
        terminal,
        [
            output_row(template, "commit-entry", selected + 1),
            output_row(template, "commit-normal-return", selected + 1),
        ],
    )
elif action == "missing-later-abort":
    remove("POSITIONOUTTRACE", "abort-normal-return", index=selected + 1)
elif action == "abort-prior":
    terminal = find("POSITIONOUTTRACE", "commit-runtime-exception")
    template = find("POSITIONOUTTRACE", "commit-entry", index=selected)
    insert_after(
        terminal,
        [
            output_row(template, "abort-entry", 0),
            output_row(template, "abort-normal-return", 0),
        ],
    )
elif action in {"altered-reports", "normal-reports"}:
    for event in ("cleanup-entry", "cleanup-normal-return"):
        row_index = find("POSITIONOUTTRACE", event)
        values = fields(row_index)
        baseline = count if action == "normal-reports" else selected
        values[7] = encoded(str(baseline + 1))
        traces[row_index] = "|".join(values)
elif action == "missing-terminal":
    remove("POSITIONOUTTRACE", "commit-runtime-exception")
elif action == "missing-pair":
    remove("POSITIONOUTTRACE", "close-normal-return", index=selected)
elif action == "wrong-payload":
    row_index = find("POSITIONOUTTRACE", "commit-runtime-exception")
    values = fields(row_index)
    values[-1] = encoded("changed")
    traces[row_index] = "|".join(values)
elif action == "wrong-class":
    row_index = find("POSITIONOUTTRACE", "commit-runtime-exception")
    values = fields(row_index)
    values[-2] = encoded("java.lang.RuntimeException")
    traces[row_index] = "|".join(values)
elif action == "wrong-outer-payload":
    for tag in ("POSITIONOUTTRACE", "FAILTRACE"):
        row_index = find(tag, "transaction-runtime-exception")
        values = fields(row_index)
        values[-1] = encoded("changed")
        traces[row_index] = "|".join(values)
elif action == "wrong-index":
    for event in ("commit-injection-before", "commit-runtime-exception"):
        row_index = find("POSITIONOUTTRACE", event)
        values = fields(row_index)
        values[5] = encoded(str(selected + 1))
        traces[row_index] = "|".join(values)
elif action in {"selection-index", "selection-mode"}:
    row_index = find("POSITIONOUTTRACE", "commit-selection")
    values = fields(row_index)
    if action == "selection-index":
        values[7] = encoded(str(selected + 1))
    else:
        values[6] = encoded("changed")
    traces[row_index] = "|".join(values)
elif action == "count":
    row_index = find("POSITIONOUTTRACE", "commit-selection")
    values = fields(row_index)
    values[5] = encoded(str(count + 1))
    traces[row_index] = "|".join(values)
elif action == "oversized-count":
    oversized = 1000000
    for event in (
        "transaction-entry",
        "control-run-before",
        "control-run-normal-return",
        "transaction-normal-return",
        "cleanup-entry",
        "cleanup-normal-return",
    ):
        for row_index, row in enumerate(traces):
            values = row.split("|")
            if (
                values[0] == "POSITIONOUTTRACE"
                and values[1] == fixture
                and values[4] == event
            ):
                values[5] = encoded(str(oversized))
                traces[row_index] = "|".join(values)
    row_index = find("POSITIONOUTTRACE", "commit-selection")
    values = fields(row_index)
    values[5] = encoded(str(oversized))
    values[7] = encoded(str(oversized - 1))
    traces[row_index] = "|".join(values)
elif action == "schema":
    row_index = find("POSITIONOUTTRACE", "transaction-entry")
    values = fields(row_index)
    values[6] = encoded("1")
    traces[row_index] = "|".join(values)
elif action == "scope-order":
    output_error = find("POSITIONOUTTRACE", "transaction-runtime-exception")
    input_error = find("FAILTRACE", "transaction-runtime-exception")
    traces[output_error], traces[input_error] = traces[input_error], traces[output_error]
elif action == "cleanup-order":
    entry = find("FAILTRACE", "cleanup-entry")
    returned = find("FAILTRACE", "cleanup-normal-return")
    pair_rows = [traces[entry], traces[returned]]
    for row_index in sorted((entry, returned), reverse=True):
        traces.pop(row_index)
    input_error = find("FAILTRACE", "transaction-runtime-exception")
    traces[input_error:input_error] = pair_rows
elif action == "missing-successful-commit":
    remove("POSITIONOUTTRACE", "commit-normal-return", index=0)
elif action == "missing-selected-abort":
    remove("POSITIONOUTTRACE", "abort-normal-return", index=selected)
elif action == "missing-selected-close":
    remove("POSITIONOUTTRACE", "close-normal-return", index=selected)
elif action == "normal-missing-commit":
    remove("POSITIONOUTTRACE", "commit-normal-return", index=0)
elif action == "reorder-input-boundary":
    before = find("FAILTRACE", "finish-before")
    returned = find("FAILTRACE", "finish-normal-return")
    row = traces.pop(before)
    if before < returned:
        returned -= 1
    traces.insert(returned + 1, row)
elif action == "reorder-selection-control":
    selection_row = find("POSITIONOUTTRACE", "commit-selection")
    control_row = find("POSITIONOUTTRACE", "control-run-before")
    traces[selection_row], traces[control_row] = traces[control_row], traces[selection_row]
elif action == "missing-case":
    cases.pop(0)
elif action == "duplicate-case":
    cases.append(cases[0])
elif action == "unknown-case":
    values = cases[0].split("|")
    values[1] = "unknown"
    cases[0] = "|".join(values)
elif action == "malformed-case":
    values = cases[0].split("|")
    cases[0] = "|".join(values[:-1])

def synchronize():
    for selected_fixture in ("normal", "commit-first", "commit-middle"):
        rows = [row for row in traces if row.split("|")[1] == selected_fixture]
        log = root / f"{selected_fixture}.raw.log"
        other = [
            line
            for line in log.read_text(encoding="utf-8").splitlines()
            if not line.startswith("FAILTRACE|")
            and not line.startswith("POSITIONOUTTRACE|")
        ]
        log.write_text("\n".join(rows + other) + "\n", encoding="utf-8")
        case_index = next(
            index
            for index, row in enumerate(cases)
            if row.startswith(f"POSITIONCASE|{selected_fixture}|")
        )
        values = cases[case_index].split("|")
        input_count = sum(row.startswith("FAILTRACE|") for row in rows)
        output_count = sum(row.startswith("POSITIONOUTTRACE|") for row in rows)
        digest = hashlib.sha256(("\n".join(rows) + "\n").encode()).hexdigest()
        values[4] = f"{len(rows)}:{input_count}:{output_count}:{digest}"
        cases[case_index] = "|".join(values)

if action == "hash":
    values = cases[0].split("|")
    summary = values[4].split(":")
    summary[3] = "0" * 64
    values[4] = ":".join(summary)
    cases[0] = "|".join(values)
elif action == "raw-log":
    log = root / f"{fixture}.raw.log"
    log.write_text(
        log.read_text(encoding="utf-8").replace("POSITIONOUTTRACE|", "BROKEN|", 1),
        encoding="utf-8",
    )
elif action not in {"missing-case", "duplicate-case", "unknown-case", "malformed-case"}:
    if action not in {"sequence", "capture"}:
        renumber(fixture)
    synchronize()

root.joinpath("cases.raw").write_text("\n".join(cases) + "\n", encoding="utf-8")
root.joinpath("traces.raw").write_text("\n".join(traces) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$copy"
}

validator_fails() {
  local reference=$1 fixture=$2 action=$3 expected=$4 copy result result_code
  copy=$(mutated_copy "$action" "$fixture" "$reference")
  printf 'T0013_S08_RAW_MUTATION=%s:%s|evidence=%s\n' \
    "$fixture" "$action" "$copy"
  if result=$("$driver" --validate-only "$copy" --manifest "$copy/rejected.tsv" 2>&1); then
    printf 'mutation unexpectedly accepted: %s:%s\n' "$fixture" "$action" >&2
    exit 1
  else
    result_code=$?
  fi
  [[ "$result_code" == 4 ]]
  [[ "$result" == "T0013/S08 driver rejected evidence: $expected" ]] || {
    printf 'unexpected validator result for %s:%s: %s\n' \
      "$fixture" "$action" "$result" >&2
    exit 1
  }
}

run_stage_b_controls() {
  local reference=$1 fixture
  validator_fails "$reference" normal missing-case case-count
  validator_fails "$reference" normal duplicate-case case-count
  validator_fails "$reference" normal unknown-case case-fixture
  validator_fails "$reference" normal malformed-case case-arity
  validator_fails "$reference" normal missing-event open-return-indexes
  validator_fails "$reference" normal duplicate-event input-callback-manifest
  validator_fails "$reference" normal unknown-event output-event-known
  validator_fails "$reference" normal malformed-event output-canonical-field
  validator_fails "$reference" normal sequence output-sequence-contiguous
  validator_fails "$reference" normal capture capture-id
  validator_fails "$reference" normal hash case-digest-match
  validator_fails "$reference" normal raw-log raw-log-trace-match
  validator_fails "$reference" normal normal-reports normal-report-counts
  validator_fails "$reference" normal normal-missing-commit commit-return-indexes
  validator_fails "$reference" normal reorder-input-boundary input-main-chain-order
  validator_fails "$reference" normal reorder-selection-control output-main-chain-order
  validator_fails "$reference" normal oversized-count output-task-cap
  for fixture in commit-first commit-middle; do
    validator_fails "$reference" "$fixture" fabricated-later-commit failure-commit-entry-indexes
    validator_fails "$reference" "$fixture" missing-later-abort abort-return-indexes
    validator_fails "$reference" "$fixture" altered-reports failure-report-counts
    validator_fails "$reference" "$fixture" missing-terminal selected-local-injection
    validator_fails "$reference" "$fixture" missing-pair close-return-indexes
    validator_fails "$reference" "$fixture" wrong-payload selected-injection-payload
    validator_fails "$reference" "$fixture" wrong-class selected-injection-payload
    validator_fails "$reference" "$fixture" wrong-outer-payload failure-outer-error-payload
    validator_fails "$reference" "$fixture" wrong-index selected-injection-index
    validator_fails "$reference" "$fixture" selection-index selection-fields
    validator_fails "$reference" "$fixture" selection-mode selection-fields
    validator_fails "$reference" "$fixture" count selection-fields
    validator_fails "$reference" "$fixture" schema empty-output-schema
    validator_fails "$reference" "$fixture" scope-order failure-scope-order
    validator_fails "$reference" "$fixture" cleanup-order cleanup-physical-order
    validator_fails "$reference" "$fixture" missing-selected-abort abort-return-indexes
    validator_fails "$reference" "$fixture" missing-selected-close close-return-indexes
    validator_fails "$reference" "$fixture" reorder-input-boundary input-main-chain-order
    validator_fails "$reference" "$fixture" reorder-selection-control output-main-chain-order
  done
  validator_fails "$reference" commit-middle abort-prior abort-entry-indexes
  validator_fails "$reference" commit-middle missing-successful-commit failure-commit-return-indexes
}

run_stage_b_controls "$reference"

T0013_S08_MANIFEST="$evidence_dir/live.tsv" cargo test --manifest-path "$root/Cargo.toml" \
  -p emburk-core \
  empty_lifecycle::tests::output_commit_position_differential_tests::live_output_commit_position_differential \
  -- --ignored --exact > "$evidence_dir/live-rust-test.log" 2>&1
grep -Fqx 'test empty_lifecycle::tests::output_commit_position_differential_tests::live_output_commit_position_differential ... ok' \
  "$evidence_dir/live-rust-test.log"
grep -Eq '^test result: ok\. 1 passed; 0 failed; 0 ignored; .* filtered out;' \
  "$evidence_dir/live-rust-test.log"
printf '%s\n' 'T0013_S08_COMPARED_CASES=3'
printf 'T0013/S08: compared exactly 3 live output-commit position projections; raw and Rust controls passed|evidence=%s\n' "$evidence_dir"

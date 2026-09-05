#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0013-output-commit-failure/run.sh"
[[ -x "$runner" ]] || exit 2

run_artifact_negative() {
  local control=$1 expected=$2 label=$3 output result_code evidence
  if output=$(T0013_COMMIT_NEGATIVE="$control" "$runner" 2>&1); then
    exit 1
  else
    result_code=$?
  fi
  [[ "$result_code" == "$expected" ]] || exit 1
  evidence=$(printf '%s\n' "$output" | sed -n 's/^T0013_COMMIT_EVIDENCE_DIR=//p' | tail -1)
  [[ -n "$evidence" && -d "$evidence" ]] || exit 1
  grep -Fqx "$label" "$evidence/negative-control.txt" || exit 1
  printf 'T0013_COMMIT_NEGATIVE=%s|exit=%s|evidence=%s\n' "$control" "$result_code" "$evidence"
}

run_artifact_negative corrupt-copy 3 corrupt-copy-injected
run_artifact_negative unavailable-asset 56 unavailable-asset-request-failed

output=$("$runner")
printf '%s\n' "$output"
evidence=$(printf '%s\n' "$output" | sed -n 's/^T0013_COMMIT_EVIDENCE_DIR=//p' | tail -1)
[[ -n "$evidence" && -d "$evidence" ]] || exit 1
for file in executable.sha256 executable-url.txt LICENSE-executable NOTICE-executable java-version.txt \
  input-source.sha256 input-source-path.txt output-source.sha256 output-source-vs-s03.diff \
  input-jar.sha256 output-jar.sha256 input-coordinate.txt output-coordinate.txt \
  cases.raw traces.raw normal.raw.log commit-failure.raw.log; do
  [[ -s "$evidence/$file" ]] || exit 1
done
expected_input_sha=$(shasum -a 256 "$root/tools/t0013-input-failure/src/T0013FailureInputPlugin.java" | awk '{print $1}')
grep -Fqx "$expected_input_sha" "$evidence/input-source.sha256"
grep -Fqx 'tools/t0013-input-failure/src/T0013FailureInputPlugin.java' "$evidence/input-source-path.txt"

validate() {
  python3 - "$1" <<'PY'
import base64
import binascii
import hashlib
import pathlib
import sys
import uuid

root = pathlib.Path(sys.argv[1])
fixtures = ("normal", "commit-failure")
injected_class = "T0013CommitFailureOutputPlugin$InjectedCommitFailure"
injected_message = "t0013-output-commit-failure"

class InvalidEvidence(Exception):
    pass

def require(label, condition):
    if not condition:
        raise InvalidEvidence(label)

def decimal(label, value):
    require(label, value and value.isascii() and value.isdigit())
    return int(value)

def decode(label, value, *, numeric=False, nonempty=False):
    require(label, value != "-")
    try:
        raw = base64.b64decode(value, validate=True)
        text = raw.decode("utf-8")
    except (binascii.Error, UnicodeDecodeError):
        raise InvalidEvidence(label)
    require(label, base64.b64encode(raw).decode("ascii") == value)
    if numeric:
        decimal(label, text)
    if nonempty:
        require(label, text != "")
    return text

input_arity = {
    "transaction-entry": 1, "control-run-before": 1, "control-run-normal-return": 1,
    "transaction-normal-return": 1, "transaction-runtime-exception": 2,
    "run-entry": 1, "injection-before": 1, "finish-before": 1,
    "finish-normal-return": 1, "run-normal-return": 1, "run-runtime-exception": 2,
    "cleanup-entry": 2, "cleanup-normal-return": 1, "resume-entry": 1,
    "resume-normal-return": 1, "guess-entry": 0, "guess-normal-return": 0,
}
input_numeric = {
    "transaction-entry": {0}, "control-run-before": {0}, "control-run-normal-return": {0},
    "transaction-normal-return": {0}, "run-entry": {0}, "injection-before": {0},
    "finish-before": {0}, "finish-normal-return": {0}, "run-normal-return": {0},
    "cleanup-entry": {0, 1}, "cleanup-normal-return": {0}, "resume-entry": {0},
    "resume-normal-return": {0},
}
output_arity = {
    "transaction-entry": 2, "commit-selection": 2, "control-run-before": 2,
    "control-run-normal-return": 3, "transaction-normal-return": 3,
    "transaction-runtime-exception": 2, "resume-entry": 2,
    "resume-control-run-before": 2, "resume-control-run-normal-return": 3,
    "resume-normal-return": 3, "resume-runtime-exception": 2,
    "cleanup-entry": 3, "cleanup-normal-return": 3,
    "open-entry": 2, "open-normal-return": 2, "add-entry": 2,
    "add-normal-return": 2, "finish-entry": 2, "finish-normal-return": 2,
    "commit-entry": 2, "commit-injection-before": 2,
    "commit-normal-return": 2, "commit-runtime-exception": 4,
    "abort-entry": 2, "abort-normal-return": 2,
    "close-entry": 2, "close-normal-return": 2,
}
output_numeric = {event: set(range(arity)) for event, arity in output_arity.items()
                  if not event.endswith("runtime-exception")}
output_numeric["commit-runtime-exception"] = {0, 1}

def only(rows, component, event, label):
    found = [row for row in rows if row[0] == component and row[1] == event]
    require(label, len(found) == 1)
    return found[0]

def positions(rows, component, event):
    return [row[5] for row in rows if row[0] == component and row[1] == event]

try:
    case_lines = root.joinpath("cases.raw").read_text(encoding="utf-8").splitlines()
    trace_lines = root.joinpath("traces.raw").read_text(encoding="utf-8").splitlines()
    require("case-count", len(case_lines) == 2)
    cases = {}
    for expected_fixture, line in zip(fixtures, case_lines, strict=True):
        fields = line.split("|")
        require("case-arity", len(fields) == 5 and fields[0] == "COMMITCASE")
        _, fixture, requested_text, exit_text, summary = fields
        require("case-fixture", fixture == expected_fixture and fixture not in cases)
        values = summary.split(":")
        require("case-summary-arity", len(values) == 4)
        total, input_count, output_count = [decimal("case-count-field", value) for value in values[:3]]
        digest = values[3]
        require("case-digest-format", len(digest) == 64 and all(char in "0123456789abcdef" for char in digest))
        cases[fixture] = (decimal("requested-count", requested_text), decimal("process-exit", exit_text),
                          total, input_count, output_count, digest)
    require("requested-count", all(case[0] == 1 for case in cases.values()))

    grouped = {fixture: [] for fixture in fixtures}
    decoded = {fixture: [] for fixture in fixtures}
    sequences = {}
    for physical, line in enumerate(trace_lines):
        fields = line.split("|")
        require("trace-minimum-arity", len(fields) >= 5)
        tag, fixture, capture, sequence_text, event = fields[:5]
        require("trace-component", tag in {"FAILTRACE", "COMMITOUTTRACE"})
        require("trace-fixture", fixture in grouped)
        try:
            parsed_capture = uuid.UUID(capture)
        except ValueError:
            raise InvalidEvidence("capture-id")
        require("capture-id", str(parsed_capture) == capture and parsed_capture.version == 4)
        component = "input" if tag == "FAILTRACE" else "output"
        sequence = decimal("capture-sequence", sequence_text)
        key = (fixture, component, capture)
        require(f"{component}-sequence-contiguous", sequence == sequences.get(key, 0) + 1)
        sequences[key] = sequence
        grammar = input_arity if component == "input" else output_arity
        numeric = input_numeric if component == "input" else output_numeric
        require(f"{component}-event-known", event in grammar)
        require(f"{component}-event-arity", len(fields) == 5 + grammar[event])
        values = []
        for index, encoded in enumerate(fields[5:]):
            if encoded == "-":
                is_message = event.endswith("runtime-exception") and index == grammar[event] - 1
                require(f"{component}-null-position", is_message)
                values.append(None)
            else:
                exception_field = event.endswith("runtime-exception") and index >= grammar[event] - 2
                values.append(decode(f"{component}-canonical-field", encoded,
                                     numeric=index in numeric.get(event, set()),
                                     nonempty=exception_field and index == grammar[event] - 2))
        require("unexpected-callback", not (event.startswith("resume") or event.startswith("guess")
                                             or event.startswith("add")))
        grouped[fixture].append(line)
        decoded[fixture].append((component, event, values, capture, sequence, physical))

    for fixture in fixtures:
        requested, process_exit, total, input_count, output_count, digest = cases[fixture]
        raw_rows = grouped[fixture]
        require("case-total-count-match", len(raw_rows) == total)
        require("case-component-count-match",
                sum(row.startswith("FAILTRACE|") for row in raw_rows) == input_count
                and sum(row.startswith("COMMITOUTTRACE|") for row in raw_rows) == output_count
                and input_count + output_count == total)
        material = ("\n".join(raw_rows) + "\n").encode("utf-8")
        require("case-digest-match", hashlib.sha256(material).hexdigest() == digest)
        raw_log = root / f"{fixture}.raw.log"
        require("raw-log-required", raw_log.is_file())
        extracted = [line for line in raw_log.read_text(encoding="utf-8").splitlines()
                     if line.startswith("FAILTRACE|") or line.startswith("COMMITOUTTRACE|")]
        require("raw-log-trace-match", extracted == raw_rows)

        rows = decoded[fixture]
        input_transaction = only(rows, "input", "transaction-entry", "input-transaction-entry")
        output_transaction = only(rows, "output", "transaction-entry", "output-transaction-entry")
        selection = only(rows, "output", "commit-selection", "commit-selection")
        input_main_capture = input_transaction[3]
        output_main_capture = output_transaction[3]
        task_count = decimal("output-task-count", output_transaction[2][0])
        schema_count = decimal("output-schema-count", output_transaction[2][1])
        require("positive-output-task-count", task_count > 0)
        require("bounded-output-task-count", task_count <= len(rows))
        require("empty-output-schema", schema_count == 0)
        selected = decimal("selected-index", selection[2][1])
        require("selection-count", decimal("selection-count", selection[2][0]) == task_count)
        require("selection-index", selected == task_count - 1)
        require("selection-capture", selection[3] == output_main_capture)
        output_chain = ["transaction-entry", "commit-selection", "control-run-before"]
        output_chain += (["control-run-normal-return", "transaction-normal-return"]
                         if fixture == "normal" else ["transaction-runtime-exception"])
        output_chain_rows = [only(rows, "output", event, f"output-{event}") for event in output_chain]
        require("output-main-capture", all(row[3] == output_main_capture for row in output_chain_rows))
        require("output-main-order", [row[4] for row in output_chain_rows]
                == sorted(row[4] for row in output_chain_rows))

        indexed = {"open-entry", "open-normal-return", "finish-entry", "finish-normal-return",
                   "commit-entry", "commit-injection-before", "commit-normal-return",
                   "commit-runtime-exception", "abort-entry", "abort-normal-return",
                   "close-entry", "close-normal-return"}
        counted = {"transaction-entry", "control-run-before", "control-run-normal-return",
                   "transaction-normal-return", "cleanup-entry", "cleanup-normal-return"}
        for component, event, values, capture, sequence, physical in rows:
            if component == "input" and event in {"transaction-entry", "control-run-before",
                    "control-run-normal-return", "transaction-normal-return", "cleanup-entry",
                    "cleanup-normal-return"}:
                require("input-count-consistency", decimal("input-count", values[0]) == requested)
            if component == "input" and event in {"run-entry", "finish-before", "finish-normal-return",
                                                   "run-normal-return", "injection-before"}:
                require("input-index", decimal("input-index", values[0]) == 0)
            if component == "output" and event in indexed:
                require("output-index-range", decimal("output-index", values[0]) < task_count)
                require("output-schema-consistency", decimal("output-schema", values[1]) == schema_count)
            if component == "output" and event in counted:
                require("output-count-consistency", decimal("output-count", values[0]) == task_count)
                require("output-schema-consistency", decimal("output-schema", values[1]) == schema_count)

        expected_indices = set(range(task_count))
        opened = {}
        for row in rows:
            component, event, values, capture, sequence, physical = row
            if component != "output" or event not in indexed:
                continue
            index = decimal("output-index", values[0])
            key = (capture, index)
            if event == "open-normal-return":
                opened[key] = sequence
            elif not event.startswith("open"):
                require("output-prior-open", key in opened and opened[key] < sequence)

        def pair(event, indices):
            entries = [row for row in rows if row[0] == "output" and row[1] == f"{event}-entry"]
            returns = [row for row in rows if row[0] == "output" and row[1] == f"{event}-normal-return"]
            require(f"{event}-entry-indexes", len(entries) == len(indices)
                    and {decimal("pair-index", row[2][0]) for row in entries} == indices)
            require(f"{event}-return-indexes", len(returns) == len(indices)
                    and {decimal("pair-index", row[2][0]) for row in returns} == indices)
            for entry in entries:
                index = decimal("pair-index", entry[2][0])
                returned = next(row for row in returns if decimal("pair-index", row[2][0]) == index)
                require(f"{event}-callback-pair", entry[2] == returned[2]
                        and entry[3] == returned[3] and entry[4] < returned[4])

        pair("open", expected_indices)
        pair("finish", expected_indices)
        pair("close", expected_indices)
        for component in ("input", "output"):
            cleanup_entry = only(rows, component, "cleanup-entry", f"{component}-cleanup-entry")
            cleanup_return = only(rows, component, "cleanup-normal-return", f"{component}-cleanup-return")
            require(f"{component}-cleanup-pair", cleanup_entry[3] == cleanup_return[3]
                    and cleanup_entry[4] < cleanup_return[4])
            if component == "output":
                require("output-cleanup-fields", cleanup_entry[2] == cleanup_return[2])

        input_required = {"transaction-entry", "control-run-before", "run-entry", "finish-before",
                          "finish-normal-return", "run-normal-return", "cleanup-entry", "cleanup-normal-return"}
        input_names = [row[1] for row in rows if row[0] == "input"]
        output_names = [row[1] for row in rows if row[0] == "output"]
        require("input-failure-branch-inactive", "injection-before" not in input_names
                and "run-runtime-exception" not in input_names)
        require("input-required", input_required.issubset(input_names))
        require("input-singletons", all(input_names.count(name) == 1 for name in input_required))
        input_chain = ["transaction-entry", "control-run-before", "run-entry", "finish-before",
                       "finish-normal-return", "run-normal-return"]
        input_chain += (["control-run-normal-return", "transaction-normal-return"]
                        if fixture == "normal" else ["transaction-runtime-exception"])
        input_chain_rows = [only(rows, "input", event, f"input-{event}") for event in input_chain]
        require("input-main-capture", all(row[3] == input_main_capture for row in input_chain_rows))
        require("input-main-order", [row[4] for row in input_chain_rows]
                == sorted(row[4] for row in input_chain_rows))
        commit_entry_positions = positions(rows, "output", "commit-entry")
        require("commit-entry-required", bool(commit_entry_positions))
        require("input-finish-before-commit", only(rows, "input", "run-normal-return", "input-run-return")[5]
                < min(commit_entry_positions))
        input_run_position = only(rows, "input", "run-entry", "input-run-entry")[5]
        input_finish_before = only(rows, "input", "finish-before", "input-finish-before")[5]
        input_finish_return = only(rows, "input", "finish-normal-return", "input-finish-return")[5]
        require("open-before-input-run", max(positions(rows, "output", "open-normal-return"))
                < input_run_position)
        require("output-control-before-open", only(rows, "output", "control-run-before",
                "output-control-before")[5] < min(positions(rows, "output", "open-entry")))
        require("output-finish-inside-input-finish", input_finish_before
                < min(positions(rows, "output", "finish-entry"))
                and max(positions(rows, "output", "finish-normal-return")) < input_finish_return)

        if fixture == "normal":
            require("normal-process-success", process_exit == 0)
            require("normal-no-exception", not any(name.endswith("runtime-exception") for name in input_names + output_names))
            require("normal-no-injection", "commit-injection-before" not in output_names)
            pair("commit", expected_indices)
            pair("abort", set())
            require("normal-output-scope", output_names.count("control-run-normal-return") == 1
                    and output_names.count("transaction-normal-return") == 1)
            require("normal-input-scope", input_names.count("control-run-normal-return") == 1
                    and input_names.count("transaction-normal-return") == 1)
            output_reports = only(rows, "output", "cleanup-entry", "output-cleanup-entry")[2][2]
            input_reports = only(rows, "input", "cleanup-entry", "input-cleanup-entry")[2][1]
            require("normal-cleanup-reports", decimal("input-reports", input_reports) == 1
                    and decimal("output-reports", output_reports) == task_count)
            require("normal-control-reports",
                    decimal("control-reports", only(rows, "output", "control-run-normal-return",
                            "output-control-return")[2][2]) == task_count
                    and decimal("transaction-reports", only(rows, "output", "transaction-normal-return",
                            "output-transaction-return")[2][2]) == task_count)
            require("normal-close-after-commit",
                    max(positions(rows, "output", "commit-normal-return"))
                    < min(positions(rows, "output", "close-entry")))
            output_scope = only(rows, "output", "transaction-normal-return", "output-scope-return")
            output_control = only(rows, "output", "control-run-normal-return", "output-control-return-order")
            input_control = only(rows, "input", "control-run-normal-return", "input-control-return")
            input_scope = only(rows, "input", "transaction-normal-return", "input-scope-return")
            require("normal-scope-physical-order",
                    max(positions(rows, "output", "close-normal-return")) < output_control[5]
                    < output_scope[5] < input_control[5] < input_scope[5])
        else:
            require("failure-process-nonzero", process_exit != 0)
            require("failure-no-normal-scopes", "control-run-normal-return" not in input_names
                    and "transaction-normal-return" not in input_names
                    and "control-run-normal-return" not in output_names
                    and "transaction-normal-return" not in output_names)
            injection = only(rows, "output", "commit-injection-before", "failure-injection")
            commit_failure = only(rows, "output", "commit-runtime-exception", "commit-exception")
            require("failure-selected-index", decimal("injection-index", injection[2][0]) == selected
                    and decimal("exception-index", commit_failure[2][0]) == selected)
            require("failure-exact-error", commit_failure[2][2:] == [injected_class, injected_message])
            commit_entries = [decimal("commit-index", row[2][0]) for row in rows
                              if row[0] == "output" and row[1] == "commit-entry"]
            commit_returns = [decimal("commit-index", row[2][0]) for row in rows
                              if row[0] == "output" and row[1] == "commit-normal-return"]
            require("failure-commit-entries", len(commit_entries) == task_count and set(commit_entries) == expected_indices)
            require("failure-other-commit-returns", len(commit_returns) == task_count - 1
                    and set(commit_returns) == expected_indices - {selected})
            require("failure-selected-no-normal-return", selected not in commit_returns)
            for index in expected_indices - {selected}:
                entries = [row for row in rows if row[0] == "output" and row[1] == "commit-entry"
                           and decimal("commit-index", row[2][0]) == index]
                returns = [row for row in rows if row[0] == "output" and row[1] == "commit-normal-return"
                           and decimal("commit-index", row[2][0]) == index]
                require("failure-other-commit-pair", len(entries) == 1 and len(returns) == 1
                        and entries[0][2] == returns[0][2] and entries[0][3] == returns[0][3]
                        and entries[0][4] < returns[0][4])
            commit_entry = next(row for row in rows if row[0] == "output" and row[1] == "commit-entry"
                                and decimal("commit-index", row[2][0]) == selected)
            require("failure-commit-terminal", commit_entry[3] == injection[3] == commit_failure[3]
                    and commit_entry[4] < injection[4] < commit_failure[4])
            pair("abort", {selected})
            output_error = only(rows, "output", "transaction-runtime-exception", "output-transaction-error")
            input_error = only(rows, "input", "transaction-runtime-exception", "input-transaction-error")
            require("failure-outer-errors", output_error[2] == [injected_class, injected_message]
                    and input_error[2] == [injected_class, injected_message])
            require("failure-physical-order", commit_failure[5]
                    < only(rows, "output", "abort-entry", "abort-entry")[5]
                    < only(rows, "output", "abort-normal-return", "abort-return")[5]
                    < min(positions(rows, "output", "close-entry"))
                    and max(positions(rows, "output", "close-normal-return")) < output_error[5] < input_error[5])
            input_cleanup = only(rows, "input", "cleanup-entry", "input-cleanup-entry")
            output_cleanup = only(rows, "output", "cleanup-entry", "output-cleanup-entry")
            require("failure-fresh-cleanup-captures", input_cleanup[3] != input_main_capture
                    and output_cleanup[3] != output_main_capture)
            require("failure-cleanup-reports", decimal("input-reports", input_cleanup[2][1]) == 1
                    and decimal("output-reports", output_cleanup[2][2]) == task_count - 1)
            successful_commit_positions = positions(rows, "output", "commit-normal-return")
            require("failure-other-commits-before-selected", not successful_commit_positions
                    or max(successful_commit_positions) < commit_entry[5])
            output_scope, input_scope = output_error, input_error
        input_cleanup = only(rows, "input", "cleanup-entry", "input-cleanup-order")
        input_cleanup_return = only(rows, "input", "cleanup-normal-return", "input-cleanup-return-order")
        output_cleanup = only(rows, "output", "cleanup-entry", "output-cleanup-order")
        output_cleanup_return = only(rows, "output", "cleanup-normal-return", "output-cleanup-return-order")
        require("cleanup-physical-order", output_scope[5] < input_scope[5] < input_cleanup[5]
                < input_cleanup_return[5] < output_cleanup[5] < output_cleanup_return[5])
except (InvalidEvidence, OSError, UnicodeError) as error:
    label = error.args[0] if error.args else "unclassified"
    print(f"VALIDATION_ERROR|{label}", file=sys.stderr)
    sys.exit(4)
PY
}

validate "$evidence"

mutated_copy() {
  local mutation=$1 copy
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-commit-validator.XXXXXX")
  cp "$evidence/cases.raw" "$evidence/traces.raw" "$evidence/normal.raw.log" \
    "$evidence/commit-failure.raw.log" "$copy/"
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
else:
    synchronize()

root.joinpath("cases.raw").write_text("\n".join(cases) + "\n", encoding="utf-8")
root.joinpath("traces.raw").write_text("\n".join(traces) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$copy"
}

validator_fails() {
  local mutation=$1 expected=$2 copy result result_code
  copy=$(mutated_copy "$mutation")
  printf 'T0013_COMMIT_MUTATION=%s|evidence=%s\n' "$mutation" "$copy"
  if result=$(validate "$copy" 2>&1); then
    exit 1
  else
    result_code=$?
  fi
  [[ "$result_code" == 4 ]] || exit 1
  [[ "$result" == "VALIDATION_ERROR|$expected" ]] || {
    printf 'unexpected validator result for %s: %s\n' "$mutation" "$result" >&2
    exit 1
  }
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

printf 'T0013_COMMIT_FULL_PROBE=passed|evidence=%s\n' "$evidence"

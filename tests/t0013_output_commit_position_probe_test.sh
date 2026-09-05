#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0013-output-commit-position-probe/run.sh"
[[ -x "$runner" ]] || exit 2

run_artifact_negative() {
  local control=$1 expected=$2 label=$3 output result_code evidence
  if output=$(T0013_POSITION_NEGATIVE="$control" "$runner" 2>&1); then
    exit 1
  else
    result_code=$?
  fi
  [[ "$result_code" == "$expected" ]] || exit 1
  evidence=$(printf '%s\n' "$output" \
    | sed -n 's/^T0013_POSITION_EVIDENCE_DIR=//p' | tail -1)
  [[ -n "$evidence" && -d "$evidence" ]] || exit 1
  grep -Fqx "$label" "$evidence/negative-control.txt"
  printf 'T0013_POSITION_NEGATIVE=%s|exit=%s|evidence=%s\n' \
    "$control" "$result_code" "$evidence"
}

run_artifact_controls() {
  run_artifact_negative corrupt-copy 3 corrupt-copy-injected
  run_artifact_negative unavailable-asset 56 unavailable-asset-request-failed
  printf '%s\n' 'T0013_POSITION_ARTIFACT_CONTROLS=passed'
}

validate_capture() {
  python3 - "$1" "$2" <<'PY'
import base64
import binascii
import hashlib
import pathlib
import sys
import uuid

root = pathlib.Path(sys.argv[1])
stage = sys.argv[2]
if stage not in {"capture", "full"}:
    raise SystemExit(2)
fixtures = ("normal", "commit-first", "commit-middle")
injected_class = "T0013CommitPositionOutputPlugin$InjectedCommitFailure"
injected_message = "t0013-output-commit-position-failure"

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
    "transaction-entry": 1,
    "control-run-before": 1,
    "control-run-normal-return": 1,
    "transaction-normal-return": 1,
    "transaction-runtime-exception": 2,
    "run-entry": 1,
    "injection-before": 1,
    "finish-before": 1,
    "finish-normal-return": 1,
    "run-normal-return": 1,
    "run-runtime-exception": 2,
    "cleanup-entry": 2,
    "cleanup-normal-return": 1,
    "resume-entry": 1,
    "resume-normal-return": 1,
    "guess-entry": 0,
    "guess-normal-return": 0,
}
input_numeric = {
    "transaction-entry": {0},
    "control-run-before": {0},
    "control-run-normal-return": {0},
    "transaction-normal-return": {0},
    "run-entry": {0},
    "injection-before": {0},
    "finish-before": {0},
    "finish-normal-return": {0},
    "run-normal-return": {0},
    "cleanup-entry": {0, 1},
    "cleanup-normal-return": {0},
    "resume-entry": {0},
    "resume-normal-return": {0},
}
output_arity = {
    "transaction-entry": 2,
    "commit-selection": 3,
    "control-run-before": 2,
    "control-run-normal-return": 3,
    "transaction-normal-return": 3,
    "transaction-runtime-exception": 2,
    "resume-entry": 2,
    "resume-control-run-before": 2,
    "resume-control-run-normal-return": 3,
    "resume-normal-return": 3,
    "resume-runtime-exception": 2,
    "cleanup-entry": 3,
    "cleanup-normal-return": 3,
    "open-entry": 2,
    "open-normal-return": 2,
    "add-entry": 2,
    "add-normal-return": 2,
    "finish-entry": 2,
    "finish-normal-return": 2,
    "commit-entry": 2,
    "commit-injection-before": 2,
    "commit-normal-return": 2,
    "commit-runtime-exception": 4,
    "abort-entry": 2,
    "abort-normal-return": 2,
    "close-entry": 2,
    "close-normal-return": 2,
}
output_numeric = {
    event: set(range(arity))
    for event, arity in output_arity.items()
    if not event.endswith("runtime-exception")
}
output_numeric["commit-selection"] = {0, 2}
output_numeric["commit-runtime-exception"] = {0, 1}

def only(rows, component, event, label):
    found = [row for row in rows if row[0] == component and row[1] == event]
    require(label, len(found) == 1)
    return found[0]

def positions(rows, component, event):
    return [row[5] for row in rows if row[0] == component and row[1] == event]

def indexed_rows(rows, event):
    return [
        row for row in rows
        if row[0] == "output" and row[1] == event
    ]

def pair(rows, event, indices):
    entries = indexed_rows(rows, f"{event}-entry")
    returns = indexed_rows(rows, f"{event}-normal-return")
    require(
        f"{event}-entry-indexes",
        len(entries) == len(indices)
        and {decimal("pair-index", row[2][0]) for row in entries} == indices,
    )
    require(
        f"{event}-return-indexes",
        len(returns) == len(indices)
        and {decimal("pair-index", row[2][0]) for row in returns} == indices,
    )
    for entry in entries:
        index = decimal("pair-index", entry[2][0])
        returned = next(
            row
            for row in returns
            if decimal("pair-index", row[2][0]) == index
        )
        require(
            f"{event}-callback-pair",
            entry[2] == returned[2]
            and entry[3] == returned[3]
            and entry[4] < returned[4],
        )

try:
    case_lines = root.joinpath("cases.raw").read_text(encoding="utf-8").splitlines()
    trace_lines = root.joinpath("traces.raw").read_text(encoding="utf-8").splitlines()
    require("case-count", len(case_lines) == 3)
    cases = {}
    for expected_fixture, line in zip(fixtures, case_lines, strict=True):
        fields = line.split("|")
        require(
            "case-arity",
            len(fields) == 5 and fields[0] == "POSITIONCASE",
        )
        _, fixture, requested_text, exit_text, summary = fields
        require(
            "case-fixture",
            fixture == expected_fixture and fixture not in cases,
        )
        values = summary.split(":")
        require("case-summary-arity", len(values) == 4)
        total, input_count, output_count = [
            decimal("case-count-field", value) for value in values[:3]
        ]
        digest = values[3]
        require(
            "case-digest-format",
            len(digest) == 64
            and all(char in "0123456789abcdef" for char in digest),
        )
        cases[fixture] = (
            decimal("requested-count", requested_text),
            decimal("process-exit", exit_text),
            total,
            input_count,
            output_count,
            digest,
        )
    require("requested-count", all(case[0] == 1 for case in cases.values()))

    grouped = {fixture: [] for fixture in fixtures}
    decoded = {fixture: [] for fixture in fixtures}
    sequences = {}
    for physical, line in enumerate(trace_lines):
        fields = line.split("|")
        require("trace-minimum-arity", len(fields) >= 5)
        tag, fixture, capture, sequence_text, event = fields[:5]
        require("trace-component", tag in {"FAILTRACE", "POSITIONOUTTRACE"})
        require("trace-fixture", fixture in grouped)
        try:
            parsed_capture = uuid.UUID(capture)
        except ValueError:
            raise InvalidEvidence("capture-id")
        require(
            "capture-id",
            str(parsed_capture) == capture and parsed_capture.version == 4,
        )
        component = "input" if tag == "FAILTRACE" else "output"
        sequence = decimal("capture-sequence", sequence_text)
        key = (fixture, component, capture)
        require(
            f"{component}-sequence-contiguous",
            sequence == sequences.get(key, 0) + 1,
        )
        sequences[key] = sequence
        grammar = input_arity if component == "input" else output_arity
        numeric = input_numeric if component == "input" else output_numeric
        require(f"{component}-event-known", event in grammar)
        require(f"{component}-event-arity", len(fields) == 5 + grammar[event])
        values = []
        for index, encoded in enumerate(fields[5:]):
            if encoded == "-":
                is_message = (
                    event.endswith("runtime-exception")
                    and index == grammar[event] - 1
                )
                require(f"{component}-null-position", is_message)
                values.append(None)
            else:
                exception_field = (
                    event.endswith("runtime-exception")
                    and index >= grammar[event] - 2
                )
                values.append(
                    decode(
                        f"{component}-canonical-field",
                        encoded,
                        numeric=index in numeric.get(event, set()),
                        nonempty=exception_field
                        and index == grammar[event] - 2,
                    )
                )
        grouped[fixture].append(line)
        decoded[fixture].append(
            (component, event, values, capture, sequence, physical)
        )

    for fixture in fixtures:
        requested, process_exit, total, input_count, output_count, digest = (
            cases[fixture]
        )
        raw_rows = grouped[fixture]
        require("case-total-count-match", len(raw_rows) == total)
        require(
            "case-component-count-match",
            sum(row.startswith("FAILTRACE|") for row in raw_rows)
            == input_count
            and sum(row.startswith("POSITIONOUTTRACE|") for row in raw_rows)
            == output_count
            and input_count + output_count == total,
        )
        material = ("\n".join(raw_rows) + "\n").encode("utf-8")
        require(
            "case-digest-match",
            hashlib.sha256(material).hexdigest() == digest,
        )
        raw_log = root / f"{fixture}.raw.log"
        require("raw-log-required", raw_log.is_file())
        extracted = [
            line
            for line in raw_log.read_text(encoding="utf-8").splitlines()
            if line.startswith("FAILTRACE|")
            or line.startswith("POSITIONOUTTRACE|")
        ]
        require("raw-log-trace-match", extracted == raw_rows)

        rows = decoded[fixture]
        input_names = [row[1] for row in rows if row[0] == "input"]
        output_names = [row[1] for row in rows if row[0] == "output"]
        require(
            "input-failure-branch-inactive",
            "injection-before" not in input_names
            and "run-runtime-exception" not in input_names,
        )
        require(
            "unexpected-input-callback",
            not any(name.startswith(("resume", "guess")) for name in input_names),
        )
        require(
            "unexpected-output-callback",
            not any(name.startswith(("resume", "add")) for name in output_names),
        )

        input_transaction = only(
            rows, "input", "transaction-entry", "input-transaction-entry"
        )
        output_transaction = only(
            rows, "output", "transaction-entry", "output-transaction-entry"
        )
        selection = only(rows, "output", "commit-selection", "commit-selection")
        require("input-main-request", decimal("input-count", input_transaction[2][0]) == requested)
        task_count = decimal("output-task-count", output_transaction[2][0])
        schema_count = decimal("output-schema-count", output_transaction[2][1])
        require("distinguishable-output-task-count", task_count >= 3)
        require("empty-output-schema", schema_count == 0)
        expected_mode = {
            "normal": "normal",
            "commit-first": "first",
            "commit-middle": "middle",
        }[fixture]
        expected_index = {
            "normal": task_count - 1,
            "commit-first": 0,
            "commit-middle": task_count // 2,
        }[fixture]
        require(
            "selection-fields",
            decimal("selection-count", selection[2][0]) == task_count
            and selection[2][1] == expected_mode
            and decimal("selection-index", selection[2][2]) == expected_index,
        )
        require(
            "selection-capture",
            selection[3] == output_transaction[3]
            and output_transaction[4] < selection[4],
        )

        indexed_events = {
            "open-entry",
            "open-normal-return",
            "finish-entry",
            "finish-normal-return",
            "commit-entry",
            "commit-injection-before",
            "commit-normal-return",
            "commit-runtime-exception",
            "abort-entry",
            "abort-normal-return",
            "close-entry",
            "close-normal-return",
        }
        counted_events = {
            "transaction-entry",
            "control-run-before",
            "control-run-normal-return",
            "transaction-normal-return",
            "cleanup-entry",
            "cleanup-normal-return",
        }
        for component, event, values, _capture, _sequence, _physical in rows:
            if component == "output" and event in indexed_events:
                require(
                    "output-index-range",
                    decimal("output-index", values[0]) < task_count,
                )
                require(
                    "output-schema-consistency",
                    decimal("output-schema", values[1]) == schema_count,
                )
            if component == "output" and event in counted_events:
                require(
                    "output-count-consistency",
                    decimal("output-count", values[0]) == task_count,
                )
                require(
                    "output-schema-consistency",
                    decimal("output-schema", values[1]) == schema_count,
                )

        injections = [
            row
            for row in rows
            if row[0] == "output" and row[1] == "commit-injection-before"
        ]
        failures = [
            row
            for row in rows
            if row[0] == "output" and row[1] == "commit-runtime-exception"
        ]
        if fixture == "normal":
            require("normal-process-success", process_exit == 0)
            require("normal-no-local-injection", not injections and not failures)
        else:
            require(
                "selected-local-injection",
                injections and len(injections) == len(failures),
            )
            used_commit_entries = set()
            for injection, failure in zip(injections, failures, strict=True):
                require(
                    "selected-injection-index",
                    decimal("injection-index", injection[2][0])
                    == expected_index
                    and decimal("failure-index", failure[2][0])
                    == expected_index,
                )
                require(
                    "selected-injection-payload",
                    failure[2][2:] == [injected_class, injected_message],
                )
                require(
                    "selected-injection-pair",
                    injection[3] == failure[3]
                    and injection[4] < failure[4],
                )
                preceding_entries = [
                    row
                    for row in rows
                    if row[0] == "output"
                    and row[1] == "commit-entry"
                    and row[3] == injection[3]
                    and row[4] < injection[4]
                    and decimal("commit-index", row[2][0])
                    == expected_index
                    and (row[3], row[4]) not in used_commit_entries
                ]
                require("selected-commit-entry", bool(preceding_entries))
                commit_entry = max(preceding_entries, key=lambda row: row[4])
                used_commit_entries.add((commit_entry[3], commit_entry[4]))
                same_invocation_returns = [
                    row
                    for row in rows
                    if row[0] == "output"
                    and row[1] == "commit-normal-return"
                    and row[3] == commit_entry[3]
                    and commit_entry[4] < row[4] < failure[4]
                    and decimal("commit-index", row[2][0])
                    == expected_index
                ]
                require(
                    "selected-injection-order",
                    not same_invocation_returns
                    and commit_entry[4] < injection[4] < failure[4],
                )

        if stage != "full":
            continue

        require("bounded-output-task-count", task_count <= len(rows))
        expected_indices = set(range(task_count))
        pair(rows, "open", expected_indices)
        pair(rows, "finish", expected_indices)
        pair(rows, "close", expected_indices)

        input_required = {
            "transaction-entry",
            "control-run-before",
            "run-entry",
            "finish-before",
            "finish-normal-return",
            "run-normal-return",
            "cleanup-entry",
            "cleanup-normal-return",
        }
        require(
            "input-callback-manifest",
            input_required.issubset(input_names)
            and all(input_names.count(name) == 1 for name in input_required),
        )
        for event in {
            "transaction-entry",
            "control-run-before",
            "control-run-normal-return",
            "transaction-normal-return",
            "cleanup-entry",
            "cleanup-normal-return",
        }:
            for row in [
                row
                for row in rows
                if row[0] == "input" and row[1] == event
            ]:
                require(
                    "input-count-consistency",
                    decimal("input-count", row[2][0]) == requested,
                )
        for event in {
            "run-entry",
            "finish-before",
            "finish-normal-return",
            "run-normal-return",
        }:
            row = only(rows, "input", event, f"input-{event}")
            require(
                "input-index",
                decimal("input-index", row[2][0]) == 0,
            )

        input_main_capture = input_transaction[3]
        output_main_capture = output_transaction[3]
        input_main_events = [
            row
            for row in rows
            if row[0] == "input" and not row[1].startswith("cleanup")
        ]
        output_main_events = [
            row
            for row in rows
            if row[0] == "output" and not row[1].startswith("cleanup")
        ]
        require(
            "input-main-capture",
            all(row[3] == input_main_capture for row in input_main_events),
        )
        require(
            "output-main-capture",
            all(row[3] == output_main_capture for row in output_main_events),
        )
        input_chain_names = [
            "transaction-entry",
            "control-run-before",
            "run-entry",
            "finish-before",
            "finish-normal-return",
            "run-normal-return",
        ]
        input_chain_names += (
            ["control-run-normal-return", "transaction-normal-return"]
            if fixture == "normal"
            else ["transaction-runtime-exception"]
        )
        input_chain = [
            only(rows, "input", event, f"input-chain-{event}")
            for event in input_chain_names
        ]
        require(
            "input-main-chain-order",
            [row[4] for row in input_chain]
            == sorted(row[4] for row in input_chain),
        )
        output_chain_names = [
            "transaction-entry",
            "commit-selection",
            "control-run-before",
        ]
        output_chain_names += (
            ["control-run-normal-return", "transaction-normal-return"]
            if fixture == "normal"
            else ["transaction-runtime-exception"]
        )
        output_chain = [
            only(rows, "output", event, f"output-chain-{event}")
            for event in output_chain_names
        ]
        require(
            "output-main-chain-order",
            [row[4] for row in output_chain]
            == sorted(row[4] for row in output_chain),
        )

        input_run = only(rows, "input", "run-entry", "input-run-entry")
        input_finish_before = only(
            rows, "input", "finish-before", "input-finish-before"
        )
        input_finish_return = only(
            rows,
            "input",
            "finish-normal-return",
            "input-finish-normal-return",
        )
        input_run_return = only(
            rows, "input", "run-normal-return", "input-run-normal-return"
        )
        require(
            "output-control-before-open",
            only(
                rows,
                "output",
                "control-run-before",
                "output-control-run-before",
            )[5]
            < min(positions(rows, "output", "open-entry")),
        )
        require(
            "open-before-input-run",
            max(positions(rows, "output", "open-normal-return"))
            < input_run[5],
        )
        require(
            "output-finish-inside-input-finish",
            input_finish_before[5]
            < min(positions(rows, "output", "finish-entry"))
            and max(positions(rows, "output", "finish-normal-return"))
            < input_finish_return[5],
        )
        commit_entries = indexed_rows(rows, "commit-entry")
        require("commit-entry-required", bool(commit_entries))
        require(
            "input-completes-before-commit",
            input_finish_return[5] < input_run_return[5]
            < min(row[5] for row in commit_entries),
        )

        input_cleanup = only(
            rows, "input", "cleanup-entry", "input-cleanup-entry"
        )
        input_cleanup_return = only(
            rows,
            "input",
            "cleanup-normal-return",
            "input-cleanup-normal-return",
        )
        output_cleanup = only(
            rows, "output", "cleanup-entry", "output-cleanup-entry"
        )
        output_cleanup_return = only(
            rows,
            "output",
            "cleanup-normal-return",
            "output-cleanup-normal-return",
        )
        require(
            "input-cleanup-pair",
            input_cleanup[3] == input_cleanup_return[3]
            and input_cleanup[4] < input_cleanup_return[4],
        )
        require(
            "output-cleanup-pair",
            output_cleanup[2] == output_cleanup_return[2]
            and output_cleanup[3] == output_cleanup_return[3]
            and output_cleanup[4] < output_cleanup_return[4],
        )

        if fixture == "normal":
            require(
                "normal-no-exception",
                not any(
                    name.endswith("runtime-exception")
                    for name in input_names + output_names
                ),
            )
            pair(rows, "commit", expected_indices)
            pair(rows, "abort", set())
            output_control = only(
                rows,
                "output",
                "control-run-normal-return",
                "normal-output-control-return",
            )
            output_scope = only(
                rows,
                "output",
                "transaction-normal-return",
                "normal-output-transaction-return",
            )
            input_control = only(
                rows,
                "input",
                "control-run-normal-return",
                "normal-input-control-return",
            )
            input_scope = only(
                rows,
                "input",
                "transaction-normal-return",
                "normal-input-transaction-return",
            )
            require(
                "normal-close-after-commit",
                max(positions(rows, "output", "commit-normal-return"))
                < min(positions(rows, "output", "close-entry")),
            )
            require(
                "normal-scope-order",
                max(positions(rows, "output", "close-normal-return"))
                < output_control[5]
                < output_scope[5]
                < input_control[5]
                < input_scope[5],
            )
            require(
                "normal-report-counts",
                decimal("input-reports", input_cleanup[2][1]) == 1
                and decimal("output-reports", output_cleanup[2][2])
                == task_count
                and decimal("control-reports", output_control[2][2])
                == task_count
                and decimal("transaction-reports", output_scope[2][2])
                == task_count,
            )
            outer_scope = input_scope
        else:
            require("failure-process-nonzero", process_exit != 0)
            require(
                "failure-no-normal-scopes",
                "control-run-normal-return" not in input_names
                and "transaction-normal-return" not in input_names
                and "control-run-normal-return" not in output_names
                and "transaction-normal-return" not in output_names,
            )
            successful_indices = set(range(expected_index))
            commit_entry_indices = [
                decimal("commit-index", row[2][0])
                for row in indexed_rows(rows, "commit-entry")
            ]
            commit_return_indices = [
                decimal("commit-index", row[2][0])
                for row in indexed_rows(rows, "commit-normal-return")
            ]
            require(
                "failure-commit-entry-indexes",
                len(commit_entry_indices) == expected_index + 1
                and commit_entry_indices == list(range(expected_index + 1)),
            )
            require(
                "failure-commit-return-indexes",
                len(commit_return_indices) == expected_index
                and commit_return_indices == list(range(expected_index)),
            )
            for index in successful_indices:
                entries = [
                    row
                    for row in indexed_rows(rows, "commit-entry")
                    if decimal("commit-index", row[2][0]) == index
                ]
                returns = [
                    row
                    for row in indexed_rows(rows, "commit-normal-return")
                    if decimal("commit-index", row[2][0]) == index
                ]
                require(
                    "failure-prior-commit-pair",
                    len(entries) == 1
                    and len(returns) == 1
                    and entries[0][2] == returns[0][2]
                    and entries[0][3] == returns[0][3]
                    and entries[0][4] < returns[0][4],
                )
            require(
                "failure-single-terminal",
                len(injections) == 1 and len(failures) == 1,
            )
            selected_entry = next(
                row
                for row in indexed_rows(rows, "commit-entry")
                if decimal("commit-index", row[2][0]) == expected_index
            )
            require(
                "failure-prior-commits-before-selected",
                not successful_indices
                or max(positions(rows, "output", "commit-normal-return"))
                < selected_entry[5],
            )
            abort_indices = set(range(expected_index, task_count))
            pair(rows, "abort", abort_indices)
            require(
                "failure-abort-after-exception",
                failures[0][5]
                < min(positions(rows, "output", "abort-entry")),
            )
            require(
                "failure-close-after-abort",
                max(positions(rows, "output", "abort-normal-return"))
                < min(positions(rows, "output", "close-entry")),
            )
            output_error = only(
                rows,
                "output",
                "transaction-runtime-exception",
                "failure-output-transaction-error",
            )
            input_error = only(
                rows,
                "input",
                "transaction-runtime-exception",
                "failure-input-transaction-error",
            )
            require(
                "failure-outer-error-payload",
                output_error[2] == [injected_class, injected_message]
                and input_error[2] == [injected_class, injected_message],
            )
            require(
                "failure-scope-order",
                max(positions(rows, "output", "close-normal-return"))
                < output_error[5]
                < input_error[5],
            )
            require(
                "failure-fresh-cleanup-captures",
                input_cleanup[3] != input_main_capture
                and output_cleanup[3] != output_main_capture,
            )
            require(
                "failure-report-counts",
                decimal("input-reports", input_cleanup[2][1]) == 1
                and decimal("output-reports", output_cleanup[2][2])
                == expected_index,
            )
            outer_scope = input_error

        require(
            "cleanup-physical-order",
            outer_scope[5]
            < input_cleanup[5]
            < input_cleanup_return[5]
            < output_cleanup[5]
            < output_cleanup_return[5],
        )
except (InvalidEvidence, OSError, UnicodeError) as error:
    label = error.args[0] if error.args else "unclassified"
    print(f"CAPTURE_VALIDATION_ERROR|{label}", file=sys.stderr)
    sys.exit(4)
PY
}


mutated_copy() {
  local action=$1 fixture=$2 reference=$3 copy
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-position-validator.XXXXXX")
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
  printf 'T0013_POSITION_MUTATION=%s:%s|evidence=%s\n' \
    "$fixture" "$action" "$copy"
  if result=$(validate_capture "$copy" full 2>&1); then
    printf 'mutation unexpectedly accepted: %s:%s\n' "$fixture" "$action" >&2
    exit 1
  else
    result_code=$?
  fi
  [[ "$result_code" == 4 ]]
  [[ "$result" == "CAPTURE_VALIDATION_ERROR|$expected" ]] || {
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
  validator_fails "$reference" normal oversized-count bounded-output-task-count
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


case ${1:-} in
  "")
    [[ "$#" == 0 ]] || exit 2
    run_artifact_controls
    stage_dir=$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-position-stage-b.XXXXXX")
    if "$runner" > "$stage_dir/runner.stdout.log" \
        2> "$stage_dir/runner.stderr.log"; then
      :
    else
      result_code=$?
      cat "$stage_dir/runner.stdout.log"
      cat "$stage_dir/runner.stderr.log" >&2
      exit "$result_code"
    fi
    cat "$stage_dir/runner.stdout.log"
    cat "$stage_dir/runner.stderr.log" >&2
    [[ $(grep -c '^T0013_POSITION_EVIDENCE_DIR=' \
      "$stage_dir/runner.stdout.log") == 1 ]]
    evidence=$(sed -n 's/^T0013_POSITION_EVIDENCE_DIR=//p' \
      "$stage_dir/runner.stdout.log")
    [[ -n "$evidence" && -d "$evidence" ]]
    cp "$stage_dir/runner.stdout.log" "$evidence/stage-b-runner.stdout.log"
    cp "$stage_dir/runner.stderr.log" "$evidence/stage-b-runner.stderr.log"
    for file in executable.sha256 executable-url.txt LICENSE-executable \
      NOTICE-executable java-version.txt input-source.sha256 input-source-path.txt \
      output-source.sha256 output-source-path.txt output-source-vs-s05.diff \
      input-jar.sha256 output-jar.sha256 input-coordinate.txt output-coordinate.txt \
      cases.raw traces.raw normal.raw.log commit-first.raw.log \
      commit-middle.raw.log; do
      [[ -s "$evidence/$file" ]]
    done
    [[ -f "$evidence/stage-b-runner.stdout.log" \
      && -f "$evidence/stage-b-runner.stderr.log" ]]
    grep -Fqx 'd45f0b6e83d39458331a2cf1be27a01d1b6863017bd87807f0e49d160c96d252' \
      "$evidence/input-source.sha256"
    grep -Fqx 'fd82c85966b90190a82e8a29d4a2b4145bf82c8776045d362116ddd7ef6bbb64' \
      "$evidence/output-source.sha256"
    validate_capture "$evidence" full
    run_stage_b_controls "$evidence"
    if bash "$root/tests/t0013_output_commit_failure_probe_test.sh" \
        > "$evidence/s05-regression.stdout.log" \
        2> "$evidence/s05-regression.stderr.log"; then
      :
    else
      result_code=$?
      exit "$result_code"
    fi
    [[ $(grep -c '^T0013_COMMIT_FULL_PROBE=passed|evidence=' \
      "$evidence/s05-regression.stdout.log") == 1 ]]
    printf 'T0013_POSITION_VALIDATED_CASES=3|evidence=%s\n' "$evidence"
    printf 'T0013_POSITION_FULL_PROBE=passed|evidence=%s\n' "$evidence"
    ;;
  --artifact-controls-only)
    [[ "$#" == 1 ]] || exit 2
    run_artifact_controls
    ;;
  --capture-only)
    [[ "$#" == 1 ]] || exit 2
    run_artifact_controls
    output=$("$runner")
    printf '%s\n' "$output"
    [[ $(printf '%s\n' "$output" \
      | grep -c '^T0013_POSITION_EVIDENCE_DIR=') == 1 ]]
    evidence=$(printf '%s\n' "$output" \
      | sed -n 's/^T0013_POSITION_EVIDENCE_DIR=//p')
    [[ -n "$evidence" && -d "$evidence" ]]
    for file in executable.sha256 executable-url.txt LICENSE-executable \
      NOTICE-executable java-version.txt input-source.sha256 input-source-path.txt \
      output-source.sha256 output-source-path.txt output-source-vs-s05.diff \
      input-jar.sha256 output-jar.sha256 input-coordinate.txt output-coordinate.txt \
      cases.raw traces.raw normal.raw.log commit-first.raw.log \
      commit-middle.raw.log; do
      [[ -s "$evidence/$file" ]]
    done
    grep -Fqx 'd45f0b6e83d39458331a2cf1be27a01d1b6863017bd87807f0e49d160c96d252' \
      "$evidence/input-source.sha256"
    grep -Fqx 'tools/t0013-input-failure/src/T0013FailureInputPlugin.java' \
      "$evidence/input-source-path.txt"
    grep -Fqx 'tools/t0013-output-commit-position-probe/src/T0013CommitPositionOutputPlugin.java' \
      "$evidence/output-source-path.txt"
    grep -Fqx 'source=maven|group=org.embulk.t0013.s07|name=t0013s07input|version=0.0.1|artifact=embulk-input-t0013s07input|category=input|local-only' \
      "$evidence/input-coordinate.txt"
    grep -Fqx 'source=maven|group=org.embulk.t0013.s07|name=t0013s07output|version=0.0.1|artifact=embulk-output-t0013s07output|category=output|local-only' \
      "$evidence/output-coordinate.txt"
    validate_capture "$evidence" capture
    printf 'T0013_POSITION_CAPTURE_ONLY=collected|evidence=%s\n' "$evidence"
    ;;
  *)
    printf '%s\n' 'expected no arguments, --artifact-controls-only or --capture-only' >&2
    exit 2
    ;;
esac

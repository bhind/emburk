#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0013-input-failure/run.sh"
[[ -x "$runner" ]] || exit 2

run_negative() {
  local control=$1 expected=$2 label=$3 output result_code evidence
  if output=$(T0013_FAILURE_NEGATIVE="$control" "$runner" 2>&1); then
    exit 1
  else
    result_code=$?
  fi
  [[ "$result_code" == "$expected" ]] || exit 1
  evidence=$(printf '%s\n' "$output" | sed -n 's/^T0013_FAILURE_EVIDENCE_DIR=//p' | tail -1)
  [[ -n "$evidence" && -d "$evidence" ]] || exit 1
  grep -Fqx "$label" "$evidence/negative-control.txt" || exit 1
  printf 'T0013_FAILURE_NEGATIVE=%s|exit=%s|evidence=%s\n' "$control" "$result_code" "$evidence"
}

run_negative corrupt-copy 3 corrupt-copy-injected
run_negative unavailable-asset 56 unavailable-asset-request-failed

output=$("$runner")
printf '%s\n' "$output"
evidence=$(printf '%s\n' "$output" | sed -n 's/^T0013_FAILURE_EVIDENCE_DIR=//p' | tail -1)
[[ -n "$evidence" && -d "$evidence" ]] || exit 1
for file in executable.sha256 executable-url.txt LICENSE-executable NOTICE-executable java-version.txt \
  input-source.sha256 output-source.sha256 input-jar.sha256 output-jar.sha256 \
  input-coordinate.txt output-coordinate.txt cases.raw traces.raw normal.raw.log failure.raw.log; do
  [[ -s "$evidence/$file" ]] || exit 1
done

validate() {
  python3 - "$1" <<'PY'
import base64
import binascii
import hashlib
import pathlib
import sys
import uuid

root = pathlib.Path(sys.argv[1])
injected_class = "T0013FailureInputPlugin$InjectedRunFailure"
injected_message = "t0013-s03-injected-run-failure"

class InvalidEvidence(Exception):
    pass

def require(label, condition):
    if not condition:
        raise InvalidEvidence(label)

def decimal(label, value):
    require(label, value.isascii() and value.isdigit())
    return int(value)

def decode_field(label, encoded, *, numeric=False, nonempty=False):
    require(label, encoded != "-")
    try:
        raw = base64.b64decode(encoded, validate=True)
        value = raw.decode("utf-8")
    except (binascii.Error, UnicodeError):
        raise InvalidEvidence(label)
    require(label, base64.b64encode(raw).decode("ascii") == encoded)
    if numeric:
        decimal(label, value)
    if nonempty:
        require(label, value != "")
    return value

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
    "transaction-entry": {0}, "control-run-before": {0}, "control-run-normal-return": {0},
    "transaction-normal-return": {0}, "run-entry": {0}, "injection-before": {0},
    "finish-before": {0}, "finish-normal-return": {0}, "run-normal-return": {0},
    "cleanup-entry": {0, 1}, "cleanup-normal-return": {0}, "resume-entry": {0},
    "resume-normal-return": {0},
}
output_arity = {
    "transaction-entry": 2,
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
    "commit-normal-return": 2,
    "abort-entry": 2,
    "abort-normal-return": 2,
    "close-entry": 2,
    "close-normal-return": 2,
}
output_numeric = {event: set(range(arity)) for event, arity in output_arity.items()
                  if not event.endswith("runtime-exception")}

try:
    require("cases-readable", root.joinpath("cases.raw").is_file())
    require("traces-readable", root.joinpath("traces.raw").is_file())
    cases = root.joinpath("cases.raw").read_text(encoding="utf-8").splitlines()
    traces = root.joinpath("traces.raw").read_text(encoding="utf-8").splitlines()
    require("case-count", len(cases) == 2)

    parsed_cases = {}
    for row in cases:
        parts = row.split("|")
        require("case-arity", len(parts) == 5)
        tag, fixture, requested_text, exit_text, summary = parts
        require("case-tag", tag == "CASE")
        require("case-fixture", fixture in {"normal", "failure"})
        require("case-duplicate", fixture not in parsed_cases)
        summary_parts = summary.split(":")
        require("case-summary-arity", len(summary_parts) == 4)
        total_text, input_text, output_text, digest = summary_parts
        requested = decimal("case-requested-count", requested_text)
        process_exit = decimal("case-process-exit", exit_text)
        total = decimal("case-total-count", total_text)
        input_count = decimal("case-input-count", input_text)
        output_count = decimal("case-output-count", output_text)
        require("case-digest-format", len(digest) == 64 and all(c in "0123456789abcdef" for c in digest))
        parsed_cases[fixture] = (requested, process_exit, total, input_count, output_count, digest)
    require("case-fixtures", set(parsed_cases) == {"normal", "failure"})
    require("requested-count", all(case[0] == 1 for case in parsed_cases.values()))

    grouped_rows = {fixture: [] for fixture in ("normal", "failure")}
    decoded = {fixture: {"input": [], "output": []} for fixture in ("normal", "failure")}
    sequence_state = {}
    for row in traces:
        parts = row.split("|")
        require("trace-minimum-arity", len(parts) >= 5)
        tag, fixture, capture_id, sequence_text, event = parts[:5]
        require("trace-tag", tag in {"FAILTRACE", "FAILOUTTRACE"})
        require("trace-fixture", fixture in grouped_rows)
        try:
            parsed_capture = uuid.UUID(capture_id)
        except ValueError:
            raise InvalidEvidence("capture-id")
        require("capture-id", str(parsed_capture) == capture_id and parsed_capture.version == 4)
        sequence = decimal("trace-sequence", sequence_text)
        component = "input" if tag == "FAILTRACE" else "output"
        sequence_key = (fixture, component, capture_id)
        expected = sequence_state.get(sequence_key, 1)
        require(f"{component}-sequence-contiguous", sequence == expected)
        sequence_state[sequence_key] = expected + 1

        grammar = input_arity if component == "input" else output_arity
        numeric_fields = input_numeric if component == "input" else output_numeric
        require(f"{component}-event-known", event in grammar)
        require(f"{component}-event-arity", len(parts) == 5 + grammar[event])
        values = []
        for index, encoded in enumerate(parts[5:]):
            if encoded == "-":
                require(f"{component}-null-position", event.endswith("runtime-exception") and index == 1)
                values.append(None)
            else:
                label = f"{component}-exception-class" if event.endswith("runtime-exception") and index == 0 else f"{component}-canonical-field"
                values.append(decode_field(label, encoded, numeric=index in numeric_fields.get(event, set()),
                                           nonempty=event.endswith("runtime-exception") and index == 0))
        grouped_rows[fixture].append(row)
        decoded[fixture][component].append((event, values, sequence, capture_id))

    for fixture in ("normal", "failure"):
        requested, process_exit, total, input_count, output_count, digest = parsed_cases[fixture]
        rows = grouped_rows[fixture]
        require("case-total-count-match", len(rows) == total)
        require("case-component-count-match",
                sum(row.startswith("FAILTRACE|") for row in rows) == input_count
                and sum(row.startswith("FAILOUTTRACE|") for row in rows) == output_count
                and input_count + output_count == total)
        material = ("\n".join(rows) + ("\n" if rows else "")).encode("utf-8")
        require("case-digest-match", hashlib.sha256(material).hexdigest() == digest)
        raw_log = root / f"{fixture}.raw.log"
        require("raw-log-required", raw_log.is_file())
        extracted = [line for line in raw_log.read_text(encoding="utf-8").splitlines()
                     if line.startswith("FAILTRACE|") or line.startswith("FAILOUTTRACE|")]
        require("raw-log-trace-match", extracted == rows)

        input_events = decoded[fixture]["input"]
        output_events = decoded[fixture]["output"]
        input_names = [event for event, _, _, _ in input_events]
        output_names = [event for event, _, _, _ in output_events]
        require("input-transaction-boundary",
                "transaction-entry" in input_names and "control-run-before" in input_names)
        require("output-transaction-boundary",
                "transaction-entry" in output_names and "control-run-before" in output_names)

        transaction_markers = {
            "transaction-entry", "control-run-before", "control-run-normal-return",
            "transaction-normal-return", "transaction-runtime-exception",
        }
        for component, events in (("input", input_events), ("output", output_events)):
            captures = {}
            for event, values, sequence, capture in events:
                captures.setdefault(capture, []).append((event, values, sequence))
            for capture_events in captures.values():
                capture_names = [event for event, _, _ in capture_events]
                if not any(event in transaction_markers for event in capture_names):
                    continue
                require(f"{component}-capture-transaction-boundary",
                        "transaction-entry" in capture_names and "control-run-before" in capture_names)
                transaction_position = capture_names.index("transaction-entry")
                control_position = capture_names.index("control-run-before")
                require(f"{component}-local-transaction-order", transaction_position < control_position)
                has_exception = "transaction-runtime-exception" in capture_names
                has_normal = ("control-run-normal-return" in capture_names
                              or "transaction-normal-return" in capture_names)
                require(f"{component}-transaction-contradiction", not (has_exception and has_normal))
                require(f"{component}-capture-transaction-terminal", has_exception or has_normal)
                if has_exception:
                    require(f"{component}-local-exception-order",
                            control_position < capture_names.index("transaction-runtime-exception"))
                if has_normal:
                    require(f"{component}-capture-normal-return",
                            "control-run-normal-return" in capture_names
                            and "transaction-normal-return" in capture_names)
                    require(f"{component}-local-normal-order",
                            control_position < capture_names.index("control-run-normal-return")
                            < capture_names.index("transaction-normal-return"))

        input_capture_groups = {}
        for event, values, sequence, capture in input_events:
            input_capture_groups.setdefault(capture, []).append((event, values, sequence))
        run_markers = {"run-entry", "injection-before", "finish-before", "finish-normal-return",
                       "run-normal-return", "run-runtime-exception"}
        for capture_events in input_capture_groups.values():
            if not any(event in run_markers for event, _, _ in capture_events):
                continue
            capture_invocations = []
            current = None
            for event, values, sequence in capture_events:
                if event == "run-entry":
                    if current is not None:
                        prior_names = [name for name, _, _ in current]
                        require("input-capture-run-terminal", "run-normal-return" in prior_names
                                or "run-runtime-exception" in prior_names)
                    current = [(event, values, sequence)]
                    capture_invocations.append(current)
                elif event in run_markers:
                    require("input-capture-run-entry", current is not None)
                    current.append((event, values, sequence))
            require("input-capture-run-entry", bool(capture_invocations))
            for invocation in capture_invocations:
                invocation_names = [event for event, _, _ in invocation]
                has_normal = "run-normal-return" in invocation_names
                has_exception = "run-runtime-exception" in invocation_names
                require("input-run-contradiction", not (has_normal and has_exception))
                require("input-capture-run-terminal", has_normal or has_exception)

        input_transaction_capture = next(capture for event, _, _, capture in input_events if event == "transaction-entry")
        input_main = [(event, values, sequence) for event, values, sequence, capture in input_events
                      if capture == input_transaction_capture]
        input_main_names = [event for event, _, _ in input_main]
        for event, values, _, _ in input_events:
            if event in {"transaction-entry", "control-run-before", "control-run-normal-return",
                         "transaction-normal-return", "cleanup-entry", "cleanup-normal-return",
                         "resume-entry", "resume-normal-return"}:
                require("input-requested-count-consistency", int(values[0]) == requested)

        output_transaction_capture = next(capture for event, _, _, capture in output_events if event == "transaction-entry")
        output_main = [(event, values, sequence) for event, values, sequence, capture in output_events
                       if capture == output_transaction_capture]
        output_main_names = [event for event, _, _ in output_main]
        output_transaction = next(values for event, values, _ in output_main if event == "transaction-entry")
        output_task_count = int(output_transaction[0])
        output_schema_count = int(output_transaction[1])
        require("output-empty-schema", output_schema_count == 0)
        count_schema_events = {
            "transaction-entry", "control-run-before", "control-run-normal-return",
            "transaction-normal-return", "resume-entry", "resume-control-run-before",
            "resume-control-run-normal-return", "resume-normal-return", "cleanup-entry",
            "cleanup-normal-return",
        }
        indexed_events = {
            "open-entry", "open-normal-return", "add-entry", "add-normal-return",
            "finish-entry", "finish-normal-return", "commit-entry", "commit-normal-return",
            "abort-entry", "abort-normal-return", "close-entry", "close-normal-return",
        }
        for event, values, _, _ in output_events:
            if event in count_schema_events:
                require("output-task-count-consistency", int(values[0]) == output_task_count)
                require("output-schema-count-consistency", int(values[1]) == output_schema_count)
            if event in indexed_events:
                require("output-schema-count-consistency", int(values[1]) == output_schema_count)
                require("output-index-range", output_task_count > 0 and int(values[0]) < output_task_count)

        opened_at = {}
        for event, values, sequence, capture in output_events:
            key = (capture, values[0]) if values and event in indexed_events else None
            if event == "open-normal-return":
                opened_at[key] = sequence
            if event in indexed_events - {"open-entry", "open-normal-return"}:
                require("output-prior-open", key in opened_at and opened_at[key] < sequence)

        report_values = [int(values[2]) for event, values, _ in output_main
                         if event in {"control-run-normal-return", "transaction-normal-return"}]
        if report_values:
            require("output-report-count-consistency", all(value == report_values[0] for value in report_values))
        require("unexpected-add", "add-entry" not in output_names and "add-normal-return" not in output_names)

        for component, events in (("input", input_events), ("output", output_events)):
            callbacks = ("cleanup",) if component == "input" else ("open", "finish", "commit", "abort", "close", "cleanup")
            for callback in callbacks:
                balances = {}
                for event, values, _, capture in events:
                    if event not in {f"{callback}-entry", f"{callback}-normal-return"}:
                        continue
                    key_values = (values[0],) if component == "input" and callback == "cleanup" else tuple(values)
                    key = (capture, key_values)
                    balances.setdefault(key, 0)
                    if event.endswith("-entry"):
                        balances[key] += 1
                    else:
                        balances[key] -= 1
                        require(f"{component}-callback-pair", balances[key] >= 0)
                require(f"{component}-callback-pair", all(balance == 0 for balance in balances.values()))

        input_transaction_exceptions = [values for event, values, _ in input_main
                                        if event == "transaction-runtime-exception"]
        input_run_exceptions = [values for event, values, _ in input_main if event == "run-runtime-exception"]
        output_transaction_exceptions = [values for event, values, _ in output_main
                                         if event == "transaction-runtime-exception"]
        run_events = {"run-entry", "injection-before", "finish-before", "finish-normal-return",
                      "run-normal-return", "run-runtime-exception"}
        invocations = []
        current_invocation = None
        for event, values, sequence in input_main:
            if event == "run-entry":
                current_invocation = [(event, values, sequence)]
                invocations.append(current_invocation)
            elif event in run_events:
                require("input-run-entry-required", current_invocation is not None)
                current_invocation.append((event, values, sequence))
        for invocation in invocations:
            names = [event for event, _, _ in invocation]
            has_exception = "run-runtime-exception" in names
            require("input-run-contradiction", not (has_exception and
                    ("finish-normal-return" in names or "run-normal-return" in names)))
        resume_captures = {capture for event, _, _, capture in output_events if event.startswith("resume")}
        for capture in resume_captures:
            resume_names = [event for event, _, _, event_capture in output_events if event_capture == capture]
            require("output-resume-boundary", "resume-entry" in resume_names and
                    "resume-control-run-before" in resume_names)
            require("output-resume-order", resume_names.index("resume-entry") <
                    resume_names.index("resume-control-run-before"))
            if "resume-runtime-exception" in resume_names:
                require("output-resume-contradiction", "resume-control-run-normal-return" not in resume_names and
                        "resume-normal-return" not in resume_names)
                require("output-resume-order", resume_names.index("resume-control-run-before") <
                        resume_names.index("resume-runtime-exception"))
            else:
                require("output-resume-normal-return", "resume-control-run-normal-return" in resume_names and
                        "resume-normal-return" in resume_names)

        if fixture == "normal":
            require("normal-process-success", process_exit == 0)
            require("normal-no-exception", not any(event.endswith("runtime-exception")
                    for component in (input_events, output_events) for event, _, _, _ in component))
            required_input = ["transaction-entry", "control-run-before", "run-entry", "finish-before",
                              "finish-normal-return", "run-normal-return", "control-run-normal-return",
                              "transaction-normal-return"]
            require("normal-input-markers", all(event in input_main_names for event in required_input))
            require("normal-input-invocations", bool(invocations) and all(
                    "finish-before" in [event for event, _, _ in invocation]
                    and "finish-normal-return" in [event for event, _, _ in invocation]
                    and "run-normal-return" in [event for event, _, _ in invocation]
                    and "run-runtime-exception" not in [event for event, _, _ in invocation]
                    for invocation in invocations))
            require("normal-input-order", [input_main_names.index(event) for event in required_input]
                    == sorted(input_main_names.index(event) for event in required_input))
            required_output = ["transaction-entry", "control-run-before", "open-entry", "open-normal-return",
                               "finish-entry", "finish-normal-return", "control-run-normal-return",
                               "transaction-normal-return"]
            require("normal-output-markers", all(event in output_main_names for event in required_output))
            require("normal-output-transaction-order",
                    output_main_names.index("control-run-before") < output_main_names.index("control-run-normal-return")
                    < output_main_names.index("transaction-normal-return"))
        else:
            require("failure-process-nonzero", process_exit != 0)
            require("failure-unrelated-nonzero", bool(invocations))
            require("failure-run-exception", bool(input_run_exceptions))
            require("failure-injection-marker", "injection-before" in input_main_names)
            require("failure-injected-class", all(values[0] == injected_class for values in input_run_exceptions))
            require("failure-injected-message", all(values[1] == injected_message for values in input_run_exceptions))
            require("failure-input-transaction-exception", bool(input_transaction_exceptions))
            require("failure-output-transaction-exception", bool(output_transaction_exceptions))
            require("failure-propagation", all(values == [injected_class, injected_message]
                    for values in input_transaction_exceptions + output_transaction_exceptions))
            require("failure-input-finish-forbidden", not any(event in input_main_names for event in
                    ("finish-before", "finish-normal-return", "run-normal-return")))
            require("failure-input-invocations", all(
                    "injection-before" in [event for event, _, _ in invocation]
                    and "run-runtime-exception" in [event for event, _, _ in invocation]
                    and not any(event in [event for event, _, _ in invocation]
                                for event in ("finish-before", "finish-normal-return", "run-normal-return"))
                    for invocation in invocations))
            required_failure = ["transaction-entry", "control-run-before", "run-entry", "injection-before",
                                "run-runtime-exception", "transaction-runtime-exception"]
            require("failure-input-order", [input_main_names.index(event) for event in required_failure]
                    == sorted(input_main_names.index(event) for event in required_failure))
            require("failure-output-order", output_main_names.index("control-run-before") <
                    output_main_names.index("transaction-runtime-exception"))
except (InvalidEvidence, OSError, UnicodeError) as failure:
    label = failure.args[0] if failure.args else "unclassified"
    print(f"VALIDATION_ERROR|{label}", file=sys.stderr)
    sys.exit(4)
PY
}

validate "$evidence"

mutated_copy() {
  local mutation=$1 copy
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-failure-validator.XXXXXX")
  cp "$evidence/cases.raw" "$evidence/traces.raw" "$evidence/normal.raw.log" "$evidence/failure.raw.log" "$copy/"
  python3 - "$mutation" "$copy" <<'PY'
import base64
import hashlib
import pathlib
import sys

action, directory = sys.argv[1:]
root = pathlib.Path(directory)
cases = root.joinpath("cases.raw").read_text(encoding="utf-8").splitlines()
traces = root.joinpath("traces.raw").read_text(encoding="utf-8").splitlines()

def fixture_rows(fixture):
    return [row for row in traces if row.split("|")[1] == fixture]

def synchronize():
    for fixture in ("normal", "failure"):
        rows = fixture_rows(fixture)
        path = root / f"{fixture}.raw.log"
        other = [line for line in path.read_text(encoding="utf-8").splitlines()
                 if not line.startswith("FAILTRACE|") and not line.startswith("FAILOUTTRACE|")]
        path.write_text("\n".join(rows + other) + "\n", encoding="utf-8")
    for index, row in enumerate(cases):
        parts = row.split("|")
        if len(parts) != 5 or parts[0] != "CASE" or parts[1] not in {"normal", "failure"}:
            continue
        rows = fixture_rows(parts[1])
        input_count = sum(item.startswith("FAILTRACE|") for item in rows)
        output_count = sum(item.startswith("FAILOUTTRACE|") for item in rows)
        material = ("\n".join(rows) + ("\n" if rows else "")).encode("utf-8")
        parts[4] = f"{len(rows)}:{input_count}:{output_count}:{hashlib.sha256(material).hexdigest()}"
        cases[index] = "|".join(parts)

def renumber_capture(fixture, tag, capture_id):
    sequence = 0
    for index, row in enumerate(traces):
        parts = row.split("|")
        if len(parts) < 5 or parts[0] != tag or parts[1] != fixture or parts[2] != capture_id:
            continue
        sequence += 1
        parts[3] = str(sequence)
        traces[index] = "|".join(parts)

if action == "missing-case":
    cases.pop()
elif action == "duplicate-case":
    cases.append(cases[0])
elif action == "truncated-trace":
    traces[0] = "FAILTRACE"
elif action == "unknown-event":
    index = next(i for i, row in enumerate(traces) if row.startswith("FAILTRACE|normal|") and "|run-entry|" in row)
    parts = traces[index].split("|")
    parts[4] = "invented"
    traces[index] = "|".join(parts)
    synchronize()
elif action == "bad-arity":
    index = next(i for i, row in enumerate(traces) if row.startswith("FAILTRACE|normal|") and "|run-entry|" in row)
    traces[index] = "|".join(traces[index].split("|")[:-1])
    synchronize()
elif action == "bad-b64":
    index = next(i for i, row in enumerate(traces) if row.startswith("FAILTRACE|normal|") and "|run-entry|" in row)
    parts = traces[index].split("|")
    parts[5] = "!"
    traces[index] = "|".join(parts)
    synchronize()
elif action == "malformed-count":
    index = next(i for i, row in enumerate(traces) if row.startswith("FAILOUTTRACE|normal|") and "|transaction-entry|" in row)
    parts = traces[index].split("|")
    parts[5] = base64.b64encode(b"not-a-count").decode("ascii")
    traces[index] = "|".join(parts)
    synchronize()
elif action == "mismatched-count":
    index = next(i for i, row in enumerate(traces) if row.startswith("FAILOUTTRACE|normal|") and "|control-run-before|" in row)
    parts = traces[index].split("|")
    parts[5] = base64.b64encode(str(int(base64.b64decode(parts[5])) + 1).encode()).decode("ascii")
    traces[index] = "|".join(parts)
    synchronize()
elif action == "duplicate-sequence-one-same-id":
    indexes = [i for i, row in enumerate(traces) if row.startswith("FAILTRACE|normal|")]
    parts = traces[indexes[1]].split("|")
    parts[3] = traces[indexes[0]].split("|")[3]
    traces[indexes[1]] = "|".join(parts)
    synchronize()
elif action == "bad-capture-id":
    index = next(i for i, row in enumerate(traces) if row.startswith("FAILTRACE|normal|"))
    parts = traces[index].split("|")
    parts[2] = "not-a-uuid"
    traces[index] = "|".join(parts)
    synchronize()
elif action == "fake-injected-class":
    index = next(i for i, row in enumerate(traces) if row.startswith("FAILTRACE|failure|") and "|run-runtime-exception|" in row)
    parts = traces[index].split("|")
    parts[5] = base64.b64encode(b"java.lang.RuntimeException").decode("ascii")
    traces[index] = "|".join(parts)
    synchronize()
elif action == "fake-injected-message":
    index = next(i for i, row in enumerate(traces) if row.startswith("FAILTRACE|failure|") and "|run-runtime-exception|" in row)
    parts = traces[index].split("|")
    parts[6] = base64.b64encode(b"different").decode("ascii")
    traces[index] = "|".join(parts)
    synchronize()
elif action == "missing-injection":
    index = next(i for i, row in enumerate(traces) if row.startswith("FAILTRACE|failure|") and "|injection-before|" in row)
    capture_id = traces[index].split("|")[2]
    traces.pop(index)
    renumber_capture("failure", "FAILTRACE", capture_id)
    synchronize()
elif action == "normal-return-contradiction":
    index = next(i for i, row in enumerate(traces) if row.startswith("FAILTRACE|failure|") and "|run-runtime-exception|" in row)
    capture_id = traces[index].split("|")[2]
    task_index = next(row.split("|")[5] for row in traces if row.startswith(f"FAILTRACE|failure|{capture_id}|") and "|run-entry|" in row)
    traces.insert(index + 1, f"FAILTRACE|failure|{capture_id}|0|run-normal-return|{task_index}")
    renumber_capture("failure", "FAILTRACE", capture_id)
    synchronize()
elif action == "failure-finish":
    index = next(i for i, row in enumerate(traces) if row.startswith("FAILTRACE|failure|") and "|injection-before|" in row)
    capture_id = traces[index].split("|")[2]
    task_index = traces[index].split("|")[5]
    traces.insert(index + 1, f"FAILTRACE|failure|{capture_id}|0|finish-before|{task_index}")
    renumber_capture("failure", "FAILTRACE", capture_id)
    synchronize()
elif action == "unrelated-nonzero":
    generic = base64.b64encode(b"java.lang.RuntimeException").decode("ascii")
    message = base64.b64encode(b"unrelated").decode("ascii")
    synthetic = [
        "FAILTRACE|failure|11111111-1111-4111-8111-111111111111|1|transaction-entry|MQ==",
        "FAILTRACE|failure|11111111-1111-4111-8111-111111111111|2|control-run-before|MQ==",
        "FAILOUTTRACE|failure|22222222-2222-4222-8222-222222222222|1|transaction-entry|MA==|MA==",
        "FAILOUTTRACE|failure|22222222-2222-4222-8222-222222222222|2|control-run-before|MA==|MA==",
        f"FAILOUTTRACE|failure|22222222-2222-4222-8222-222222222222|3|transaction-runtime-exception|{generic}|{message}",
        f"FAILTRACE|failure|11111111-1111-4111-8111-111111111111|3|transaction-runtime-exception|{generic}|{message}",
    ]
    traces = fixture_rows("normal") + synthetic
    synchronize()
elif action in {"null-message", "empty-message"}:
    message = "-" if action == "null-message" else ""
    generic = base64.b64encode(b"java.lang.RuntimeException").decode("ascii")
    failure = fixture_rows("failure")
    transaction = next(row.split("|") for row in failure
                       if row.startswith("FAILOUTTRACE|") and "|transaction-entry|" in row)
    output_count, schema_count = transaction[5], transaction[6]
    failure += [
        f"FAILOUTTRACE|failure|33333333-3333-4333-8333-333333333333|1|resume-entry|{output_count}|{schema_count}",
        f"FAILOUTTRACE|failure|33333333-3333-4333-8333-333333333333|2|resume-control-run-before|{output_count}|{schema_count}",
        f"FAILOUTTRACE|failure|33333333-3333-4333-8333-333333333333|3|resume-runtime-exception|{generic}|{message}",
    ]
    traces = fixture_rows("normal") + failure
    synchronize()
elif action == "new-capture-transaction-contradiction":
    normal = fixture_rows("normal")
    transaction = next(row.split("|") for row in normal
                       if row.startswith("FAILOUTTRACE|") and "|transaction-entry|" in row)
    control_return = next(row.split("|") for row in normal
                          if row.startswith("FAILOUTTRACE|") and "|control-run-normal-return|" in row)
    output_count, schema_count, report_count = transaction[5], transaction[6], control_return[7]
    generic = base64.b64encode(b"java.lang.RuntimeException").decode("ascii")
    capture = "66666666-6666-4666-8666-666666666666"
    normal += [
        f"FAILOUTTRACE|normal|{capture}|1|transaction-entry|{output_count}|{schema_count}",
        f"FAILOUTTRACE|normal|{capture}|2|control-run-before|{output_count}|{schema_count}",
        f"FAILOUTTRACE|normal|{capture}|3|control-run-normal-return|{output_count}|{schema_count}|{report_count}",
        f"FAILOUTTRACE|normal|{capture}|4|transaction-normal-return|{output_count}|{schema_count}|{report_count}",
        f"FAILOUTTRACE|normal|{capture}|5|transaction-runtime-exception|{generic}|-",
    ]
    traces = normal + fixture_rows("failure")
    synchronize()
elif action == "incomplete-transaction-capture":
    normal = fixture_rows("normal")
    transaction = next(row.split("|") for row in normal
                       if row.startswith("FAILOUTTRACE|") and "|transaction-entry|" in row)
    output_count, schema_count = transaction[5], transaction[6]
    capture = "77777777-7777-4777-8777-777777777777"
    normal += [
        f"FAILOUTTRACE|normal|{capture}|1|transaction-entry|{output_count}|{schema_count}",
        f"FAILOUTTRACE|normal|{capture}|2|control-run-before|{output_count}|{schema_count}",
    ]
    traces = normal + fixture_rows("failure")
    synchronize()
elif action == "fresh-cleanup-capture":
    replacements = {
        "FAILTRACE": "44444444-4444-4444-8444-444444444444",
        "FAILOUTTRACE": "55555555-5555-4555-8555-555555555555",
    }
    next_sequence = {tag: 0 for tag in replacements}
    for index, row in enumerate(traces):
        parts = row.split("|")
        if parts[1] != "normal" or parts[0] not in replacements or not parts[4].startswith("cleanup-"):
            continue
        next_sequence[parts[0]] += 1
        parts[2] = replacements[parts[0]]
        parts[3] = str(next_sequence[parts[0]])
        traces[index] = "|".join(parts)
    synchronize()
elif action == "unexpected-add":
    output_main = [row for row in fixture_rows("normal") if row.startswith("FAILOUTTRACE|")]
    capture_id = next(row.split("|")[2] for row in output_main if "|transaction-entry|" in row)
    next_sequence = max(int(row.split("|")[3]) for row in output_main if row.split("|")[2] == capture_id) + 1
    traces += [f"FAILOUTTRACE|normal|{capture_id}|{next_sequence}|add-entry|MA==|MA==",
               f"FAILOUTTRACE|normal|{capture_id}|{next_sequence + 1}|add-normal-return|MA==|MA=="]
    synchronize()
elif action == "missing-prior-open":
    open_row = next(row for row in traces if row.startswith("FAILOUTTRACE|normal|") and "|open-entry|" in row)
    capture_id = open_row.split("|")[2]
    open_index = open_row.split("|")[5]
    traces = [row for row in traces if not (row.startswith("FAILOUTTRACE|normal|") and
              ("|open-entry|" in row or "|open-normal-return|" in row) and row.split("|")[5] == open_index)]
    renumber_capture("normal", "FAILOUTTRACE", capture_id)
    synchronize()
elif action == "case-total-corrupt":
    index = next(i for i, row in enumerate(cases) if row.startswith("CASE|normal|"))
    parts = cases[index].split("|")
    summary = parts[4].split(":")
    summary[0] = str(int(summary[0]) + 1)
    parts[4] = ":".join(summary)
    cases[index] = "|".join(parts)
elif action == "case-component-corrupt":
    index = next(i for i, row in enumerate(cases) if row.startswith("CASE|normal|"))
    parts = cases[index].split("|")
    summary = parts[4].split(":")
    summary[1] = str(int(summary[1]) + 1)
    parts[4] = ":".join(summary)
    cases[index] = "|".join(parts)
elif action == "digest-corrupt":
    index = next(i for i, row in enumerate(cases) if row.startswith("CASE|normal|"))
    parts = cases[index].split("|")
    summary = parts[4].split(":")
    summary[3] = "0" * 64
    parts[4] = ":".join(summary)
    cases[index] = "|".join(parts)
elif action == "missing-raw-log":
    root.joinpath("failure.raw.log").unlink()
elif action == "raw-log-mismatch":
    path = root / "failure.raw.log"
    lines = path.read_text(encoding="utf-8").splitlines()
    lines = [line for line in lines if not (line.startswith("FAILOUTTRACE|") and "|abort-normal-return|" in line)]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
else:
    raise ValueError(action)

root.joinpath("cases.raw").write_text("\n".join(cases) + "\n", encoding="utf-8")
root.joinpath("traces.raw").write_text("\n".join(traces) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$copy"
}

validator_fails() {
  local mutation=$1 expected=$2 copy output result_code
  copy=$(mutated_copy "$mutation")
  printf 'T0013_FAILURE_MUTATION=%s|evidence=%s\n' "$mutation" "$copy"
  if output=$(validate "$copy" 2>&1); then
    exit 1
  else
    result_code=$?
  fi
  [[ "$result_code" == 4 ]] || exit 1
  [[ "$output" == "VALIDATION_ERROR|$expected" ]] || {
    printf 'unexpected validator result for %s: %s\n' "$mutation" "$output" >&2
    exit 1
  }
}

validator_accepts() {
  local mutation=$1 copy
  copy=$(mutated_copy "$mutation")
  printf 'T0013_FAILURE_MUTATION=%s|evidence=%s\n' "$mutation" "$copy"
  validate "$copy"
}

validator_fails missing-case case-count
validator_fails duplicate-case case-count
validator_fails truncated-trace trace-minimum-arity
validator_fails unknown-event input-event-known
validator_fails bad-arity input-event-arity
validator_fails bad-b64 input-canonical-field
validator_fails malformed-count output-canonical-field
validator_fails mismatched-count output-task-count-consistency
validator_fails duplicate-sequence-one-same-id input-sequence-contiguous
validator_fails bad-capture-id capture-id
validator_fails fake-injected-class failure-injected-class
validator_fails fake-injected-message failure-injected-message
validator_fails missing-injection failure-injection-marker
validator_fails normal-return-contradiction input-run-contradiction
validator_fails failure-finish failure-input-finish-forbidden
validator_fails unrelated-nonzero failure-unrelated-nonzero
validator_fails unexpected-add unexpected-add
validator_fails missing-prior-open output-prior-open
validator_fails new-capture-transaction-contradiction output-transaction-contradiction
validator_fails incomplete-transaction-capture output-capture-transaction-terminal
validator_fails case-total-corrupt case-total-count-match
validator_fails case-component-corrupt case-component-count-match
validator_fails digest-corrupt case-digest-match
validator_fails missing-raw-log raw-log-required
validator_fails raw-log-mismatch raw-log-trace-match
validator_accepts null-message
validator_accepts empty-message
validator_accepts fresh-cleanup-capture

printf 'T0013_FAILURE_FULL_PROBE=passed|evidence=%s\n' "$evidence"

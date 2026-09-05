#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0013-output-lifecycle/run.sh"
[[ -x "$runner" ]] || exit 2

run_negative() {
  local control=$1 expected=$2 label=$3 output result_code evidence
  if output=$(T0013_OUTPUT_NEGATIVE="$control" "$runner" 2>&1); then
    exit 1
  else
    result_code=$?
  fi
  [[ "$result_code" == "$expected" ]] || exit 1
  evidence=$(printf '%s\n' "$output" | sed -n 's/^T0013_OUTPUT_EVIDENCE_DIR=//p' | tail -1)
  [[ -n "$evidence" && -d "$evidence" ]] || exit 1
  grep -Fqx "$label" "$evidence/negative-control.txt" || exit 1
  printf 'T0013_OUTPUT_NEGATIVE=%s|exit=%s|evidence=%s\n' "$control" "$result_code" "$evidence"
}

run_negative corrupt-copy 3 corrupt-copy-injected
run_negative unavailable-asset 56 unavailable-asset-request-failed

output=$("$runner")
printf '%s\n' "$output"
evidence=$(printf '%s\n' "$output" | sed -n 's/^T0013_OUTPUT_EVIDENCE_DIR=//p' | tail -1)
[[ -n "$evidence" && -d "$evidence" ]] || exit 1
for file in executable.sha256 executable-url.txt LICENSE-executable NOTICE-executable java-version.txt \
  input-source.sha256 output-source.sha256 input-jar.sha256 output-jar.sha256 \
  input-coordinate.txt output-coordinate.txt cases.raw traces.raw zero.raw.log one.raw.log; do
  [[ -s "$evidence/$file" ]] || exit 1
done

validate() {
  python3 - "$1" <<'PY'
import base64
import binascii
import hashlib
import pathlib
import sys

root = pathlib.Path(sys.argv[1])

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
    "transaction-normal-return": {0}, "run-entry": {0}, "finish-before": {0},
    "finish-normal-return": {0}, "run-normal-return": {0}, "cleanup-entry": {0, 1},
    "cleanup-normal-return": {0}, "resume-entry": {0}, "resume-normal-return": {0},
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
        require("case-fixture", fixture in {"zero", "one"})
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
    require("case-fixtures", set(parsed_cases) == {"zero", "one"})
    require("requested-fixtures", parsed_cases["zero"][0] == 0 and parsed_cases["one"][0] == 1)

    grouped_rows = {fixture: [] for fixture in ("zero", "one")}
    decoded = {fixture: {"input": [], "output": []} for fixture in ("zero", "one")}
    for row in traces:
        parts = row.split("|")
        require("trace-minimum-arity", len(parts) >= 4)
        tag, fixture, sequence_text, event = parts[:4]
        require("trace-tag", tag in {"TRACE", "OUTTRACE"})
        require("trace-fixture", fixture in grouped_rows)
        decimal("trace-sequence", sequence_text)
        component = "input" if tag == "TRACE" else "output"
        grammar = input_arity if component == "input" else output_arity
        numeric_fields = input_numeric if component == "input" else output_numeric
        require(f"{component}-event-known", event in grammar)
        require(f"{component}-event-arity", len(parts) == 4 + grammar[event])
        values = []
        for index, encoded in enumerate(parts[4:]):
            if encoded == "-":
                require(f"{component}-null-position", event.endswith("runtime-exception") and index == 1)
                values.append(None)
            else:
                label = f"{component}-exception-class" if event.endswith("runtime-exception") and index == 0 else f"{component}-canonical-field"
                values.append(decode_field(label, encoded, numeric=index in numeric_fields.get(event, set()),
                                           nonempty=event.endswith("runtime-exception") and index == 0))
        grouped_rows[fixture].append(row)
        decoded[fixture][component].append((event, values, int(sequence_text)))

    for fixture in ("zero", "one"):
        requested, process_exit, total, input_count, output_count, digest = parsed_cases[fixture]
        rows = grouped_rows[fixture]
        require("case-total-count-match", len(rows) == total)
        require("case-component-count-match",
                sum(row.startswith("TRACE|") for row in rows) == input_count
                and sum(row.startswith("OUTTRACE|") for row in rows) == output_count
                and input_count + output_count == total)
        material = ("\n".join(rows) + ("\n" if rows else "")).encode("utf-8")
        require("case-digest-match", hashlib.sha256(material).hexdigest() == digest)
        raw_log = root / f"{fixture}.raw.log"
        require("raw-log-required", raw_log.is_file())
        raw_traces = [line for line in raw_log.read_text(encoding="utf-8").splitlines()
                      if line.startswith("TRACE|") or line.startswith("OUTTRACE|")]
        require("raw-log-trace-match", raw_traces == rows)

        for component, expected_count in (("input", input_count), ("output", output_count)):
            sequences = [sequence for _, _, sequence in decoded[fixture][component]]
            require(f"{component}-sequence-contiguous", sequences == list(range(1, expected_count + 1)))

        input_events = decoded[fixture]["input"]
        output_events = decoded[fixture]["output"]
        input_names = [event for event, _, _ in input_events]
        output_names = [event for event, _, _ in output_events]
        require("input-transaction-boundary",
                "transaction-entry" in input_names and "control-run-before" in input_names)
        require("output-transaction-boundary",
                "transaction-entry" in output_names and "control-run-before" in output_names)

        input_transaction_position = input_names.index("transaction-entry")
        input_control_position = input_names.index("control-run-before")
        require("input-local-transaction-order", input_transaction_position < input_control_position)
        output_transaction_position = output_names.index("transaction-entry")
        output_control_position = output_names.index("control-run-before")
        require("output-local-transaction-order", output_transaction_position < output_control_position)

        for event, values, _ in input_events:
            if event in {"transaction-entry", "control-run-before", "control-run-normal-return",
                         "transaction-normal-return", "cleanup-entry", "cleanup-normal-return",
                         "resume-entry", "resume-normal-return"}:
                require("input-requested-count-consistency", int(values[0]) == requested)

        output_transaction = next(values for event, values, _ in output_events if event == "transaction-entry")
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
        for event, values, _ in output_events:
            if event in count_schema_events:
                require("output-task-count-consistency", int(values[0]) == output_task_count)
                require("output-schema-count-consistency", int(values[1]) == output_schema_count)
            if event in indexed_events:
                require("output-schema-count-consistency", int(values[1]) == output_schema_count)
                require("output-index-range", output_task_count > 0 and int(values[0]) < output_task_count)

        opened_at = {}
        for event, values, sequence in output_events:
            if event == "open-normal-return":
                opened_at.setdefault(values[0], sequence)
            if event in {"add-entry", "add-normal-return", "finish-entry", "finish-normal-return",
                         "commit-entry", "commit-normal-return", "abort-entry", "abort-normal-return",
                         "close-entry", "close-normal-return"}:
                require("output-prior-open", values[0] in opened_at and opened_at[values[0]] < sequence)

        transaction_report_values = [int(values[2]) for event, values, _ in output_events
                                     if event in {"control-run-normal-return", "transaction-normal-return"}]
        if transaction_report_values:
            require("output-report-count-consistency",
                    all(value == transaction_report_values[0] for value in transaction_report_values))
        resume_report_values = [int(values[2]) for event, values, _ in output_events
                                if event in {"resume-control-run-normal-return", "resume-normal-return"}]
        if resume_report_values:
            require("output-resume-report-count-consistency",
                    all(value == resume_report_values[0] for value in resume_report_values))

        require("unexpected-add", "add-entry" not in output_names and "add-normal-return" not in output_names)

        for callback in ("open", "finish", "commit", "abort", "close", "cleanup"):
            balances = {}
            for event, values, _ in output_events:
                if event not in {f"{callback}-entry", f"{callback}-normal-return"}:
                    continue
                key = tuple(values)
                balances.setdefault(key, 0)
                if event.endswith("-entry"):
                    balances[key] += 1
                else:
                    balances[key] -= 1
                    require("output-callback-pair", balances[key] >= 0)
            require("output-callback-pair", all(balance == 0 for balance in balances.values()))

        input_transaction_exception = "transaction-runtime-exception" in input_names
        input_run_exception = "run-runtime-exception" in input_names
        output_transaction_exception = "transaction-runtime-exception" in output_names
        output_resume_exception = "resume-runtime-exception" in output_names
        require("input-transaction-contradiction", not (input_transaction_exception and
                ("control-run-normal-return" in input_names or "transaction-normal-return" in input_names)))
        require("input-run-contradiction", not (input_run_exception and
                ("finish-normal-return" in input_names or "run-normal-return" in input_names)))
        require("output-transaction-contradiction", not (output_transaction_exception and
                ("control-run-normal-return" in output_names or "transaction-normal-return" in output_names)))
        require("output-resume-contradiction", not (output_resume_exception and
                ("resume-control-run-normal-return" in output_names or "resume-normal-return" in output_names)))
        if input_transaction_exception:
            require("input-local-exception-order",
                    input_control_position < input_names.index("transaction-runtime-exception"))
        if output_transaction_exception:
            require("output-local-exception-order",
                    output_control_position < output_names.index("transaction-runtime-exception"))

        exceptions = [(component, event, values) for component in ("input", "output")
                      for event, values, _ in decoded[fixture][component] if event.endswith("runtime-exception")]
        if process_exit != 0:
            require("nonzero-exception", bool(exceptions))
            if fixture == "zero":
                require("zero-output-transaction-exception", output_transaction_exception)
                require("zero-input-propagated-exception", input_transaction_exception)

        if any(event.startswith("resume") for event in output_names):
            require("output-resume-boundary", "resume-entry" in output_names and
                    "resume-control-run-before" in output_names)
            if not output_resume_exception:
                require("output-resume-normal-return", "resume-control-run-normal-return" in output_names and
                        "resume-normal-return" in output_names)

        if process_exit == 0:
            require("zero-exit-no-exception", not exceptions)
            require("input-normal-transaction", "control-run-normal-return" in input_names and
                    "transaction-normal-return" in input_names)
            require("output-normal-transaction", "control-run-normal-return" in output_names and
                    "transaction-normal-return" in output_names)
            require("input-local-normal-order", input_control_position < input_names.index("control-run-normal-return") <
                    input_names.index("transaction-normal-return"))
            require("output-local-normal-order", output_control_position < output_names.index("control-run-normal-return") <
                    output_names.index("transaction-normal-return"))

    one_input_names = [event for event, _, _ in decoded["one"]["input"]]
    one_output_names = [event for event, _, _ in decoded["one"]["output"]]
    require("one-process-success", parsed_cases["one"][1] == 0)
    require("one-input-finish-before", "finish-before" in one_input_names)
    require("one-input-positive", all(event in one_input_names for event in
            ("run-entry", "finish-normal-return", "run-normal-return", "control-run-normal-return",
             "transaction-normal-return")))
    input_positive_order = ["transaction-entry", "control-run-before", "run-entry", "finish-before",
                            "finish-normal-return", "run-normal-return", "control-run-normal-return",
                            "transaction-normal-return"]
    require("one-input-positive-order",
            [one_input_names.index(event) for event in input_positive_order]
            == sorted(one_input_names.index(event) for event in input_positive_order))
    require("one-output-positive", all(event in one_output_names for event in
            ("open-entry", "open-normal-return", "finish-entry", "finish-normal-return",
             "control-run-normal-return", "transaction-normal-return")))
except (InvalidEvidence, OSError, UnicodeError) as failure:
    label = failure.args[0] if failure.args else "unclassified"
    print(f"VALIDATION_ERROR|{label}", file=sys.stderr)
    sys.exit(4)
PY
}

validate "$evidence"

mutated_copy() {
  local mutation=$1 copy
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-output-validator.XXXXXX")
  cp "$evidence/cases.raw" "$evidence/traces.raw" "$evidence/zero.raw.log" "$evidence/one.raw.log" "$copy/"
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

def next_sequence(fixture, tag):
    return max(int(row.split("|")[2]) for row in traces if row.startswith(f"{tag}|{fixture}|")) + 1

def renumber(fixture, tag):
    sequence = 0
    for index, row in enumerate(traces):
        if not row.startswith(f"{tag}|{fixture}|"):
            continue
        sequence += 1
        parts = row.split("|")
        parts[2] = str(sequence)
        traces[index] = "|".join(parts)

def synchronize():
    for fixture in ("zero", "one"):
        rows = fixture_rows(fixture)
        path = root / f"{fixture}.raw.log"
        other = [line for line in path.read_text(encoding="utf-8").splitlines()
                 if not line.startswith("TRACE|") and not line.startswith("OUTTRACE|")]
        path.write_text("\n".join(rows + other) + "\n", encoding="utf-8")
    for index, row in enumerate(cases):
        parts = row.split("|")
        if len(parts) != 5 or parts[0] != "CASE" or parts[1] not in {"zero", "one"}:
            continue
        rows = fixture_rows(parts[1])
        input_count = sum(item.startswith("TRACE|") for item in rows)
        output_count = sum(item.startswith("OUTTRACE|") for item in rows)
        material = ("\n".join(rows) + ("\n" if rows else "")).encode("utf-8")
        parts[4] = f"{len(rows)}:{input_count}:{output_count}:{hashlib.sha256(material).hexdigest()}"
        cases[index] = "|".join(parts)

if action == "missing-case":
    cases.pop()
elif action == "duplicate-case":
    cases.append(cases[0])
elif action == "truncated-trace":
    traces[0] = "OUTTRACE"
elif action == "unknown-output-event":
    traces.append(f"OUTTRACE|one|{next_sequence('one', 'OUTTRACE')}|invented")
    synchronize()
elif action == "bad-output-arity":
    traces.append(f"OUTTRACE|one|{next_sequence('one', 'OUTTRACE')}|open-entry|MA==")
    synchronize()
elif action == "bad-output-b64":
    index = next(i for i, row in enumerate(traces) if row.startswith("OUTTRACE|one|") and "|open-entry|" in row)
    parts = traces[index].split("|")
    parts[4] = "!"
    traces[index] = "|".join(parts)
    synchronize()
elif action == "malformed-output-count":
    index = next(i for i, row in enumerate(traces) if row.startswith("OUTTRACE|one|") and "|transaction-entry|" in row)
    parts = traces[index].split("|")
    parts[4] = base64.b64encode(b"not-a-count").decode("ascii")
    traces[index] = "|".join(parts)
    synchronize()
elif action == "mismatched-output-count":
    index = next(i for i, row in enumerate(traces) if row.startswith("OUTTRACE|one|") and "|control-run-before|" in row)
    parts = traces[index].split("|")
    parts[4] = base64.b64encode(str(int(base64.b64decode(parts[4])) + 1).encode()).decode("ascii")
    traces[index] = "|".join(parts)
    synchronize()
elif action == "mismatched-schema-count":
    index = next(i for i, row in enumerate(traces) if row.startswith("OUTTRACE|one|") and "|open-entry|" in row)
    parts = traces[index].split("|")
    parts[5] = base64.b64encode(b"1").decode("ascii")
    traces[index] = "|".join(parts)
    synchronize()
elif action == "mismatched-report-count":
    index = next(i for i, row in enumerate(traces) if row.startswith("OUTTRACE|one|") and "|transaction-normal-return|" in row)
    parts = traces[index].split("|")
    parts[6] = base64.b64encode(str(int(base64.b64decode(parts[6])) + 1).encode()).decode("ascii")
    traces[index] = "|".join(parts)
    synchronize()
elif action == "input-local-order":
    transaction = next(i for i, row in enumerate(traces) if row.startswith("TRACE|one|") and "|transaction-entry|" in row)
    control = next(i for i, row in enumerate(traces) if row.startswith("TRACE|one|") and "|control-run-before|" in row)
    transaction_parts = traces[transaction].split("|")
    control_parts = traces[control].split("|")
    transaction_parts[3], control_parts[3] = control_parts[3], transaction_parts[3]
    traces[transaction] = "|".join(transaction_parts)
    traces[control] = "|".join(control_parts)
    synchronize()
elif action == "output-local-order":
    transaction = next(i for i, row in enumerate(traces) if row.startswith("OUTTRACE|one|") and "|transaction-entry|" in row)
    control = next(i for i, row in enumerate(traces) if row.startswith("OUTTRACE|one|") and "|control-run-before|" in row)
    transaction_parts = traces[transaction].split("|")
    control_parts = traces[control].split("|")
    transaction_parts[3], control_parts[3] = control_parts[3], transaction_parts[3]
    traces[transaction] = "|".join(transaction_parts)
    traces[control] = "|".join(control_parts)
    synchronize()
elif action == "malformed-index":
    index = next(i for i, row in enumerate(traces) if row.startswith("OUTTRACE|one|") and "|open-entry|" in row)
    parts = traces[index].split("|")
    parts[4] = base64.b64encode(b"not-an-index").decode("ascii")
    traces[index] = "|".join(parts)
    synchronize()
elif action == "out-of-range-index":
    output_count_row = next(row for row in traces if row.startswith("OUTTRACE|one|") and "|transaction-entry|" in row)
    output_count = output_count_row.split("|")[4]
    index = next(i for i, row in enumerate(traces) if row.startswith("OUTTRACE|one|") and "|open-entry|" in row)
    parts = traces[index].split("|")
    parts[4] = output_count
    traces[index] = "|".join(parts)
    synchronize()
elif action == "duplicate-output-sequence":
    indexes = [i for i, row in enumerate(traces) if row.startswith("OUTTRACE|one|")]
    parts = traces[indexes[1]].split("|")
    parts[2] = traces[indexes[0]].split("|")[2]
    traces[indexes[1]] = "|".join(parts)
    synchronize()
elif action == "duplicate-output-trace":
    traces.append(next(row for row in traces if row.startswith("OUTTRACE|one|") and "|open-entry|" in row))
    synchronize()
elif action == "output-transaction-contradiction":
    traces.append(f"OUTTRACE|one|{next_sequence('one', 'OUTTRACE')}|transaction-runtime-exception|amF2YS5sYW5nLlJ1bnRpbWVFeGNlcHRpb24=|-")
    synchronize()
elif action == "unexpected-add":
    sequence = next_sequence("one", "OUTTRACE")
    traces += [f"OUTTRACE|one|{sequence}|add-entry|MA==|MA==",
               f"OUTTRACE|one|{sequence + 1}|add-normal-return|MA==|MA=="]
    synchronize()
elif action == "missing-output-return":
    sequence = next_sequence("one", "OUTTRACE")
    close = next(row for row in traces if row.startswith("OUTTRACE|one|") and "|close-entry|" in row).split("|")
    traces.append(f"OUTTRACE|one|{sequence}|close-entry|{close[4]}|{close[5]}")
    synchronize()
elif action == "missing-input-finish-before":
    traces = [row for row in traces if not (row.startswith("TRACE|one|") and "|finish-before|" in row)]
    renumber("one", "TRACE")
    synchronize()
elif action == "missing-matching-open":
    open_row = next(row for row in traces if row.startswith("OUTTRACE|one|") and "|open-entry|" in row)
    open_index = open_row.split("|")[4]
    traces = [row for row in traces if not (row.startswith("OUTTRACE|one|") and
              ("|open-entry|" in row or "|open-normal-return|" in row) and row.split("|")[4] == open_index)]
    renumber("one", "OUTTRACE")
    synchronize()
elif action in {"null-message", "empty-message", "empty-class", "nonzero-no-exception",
                "unrelated-output-exception", "missing-input-propagation"}:
    input_class = "amF2YS5sYW5nLlJ1bnRpbWVFeGNlcHRpb24="
    output_class = "" if action == "empty-class" else input_class
    message = "-" if action == "null-message" else ""
    synthetic = [
        "TRACE|zero|1|transaction-entry|MA==",
        "TRACE|zero|2|control-run-before|MA==",
        "OUTTRACE|zero|1|transaction-entry|MA==|MA==",
        "OUTTRACE|zero|2|control-run-before|MA==|MA==",
    ]
    if action not in {"nonzero-no-exception", "unrelated-output-exception"}:
        synthetic.append(f"OUTTRACE|zero|3|transaction-runtime-exception|{output_class}|{message}")
    if action == "unrelated-output-exception":
        synthetic.append(f"OUTTRACE|zero|3|resume-runtime-exception|{output_class}|{message}")
    if action not in {"nonzero-no-exception", "missing-input-propagation"}:
        synthetic.append(f"TRACE|zero|3|transaction-runtime-exception|{input_class}|{message}")
    traces = synthetic + fixture_rows("one")
    cases = [row if not row.startswith("CASE|zero|") else "CASE|zero|0|1|pending" for row in cases]
    synchronize()
elif action == "case-total-corrupt":
    index = next(i for i, row in enumerate(cases) if row.startswith("CASE|one|"))
    parts = cases[index].split("|")
    summary = parts[4].split(":")
    summary[0] = str(int(summary[0]) + 1)
    parts[4] = ":".join(summary)
    cases[index] = "|".join(parts)
elif action == "case-component-corrupt":
    index = next(i for i, row in enumerate(cases) if row.startswith("CASE|one|"))
    parts = cases[index].split("|")
    summary = parts[4].split(":")
    summary[1] = str(int(summary[1]) + 1)
    parts[4] = ":".join(summary)
    cases[index] = "|".join(parts)
elif action == "digest-corrupt":
    index = next(i for i, row in enumerate(cases) if row.startswith("CASE|one|"))
    parts = cases[index].split("|")
    summary = parts[4].split(":")
    summary[3] = "0" * 64
    parts[4] = ":".join(summary)
    cases[index] = "|".join(parts)
elif action == "missing-raw-log":
    root.joinpath("zero.raw.log").unlink()
elif action == "raw-log-mismatch":
    path = root / "one.raw.log"
    lines = path.read_text(encoding="utf-8").splitlines()
    lines = [line for line in lines if not (line.startswith("OUTTRACE|") and "|close-normal-return|" in line)]
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
  printf 'T0013_OUTPUT_MUTATION=%s|evidence=%s\n' "$mutation" "$copy"
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
  printf 'T0013_OUTPUT_MUTATION=%s|evidence=%s\n' "$mutation" "$copy"
  validate "$copy"
}

validator_fails missing-case case-count
validator_fails duplicate-case case-count
validator_fails truncated-trace trace-minimum-arity
validator_fails unknown-output-event output-event-known
validator_fails bad-output-arity output-event-arity
validator_fails bad-output-b64 output-canonical-field
validator_fails malformed-output-count output-canonical-field
validator_fails mismatched-output-count output-task-count-consistency
validator_fails mismatched-schema-count output-schema-count-consistency
validator_fails mismatched-report-count output-report-count-consistency
validator_fails input-local-order input-local-transaction-order
validator_fails output-local-order output-local-transaction-order
validator_fails malformed-index output-canonical-field
validator_fails out-of-range-index output-index-range
validator_fails duplicate-output-sequence output-sequence-contiguous
validator_fails duplicate-output-trace output-sequence-contiguous
validator_fails output-transaction-contradiction output-transaction-contradiction
validator_fails unexpected-add unexpected-add
validator_fails missing-output-return output-callback-pair
validator_fails missing-input-finish-before one-input-finish-before
validator_fails missing-matching-open output-prior-open
validator_fails empty-class output-exception-class
validator_fails nonzero-no-exception nonzero-exception
validator_fails unrelated-output-exception zero-output-transaction-exception
validator_fails missing-input-propagation zero-input-propagated-exception
validator_fails case-total-corrupt case-total-count-match
validator_fails case-component-corrupt case-component-count-match
validator_fails digest-corrupt case-digest-match
validator_fails missing-raw-log raw-log-required
validator_fails raw-log-mismatch raw-log-trace-match
validator_accepts null-message
validator_accepts empty-message

printf 'T0013_OUTPUT_FULL_PROBE=passed|evidence=%s\n' "$evidence"

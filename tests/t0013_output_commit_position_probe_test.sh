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
  python3 - "$1" <<'PY'
import base64
import binascii
import hashlib
import pathlib
import sys
import uuid

root = pathlib.Path(sys.argv[1])
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
except (InvalidEvidence, OSError, UnicodeError) as error:
    label = error.args[0] if error.args else "unclassified"
    print(f"CAPTURE_VALIDATION_ERROR|{label}", file=sys.stderr)
    sys.exit(4)
PY
}

case ${1:-} in
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
    validate_capture "$evidence"
    printf 'T0013_POSITION_CAPTURE_ONLY=collected|evidence=%s\n' "$evidence"
    ;;
  *)
    printf '%s\n' 'Stage A requires --artifact-controls-only or --capture-only' >&2
    exit 2
    ;;
esac

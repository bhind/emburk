#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0013-input-lifecycle/run.sh"
[[ -x "$runner" ]] || exit 2

run_negative() {
  local control=$1 expected=$2 label=$3 output status evidence
  if output=$(T0013_NEGATIVE="$control" "$runner" 2>&1); then
    exit 1
  else
    status=$?
  fi
  [[ "$status" == "$expected" ]] || exit 1
  evidence=$(printf '%s\n' "$output" | sed -n 's/^T0013_EVIDENCE_DIR=//p' | tail -1)
  [[ -n "$evidence" && -d "$evidence" ]] || exit 1
  grep -Fqx "$label" "$evidence/negative-control.txt" || exit 1
  printf 'T0013_NEGATIVE_CONTROL=%s|exit=%s|evidence=%s\n' "$control" "$status" "$evidence"
}

run_negative corrupt-copy 3 corrupt-copy-injected
run_negative unavailable-asset 56 unavailable-asset-request-failed

output=$("$runner")
printf '%s\n' "$output"
evidence=$(printf '%s\n' "$output" | sed -n 's/^T0013_EVIDENCE_DIR=//p' | tail -1)
[[ -n "$evidence" && -d "$evidence" ]] || exit 1
for file in executable.sha256 executable-url.txt LICENSE-executable NOTICE-executable java-version.txt \
  plugin-source.sha256 plugin-jar.sha256 plugin-coordinate.txt cases.raw traces.raw zero.raw.log one.raw.log; do
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

def field(label, value, *, numeric=False, nonempty=False):
    require(label, value != "-")
    try:
        raw = base64.b64decode(value, validate=True)
        text = raw.decode("utf-8")
    except (binascii.Error, UnicodeError):
        raise InvalidEvidence(label)
    require(label, base64.b64encode(raw).decode("ascii") == value)
    if nonempty:
        require(label, text != "")
    if numeric:
        decimal(label, text)
    return text

try:
    require("cases-readable", root.joinpath("cases.raw").is_file())
    require("traces-readable", root.joinpath("traces.raw").is_file())
    cases = root.joinpath("cases.raw").read_text(encoding="utf-8").splitlines()
    traces = root.joinpath("traces.raw").read_text(encoding="utf-8").splitlines()
    require("case-count", len(cases) == 2)

    parsed = {}
    for row in cases:
        parts = row.split("|")
        require("case-arity", len(parts) == 5)
        tag, fixture, requested, process_exit, summary = parts
        require("case-tag", tag == "CASE")
        require("case-fixture", fixture in {"zero", "one"})
        require("case-duplicate", fixture not in parsed)
        event_count_text, separator, digest = summary.partition(":")
        require("case-summary", separator == ":")
        event_count = decimal("case-event-count", event_count_text)
        exit_code = decimal("case-process-exit", process_exit)
        require("case-digest-format", len(digest) == 64 and all(c in "0123456789abcdef" for c in digest))
        parsed[fixture] = (requested, exit_code, event_count, digest)
    require("case-fixtures", set(parsed) == {"zero", "one"})
    require("requested-count", parsed["zero"][0] == "0" and parsed["one"][0] == "1")

    arity = {
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
    count_events = {
        "transaction-entry", "control-run-before", "control-run-normal-return",
        "transaction-normal-return", "cleanup-entry", "cleanup-normal-return", "resume-entry",
        "resume-normal-return",
    }
    index_events = {"run-entry", "finish-before", "finish-normal-return", "run-normal-return"}
    grouped = {"zero": [], "one": []}
    decoded_events = {"zero": [], "one": []}
    for row in traces:
        parts = row.split("|")
        require("trace-arity-minimum", len(parts) >= 4)
        tag, fixture, sequence, event = parts[:4]
        require("trace-tag", tag == "TRACE")
        require("trace-fixture", fixture in grouped)
        decimal("trace-sequence", sequence)
        require("event-known", event in arity)
        require("event-arity", len(parts) == 4 + arity[event])
        values = []
        for index, encoded in enumerate(parts[4:]):
            if encoded == "-":
                require("null-field-position", event.endswith("runtime-exception") and index == 1)
                values.append(None)
            else:
                numeric = ((event in count_events and index == 0)
                           or (event == "cleanup-entry" and index == 1)
                           or (event in index_events and index == 0))
                label = "exception-class-field" if event.endswith("runtime-exception") and index == 0 else "canonical-field"
                values.append(field(label, encoded, numeric=numeric,
                                    nonempty=event.endswith("runtime-exception") and index == 0))
        grouped[fixture].append(row)
        decoded_events[fixture].append((event, values))

    for fixture in ("zero", "one"):
        requested, exit_code, event_count, digest = parsed[fixture]
        actual = grouped[fixture]
        require("case-event-count-match", len(actual) == event_count)
        material = ("\n".join(actual) + ("\n" if actual else "")).encode("utf-8")
        require("case-digest-match", hashlib.sha256(material).hexdigest() == digest)
        raw_log = root / f"{fixture}.raw.log"
        require("raw-log-required", raw_log.is_file())
        extracted = [line for line in raw_log.read_text(encoding="utf-8").splitlines() if line.startswith("TRACE|")]
        require("raw-log-trace-match", extracted == actual)
        sequences = [decimal("trace-sequence", row.split("|")[2]) for row in actual]
        require("trace-sequence-contiguous", sequences == list(range(1, event_count + 1)))

        events = [name for name, _ in decoded_events[fixture]]
        require("transaction-entry-required", "transaction-entry" in events)
        require("control-entry-required", "control-run-before" in events)
        for name, values in decoded_events[fixture]:
            if name in count_events:
                require("event-requested-count", values[0] == requested)

        transaction_exception = "transaction-runtime-exception" in events
        run_exception = "run-runtime-exception" in events
        require("transaction-contradiction", not (transaction_exception and "transaction-normal-return" in events))
        require("control-contradiction", not (transaction_exception and "control-run-normal-return" in events))
        require("run-contradiction", not (run_exception and "run-normal-return" in events))
        require("finish-contradiction", not (run_exception and "finish-normal-return" in events))
        exceptions = [values for name, values in decoded_events[fixture] if name.endswith("runtime-exception")]
        require("exception-class", all(values[0] is not None and values[0] != "" for values in exceptions))
        if exit_code == 0:
            require("zero-exit-no-exception", not exceptions)
            require("zero-exit-control-return", "control-run-normal-return" in events)
            require("zero-exit-transaction-return", "transaction-normal-return" in events)
        else:
            require("nonzero-exception", bool(exceptions))
            if fixture == "zero":
                require("zero-nonzero-transaction-exception", transaction_exception)

    one_events = [name for name, _ in decoded_events["one"]]
    require("one-process-success", parsed["one"][1] == 0)
    required_one = ["run-entry", "finish-before", "finish-normal-return", "run-normal-return",
                    "control-run-normal-return", "transaction-normal-return"]
    require("one-positive-markers", all(name in one_events for name in required_one))
    require("one-positive-order", [one_events.index(name) for name in required_one] == sorted(one_events.index(name) for name in required_one))
except (InvalidEvidence, OSError, UnicodeError) as failure:
    label = failure.args[0] if failure.args else "unclassified"
    print(f"VALIDATION_ERROR|{label}", file=sys.stderr)
    sys.exit(4)
PY
}

validate "$evidence"

mutated_copy() {
  local mutation=$1 copy
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-trace-validator.XXXXXX")
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

def next_sequence(fixture):
    return max(int(row.split("|")[2]) for row in traces if row.startswith(f"TRACE|{fixture}|")) + 1

def regroup_and_rehash():
    grouped = {fixture: [row for row in traces if row.split("|")[1] == fixture] for fixture in ("zero", "one")}
    for fixture, rows in grouped.items():
        path = root / f"{fixture}.raw.log"
        nontrace = [line for line in path.read_text(encoding="utf-8").splitlines() if not line.startswith("TRACE|")]
        path.write_text("\n".join(rows + nontrace) + "\n", encoding="utf-8")
    for index, row in enumerate(cases):
        parts = row.split("|")
        if len(parts) == 5 and parts[0] == "CASE" and parts[1] in grouped:
            rows = grouped[parts[1]]
            material = ("\n".join(rows) + ("\n" if rows else "")).encode("utf-8")
            parts[4] = f"{len(rows)}:{hashlib.sha256(material).hexdigest()}"
            cases[index] = "|".join(parts)

if action == "missing-case":
    cases.pop()
elif action == "duplicate-case":
    cases.append(cases[0])
elif action == "truncated-trace":
    traces[0] = "TRACE"
elif action == "unknown-event":
    traces.append(f"TRACE|one|{next_sequence('one')}|invented-event")
    regroup_and_rehash()
elif action == "bad-arity":
    traces.append(f"TRACE|one|{next_sequence('one')}|run-entry")
    regroup_and_rehash()
elif action == "bad-b64":
    index = next(i for i, row in enumerate(traces) if "|run-entry|" in row)
    parts = traces[index].split("|")
    parts[4] = "!"
    traces[index] = "|".join(parts)
    regroup_and_rehash()
elif action == "bad-count":
    index = next(i for i, row in enumerate(traces) if row.startswith("TRACE|one|") and "|transaction-entry|" in row)
    parts = traces[index].split("|")
    parts[4] = base64.b64encode(b"2").decode("ascii")
    traces[index] = "|".join(parts)
    regroup_and_rehash()
elif action == "malformed-count":
    index = next(i for i, row in enumerate(traces) if row.startswith("TRACE|one|") and "|transaction-entry|" in row)
    parts = traces[index].split("|")
    parts[4] = base64.b64encode(b"not-a-count").decode("ascii")
    traces[index] = "|".join(parts)
    regroup_and_rehash()
elif action == "bad-sequence":
    one_indexes = [i for i, row in enumerate(traces) if row.startswith("TRACE|one|")]
    index = one_indexes[1]
    parts = traces[index].split("|")
    parts[2] = traces[one_indexes[0]].split("|")[2]
    traces[index] = "|".join(parts)
    regroup_and_rehash()
elif action == "duplicate-trace":
    row = [row for row in traces if row.startswith("TRACE|one|")][1]
    traces.append(row)
    regroup_and_rehash()
elif action == "contradiction":
    traces.append(f"TRACE|one|{next_sequence('one')}|run-runtime-exception|amF2YS5sYW5nLlJ1bnRpbWVFeGNlcHRpb24=|-")
    regroup_and_rehash()
elif action in {"null-message", "empty-message", "empty-class", "no-exception-nonzero", "unrelated-exception-nonzero"}:
    traces = [row for row in traces if not row.startswith("TRACE|zero|")]
    synthetic = ["TRACE|zero|1|transaction-entry|MA==", "TRACE|zero|2|control-run-before|MA=="]
    if action != "no-exception-nonzero":
        kind = "" if action == "empty-class" else "amF2YS5sYW5nLlJ1bnRpbWVFeGNlcHRpb24="
        message = "-" if action == "null-message" else ""
        event = "run-runtime-exception" if action == "unrelated-exception-nonzero" else "transaction-runtime-exception"
        synthetic.append(f"TRACE|zero|3|{event}|{kind}|{message}")
    traces = synthetic + traces
    cases = [row if not row.startswith("CASE|zero|") else "CASE|zero|0|1|pending" for row in cases]
    regroup_and_rehash()
elif action == "event-count-corrupt":
    index = next(i for i, row in enumerate(cases) if row.startswith("CASE|one|"))
    parts = cases[index].split("|")
    count, digest = parts[4].split(":")
    parts[4] = f"{int(count) + 1}:{digest}"
    cases[index] = "|".join(parts)
elif action == "digest-corrupt":
    index = next(i for i, row in enumerate(cases) if row.startswith("CASE|one|"))
    parts = cases[index].split("|")
    count, _ = parts[4].split(":")
    parts[4] = f"{count}:{'0' * 64}"
    cases[index] = "|".join(parts)
elif action == "missing-raw-log":
    root.joinpath("zero.raw.log").unlink()
else:
    raise ValueError(action)

root.joinpath("cases.raw").write_text("\n".join(cases) + "\n", encoding="utf-8")
root.joinpath("traces.raw").write_text("\n".join(traces) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$copy"
}

validator_fails() {
  local mutation=$1 expected=$2 copy output status
  copy=$(mutated_copy "$mutation")
  printf 'T0013_TRACE_MUTATION=%s|evidence=%s\n' "$mutation" "$copy"
  if output=$(validate "$copy" 2>&1); then
    exit 1
  else
    status=$?
  fi
  [[ "$status" == 4 ]] || exit 1
  [[ "$output" == "VALIDATION_ERROR|$expected" ]] || {
    printf 'unexpected validator result for %s: %s\n' "$mutation" "$output" >&2
    exit 1
  }
}

validator_accepts() {
  local mutation=$1 copy
  copy=$(mutated_copy "$mutation")
  printf 'T0013_TRACE_MUTATION=%s|evidence=%s\n' "$mutation" "$copy"
  validate "$copy"
}

validator_fails missing-case case-count
validator_fails duplicate-case case-count
validator_fails truncated-trace trace-arity-minimum
validator_fails unknown-event event-known
validator_fails bad-arity event-arity
validator_fails bad-b64 canonical-field
validator_fails bad-count event-requested-count
validator_fails malformed-count canonical-field
validator_fails bad-sequence trace-sequence-contiguous
validator_fails duplicate-trace trace-sequence-contiguous
validator_fails contradiction run-contradiction
validator_fails empty-class exception-class-field
validator_fails no-exception-nonzero nonzero-exception
validator_fails unrelated-exception-nonzero zero-nonzero-transaction-exception
validator_fails event-count-corrupt case-event-count-match
validator_fails digest-corrupt case-digest-match
validator_fails missing-raw-log raw-log-required
validator_accepts null-message
validator_accepts empty-message

printf 'T0013_FULL_PROBE=passed|evidence=%s\n' "$evidence"

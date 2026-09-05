#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
driver="$root/tools/t0013-empty-lifecycle-differential"
evidence_dir=${T0013_S04_EVIDENCE_DIR:-$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-s04.XXXXXX")}
mkdir -p -- "$evidence_dir"
printf 'T0013_S04_EVIDENCE_DIR=%s\n' "$evidence_dir"
[[ -x "$driver" ]] || exit 2

"$driver" --self-test > "$evidence_dir/python-self-test.log" 2>&1
cargo test --manifest-path "$root/Cargo.toml" -p emburk-core \
  empty_lifecycle::tests::differential_tests::differential_manifest_rejects_invalid_or_mutated_outcomes \
  -- --exact > "$evidence_dir/rust-negative-controls.log" 2>&1
grep -Fqx 'test empty_lifecycle::tests::differential_tests::differential_manifest_rejects_invalid_or_mutated_outcomes ... ok' \
  "$evidence_dir/rust-negative-controls.log"
grep -Eq '^test result: ok\. 1 passed; 0 failed; 0 ignored; .* filtered out;' \
  "$evidence_dir/rust-negative-controls.log"

"$driver" \
  --manifest "$evidence_dir/live.tsv" \
  --evidence-manifest "$evidence_dir/driver-evidence-manifest.txt" \
  --raw-hashes "$evidence_dir/raw-evidence-hashes.txt" \
  --probe-stdout "$evidence_dir/s03-full-probe.stdout.log" \
  --probe-stderr "$evidence_dir/s03-full-probe.stderr.log" \
  > "$evidence_dir/driver.log" 2>&1
grep -Fqx 'T0013_S04_PROJECTED_CASES=2' "$evidence_dir/driver.log"
[[ $(grep -c $'^CASE\t' "$evidence_dir/live.tsv") == 2 ]]
[[ $(grep -c '^T0013_FAILURE_FULL_PROBE=passed|evidence=' "$evidence_dir/s03-full-probe.stdout.log") == 1 ]]
for file in cases.raw traces.raw normal.raw.log failure.raw.log; do
  grep -Eq "^${file//./\\.}=[0-9a-f]{64}$" "$evidence_dir/raw-evidence-hashes.txt"
done

reference=$(sed -n 's/^evidence=//p' "$evidence_dir/driver-evidence-manifest.txt")
[[ -n "$reference" && -d "$reference" ]]

for mutation in missing missing-commit missing-abort missing-close reordered-excluded duplicate unknown malformed hash raw-log sequence cap index; do
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0013-s04-negative.XXXXXX")
  cp "$reference/cases.raw" "$reference/traces.raw" \
    "$reference/normal.raw.log" "$reference/failure.raw.log" "$copy/"
  python3 - "$mutation" "$copy" <<'PY'
import base64
import hashlib
import pathlib
import sys

action, directory = sys.argv[1:]
root = pathlib.Path(directory)
traces = root.joinpath("traces.raw").read_text(encoding="utf-8").splitlines()
cases = root.joinpath("cases.raw").read_text(encoding="utf-8").splitlines()

def select(fixture, component=None, event=None):
    for index, row in enumerate(traces):
        fields = row.split("|")
        if fields[1] != fixture:
            continue
        if component is not None and fields[0] != component:
            continue
        if event is not None and fields[4] != event:
            continue
        return index
    raise ValueError("mutation target absent")

def remove_and_renumber(fixture, component, event):
    index = select(fixture, component, event)
    capture = traces[index].split("|")[2]
    traces.pop(index)
    sequence = 0
    for row_index, row in enumerate(traces):
        fields = row.split("|")
        if fields[0] == component and fields[1] == fixture and fields[2] == capture:
            sequence += 1
            fields[3] = str(sequence)
            traces[row_index] = "|".join(fields)

if action == "missing":
    remove_and_renumber("normal", "FAILTRACE", "cleanup-entry")
elif action == "missing-commit":
    remove_and_renumber("normal", "FAILOUTTRACE", "commit-normal-return")
elif action == "missing-abort":
    remove_and_renumber("failure", "FAILOUTTRACE", "abort-normal-return")
elif action == "missing-close":
    remove_and_renumber("failure", "FAILOUTTRACE", "close-normal-return")
elif action == "reordered-excluded":
    before = select("normal", "FAILTRACE", "finish-before")
    returned = select("normal", "FAILTRACE", "finish-normal-return")
    row = traces.pop(before)
    if before < returned:
        returned -= 1
    traces.insert(returned + 1, row)
    capture = row.split("|")[2]
    sequence = 0
    for row_index, trace in enumerate(traces):
        fields = trace.split("|")
        if fields[0] == "FAILTRACE" and fields[1] == "normal" and fields[2] == capture:
            sequence += 1
            fields[3] = str(sequence)
            traces[row_index] = "|".join(fields)
elif action == "duplicate":
    index = select("normal", "FAILTRACE", "run-entry")
    traces.insert(index + 1, traces[index])
elif action == "unknown":
    index = select("normal", "FAILTRACE", "run-entry")
    fields = traces[index].split("|"); fields[4] = "invented"; traces[index] = "|".join(fields)
elif action == "malformed":
    index = select("normal", "FAILTRACE", "run-entry")
    fields = traces[index].split("|"); fields[5] = "!"; traces[index] = "|".join(fields)
elif action == "sequence":
    index = select("normal", "FAILTRACE", "run-entry")
    fields = traces[index].split("|"); fields[3] = "1"; traces[index] = "|".join(fields)
elif action == "cap":
    index = select("normal", "FAILOUTTRACE", "transaction-entry")
    fields = traces[index].split("|"); fields[5] = base64.b64encode(b"1025").decode(); traces[index] = "|".join(fields)
elif action == "index":
    index = select("normal", "FAILOUTTRACE", "open-normal-return")
    fields = traces[index].split("|")
    transaction = traces[select("normal", "FAILOUTTRACE", "transaction-entry")].split("|")
    fields[5] = transaction[5]; traces[index] = "|".join(fields)

if action not in {"hash", "raw-log"}:
    for fixture in ("normal", "failure"):
        rows = [row for row in traces if row.split("|")[1] == fixture]
        path = root / f"{fixture}.raw.log"
        other = [line for line in path.read_text(encoding="utf-8").splitlines()
                 if not line.startswith("FAILTRACE|") and not line.startswith("FAILOUTTRACE|")]
        path.write_text("\n".join(rows + other) + "\n", encoding="utf-8")
        case_index = next(i for i, row in enumerate(cases) if row.startswith(f"CASE|{fixture}|"))
        fields = cases[case_index].split("|")
        input_count = sum(row.startswith("FAILTRACE|") for row in rows)
        output_count = sum(row.startswith("FAILOUTTRACE|") for row in rows)
        digest = hashlib.sha256(("\n".join(rows) + "\n").encode()).hexdigest()
        fields[4] = f"{len(rows)}:{input_count}:{output_count}:{digest}"
        cases[case_index] = "|".join(fields)
elif action == "hash":
    fields = cases[0].split("|"); summary = fields[4].split(":"); summary[3] = "0" * 64
    fields[4] = ":".join(summary); cases[0] = "|".join(fields)
else:
    path = root / "normal.raw.log"
    path.write_text(path.read_text(encoding="utf-8").replace("FAILTRACE|", "BROKENTRACE|", 1), encoding="utf-8")

root.joinpath("traces.raw").write_text("\n".join(traces) + "\n", encoding="utf-8")
root.joinpath("cases.raw").write_text("\n".join(cases) + "\n", encoding="utf-8")
PY
  if "$driver" --validate-only "$copy" --manifest "$copy/rejected.tsv" \
      > "$copy/driver.stdout.log" 2> "$copy/driver.stderr.log"; then
    printf 'mutation unexpectedly accepted: %s\n' "$mutation" >&2
    exit 1
  else
    code=$?
  fi
  [[ "$code" == 4 ]]
  case "$mutation" in
    missing)
      expected='T0013/S04 driver rejected evidence: input marker manifest is not exact'
      ;;
    missing-commit)
      expected='T0013/S04 driver rejected evidence: output commit-normal-return manifest is not exact'
      ;;
    missing-abort)
      expected='T0013/S04 driver rejected evidence: output abort-normal-return manifest is not exact'
      ;;
    missing-close)
      expected='T0013/S04 driver rejected evidence: output close-normal-return manifest is not exact'
      ;;
    reordered-excluded)
      expected='T0013/S04 driver rejected evidence: input callback boundary order differs'
      ;;
    *)
      expected=''
      ;;
  esac
  if [[ -n "$expected" ]]; then
    grep -Fqx "$expected" "$copy/driver.stderr.log"
  fi
  printf 'T0013_S04_RAW_MUTATION=%s|exit=%s|evidence=%s\n' "$mutation" "$code" "$copy"
done

T0013_S04_MANIFEST="$evidence_dir/live.tsv" cargo test --manifest-path "$root/Cargo.toml" \
  -p emburk-core empty_lifecycle::tests::differential_tests::live_empty_lifecycle_differential \
  -- --ignored --exact > "$evidence_dir/live-rust-test.log" 2>&1
grep -Fqx 'test empty_lifecycle::tests::differential_tests::live_empty_lifecycle_differential ... ok' \
  "$evidence_dir/live-rust-test.log"
grep -Eq '^test result: ok\. 1 passed; 0 failed; 0 ignored; .* filtered out;' \
  "$evidence_dir/live-rust-test.log"
printf '%s\n' 'T0013_S04_COMPARED_CASES=2'
printf '%s\n' 'T0013/S04: compared exactly 2 live empty-lifecycle projections; negative controls passed'

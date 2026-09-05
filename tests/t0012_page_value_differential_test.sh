#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
driver="$root/tools/t0012-page-value-differential"
evidence_dir=${T0012_S08_EVIDENCE_DIR:-$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-s08.XXXXXX")}
mkdir -p -- "$evidence_dir"
printf 'T0012_S08_EVIDENCE_DIR=%s\n' "$evidence_dir"

PYTHONPYCACHEPREFIX="$evidence_dir/pycache" python3 -m py_compile "$driver"
bash -n "$0"
cargo test --manifest-path "$root/Cargo.toml" -p emburk-core \
  logical_record::tests -- --nocapture > "$evidence_dir/rust-controls.log" 2>&1
grep -Fqx 'test logical_record::tests::live_tsv_bridge_rejects_header_case_dimension_and_order_errors ... ok' \
  "$evidence_dir/rust-controls.log"
grep -Eq '^test result: ok\. [1-9][0-9]* passed; 0 failed; 1 ignored; .* filtered out;' \
  "$evidence_dir/rust-controls.log"

"$driver" --output "$evidence_dir/live.tsv" \
  > "$evidence_dir/driver.stdout.log" 2> "$evidence_dir/driver.stderr.log"
[[ $(grep -Ec '^T0012_S08_PROJECTED_CASES=2\|evidence=.+\|manifest=.+' \
  "$evidence_dir/driver.stdout.log") == 1 ]]
[[ $(grep -c '^T0012_PAGE_FULL_PROBE=passed|evidence=' \
  "$evidence_dir/driver.stdout.log") == 1 ]]
raw_evidence=$(python3 - "$evidence_dir/driver.stdout.log" <<'PY'
import pathlib
import sys

prefix = "T0012_S08_PROJECTED_CASES=2|evidence="
lines = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
rows = [line for line in lines if line.startswith(prefix)]
if len(rows) != 1 or "|manifest=" not in rows[0]:
    raise SystemExit(1)
print(rows[0][len(prefix):].split("|manifest=", 1)[0])
PY
)
[[ -d "$raw_evidence" ]]
grep -Fqx $'T0012-S08\t1' "$evidence_dir/live.tsv"
[[ $(grep -c $'^CASE\t' "$evidence_dir/live.tsv") == 2 ]]
[[ $(grep -c $'^ROW\t' "$evidence_dir/live.tsv") == 3 ]]
[[ $(grep -c $'^CELL\t' "$evidence_dir/live.tsv") == 9 ]]

copy_raw() {
  local destination=$1
  mkdir -p -- "$destination"
  cp "$raw_evidence/page-cases.raw" "$raw_evidence/page-traces.raw" \
    "$raw_evidence/raw-evidence-hashes.txt" "$raw_evidence/empty.trace.raw" \
    "$raw_evidence/typed-null.trace.raw" "$raw_evidence/empty.raw.log" \
    "$raw_evidence/typed-null.raw.log" "$destination/"
}

mutated_copy() {
  local action=$1 fixture=${2:-typed-null} copy
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-s08-raw.XXXXXX")
  copy_raw "$copy"
  PYTHONDONTWRITEBYTECODE=1 python3 - "$action" "$fixture" "$copy" <<'PY'
import base64
import hashlib
import pathlib
import sys

action, fixture, directory = sys.argv[1:]
root = pathlib.Path(directory)
cases = root.joinpath("page-cases.raw").read_text(encoding="utf-8").splitlines()
traces = root.joinpath("page-traces.raw").read_text(encoding="utf-8").splitlines()

def enc(value):
    return base64.b64encode(value.encode("utf-8")).decode("ascii")

def find(name, occurrence=0):
    matches = [index for index, row in enumerate(traces)
               if row.split("|")[1] == fixture and row.split("|")[4] == name]
    return matches[occurrence]

def repair_transport():
    for selected in ("empty", "typed-null"):
        sequence = 0
        for index, row in enumerate(traces):
            fields = row.split("|")
            if fields[1] == selected:
                sequence += 1
                fields[3] = str(sequence)
                traces[index] = "|".join(fields)
        rows = [row for row in traces if row.split("|")[1] == selected]
        material = ("\n".join(rows) + "\n").encode("utf-8")
        root.joinpath(f"{selected}.trace.raw").write_bytes(material)
        log = root / f"{selected}.raw.log"
        other = [line for line in log.read_text(encoding="utf-8").splitlines()
                 if not line.startswith("PAGETRACE|")]
        log.write_text("\n".join(rows + other) + "\n", encoding="utf-8")
        case_index = next(index for index, row in enumerate(cases)
                          if row.startswith(f"PAGECASE|{selected}|"))
        fields = cases[case_index].split("|")
        fields[3] = str(len(rows))
        fields[4] = hashlib.sha256(material).hexdigest()
        cases[case_index] = "|".join(fields)

if action == "missing-case":
    cases.pop(0)
elif action == "duplicate-case":
    cases[1] = cases[0]
elif action == "reorder-case":
    cases.reverse()
elif action == "capture":
    index = find("schema-column")
    fields = traces[index].split("|"); fields[2] = "not-a-uuid"
    traces[index] = "|".join(fields)
elif action == "sequence":
    index = find("schema-column")
    fields = traces[index].split("|"); fields[3] = "1"
    traces[index] = "|".join(fields)
elif action == "digest":
    index = 0 if fixture == "empty" else 1
    fields = cases[index].split("|"); fields[4] = "0" * 64
    cases[index] = "|".join(fields)
elif action == "raw-log":
    path = root / f"{fixture}.raw.log"
    path.write_text(path.read_text(encoding="utf-8").replace(
        f"PAGETRACE|{fixture}|", "BROKEN|", 1), encoding="utf-8")
elif action == "schema":
    index = find("schema-column")
    fields = traces[index].split("|"); fields[-2] = enc("changed")
    traces[index] = "|".join(fields)
    repair_transport()
elif action == "input-value":
    index = find("input-cell")
    fields = traces[index].split("|"); fields[-1] = enc("false")
    traces[index] = "|".join(fields)
    repair_transport()
elif action == "null-contradiction":
    index = find("reader-is-null-return", 6)
    fields = traces[index].split("|"); fields[-1] = enc("false")
    traces[index] = "|".join(fields)
    repair_transport()
elif action == "missing-row":
    start = find("reader-next-record-entry", 1)
    end = find("reader-next-record-entry", 2)
    del traces[start:end]
    repair_transport()
elif action == "exhaustion":
    index = find("reader-next-record-return", 3)
    fields = traces[index].split("|"); fields[-1] = enc("true")
    traces[index] = "|".join(fields)
    repair_transport()
elif action == "callback-order":
    first = find("reader-is-null-entry")
    second = find("reader-is-null-return")
    traces[first], traces[second] = traces[second], traces[first]
    repair_transport()
elif action.startswith("hash-"):
    hash_lines = root.joinpath("raw-evidence-hashes.txt").read_text(
        encoding="utf-8").splitlines()
    if action == "hash-missing":
        hash_lines.pop()
    elif action == "hash-duplicate":
        hash_lines[-1] = hash_lines[0]
    elif action == "hash-name":
        hash_lines[0] = "../page-cases.raw=" + hash_lines[0].split("=", 1)[1]
    elif action == "hash-extra":
        hash_lines.append("extra=" + "0" * 64)
    elif action == "hash-digest":
        hash_lines[0] = hash_lines[0].split("=", 1)[0] + "=" + "G" * 64
    root.joinpath("raw-evidence-hashes.txt").write_text(
        "\n".join(hash_lines) + "\n", encoding="utf-8")
    print(root)
    raise SystemExit(0)
else:
    raise ValueError(action)

root.joinpath("page-cases.raw").write_text("\n".join(cases) + "\n",
                                                encoding="utf-8")
root.joinpath("page-traces.raw").write_text("\n".join(traces) + "\n",
                                                 encoding="utf-8")
names = ("page-cases.raw", "page-traces.raw", "empty.raw.log",
         "typed-null.raw.log", "empty.trace.raw", "typed-null.trace.raw")
root.joinpath("raw-evidence-hashes.txt").write_text(
    "".join(f"{name}={hashlib.sha256(root.joinpath(name).read_bytes()).hexdigest()}\n"
            for name in names), encoding="utf-8")
print(root)
PY
}

validator_fails() {
  local action=$1 fixture=$2 expected=$3 copy status
  copy=$(mutated_copy "$action" "$fixture")
  printf 'T0012_S08_RAW_CONTROL=%s:%s|evidence=%s\n' "$fixture" "$action" "$copy"
  if "$driver" --validate-evidence "$copy" \
    > "$copy/validator.stdout.log" 2> "$copy/validator.stderr.log"; then
    status=0
  else
    status=$?
  fi
  [[ "$status" == 4 ]]
  grep -Fqx "T0012_S08_VALIDATION_ERROR|$expected" "$copy/validator.stderr.log"
  [[ ! -s "$copy/validator.stdout.log" ]]
}

validator_fails missing-case empty 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|case-count'
validator_fails duplicate-case empty 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|case-fixture'
validator_fails reorder-case empty 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|case-fixture'
validator_fails capture typed-null 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|capture-id'
validator_fails sequence typed-null 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|sequence-contiguous'
validator_fails digest empty 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|case-digest-match'
validator_fails raw-log typed-null 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|raw-log-trace-match'
validator_fails schema typed-null 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|schema-order-values'
validator_fails input-value typed-null 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|assignment-order-values'
validator_fails null-contradiction typed-null 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|page-read-order-values'
validator_fails missing-row typed-null 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|page-read-order-values'
validator_fails exhaustion typed-null 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|page-read-order-values'
validator_fails callback-order typed-null 'S07-raw-gate:4:T0012_PAGE_VALIDATION_ERROR|page-read-order-values'
validator_fails hash-missing empty raw-hash-file-count
validator_fails hash-duplicate empty raw-hash-name
validator_fails hash-name empty raw-hash-name
validator_fails hash-extra empty raw-hash-file-count
validator_fails hash-digest empty raw-hash-digest

valid_copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-s08-raw-valid.XXXXXX")
copy_raw "$valid_copy"
resolved_valid_copy=$(python3 - "$valid_copy" <<'PY'
import pathlib
import sys
print(pathlib.Path(sys.argv[1]).resolve())
PY
)
"$driver" --validate-evidence "$valid_copy" \
  > "$evidence_dir/raw-validate.stdout.log" 2> "$evidence_dir/raw-validate.stderr.log"
grep -Fqx "T0012_S08_RAW_VALIDATE_ONLY=passed|evidence=$resolved_valid_copy" \
  "$evidence_dir/raw-validate.stdout.log"
[[ ! -s "$evidence_dir/raw-validate.stderr.log" ]]
[[ $(grep -c '^T0012_PAGE_FULL_PROBE=' "$evidence_dir/raw-validate.stdout.log") == 0 ]]

T0012_S08_MANIFEST="$evidence_dir/live.tsv" cargo test \
  --manifest-path "$root/Cargo.toml" -p emburk-core \
  logical_record::tests::live_page_value_differential -- --ignored --exact \
  > "$evidence_dir/live-rust-test.log" 2>&1
grep -Fqx 'test logical_record::tests::live_page_value_differential ... ok' \
  "$evidence_dir/live-rust-test.log"
grep -Eq '^test result: ok\. 1 passed; 0 failed; 0 ignored; .* filtered out;' \
  "$evidence_dir/live-rust-test.log"

git -C "$root" rev-parse HEAD > "$evidence_dir/source-revision.txt"
printf '%s\n' "$raw_evidence" > "$evidence_dir/raw-evidence-path.txt"
shasum -a 256 "$root/crates/emburk-core/src/logical_record.rs" \
  "$root/crates/emburk-core/src/lib.rs" "$driver" "$0" \
  > "$evidence_dir/source.sha256"
shasum -a 256 "$evidence_dir/live.tsv" > "$evidence_dir/manifest.sha256"
cp "$raw_evidence/raw-evidence-hashes.txt" "$evidence_dir/raw-evidence-hashes.txt"

printf 'T0012/S08: compared exactly 2 live record-value projections; S07 full/raw gates, 18 raw controls, and Rust storage/transport controls passed|evidence=%s\n' \
  "$evidence_dir"

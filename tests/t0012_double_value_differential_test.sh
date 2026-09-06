#!/usr/bin/env bash
set -euo pipefail

# LogicalValue equality exercised here is private bitwise storage identity; this
# wrapper does not establish a public or numeric floating-point equality policy.
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
driver="$root/tools/t0012-double-value-differential"
evidence=${T0012_S10_EVIDENCE_DIR:-$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-s10.XXXXXX")}
evidence=$(cd -- "$evidence" && pwd -P)
printf 'T0012_S10_EVIDENCE_DIR=%s\n' "$evidence"

PYTHONPYCACHEPREFIX="$evidence/pycache" python3 -m py_compile "$driver"
bash -n "$0"
rust_status=0
cargo test --manifest-path "$root/Cargo.toml" -p emburk-core \
  logical_record::double_tests -- --nocapture \
  > "$evidence/rust-controls.stdout.log" 2> "$evidence/rust-controls.stderr.log" || rust_status=$?
printf '%s\n' "$rust_status" > "$evidence/rust-controls.exit.txt"
[[ "$rust_status" == 0 ]]
for test_name in \
  comparison_rejects_missing_and_extra_actual_cells \
  expected_only_mutation_fails_without_changing_supplied_values \
  manifest_rejects_transport_and_value_errors \
  null_is_distinct_and_record_order_is_preserved \
  stores_arbitrary_selected_bit_patterns_and_reconstructs_them \
  structural_identity_is_bitwise_not_numeric_equality
do
  grep -Fqx "test logical_record::double_tests::$test_name ... ok" \
    "$evidence/rust-controls.stdout.log"
done
grep -Eq '^test result: ok\. 6 passed; 0 failed; 1 ignored;' \
  "$evidence/rust-controls.stdout.log"

driver_status=0
"$driver" --output "$evidence/live.tsv" \
  > "$evidence/driver.stdout.log" 2> "$evidence/driver.stderr.log" || driver_status=$?
printf '%s\n' "$driver_status" > "$evidence/driver.exit.txt"
[[ "$driver_status" == 0 ]]
grep -Fq 'T0012_DOUBLE_FULL_PROBE=passed|evidence=' "$evidence/driver.stdout.log"
grep -Eq '^T0012_S10_PROJECTED_CASES=2\|evidence=.+\|manifest=.+' \
  "$evidence/driver.stdout.log"
[[ ! -s "$evidence/driver.stderr.log" ]]
grep -Fqx $'T0012-S10\t1' "$evidence/live.tsv"
[[ $(grep -c $'^CASE\t' "$evidence/live.tsv") == 2 ]]
[[ $(grep -c $'^ROW\t' "$evidence/live.tsv") == 12 ]]
[[ $(grep -c $'^CELL\t' "$evidence/live.tsv") == 12 ]]

raw_evidence=$(sed -n \
  's/^T0012_S10_PROJECTED_CASES=2|evidence=\([^|]*\)|manifest=.*$/\1/p' \
  "$evidence/driver.stdout.log")
[[ -d "$raw_evidence" ]]

copy_raw() {
  local destination=$1
  python3 - "$raw_evidence" "$destination" <<'PY'
import pathlib
import shutil
import sys

source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
destination.mkdir()
for item in source.iterdir():
    if item.is_symlink() or not item.is_file():
        raise ValueError("unsafe S09 evidence member: " + item.name)
    shutil.copy2(item, destination / item.name)
PY
}

mutated_raw() {
  local action=$1 copy
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-s10-raw-parent.XXXXXX")
  copy=$(cd -- "$copy" && pwd -P)/evidence
  copy_raw "$copy"
  python3 - "$action" "$copy" <<'PY'
import base64
import hashlib
import pathlib
import sys

action = sys.argv[1]
root = pathlib.Path(sys.argv[2])

def repair(fixture):
    trace = root / f"{fixture}.trace.raw"
    rows = trace.read_text(encoding="utf-8").splitlines()
    material = ("\n".join(rows) + "\n").encode()
    trace.write_bytes(material)
    raw = root / f"{fixture}.raw.log"
    other = [line for line in raw.read_text(encoding="utf-8").splitlines()
             if not line.startswith("DOUBLETRACE|")]
    raw.write_text("\n".join(rows + other) + "\n", encoding="utf-8")
    cases = (root / "double-cases.raw").read_text(encoding="utf-8").splitlines()
    index = 0 if fixture == "finite-null" else 1
    fields = cases[index].split("|")
    fields[3] = str(len(rows))
    fields[4] = hashlib.sha256(material).hexdigest()
    cases[index] = "|".join(fields)
    (root / "double-cases.raw").write_text("\n".join(cases) + "\n", encoding="utf-8")
    combined = []
    for selected in ("finite-null", "nonfinite"):
        combined.extend((root / f"{selected}.trace.raw").read_text(encoding="utf-8").splitlines())
    (root / "double-traces.raw").write_text("\n".join(combined) + "\n", encoding="utf-8")

def repair_hashes():
    names = (
        "double-cases.raw", "double-traces.raw", "finite-null.raw.log",
        "nonfinite.raw.log", "finite-null.trace.raw", "nonfinite.trace.raw",
    )
    text = "".join(
        f"{name}={hashlib.sha256((root / name).read_bytes()).hexdigest()}\n"
        for name in names
    )
    (root / "raw-evidence-hashes.txt").write_text(text, encoding="utf-8")

if action == "case":
    (root / "double-cases.raw").unlink()
elif action == "hash":
    (root / "raw-evidence-hashes.txt").write_text("broken\n", encoding="utf-8")
elif action == "source":
    (root / "runner-source-path.txt").write_text("tools/wrong/run.sh\n", encoding="utf-8")
elif action in ("capture", "projection"):
    trace = root / "finite-null.trace.raw"
    rows = trace.read_text(encoding="utf-8").splitlines()
    if action == "capture":
        fields = rows[1].split("|")
        fields[2] = "12345678-1234-4234-9234-123456789abc"
    else:
        index = next(i for i, row in enumerate(rows)
                     if row.split("|")[4] == "reader-get-double-return")
        fields = rows[index].split("|")
        fields[-1] = base64.b64encode(b"0000000000000000").decode()
        rows[index] = "|".join(fields)
    if action == "capture":
        rows[1] = "|".join(fields)
    trace.write_text("\n".join(rows) + "\n", encoding="utf-8")
    repair("finite-null")
    repair_hashes()
else:
    raise ValueError(action)
PY
  printf '%s\n' "$copy"
}

raw_fails() {
  local action=$1 diagnostic=$2 copy attempt status=0
  copy=$(mutated_raw "$action")
  attempt=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-s10-negative.XXXXXX")
  attempt=$(cd -- "$attempt" && pwd -P)
  "$driver" --validate-evidence "$copy" --log-directory "$attempt" \
    > "$attempt/stdout.log" 2> "$attempt/stderr.log" || status=$?
  printf '%s\n' "$status" > "$attempt/exit.txt"
  [[ "$status" == 4 && ! -s "$attempt/stdout.log" ]]
  grep -Fqx "T0012_S10_VALIDATION_ERROR|S09-strict-exit:4" "$attempt/stderr.log"
  grep -Fqx "T0012_DOUBLE_VALIDATION_ERROR|$diagnostic" \
    "$attempt/strict-validate.stderr.log"
  printf 'T0012_S10_RAW_CONTROL=%s|copy=%s|attempt=%s\n' \
    "$action" "$copy" "$attempt"
}

raw_fails case missing-artifact
raw_fails hash hash-manifest-grammar
raw_fails source source-path
raw_fails capture single-capture
raw_fails projection expected-input-getter

live_status=0
T0012_S10_MANIFEST="$evidence/live.tsv" cargo test \
  --manifest-path "$root/Cargo.toml" -p emburk-core \
  logical_record::double_tests::live_double_value_differential -- --ignored --exact \
  > "$evidence/live-rust.stdout.log" 2> "$evidence/live-rust.stderr.log" || live_status=$?
printf '%s\n' "$live_status" > "$evidence/live-rust.exit.txt"
[[ "$live_status" == 0 ]]
grep -Fqx 'test logical_record::double_tests::live_double_value_differential ... ok' \
  "$evidence/live-rust.stdout.log"

git -C "$root" rev-parse HEAD > "$evidence/source-revision.txt"
printf '%s\n' "$raw_evidence" > "$evidence/raw-evidence-path.txt"
shasum -a 256 \
  "$root/crates/emburk-core/src/logical_record.rs" \
  "$root/crates/emburk-core/src/logical_record/double_tests.rs" \
  "$driver" "$0" > "$evidence/source.sha256"
shasum -a 256 "$evidence/live.tsv" > "$evidence/manifest.sha256"
cp "$raw_evidence/raw-evidence-hashes.txt" "$evidence/raw-evidence-hashes.txt"

printf 'T0012/S10: compared 12 selected double/null cells with private bit storage; 5 bridge controls passed|evidence=%s\n' \
  "$evidence"

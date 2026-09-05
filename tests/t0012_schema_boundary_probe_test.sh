#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0012-config-presence/run.sh"
[[ -x "$runner" ]] || exit 2

run_negative() {
  local control=$1 expected=$2 output status
  if output=$(T0012_MODE=schema T0012_NEGATIVE="$control" "$runner" 2>&1); then exit 1; else status=$?; fi
  [[ "$status" == "$expected" ]] || exit 1
  printf '%s\n' "$output"
}
corrupt_output=$(run_negative corrupt-hash 3)
corrupt_evidence=$(printf '%s\n' "$corrupt_output" | sed -n 's/^T0012_EVIDENCE_DIR=//p' | tail -1)
[[ -s "$corrupt_evidence/negative-control.txt" ]]
grep -Fxq 'corrupt-copy-injected' "$corrupt_evidence/negative-control.txt"
run_negative unavailable-runtime 56

output=$(T0012_MODE=schema "$runner")
printf '%s\n' "$output"
evidence=$(printf '%s\n' "$output" | sed -n 's/^T0012_EVIDENCE_DIR=//p' | tail -1)
for file in executable.sha256 plugin-source.sha256 plugin-jar.sha256 observations.raw.bin schema-cases.raw schema-results.raw; do [[ -s "$evidence/$file" ]]; done
grep -Fqx 'e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47' "$evidence/executable.sha256"
[[ $(wc -l < "$evidence/schema-cases.raw" | tr -d ' ') == 3 ]]

mutated_copy() {
  local mutation=$1 copy
  copy=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-schema-validator.XXXXXX")
  cp "$evidence/schema-cases.raw" "$evidence/schema-results.raw" "$copy/"
  python3 - "$mutation" "$copy" <<'PY'
import base64, hashlib, pathlib, sys
action, root = sys.argv[1:]
root = pathlib.Path(root)
cases = root.joinpath("schema-cases.raw").read_text().splitlines()
rows = root.joinpath("schema-results.raw").read_text().splitlines()
if action == "missing": cases.pop(0)
elif action == "duplicate": cases.append(cases[0])
elif action == "truncated": cases[0] = "SCHEMA"
elif action == "unknown": rows.append("broken")
elif action == "duplicate-field": rows.append(next(row for row in rows if row.startswith("SCHEMA_FIELD|ordered6types|run|0|")))
elif action == "bad-b64":
    index = next(i for i, row in enumerate(rows) if row.startswith("SCHEMA_FIELD|ordered6types|run|0|"))
    rows[index] = rows[index].replace("|Ym9vbGVhbl9jb2x1bW4=|", "|!|")
elif action == "phase-mismatch":
    fields = []
    for index, row in enumerate(rows):
        if row.startswith("SCHEMA_FIELD|ordered6types|run|"):
            parts = row.split("|")
            if parts[3] == "0": parts[4] = base64.b64encode(b"changed_column").decode()
            rows[index] = "|".join(parts)
            fields.append(rows[index].split("|"))
    material = "".join(f"{p[3]}|{p[4]}|{p[5]}\n" for p in fields)
    digest = hashlib.sha256(material.encode()).hexdigest()
    index = next(i for i, row in enumerate(rows) if row.startswith("SCHEMA_PHASE|ordered6types|run|"))
    rows[index] = f"SCHEMA_PHASE|ordered6types|run|6|{digest}"
elif action == "contradictory-exception":
    rows.append("SCHEMA_EXCEPTION|empty|transaction|amF2YS5sYW5nLlJ1bnRpbWVFeGNlcHRpb24=|-")
elif action in {"exception-null", "exception-empty", "exception-empty-class"}:
    cases = [row if not row.startswith("SCHEMA_CASE|duplicate-name-differing-types|") else "SCHEMA_CASE|duplicate-name-differing-types|0|EXCEPTION|0" for row in cases]
    rows = [row for row in rows if row.split("|")[1] != "duplicate-name-differing-types"]
    kind = "" if action == "exception-empty-class" else "amF2YS5sYW5nLlJ1bnRpbWVFeGNlcHRpb24="
    message = "-" if action == "exception-null" else ""
    rows.append(f"SCHEMA_EXCEPTION|duplicate-name-differing-types|transaction|{kind}|{message}")
else: raise ValueError(action)
root.joinpath("schema-cases.raw").write_text("\n".join(cases) + "\n")
root.joinpath("schema-results.raw").write_text("\n".join(rows) + "\n")
PY
  printf 'T0012_SCHEMA_MUTATION_DIR=%s\n' "$copy"
}

validator_fails() {
  local mutation=$1 copy status
  copy=$(mutated_copy "$mutation" | tee /dev/stderr | sed -n 's/^T0012_SCHEMA_MUTATION_DIR=//p')
  if T0012_MODE=schema-validate T0012_SCHEMA_EVIDENCE_DIR="$copy" "$runner"; then status=0; else status=$?; fi
  [[ "$status" == 4 ]]
}
for mutation in missing duplicate truncated unknown duplicate-field bad-b64 phase-mismatch contradictory-exception; do validator_fails "$mutation"; done
for mutation in exception-null exception-empty; do
  copy=$(mutated_copy "$mutation" | tee /dev/stderr | sed -n 's/^T0012_SCHEMA_MUTATION_DIR=//p')
  T0012_MODE=schema-validate T0012_SCHEMA_EVIDENCE_DIR="$copy" "$runner"
done
validator_fails exception-empty-class

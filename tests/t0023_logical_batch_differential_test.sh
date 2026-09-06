#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
driver="$root/tools/t0023-logical-batch-differential"
evidence=$(mktemp -d "${TMPDIR:-/private/tmp}/t0023-s02.XXXXXX")
evidence=$(cd -- "$evidence" && pwd -P)
printf 'T0023_S02_EVIDENCE_DIR=%s\n' "$evidence"
PYTHONPYCACHEPREFIX="$evidence/pycache" python3 -m py_compile "$driver"
bash -n "$0"

run_logged() {
  local label=$1 status=0
  shift
  "$@" > "$evidence/$label.stdout.log" 2> "$evidence/$label.stderr.log" || status=$?
  printf '%s\n' "$status" > "$evidence/$label.exit.txt"
  [[ "$status" == 0 ]]
}

run_logged offline cargo test --manifest-path "$root/Cargo.toml" -p emburk-core \
  logical_batch::differential_tests
grep -Eq '^test result: ok\. 4 passed; 0 failed; 1 ignored;' "$evidence/offline.stdout.log"

# This is the sole live S11 invocation for this S02 run.
run_logged s11 bash "$root/tests/t0012_schema_value_coupling_probe_test.sh"
marker=$(sed -n 's/^T0012\/S11: five exact reviewed traces and 39 diagnostic rejections passed|evidence=//p' "$evidence/s11.stdout.log")
[[ $(printf '%s\n' "$marker" | wc -l | tr -d ' ') == 1 && -d "$marker" ]]

mkdir "$evidence/driver-logs"
run_logged driver python3 "$driver" --evidence "$marker" --output "$evidence/live.tsv" \
  --log-directory "$evidence/driver-logs"
[[ ! -s "$evidence/driver.stderr.log" && $(wc -l < "$evidence/driver.stdout.log") == 1 ]]
grep -Fqx "T0023_S02_PROJECTED_CASES=3|evidence=$marker|manifest=$evidence/live.tsv" "$evidence/driver.stdout.log"
run_logged live env T0023_S02_MANIFEST="$evidence/live.tsv" cargo test \
  --manifest-path "$root/Cargo.toml" -p emburk-core \
  logical_batch::differential_tests::live_logical_batch_differential -- --ignored --exact
grep -Fqx 'test logical_batch::differential_tests::live_logical_batch_differential ... ok' "$evidence/live.stdout.log"
grep -Eq '^test result: ok\. 1 passed; 0 failed; 0 ignored;' "$evidence/live.stdout.log"

git -C "$root" rev-parse HEAD > "$evidence/source-revision.txt"
shasum -a 256 "$root/crates/emburk-core/src/logical_batch.rs" "$driver" "$0" > "$evidence/source.sha256"
PYTHONDONTWRITEBYTECODE=1 python3 - "$marker" "$driver" "$evidence" <<'PY'
import base64
import copy
import hashlib
import pathlib
import runpy
import shutil
import subprocess
import sys
import tempfile

source, driver, evidence = map(pathlib.Path, sys.argv[1:])
module = runpy.run_path(str(driver))
fixtures = ("matching", "explicit-null", "unset-text", "wrong-setter", "duplicate-name")

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

assert len((evidence / "live.tsv").read_bytes()) <= 65536
assert (evidence / "live.sha256").read_text() == digest(evidence / "live.tsv") + "\n"

def invoke(name, target, expected, output=True):
    attempt = pathlib.Path(tempfile.mkdtemp(prefix="t0023-s02-control.")).resolve()
    logs = attempt / "logs"
    logs.mkdir()
    command = [sys.executable, str(driver),
               "--evidence" if output else "--validate-evidence", str(target),
               "--log-directory", str(logs)]
    manifest = attempt / "result.tsv"
    if output:
        command += ["--output", str(manifest)]
    result = subprocess.run(command, capture_output=True, text=True)
    for suffix, material in (("stdout.log", result.stdout), ("stderr.log", result.stderr),
                             ("exit.txt", f"{result.returncode}\n")):
        (attempt / suffix).write_text(material)
    if expected is None:
        assert result.returncode == 0 and not result.stderr
        assert result.stdout == f"T0023_S02_VALIDATE_ONLY=passed|evidence={target}\n"
    else:
        assert result.returncode == 4 and not result.stdout
        assert result.stderr == f"T0023_S02_VALIDATION_ERROR|{expected}\n", result.stderr
        assert not manifest.exists() and not manifest.with_suffix(".sha256").exists()
    print(f"T0023_S02_CONTROL={name}|attempt={attempt}")
    return logs

invoke("positive-validate-only", source, None, output=False)

def seal(directory):
    names = ["coupling-cases.raw", "coupling-traces.raw"] + [
        f"{f}.{suffix}" for f in fixtures
        for suffix in ("stdout.log", "stderr.log", "trace.raw", "exit.txt")]
    (directory / "raw-evidence-hashes.txt").write_text("".join(
        f"{n}={digest(directory / n)}\n" for n in sorted(names)))
    names = sorted(p.name for p in directory.iterdir() if p.is_file()
                   and p.name not in ("integrity-manifest.txt", "integrity-manifest.sha256"))
    (directory / "integrity-manifest.txt").write_text("".join(
        f"{n}={digest(directory / n)}\n" for n in names))
    (directory / "integrity-manifest.sha256").write_text(digest(directory / "integrity-manifest.txt") + "\n")

for name, event, payload, diagnostic in [
    ("raw-schema", "schema-column", "long", "expected-vector"),
    ("raw-value", "reader-get-long-return", "38", "expected-vector"),
    ("raw-null", "reader-is-null-return", "true", "expected-vector"),
    ("raw-trace", "builder-set-long-return", None, "event-count"),
]:
    parent = pathlib.Path(tempfile.mkdtemp(prefix="t0023-s02-raw.")).resolve()
    directory = parent / "evidence"
    shutil.copytree(source, directory)
    path = directory / "matching.trace.raw"
    original = path.read_text()
    rows = [line.split("|") for line in original.splitlines()]
    index = next(i for i, row in enumerate(rows) if row[4] == event)
    if payload is None:
        rows.pop(index)
    else:
        rows[index][-1] = base64.b64encode(payload.encode()).decode()
    material = "\n".join("|".join(row) for row in rows) + "\n"
    assert material != original
    path.write_text(material)
    stdout = directory / "matching.stdout.log"
    other = [line for line in stdout.read_text().splitlines()
             if not line.startswith("COUPLINGTRACE|")]
    stdout.write_text("\n".join(other) + "\n" + material)
    cases = [line.split("|") for line in (directory / "coupling-cases.raw").read_text().splitlines()]
    cases[0][4] = digest(path)
    (directory / "coupling-cases.raw").write_text("\n".join("|".join(row) for row in cases) + "\n")
    (directory / "coupling-traces.raw").write_text("".join(
        (directory / f"{f}.trace.raw").read_text() for f in fixtures))
    seal(directory)
    logs = invoke(name, directory, "S11-strict-exit")
    assert (logs / "s11-validate.exit.txt").read_text() == "4\n"
    assert (logs / "s11-validate.stdout.log").read_text() == ""
    assert (logs / "s11-validate.stderr.log").read_text() == f"T0012_COUPLING_VALIDATION_ERROR|{diagnostic}\n"

# Exercise projector contradictions independently of the upstream validator.
baseline = module["read_events"](source, "explicit-null")
for name in ("missing-null-marker", "extra-getter"):
    changed = copy.deepcopy(baseline)
    if name == "missing-null-marker":
        changed.pop(next(i for i, (event, _) in enumerate(changed) if event == "cell-null"))
    else:
        changed.append(("reader-get-boolean-return", ["0", "0", "0", "0", "false"]))
    assert changed != baseline
    try:
        module["project"](changed, 4)
    except module["Invalid"] as error:
        assert str(error) == "null-getter"
    else:
        raise AssertionError("contradiction accepted")
    print(f"T0023_S02_PROJECTOR_CONTROL={name}|diagnostic=null-getter")

alias_parent = pathlib.Path(tempfile.mkdtemp(prefix="t0023-s02-alias.")).resolve()
alias = alias_parent / "alias"
alias.symlink_to(source, target_is_directory=True)
invoke("evidence-symlink", alias, "external-path")

for name, suffix in (("existing-output", ".tsv"), ("existing-hash", ".sha256")):
    attempt = pathlib.Path(tempfile.mkdtemp(prefix="t0023-s02-existing.")).resolve()
    output = attempt / "result.tsv"
    protected = output.with_suffix(suffix)
    protected.write_bytes(b"preserve")
    logs = attempt / "logs"
    logs.mkdir()
    result = subprocess.run([sys.executable, str(driver), "--evidence", str(source),
                             "--output", str(output), "--log-directory", str(logs)],
                            capture_output=True, text=True)
    for label, data in (("stdout.log", result.stdout), ("stderr.log", result.stderr),
                        ("exit.txt", f"{result.returncode}\n")):
        (attempt / label).write_text(data)
    assert result.returncode == 4 and result.stdout == ""
    assert result.stderr == "T0023_S02_VALIDATION_ERROR|output-exists\n"
    assert protected.read_bytes() == b"preserve"
    print(f"T0023_S02_CONTROL={name}|attempt={attempt}")

(evidence / "artifact-hashes.txt").write_text("".join(
    f"{path.relative_to(evidence)}={digest(path)}\n"
    for path in sorted(evidence.rglob("*"))
    if path.is_file() and "pycache" not in path.parts
    and path.name != "artifact-hashes.txt"))
PY
printf 'T0023/S02: three selected schema/value projections compared with private LogicalBatch|evidence=%s\n' "$evidence"

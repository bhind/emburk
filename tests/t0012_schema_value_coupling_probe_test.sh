#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0012-schema-value-coupling-probe/run.sh"
attempt=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-coupling-full.XXXXXX")
attempt=$(cd -- "$attempt" && pwd -P)
status=0
T0012_COUPLING_MODE=full "$runner" > "$attempt/stdout.log" 2> "$attempt/stderr.log" || status=$?
printf '%s\n' "$status" > "$attempt/exit.txt"
printf 'T0012_COUPLING_FULL_ATTEMPT=%s|exit=%s\n' "$attempt" "$status"
[[ "$status" == 0 ]]
evidence=$(sed -n 's/^T0012_COUPLING_FULL_RUN=passed|evidence=//p' "$attempt/stdout.log")
[[ -d "$evidence" && $(grep -c '^COUPLINGCASE|' "$evidence/coupling-cases.raw") == 5 ]]

artifact_control() {
  local name=$1 expected=$2 log status=0
  log=$(mktemp -d "${TMPDIR:-/private/tmp}/t0012-coupling-artifact.XXXXXX")
  log=$(cd -- "$log" && pwd -P)
  T0012_COUPLING_MODE=full T0012_COUPLING_NEGATIVE="$name" "$runner" \
    > "$log/stdout.log" 2> "$log/stderr.log" || status=$?
  printf '%s\n' "$status" > "$log/exit.txt"
  [[ "$status" == "$expected" ]]
  if [[ "$name" == corrupt-hash ]]; then
    grep -Fqx 'pinned executable checksum mismatch' "$log/stderr.log"
  else
    grep -Fq 'unable to retrieve pinned executable:' "$log/stderr.log"
  fi
  printf 'T0012_COUPLING_ARTIFACT_CONTROL=%s|attempt=%s\n' "$name" "$log"
}
artifact_control corrupt-hash 3
artifact_control unavailable-runtime 56

# Validate-only must succeed without claiming runtime admission or a full run.
validation="$attempt/validate"
mkdir "$validation"
validation_status=0
T0012_COUPLING_MODE=validate T0012_COUPLING_EVIDENCE_DIR="$evidence" "$runner" \
  > "$validation/stdout.log" 2> "$validation/stderr.log" || validation_status=$?
printf '%s\n' "$validation_status" > "$validation/exit.txt"
[[ "$validation_status" == 0 && ! -s "$validation/stderr.log" ]]
grep -Fqx "T0012_COUPLING_VALIDATE_ONLY=passed|evidence=$evidence" "$validation/stdout.log"
[[ $(wc -l < "$validation/stdout.log") == 1 ]]

# Mutate structured fields, repair dependent transport hashes, and require one
# exact diagnostic. Hash/manifest tests deliberately leave their target broken.
PYTHONDONTWRITEBYTECODE=1 python3 - "$evidence" "$runner" "$root" <<'PY'
import base64
import hashlib
import os
import pathlib
import shutil
import subprocess
import tempfile

source, runner, repository = map(pathlib.Path, __import__("sys").argv[1:])
fixtures = ("matching", "explicit-null", "unset-text", "wrong-setter", "duplicate-name")
raw_names = sorted(["coupling-cases.raw", "coupling-traces.raw"] + [
    f"{fixture}.{suffix}" for fixture in fixtures
    for suffix in ("stdout.log", "stderr.log", "trace.raw", "exit.txt")
])
controls = [
    ("fixture-missing", "case-count"),
    ("fixture-duplicate", "case-count"),
    ("fixture-reordered", "case-grammar"),
    ("fixture-unknown", "case-grammar"),
    ("schema-type", "expected-vector"),
    ("event-missing", "event-count"),
    ("event-duplicate", "event-count"),
    ("event-reordered", "expected-vector"),
    ("value", "expected-vector"),
    ("exception", "expected-vector"),
    ("terminal", "expected-vector"),
    ("cleanup", "expected-vector"),
    ("capture-invalid", "capture-id"),
    ("capture-shared", "capture-cross-fixture-uniqueness"),
    ("capture-interleaved", "context-segments"),
    ("sequence-leading-zero", "sequence"),
    ("trace-no-newline", "canonical-newline"),
    ("trace-crlf", "canonical-newline"),
    ("foreign-trace", "foreign-trace"),
    ("process-exit", "process-exit"),
    ("combined-order", "combined-order"),
    ("source-missing", "missing-artifact"),
    ("source-path", "source-path"),
    ("source-hash", "source-hash"),
    ("source-revision", "source-revision"),
    ("metadata-duplicate", "metadata-line"),
    ("runtime-empty", "runtime-metadata"),
    ("url", "executable-url"),
    ("license", "license-hash"),
    ("raw-hash-missing", "missing-artifact"),
    ("raw-hash-duplicate", "hash-manifest-grammar"),
    ("raw-hash-order", "hash-manifest-order"),
    ("raw-hash-digest", "raw-hash"),
    ("integrity-member", "integrity-hash"),
    ("integrity-seal", "integrity-seal"),
    ("leaf-symlink", "evidence-path"),
    ("ancestor-symlink", "evidence-path"),
    ("repository-path", "evidence-path"),
    ("outside-temp", "evidence-temp"),
]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def fingerprint(directory):
    return sorted((p.name, digest(p)) for p in directory.iterdir() if p.is_file())

def manifest(directory, name, names):
    (directory / name).write_text(
        "".join(f"{n}={digest(directory / n)}\n" for n in sorted(names)),
        encoding="utf-8",
    )

def seal(directory):
    names = [p.name for p in directory.iterdir()
             if p.is_file() and p.name not in ("integrity-manifest.txt", "integrity-manifest.sha256")]
    manifest(directory, "integrity-manifest.txt", names)
    (directory / "integrity-manifest.sha256").write_text(
        digest(directory / "integrity-manifest.txt") + "\n", encoding="ascii")

def trace(directory, fixture):
    return [line.split("|") for line in
            (directory / f"{fixture}.trace.raw").read_text().splitlines()]

def encode(value):
    return base64.b64encode(value.encode()).decode()

def event(rows, name):
    matches = [i for i, row in enumerate(rows) if row[4] == name]
    assert len(matches) == 1, (name, matches)
    return matches[0]

def put_trace(directory, fixture, rows):
    lines = ["|".join(row) for row in rows]
    material = "\n".join(lines) + "\n"
    (directory / f"{fixture}.trace.raw").write_text(material)
    log = directory / f"{fixture}.stdout.log"
    other = [line for line in log.read_text().splitlines()
             if not line.startswith("COUPLINGTRACE|")]
    log.write_text("\n".join(other + lines) + "\n")
    cases = [line.split("|") for line in (directory / "coupling-cases.raw").read_text().splitlines()]
    cases[fixtures.index(fixture)][4] = hashlib.sha256(material.encode()).hexdigest()
    (directory / "coupling-cases.raw").write_text(
        "\n".join("|".join(row) for row in cases) + "\n")
    (directory / "coupling-traces.raw").write_text("".join(
        (directory / f"{f}.trace.raw").read_text() for f in fixtures))

for name, expected in controls:
    attempt = pathlib.Path(tempfile.mkdtemp(prefix="t0012-coupling-control.")).resolve()
    directory = attempt / "evidence"
    shutil.copytree(source, directory)
    before = fingerprint(directory)
    target = directory
    fixture = "unset-text" if name in ("exception", "capture-interleaved") else "matching"
    rows = trace(directory, fixture)
    trace_changed = False

    if name.startswith("fixture-"):
        p = directory / "coupling-cases.raw"
        cases = p.read_text().splitlines()
        if name == "fixture-missing":
            cases.pop()
        elif name == "fixture-duplicate":
            cases.append(cases[0])
        elif name == "fixture-reordered":
            cases[0], cases[1] = cases[1], cases[0]
        else:
            cases[0] = cases[0].replace("|matching|", "|unknown|")
        p.write_text("\n".join(cases) + "\n")
    elif name == "schema-type":
        index = next(i for i, row in enumerate(rows) if row[4] == "schema-column")
        rows[index][-1] = encode("long")
        trace_changed = True
    elif name in ("event-missing", "event-duplicate"):
        index = event(rows, "builder-set-long-return")
        if name == "event-missing":
            rows.pop(index)
        else:
            rows.insert(index, rows[index].copy())
        trace_changed = True
    elif name == "event-reordered":
        a, b = event(rows, "builder-set-long-entry"), event(rows, "builder-set-long-return")
        rows[a], rows[b] = rows[b], rows[a]
        for i, row in enumerate(rows, 1):
            row[3] = str(i)
        trace_changed = True
    elif name in ("value", "exception", "terminal", "cleanup"):
        key = {"value": "reader-get-string-return", "exception": "builder-add-record-exception",
               "terminal": "terminal", "cleanup": "cleanup-return"}[name]
        rows[event(rows, key)][-1] = encode("changed")
        trace_changed = True
    elif name == "capture-invalid":
        rows[0][2] = "invalid"
        trace_changed = True
    elif name == "capture-shared":
        shared = rows[0][2]
        fixture = "explicit-null"
        rows = trace(directory, fixture)
        for row in rows:
            row[2] = shared
        trace_changed = True
    elif name == "capture-interleaved":
        rows[-3], rows[-2] = rows[-2], rows[-3]
        trace_changed = True
    elif name == "sequence-leading-zero":
        rows[0][3] = "01"
        trace_changed = True
    elif name in ("trace-no-newline", "trace-crlf"):
        p = directory / "matching.trace.raw"
        material = p.read_bytes()
        p.write_bytes(material[:-1] if name == "trace-no-newline" else material.replace(b"\n", b"\r\n"))
    elif name == "foreign-trace":
        p = directory / "matching.stdout.log"
        p.write_text(p.read_text() + "|".join(trace(directory, "explicit-null")[0]) + "\n")
    elif name == "process-exit":
        (directory / "matching.exit.txt").write_text("1\n")
    elif name == "combined-order":
        p = directory / "coupling-traces.raw"
        p.write_text("\n".join(reversed(p.read_text().splitlines())) + "\n")
    elif name == "source-missing":
        (directory / "runner-source-path.txt").unlink()
    elif name == "source-path":
        (directory / "runner-source-path.txt").write_text("unexpected/path\n")
    elif name == "source-hash":
        (directory / "runner-source.sha256").write_text("0" * 64 + "\n")
    elif name == "source-revision":
        (directory / "source-revision.txt").write_text("0" * 40 + "\n")
    elif name == "metadata-duplicate":
        p = directory / "runner-source-path.txt"
        p.write_text(p.read_text() + "extra\n")
    elif name == "runtime-empty":
        (directory / "java-version.txt").write_text("")
    elif name == "url":
        (directory / "executable-url.txt").write_text("https://invalid.example/\n")
    elif name == "license":
        (directory / "LICENSE-executable").write_text("changed\n")
    elif name == "integrity-member":
        p = directory / "java-version.txt"
        p.write_text(p.read_text() + "changed\n")
    elif name == "leaf-symlink":
        target = attempt / "alias"
        target.symlink_to(directory, target_is_directory=True)
    elif name == "ancestor-symlink":
        parent = attempt / "alias-parent"
        parent.symlink_to(attempt, target_is_directory=True)
        target = parent / "evidence"
    elif name == "repository-path":
        target = repository
    elif name == "outside-temp":
        target = pathlib.Path("/")

    if trace_changed:
        put_trace(directory, fixture, rows)
    manifest(directory, "raw-evidence-hashes.txt",
             [n for n in raw_names if (directory / n).is_file()])
    p = directory / "raw-evidence-hashes.txt"
    if name == "raw-hash-missing":
        p.unlink()
    elif name == "raw-hash-duplicate":
        lines = p.read_text().splitlines()
        p.write_text("\n".join(lines + [lines[0]]) + "\n")
    elif name == "raw-hash-order":
        p.write_text("\n".join(reversed(p.read_text().splitlines())) + "\n")
    elif name == "raw-hash-digest":
        lines = p.read_text().splitlines()
        lines[0] = lines[0].split("=")[0] + "=" + "0" * 64
        p.write_text("\n".join(lines) + "\n")
    if name != "integrity-member":
        seal(directory)
    if name == "integrity-seal":
        (directory / "integrity-manifest.sha256").write_text("0" * 64 + "\n")

    assert target != directory or fingerprint(directory) != before, f"no-op control: {name}"
    completed = subprocess.run(
        ["bash", str(runner)], cwd=repository, capture_output=True,
        env={**os.environ, "T0012_COUPLING_MODE": "validate",
             "T0012_COUPLING_EVIDENCE_DIR": str(target)})
    (attempt / "stdout.log").write_bytes(completed.stdout)
    (attempt / "stderr.log").write_bytes(completed.stderr)
    (attempt / "exit.txt").write_text(f"{completed.returncode}\n")
    print(f"T0012_COUPLING_CONTROL_ATTEMPT={name}|attempt={attempt}", flush=True)
    assert completed.returncode == 4, (name, completed.returncode)
    assert completed.stdout == b"", (name, completed.stdout)
    assert completed.stderr == f"T0012_COUPLING_VALIDATION_ERROR|{expected}\n".encode(), (
        name, expected, completed.stderr)
    print(f"T0012_COUPLING_REPAIRED_CONTROL={name}|diagnostic={expected}|attempt={attempt}", flush=True)

print(f"T0012/S11: five exact reviewed traces and {len(controls)} diagnostic rejections passed|evidence={source}")
PY

#!/usr/bin/env python3
"""Differentially replay the bounded T-0032/S04 Float64 lexical cases.

Fresh raw Stage A evidence is validated before any native/reference equality
comparison. Evidence stays under a private, bounded temporary root.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import tempfile
import uuid


ROOT = Path(__file__).resolve().parents[1]
ORACLE_PATH = ROOT / "tools/t0032-float64-lexical-oracle/run.py"
SPEC = importlib.util.spec_from_file_location("t0032_s04_oracle", ORACLE_PATH)
oracle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(oracle)
TIMEOUT_SECONDS = 90
MAX_TREE_BYTES = 20 * 1024 * 1024
MAX_BINARY_BYTES = 256 * 1024 * 1024


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def confined(path, root):
    resolved, boundary = path.resolve(), root.resolve()
    require(resolved != boundary and boundary in resolved.parents, "evidence path escapes root")
    return resolved


def regular(path, root, limit=MAX_TREE_BYTES):
    confined(path, root)
    metadata = path.lstat()
    require(stat.S_ISREG(metadata.st_mode) and not path.is_symlink(), "evidence item is not regular")
    require(metadata.st_size <= limit, "evidence item exceeds byte cap")
    data = path.read_bytes()
    require(len(data) == metadata.st_size, "evidence item changed during read")
    return {"name": str(path.relative_to(root)), "size": len(data), "sha256": digest(data)}


def inventory(root):
    entries, total = [], 0
    for path in sorted(root.rglob("*")):
        confined(path, root)
        metadata = path.lstat()
        if stat.S_ISLNK(metadata.st_mode):
            raise ValueError("evidence tree contains symlink")
        if stat.S_ISDIR(metadata.st_mode):
            entries.append({"name": str(path.relative_to(root)), "type": "directory"})
        elif stat.S_ISREG(metadata.st_mode):
            item = regular(path, root, MAX_TREE_BYTES - total)
            total += item["size"]
            entries.append({"type": "regular", **item})
        else:
            raise ValueError("evidence tree contains special file")
    return entries


def executable():
    raw = os.environ.get("EMBURK_BINARY")
    require(raw is not None, "EMBURK_BINARY is required")
    path = Path(raw).resolve()
    require(path.is_file() and not path.is_symlink() and os.access(path, os.X_OK), "EMBURK_BINARY invalid")
    require(0 < path.stat().st_size <= MAX_BINARY_BYTES, "EMBURK_BINARY exceeds byte cap")
    return path


def kill_group(process):
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def execute(command, root, label, environment):
    stdout, stderr = root / (label + ".stdout"), root / (label + ".stderr")
    with stdout.open("xb") as out, stderr.open("xb") as err:
        process = subprocess.Popen(command, cwd=root, env=environment, stdout=out, stderr=err, start_new_session=True)
        timed_out = False
        try:
            exit_code = process.wait(timeout=TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            timed_out = True
            kill_group(process)
            exit_code = process.wait()
        finally:
            kill_group(process)
    exit_file = root / (label + ".exit")
    exit_file.write_text(str(exit_code) + "\n", encoding="ascii")
    return {"command": [str(part) for part in command], "exit": exit_code, "timed_out": timed_out,
            "stdout": regular(stdout, root), "stderr": regular(stderr, root), "exit_file": regular(exit_file, root)}


def run_stage_a():
    completed = subprocess.run([sys.executable, "-I", "-B", str(ORACLE_PATH)], cwd=ROOT, env=dict(os.environ),
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=TIMEOUT_SECONDS * 4)
    require(completed.returncode == 0, "fresh Stage A oracle did not complete")
    marker = "T0032_S04_EVIDENCE_DIR="
    paths = [line[len(marker):] for line in completed.stdout.decode("utf-8").splitlines() if line.startswith(marker)]
    require(len(paths) == 1, "fresh Stage A evidence location missing")
    manifest = Path(paths[0]) / "manifest.json"
    value = oracle.validate_summary(manifest)
    require(value["result"] == "captured", "fresh Stage A manifest result invalid")
    return {"path": str(manifest.parent), "manifest_sha256": digest(manifest.read_bytes())}


def output_bytes(root):
    result, total = [], 0
    for path in sorted(root.rglob("*")):
        confined(path, root)
        metadata = path.lstat()
        if stat.S_ISLNK(metadata.st_mode):
            raise ValueError("output tree contains symlink")
        if stat.S_ISDIR(metadata.st_mode):
            result.append({"name": str(path.relative_to(root)), "type": "directory"})
        elif stat.S_ISREG(metadata.st_mode):
            require(metadata.st_size <= MAX_TREE_BYTES - total, "output tree exceeds byte cap")
            data = path.read_bytes()
            require(len(data) == metadata.st_size, "output changed during read")
            total += len(data)
            result.append({"name": str(path.relative_to(root)), "type": "regular", "bytes": data.hex()})
        else:
            raise ValueError("output tree contains special file")
    return result


def assert_equal(reference, native, reference_root, native_root):
    require(not reference["timed_out"] and not native["timed_out"], "timeout is not an outcome")
    require(reference["exit"] == native["exit"], "reference/native exit differs")
    require(output_bytes(reference_root) == output_bytes(native_root), "reference/native output names or bytes differ")


def run_case(case, root, jar, java, version, binary, run_uuid):
    case_root = root / "cases" / case
    case_root.mkdir(parents=True, mode=0o700)
    for name in ("reference-output", "native-output", "reference-home", "reference-tmp"):
        (case_root / name).mkdir(mode=0o700)
    (case_root / "input.csv").write_bytes(oracle.fixture(case))
    profile = oracle.config(case)
    (case_root / "reference.yml").write_bytes(profile.replace(b"output/result", b"reference-output/result"))
    (case_root / "native.yml").write_bytes(profile.replace(b"output/result", b"native-output/result"))
    (case_root / "java-version.txt").write_bytes(version)
    home, temporary = case_root / "reference-home", case_root / "reference-tmp"
    reference = execute([str(java), "-Duser.home=" + str(home), "-Djava.io.tmpdir=" + str(temporary), "-jar", str(jar), "-Xembulk_home=" + str(home), "run", "reference.yml"], case_root, "reference", {"PATH": os.defpath, "JAVA_HOME": str(java.parent.parent), "HOME": str(home), "TMPDIR": str(temporary), "EMBULK_HOME": str(home)})
    native = execute([str(binary), "run", "native.yml"], case_root, "native", {"PATH": os.defpath})
    assert_equal(reference, native, case_root / "reference-output", case_root / "native-output")
    value = {"case": case, "run_uuid": run_uuid, "reference": reference, "native": native,
             "reference_output": output_bytes(case_root / "reference-output"), "native_output": output_bytes(case_root / "native-output")}
    value["tree"] = inventory(case_root)
    manifest = case_root / "manifest.json"
    manifest.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def main():
    stage_a = run_stage_a()
    jar_data = oracle.reference(os.environ)
    java, version, _ = oracle.java17(os.environ)
    source = executable()
    root = Path(tempfile.mkdtemp(prefix="emburk-t0032-s04-float64-lexical-differential-", dir="/private/tmp"))
    root.chmod(0o700)
    jar = root / "embulk.jar"; jar.write_bytes(jar_data); jar.chmod(0o400)
    binary = root / "emburk"; binary.write_bytes(source.read_bytes()); binary.chmod(0o500)
    summary = {"run_uuid": str(uuid.uuid4()), "stage_a": stage_a, "reference": {"sha256": oracle.REFERENCE_SHA256}, "cases": [], "result": "incomplete"}
    try:
        for case in oracle.CASES:
            manifest = run_case(case, root, jar, java, version, binary, summary["run_uuid"])
            summary["cases"].append({"case": case, "path": str(manifest.parent.relative_to(root)), "manifest_sha256": digest(manifest.read_bytes())})
            print("T0032_S04_MATCH=" + case, flush=True)
        summary["result"] = "pass"
    finally:
        summary["tree"] = inventory(root)
        (root / "manifest.json").write_text(json.dumps(summary, sort_keys=True) + "\n", encoding="utf-8")
        print("T0032_S04_EVIDENCE_DIR=" + str(root), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as failure:
        print("T0032_S04_DIFFERENTIAL_ERROR=" + str(failure), file=sys.stderr)
        raise SystemExit(2)

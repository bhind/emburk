#!/usr/bin/env python3
"""Compare the authorized Float64 CSV observations against Emburk.

The frozen Stage A oracle is rerun and its raw manifest is validated before
this driver projects any case into a native/reference equality assertion.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import uuid


ROOT = Path(__file__).resolve().parents[1]
ORACLE_PATH = ROOT / "tools/t0032-float64-file-csv-oracle/run.py"
SPEC = importlib.util.spec_from_file_location("t0032_float64_oracle", ORACLE_PATH)
oracle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(oracle)
CASES = oracle.CASES
TIMEOUT_SECONDS = 90
MAX_TREE_BYTES = 20 * 1024 * 1024
MAX_BINARY_BYTES = 256 * 1024 * 1024


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def confined(path, root):
    resolved, boundary = path.resolve(), root.resolve()
    require(resolved != boundary and boundary in resolved.parents, "evidence path escapes root")
    return resolved


def detail(path, root):
    confined(path, root)
    require(path.is_file() and not path.is_symlink(), "evidence item is not regular")
    data = path.read_bytes()
    return {"name": str(path.relative_to(root)), "size": len(data), "sha256": digest(data)}


def inventory(root):
    entries, total = [], 0
    for path in sorted(root.rglob("*")):
        confined(path, root)
        require(not path.is_symlink(), "evidence tree contains symlink")
        if path.is_dir():
            entries.append({"name": str(path.relative_to(root)), "type": "directory"})
        elif path.is_file():
            item = detail(path, root); total += item["size"]
            entries.append({"type": "regular", **item})
        else:
            raise ValueError("evidence tree contains special file")
    require(total <= MAX_TREE_BYTES, "evidence tree exceeds byte cap")
    return entries


def binary():
    raw = os.environ.get("EMBURK_BINARY")
    require(raw is not None, "EMBURK_BINARY is required")
    path = Path(raw).resolve()
    require(path.is_file() and not path.is_symlink() and os.access(path, os.X_OK), "EMBURK_BINARY invalid")
    require(0 < path.stat().st_size <= MAX_BINARY_BYTES, "EMBURK_BINARY exceeds byte cap")
    return path


def terminate(process):
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def execute(command, root, label, environment):
    stdout, stderr = root / f"{label}.stdout", root / f"{label}.stderr"
    with stdout.open("xb") as out, stderr.open("xb") as err:
        process = subprocess.Popen(command, cwd=root, env=environment, stdout=out, stderr=err,
                                   start_new_session=True)
        timed_out = False
        try:
            exit_code = process.wait(timeout=TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            timed_out = True; terminate(process); exit_code = process.wait()
        finally:
            terminate(process)
    exit_file = root / f"{label}.exit"; exit_file.write_text(f"{exit_code}\n", encoding="ascii")
    return {"command": [str(item) for item in command], "exit": exit_code, "timed_out": timed_out,
            "stdout": detail(stdout, root), "stderr": detail(stderr, root), "exit_file": detail(exit_file, root)}


def run_oracle():
    environment = dict(os.environ)
    completed = subprocess.run([sys.executable, "-I", "-B", str(ORACLE_PATH)], cwd=ROOT, env=environment,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=TIMEOUT_SECONDS * 4)
    require(completed.returncode == 0, "Stage A oracle did not complete")
    lines = completed.stdout.decode("utf-8").splitlines()
    marker = "T0032_S03_EVIDENCE_DIR="
    locations = [line[len(marker):] for line in lines if line.startswith(marker)]
    require(len(locations) == 1, "Stage A oracle evidence location missing")
    manifest = Path(locations[0]) / "manifest.json"
    value = oracle.validate_summary(manifest)
    require(value["result"] == "captured", "Stage A oracle result invalid")
    return {"path": str(manifest.parent), "manifest_sha256": digest(manifest.read_bytes())}


def validate_case_manifest(path):
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {"case", "run_uuid", "input", "reference_config", "native_config", "reference", "native", "reference_output", "native_output", "tree"}
    require(isinstance(value, dict) and set(value) == required and value["case"] in CASES, "case manifest structure")
    require(str(uuid.UUID(value["run_uuid"])) == value["run_uuid"], "case run identity")
    root = path.parent
    for key, name in (("input", "input.csv"), ("reference_config", "reference.yml"), ("native_config", "native.yml")):
        require(value[key] == detail(root / name, root), "case input changed")
    for side in ("reference", "native"):
        process = value[side]
        require(isinstance(process, dict) and set(process) == {"command", "exit", "timed_out", "stdout", "stderr", "exit_file"}, "process manifest structure")
        require(isinstance(process["exit"], int) and isinstance(process["timed_out"], bool), "process result")
        for key, name in (("stdout", f"{side}.stdout"), ("stderr", f"{side}.stderr"), ("exit_file", f"{side}.exit")):
            require(process[key] == detail(root / name, root), "process evidence changed")
    require(value["reference_output"] == inventory(root / "reference-output"), "reference output changed")
    require(value["native_output"] == inventory(root / "native-output"), "native output changed")
    actual = [entry for entry in inventory(root) if entry["name"] != "manifest.json"]
    require(value["tree"] == actual, "case tree changed")
    return value


def validate_summary_manifest(path):
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {"run_uuid", "stage_a", "reference", "reference_snapshot", "binary", "cases", "result", "tree"}
    require(isinstance(value, dict) and set(value) == required, "summary manifest structure")
    require(str(uuid.UUID(value["run_uuid"])) == value["run_uuid"], "summary run identity")
    require(value["reference"] == {"sha256": oracle.REFERENCE_SHA256}, "summary reference identity")
    root = path.parent
    require(value["reference_snapshot"] == detail(root / "embulk.jar", root), "reference snapshot changed")
    require(value["binary"] == detail(root / "emburk", root), "binary snapshot changed")
    require(value["result"] in ("pass", "incomplete"), "summary result")
    require(isinstance(value["stage_a"], dict) and set(value["stage_a"]) == {"path", "manifest_sha256"}, "Stage A linkage")
    stage_a_manifest = Path(value["stage_a"]["path"]) / "manifest.json"
    require(stage_a_manifest.is_file() and digest(stage_a_manifest.read_bytes()) == value["stage_a"]["manifest_sha256"], "Stage A manifest changed")
    oracle.validate_summary(stage_a_manifest)
    require([item.get("case") if isinstance(item, dict) else None for item in value["cases"]] == list(CASES), "summary case order")
    for item, case in zip(value["cases"], CASES):
        require(set(item) == {"case", "path", "manifest_sha256"} and item["case"] == case and item["path"] == f"cases/{case}", "summary case linkage")
        manifest = root / item["path"] / "manifest.json"
        require(manifest.is_file() and digest(manifest.read_bytes()) == item["manifest_sha256"], "summary case hash")
        validate_case_manifest(manifest)
    actual = [entry for entry in inventory(root) if entry["name"] != "manifest.json"]
    require(value["tree"] == actual, "summary tree changed")
    return value


def assert_equal(value):
    require(not value["reference"]["timed_out"] and not value["native"]["timed_out"], "timeout is not an outcome")
    require(value["reference"]["exit"] == value["native"]["exit"], "reference/native exit differs")
    require(value["reference_output"] == value["native_output"], "reference/native output differs")


def run_case(case, root, jar, java, version, binary_snapshot, run_uuid):
    case_root = root / "cases" / case
    case_root.mkdir(parents=True, mode=0o700)
    for name in ("reference-output", "native-output", "reference-home", "reference-tmp"):
        (case_root / name).mkdir(mode=0o700)
    input_file = case_root / "input.csv"; input_file.write_bytes(oracle.fixture(case))
    (case_root / "java-version.txt").write_bytes(version)
    profile = oracle.config(case)
    reference_config = profile.replace(b"output/result", b"reference-output/result")
    native_config = profile.replace(b"output/result", b"native-output/result")
    (case_root / "reference.yml").write_bytes(reference_config)
    (case_root / "native.yml").write_bytes(native_config)
    home, temporary = case_root / "reference-home", case_root / "reference-tmp"
    reference = execute([str(java), f"-Duser.home={home}", f"-Djava.io.tmpdir={temporary}", "-jar", str(jar),
                         f"-Xembulk_home={home}", "run", "reference.yml"], case_root, "reference",
                        {"PATH": os.defpath, "JAVA_HOME": str(java.parent.parent), "HOME": str(home),
                         "TMPDIR": str(temporary), "EMBULK_HOME": str(home)})
    native = execute([str(binary_snapshot), "run", "native.yml"], case_root, "native", {"PATH": os.defpath})
    reference_output, native_output = inventory(case_root / "reference-output"), inventory(case_root / "native-output")
    value = {"case": case, "run_uuid": run_uuid, "input": detail(input_file, case_root),
             "reference_config": detail(case_root / "reference.yml", case_root),
             "native_config": detail(case_root / "native.yml", case_root), "reference": reference,
             "native": native, "reference_output": reference_output, "native_output": native_output}
    value["tree"] = inventory(case_root)
    manifest = case_root / "manifest.json"; manifest.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
    assert_equal(validate_case_manifest(manifest))
    return manifest


def main():
    stage_a = run_oracle()
    jar_data = oracle.reference(os.environ); java, version, _ = oracle.java17(os.environ); executable = binary()
    root = Path(tempfile.mkdtemp(prefix="emburk-t0032-s03-float64-differential-", dir="/private/tmp")); root.chmod(0o700)
    jar = root / "embulk.jar"; jar.write_bytes(jar_data); jar.chmod(0o400)
    native = root / "emburk"; native.write_bytes(executable.read_bytes()); native.chmod(0o500)
    summary = {"run_uuid": str(uuid.uuid4()), "stage_a": stage_a, "reference": {"sha256": oracle.REFERENCE_SHA256},
               "reference_snapshot": detail(jar, root), "binary": detail(native, root), "cases": [], "result": "incomplete"}
    try:
        for case in CASES:
            manifest = run_case(case, root, jar, java, version, native, summary["run_uuid"])
            summary["cases"].append({"case": case, "path": str(manifest.parent.relative_to(root)),
                                     "manifest_sha256": digest(manifest.read_bytes())})
            print("T0032_S03_MATCH=" + case, flush=True)
        summary["result"] = "pass"
    finally:
        summary["tree"] = inventory(root)
        manifest = root / "manifest.json"; manifest.write_text(json.dumps(summary, sort_keys=True) + "\n", encoding="utf-8")
        validate_summary_manifest(manifest)
        print("T0032_S03_EVIDENCE_DIR=" + str(root), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as failure:
        print("T0032_S03_DIFFERENTIAL_ERROR=" + str(failure), file=sys.stderr)
        raise SystemExit(2)

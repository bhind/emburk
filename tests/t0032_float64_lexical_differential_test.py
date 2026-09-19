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
    source = Path(raw)
    require(not stat.S_ISLNK(source.lstat().st_mode), "EMBURK_BINARY invalid")
    path = source.resolve()
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


def driver_identity():
    return {"path": "tests/t0032_float64_lexical_differential_test.py", "sha256": digest(Path(__file__).read_bytes())}


def validate_case_manifest(path):
    root = path.parent
    regular(path, root)
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {"case", "run_uuid", "input", "reference_config", "native_config", "java_version", "driver", "reference", "native", "reference_output", "native_output", "tree"}
    require(isinstance(value, dict) and set(value) == required, "case manifest structure")
    require(value["case"] in oracle.CASES and str(uuid.UUID(value["run_uuid"])) == value["run_uuid"], "case identity")
    require(value["input"] == regular(root / "input.csv", root), "case input changed")
    require(value["reference_config"] == regular(root / "reference.yml", root), "reference config changed")
    require(value["native_config"] == regular(root / "native.yml", root), "native config changed")
    require(value["java_version"] == regular(root / "java-version.txt", root), "Java version changed")
    require(value["driver"] == driver_identity(), "driver identity changed")
    for side in ("reference", "native"):
        process = value[side]
        require(isinstance(process, dict) and set(process) == {"command", "exit", "timed_out", "stdout", "stderr", "exit_file"}, "process manifest structure")
        require(isinstance(process["exit"], int) and isinstance(process["timed_out"], bool), "process result")
        for key, name in (("stdout", side + ".stdout"), ("stderr", side + ".stderr"), ("exit_file", side + ".exit")):
            require(process[key] == regular(root / name, root), "process evidence changed")
        require((root / (side + ".exit")).read_text(encoding="ascii") == str(process["exit"]) + "\n", "exit record changed")
    require(value["reference_output"] == inventory(root / "reference-output"), "reference output changed")
    require(value["native_output"] == inventory(root / "native-output"), "native output changed")
    require(value["tree"] == [item for item in inventory(root) if item["name"] != "manifest.json"], "case tree changed")
    return value


def validate_summary_manifest(path):
    root = path.parent
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {"run_uuid", "stage_a", "reference", "reference_snapshot", "binary", "driver", "cases", "result", "tree"}
    require(isinstance(value, dict) and set(value) == required, "summary manifest structure")
    require(str(uuid.UUID(value["run_uuid"])) == value["run_uuid"], "summary run identity")
    require(value["reference"] == {"sha256": oracle.REFERENCE_SHA256}, "summary reference identity")
    require(value["reference_snapshot"] == regular(root / "embulk.jar", root, oracle.REFERENCE_BYTES), "reference snapshot changed")
    require(value["reference_snapshot"]["sha256"] == oracle.REFERENCE_SHA256, "reference snapshot hash changed")
    require(value["binary"] == regular(root / "emburk", root, MAX_BINARY_BYTES), "native snapshot changed")
    require(value["driver"] == driver_identity() and value["result"] in ("pass", "incomplete"), "summary identity")
    require(isinstance(value["stage_a"], dict) and set(value["stage_a"]) == {"path", "manifest_sha256"}, "Stage A linkage")
    stage_a = Path(value["stage_a"]["path"]) / "manifest.json"
    require(stage_a.is_file() and digest(stage_a.read_bytes()) == value["stage_a"]["manifest_sha256"], "Stage A manifest changed")
    oracle.validate_summary(stage_a)
    require([item.get("case") if isinstance(item, dict) else None for item in value["cases"]] == list(oracle.CASES), "summary case order")
    for item, case in zip(value["cases"], oracle.CASES):
        require(set(item) == {"case", "path", "manifest_sha256"} and item["case"] == case and item["path"] == "cases/" + case, "summary case linkage")
        manifest = root / item["path"] / "manifest.json"
        require(manifest.is_file() and digest(manifest.read_bytes()) == item["manifest_sha256"], "summary case hash")
        require(validate_case_manifest(manifest)["run_uuid"] == value["run_uuid"], "summary UUID linkage")
    require(value["tree"] == [item for item in inventory(root) if item["name"] != "manifest.json"], "summary tree changed")
    return value


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
    value = {"case": case, "run_uuid": run_uuid, "input": regular(case_root / "input.csv", case_root),
             "reference_config": regular(case_root / "reference.yml", case_root), "native_config": regular(case_root / "native.yml", case_root),
             "java_version": regular(case_root / "java-version.txt", case_root), "driver": driver_identity(), "reference": reference, "native": native,
             "reference_output": inventory(case_root / "reference-output"), "native_output": inventory(case_root / "native-output")}
    value["tree"] = inventory(case_root)
    manifest = case_root / "manifest.json"
    manifest.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
    validate_case_manifest(manifest)
    assert_equal(reference, native, case_root / "reference-output", case_root / "native-output")
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
    summary = {"run_uuid": str(uuid.uuid4()), "stage_a": stage_a, "reference": {"sha256": oracle.REFERENCE_SHA256},
               "reference_snapshot": regular(jar, root, oracle.REFERENCE_BYTES), "binary": regular(binary, root, MAX_BINARY_BYTES),
               "driver": driver_identity(), "cases": [], "result": "incomplete"}
    try:
        for case in oracle.CASES:
            manifest = run_case(case, root, jar, java, version, binary, summary["run_uuid"])
            summary["cases"].append({"case": case, "path": str(manifest.parent.relative_to(root)), "manifest_sha256": digest(manifest.read_bytes())})
            print("T0032_S04_MATCH=" + case, flush=True)
        summary["result"] = "pass"
    finally:
        summary["tree"] = inventory(root)
        manifest = root / "manifest.json"
        manifest.write_text(json.dumps(summary, sort_keys=True) + "\n", encoding="utf-8")
        validate_summary_manifest(manifest)
        print("T0032_S04_EVIDENCE_DIR=" + str(root), flush=True)
    return root


def self_test():
    with tempfile.TemporaryDirectory(prefix="emburk-t0032-s04-symlink-", dir="/private/tmp") as temporary:
        root = Path(temporary)
        binary = root / "binary"
        binary.write_bytes(b"not executed\n")
        binary.chmod(0o500)
        link = root / "binary-link"
        link.symlink_to(binary)
        original = os.environ.get("EMBURK_BINARY")
        os.environ["EMBURK_BINARY"] = str(link)
        try:
            try:
                executable()
            except ValueError:
                pass
            else:
                raise AssertionError("EMBURK_BINARY symlink was accepted")
        finally:
            if original is None:
                del os.environ["EMBURK_BINARY"]
            else:
                os.environ["EMBURK_BINARY"] = original
    root = main()
    summary_path = root / "manifest.json"
    case_root = root / "cases" / oracle.CASES[0]
    mutations = [
        (case_root / "input.csv", lambda path: path.write_bytes(path.read_bytes() + b"tamper\n")),
        (case_root / "reference.yml", lambda path: path.write_bytes(path.read_bytes() + b"# tamper\n")),
        (case_root / "reference.stderr", lambda path: path.write_bytes(b"tamper\n")),
        (case_root / "native.exit", lambda path: path.write_text("99\n", encoding="ascii")),
        (case_root / "reference-output" / "result000.00.csv", lambda path: path.write_bytes(b"tamper\n")),
        (case_root / "unexpected", lambda path: path.write_bytes(b"tamper\n")),
    ]
    for path, mutate in mutations:
        original = path.read_bytes() if path.exists() else None
        mutate(path)
        try:
            try:
                validate_summary_manifest(summary_path)
            except ValueError:
                pass
            else:
                raise AssertionError("mutation was accepted: " + str(path))
        finally:
            if original is None:
                path.unlink()
            else:
                path.write_bytes(original)
        validate_summary_manifest(summary_path)
    original = summary_path.read_bytes()
    for mutate in (
        lambda value: value["cases"].reverse(),
        lambda value: value["cases"].__setitem__(0, {**value["cases"][0], "manifest_sha256": "0" * 64}),
        lambda value: value["cases"].__setitem__(0, {**value["cases"][0], "path": "cases/wrong"}),
    ):
        value = json.loads(original)
        mutate(value)
        summary_path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
        try:
            try:
                validate_summary_manifest(summary_path)
            except ValueError:
                pass
            else:
                raise AssertionError("summary mutation was accepted")
        finally:
            summary_path.write_bytes(original)
        validate_summary_manifest(summary_path)
    print("T0032_S04_SELF_TEST=pass", flush=True)


if __name__ == "__main__":
    try:
        self_test() if sys.argv[1:] == ["--self-test"] else main()
    except (OSError, ValueError, subprocess.SubprocessError) as failure:
        print("T0032_S04_DIFFERENTIAL_ERROR=" + str(failure), file=sys.stderr)
        raise SystemExit(2)

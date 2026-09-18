#!/usr/bin/env python3
"""Strict, three-case T-0032/S02 Boolean File/CSV executable comparison.

The pinned Embulk executable and Emburk binary are independent black boxes.
All raw inputs, configs, logs, exits, output inventories, and a complete
link-free evidence tree are retained before equality is asserted.
"""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
JAR_SHA256 = "e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47"
CASES = ("canonical-true-false", "unquoted-and-quoted-empty", "invalid-between-valid")
TIMEOUT_SECONDS = 90


def require(value, message):
    if not value:
        raise ValueError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def confined(path, root):
    resolved, boundary = path.resolve(), root.resolve()
    require(resolved != boundary and boundary in resolved.parents, "evidence path escapes root")
    return resolved


def detail(path, root):
    confined(path, root)
    require(path.is_file() and not path.is_symlink(), "evidence item is not a regular file")
    contents = path.read_bytes()
    return {"name": str(path.relative_to(root)), "size": len(contents), "sha256": sha256(contents)}


def tree(root):
    entries = []
    for path in sorted(root.rglob("*")):
        confined(path, root)
        require(not path.is_symlink(), "evidence tree contains symlink")
        name = str(path.relative_to(root))
        if path.is_dir():
            entries.append({"name": name, "type": "directory"})
        elif path.is_file():
            entries.append({"type": "regular", **detail(path, root)})
        else:
            raise ValueError("evidence tree contains special file")
    return entries


def fixture(case):
    values = {
        "canonical-true-false": b"flag\ntrue\nfalse\n",
        "unquoted-and-quoted-empty": b'label,flag\nbare,\nquoted,""\n',
        "invalid-between-valid": b"flag\ntrue\ntruthy\nfalse\n",
    }
    try:
        return values[case]
    except KeyError as failure:
        raise ValueError("unknown selected case") from failure


def config(case):
    columns = b"    - {name: flag, type: boolean}\n"
    if case == "unquoted-and-quoted-empty":
        columns = b"    - {name: label, type: string}\n    - {name: flag, type: boolean}\n"
    return b'''in:
  type: file
  path_prefix: input.csv
  parser:
    type: csv
    charset: UTF-8
    newline: LF
    delimiter: ','
    quote: '"'
    escape: '"'
    skip_header_lines: 1
    columns:
''' + columns + b'''out:
  type: file
  path_prefix: output/result
  file_ext: csv
  formatter:
    type: csv
    charset: UTF-8
    newline: LF
    delimiter: ','
    quote: '"'
    escape: '"'
    header_line: true
    quote_policy: MINIMAL
exec:
  max_threads: 1
  min_output_tasks: 1
'''


def reference_bytes():
    value = os.environ.get("EMBURK_REFERENCE_JAR")
    require(value is not None, "EMBURK_REFERENCE_JAR is required")
    path = Path(value)
    require(path.is_file() and not path.is_symlink(), "reference JAR must be a regular file")
    data = path.read_bytes()
    require(sha256(data) == JAR_SHA256, "reference JAR checksum mismatch")
    return data


def java_command():
    value = os.environ.get("JAVA_HOME")
    require(value is not None, "JAVA_HOME is required")
    java = Path(value) / "bin" / "java"
    require(java.is_file() and os.access(java, os.X_OK), "JAVA_HOME does not provide java")
    probe = subprocess.run([str(java), "-version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           env={"PATH": os.defpath, "JAVA_HOME": str(Path(value).resolve())}, timeout=10)
    version = probe.stdout + probe.stderr
    require(probe.returncode == 0 and b'version "17.' in version, "Java 17 is required")
    return java.resolve(), version


def binary_path():
    value = os.environ.get("EMBURK_BINARY")
    require(value is not None, "EMBURK_BINARY is required")
    path = Path(value).resolve()
    require(path.is_file() and not path.is_symlink() and os.access(path, os.X_OK),
            "EMBURK_BINARY must be a regular executable")
    return path


def kill_group(process):
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def wait_group(process, timeout):
    code, timed_out = None, False
    try:
        code = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
    finally:
        # A leader that exits normally may still leave a descendant running.
        kill_group(process)
    if code is None:
        code = process.wait()
    return code, timed_out


def execute(command, root, label, environment):
    stdout, stderr = root / f"{label}.stdout", root / f"{label}.stderr"
    with stdout.open("xb") as out, stderr.open("xb") as err:
        process = subprocess.Popen(command, cwd=root, env=environment, stdout=out, stderr=err,
                                   start_new_session=True)
        exit_code, timed_out = wait_group(process, TIMEOUT_SECONDS)
    exit_file = root / f"{label}.exit"
    exit_file.write_text(f"{exit_code}\n", encoding="ascii")
    return {"command": [str(part) for part in command], "exit": exit_code, "timed_out": timed_out,
            "stdout": detail(stdout, root), "stderr": detail(stderr, root),
            "exit_file": detail(exit_file, root)}


def outputs(root):
    return [entry for entry in tree(root) if entry["type"] == "regular"]


def validate_process(value, root, label):
    required = {"command", "exit", "timed_out", "stdout", "stderr", "exit_file"}
    require(isinstance(value, dict) and set(value) == required, "process structure")
    require(isinstance(value["command"], list) and all(isinstance(x, str) for x in value["command"]), "process command")
    require(isinstance(value["exit"], int) and isinstance(value["timed_out"], bool), "process result")
    for key, name in (("stdout", f"{label}.stdout"), ("stderr", f"{label}.stderr"), ("exit_file", f"{label}.exit")):
        require(value[key] == detail(root / name, root), "raw process evidence changed")
    require((root / f"{label}.exit").read_text(encoding="ascii") == str(value["exit"]) + "\n", "exit record changed")


def validate_case_manifest(path):
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {"case", "run_uuid", "reference", "binary", "java_version", "input", "reference_config",
                "native_config", "reference_run", "native_run", "case_tree"}
    require(isinstance(value, dict) and set(value) == required and value["case"] in CASES, "case manifest structure")
    require(str(uuid.UUID(value["run_uuid"])) == value["run_uuid"], "case identity")
    require(value["reference"] == {"sha256": JAR_SHA256}, "reference identity")
    root = path.parent
    for key, name in (("java_version", "java-version.txt"), ("input", "input.csv"),
                      ("reference_config", "reference.yml"), ("native_config", "native.yml")):
        require(value[key] == detail(root / name, root), "captured raw input changed")
    require(value["input"]["sha256"] == sha256(fixture(value["case"])), "fixture changed")
    for side in ("reference", "native"):
        run = value[f"{side}_run"]
        require(isinstance(run, dict) and set(run) == {"process", "outputs"}, "run structure")
        validate_process(run["process"], root, side)
        require(run["outputs"] == outputs(root / f"{side}-output"), "output inventory changed")
    actual = [entry for entry in tree(root) if entry["name"] != "manifest.json"]
    require(value["case_tree"] == actual, "case tree changed")
    return value


def validate_summary_manifest(path):
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {"run_uuid", "reference", "reference_snapshot", "binary", "cases", "result", "tree"}
    require(isinstance(value, dict) and set(value) == required, "summary structure")
    require(str(uuid.UUID(value["run_uuid"])) == value["run_uuid"], "summary identity")
    require(value["reference"] == {"sha256": JAR_SHA256}, "summary reference identity")
    root = path.parent
    require(value["reference_snapshot"] == detail(root / "embulk.jar", root), "reference snapshot changed")
    require(value["reference_snapshot"]["sha256"] == JAR_SHA256, "reference snapshot identity")
    require(value["binary"] == detail(root / "emburk", root), "binary snapshot changed")
    require(value["result"] in ("pass", "incomplete"), "summary result")
    order = [x.get("case") if isinstance(x, dict) else None for x in value["cases"]]
    require(isinstance(value["cases"], list) and order == list(CASES), "case order")
    for entry, case in zip(value["cases"], CASES):
        require(isinstance(entry, dict) and set(entry) == {"case", "path", "manifest_sha256"}, "case entry")
        require(entry["case"] == case and entry["path"] == f"cases/{case}", "case linkage")
        manifest = root / entry["path"] / "manifest.json"
        require(manifest.is_file() and not manifest.is_symlink() and entry["manifest_sha256"] == sha256(manifest.read_bytes()), "case hash")
        observed = validate_case_manifest(manifest)
        require(observed["run_uuid"] == value["run_uuid"] and observed["reference"] == value["reference"], "case identity linkage")
    actual = [entry for entry in tree(root) if entry["name"] != "manifest.json"]
    require(value["tree"] == actual, "summary tree changed")
    return value


def assert_equal(value):
    ref, native = value["reference_run"], value["native_run"]
    require(not ref["process"]["timed_out"] and not native["process"]["timed_out"], "timeout is not an outcome")
    require(ref["process"]["exit"] == native["process"]["exit"], "reference/native exit differs")
    require(ref["outputs"] == native["outputs"], "reference/native output inventory differs")


def run_case(case, run_root, jar, binary, java, version, run_uuid):
    root = run_root / "cases" / case
    root.mkdir(parents=True, mode=0o700); root.chmod(0o700)
    for directory in (root / "reference-output", root / "native-output", root / "reference-home", root / "reference-tmp"):
        directory.mkdir(mode=0o700); directory.chmod(0o700)
    (root / "input.csv").write_bytes(fixture(case))
    (root / "java-version.txt").write_bytes(version)
    profile = config(case)
    ref_config = profile.replace(b"output/result", b"reference-output/result")
    native_config = profile.replace(b"output/result", b"native-output/result")
    (root / "reference.yml").write_bytes(ref_config); (root / "native.yml").write_bytes(native_config)
    home, temporary = root / "reference-home", root / "reference-tmp"
    environment = {"PATH": os.defpath, "JAVA_HOME": str(java.parent.parent), "HOME": str(home),
                   "TMPDIR": str(temporary), "EMBULK_HOME": str(home)}
    reference = execute([str(java), f"-Duser.home={home}", f"-Djava.io.tmpdir={temporary}", "-jar", str(jar),
                         f"-Xembulk_home={home}", "run", "reference.yml"], root, "reference", environment)
    native = execute([str(binary), "run", "native.yml"], root, "native", {"PATH": os.defpath})
    value = {"case": case, "run_uuid": run_uuid, "reference": {"sha256": JAR_SHA256},
             "binary": {"sha256": sha256(binary.read_bytes())}, "java_version": detail(root / "java-version.txt", root),
             "input": detail(root / "input.csv", root), "reference_config": detail(root / "reference.yml", root),
             "native_config": detail(root / "native.yml", root),
             "reference_run": {"process": reference, "outputs": outputs(root / "reference-output")},
             "native_run": {"process": native, "outputs": outputs(root / "native-output")}}
    value["case_tree"] = tree(root)
    manifest = root / "manifest.json"; manifest.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
    value = validate_case_manifest(manifest); assert_equal(value)
    return manifest


def main():
    binary = binary_path(); jar_data = reference_bytes(); java, version = java_command()
    root = Path(tempfile.mkdtemp(prefix="emburk-t0032-s02-differential-", dir="/private/tmp")); root.chmod(0o700)
    jar = root / "embulk.jar"; jar.write_bytes(jar_data); jar.chmod(0o400)
    binary_snapshot = root / "emburk"; binary_snapshot.write_bytes(binary.read_bytes()); binary_snapshot.chmod(0o500)
    summary = {"run_uuid": str(uuid.uuid4()), "reference": {"sha256": JAR_SHA256},
               "reference_snapshot": detail(jar, root), "binary": detail(binary_snapshot, root), "cases": [], "result": "incomplete"}
    try:
        for case in CASES:
            manifest = run_case(case, root, jar, binary_snapshot, java, version, summary["run_uuid"])
            summary["cases"].append({"case": case, "path": str(manifest.parent.relative_to(root)), "manifest_sha256": sha256(manifest.read_bytes())})
            print("T0032_S02_MATCH=" + case, flush=True)
        summary["result"] = "pass"
    finally:
        summary["tree"] = tree(root)
        manifest = root / "manifest.json"; manifest.write_text(json.dumps(summary, sort_keys=True) + "\n", encoding="utf-8")
        validate_summary_manifest(manifest)
        print("T0032_S02_EVIDENCE_DIR=" + str(root), flush=True)


class DriverTests(unittest.TestCase):
    def test_cases_are_the_authorized_oracle_cases(self):
        self.assertEqual(CASES, ("canonical-true-false", "unquoted-and-quoted-empty", "invalid-between-valid"))

    def test_tree_rejects_link(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); (root / "regular").write_text("x")
            (root / "link").symlink_to(root / "regular")
            with self.assertRaises(ValueError): tree(root)

    def test_process_group_cleanup_on_normal_and_timeout(self):
        parents = (("import subprocess,sys;subprocess.Popen([sys.executable,'-c',sys.argv[1],sys.argv[2]])", 2),
                   ("import subprocess,sys,time;subprocess.Popen([sys.executable,'-c',sys.argv[1],sys.argv[2]]);time.sleep(4)", .03))
        for parent, timeout in parents:
            with tempfile.TemporaryDirectory() as temporary:
                marker = Path(temporary) / "marker"
                child = "import pathlib,sys,time;time.sleep(.2);pathlib.Path(sys.argv[1]).write_text('bad')"
                process = subprocess.Popen([sys.executable, "-c", parent, child, str(marker)], start_new_session=True)
                wait_group(process, timeout); time.sleep(.3); self.assertFalse(marker.exists())

    def test_summary_rejects_added_tree_entry(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); (root / "entry").write_text("x")
            observed = tree(root); (root / "later").write_text("x")
            self.assertNotEqual(observed, tree(root))


if __name__ == "__main__":
    if "--unit" in sys.argv:
        sys.argv.remove("--unit"); unittest.main()
    else:
        try:
            main()
        except (OSError, ValueError, subprocess.SubprocessError) as failure:
            print("T0032_S02_DIFFERENTIAL_ERROR=" + str(failure), file=sys.stderr)
            raise SystemExit(2)

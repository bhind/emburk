#!/usr/bin/env python3
"""Selected T-0031/S03 native/reference File/CSV comparisons.

This is an original test driver.  It deliberately uses the pinned executable as
a black box and records raw evidence before checking the three selected
projections.  It is not a general File-plugin compatibility harness.
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

REPO = Path(__file__).resolve().parents[1]
JAR_SHA256 = "e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47"
CASES = ("two-regular", "regular-and-directory", "malformed-later")
TIMEOUT_SECONDS = 90


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def confined(path, root):
    resolved, boundary = path.resolve(), root.resolve()
    if resolved == boundary or boundary not in resolved.parents:
        raise ValueError("evidence path escapes root")
    return resolved


def detail(path, root):
    confined(path, root)
    if not path.is_file() or path.is_symlink():
        raise ValueError("evidence item is not a regular file")
    data = path.read_bytes()
    return {"name": str(path.relative_to(root)), "size": len(data), "sha256": sha256(data)}


def tree(root):
    """Strict inventory: no links, special files, or unrecorded entries."""
    entries = []
    for path in sorted(root.rglob("*")):
        confined(path, root)
        if path.is_symlink():
            raise ValueError("evidence tree contains symlink")
        name = str(path.relative_to(root))
        if path.is_dir():
            entries.append({"name": name, "type": "directory"})
        elif path.is_file():
            entries.append({"type": "regular", **detail(path, root)})
        else:
            raise ValueError("evidence tree contains special file")
    return entries


def reference_bytes():
    value = os.environ.get("EMBURK_REFERENCE_JAR")
    require(value is not None, "EMBURK_REFERENCE_JAR is required")
    path = Path(value)
    require(path.is_file() and not path.is_symlink(), "reference JAR must be a regular file")
    data = path.read_bytes()
    require(sha256(data) == JAR_SHA256, "reference JAR checksum mismatch")
    return data


def java_command():
    home = os.environ.get("JAVA_HOME")
    require(home is not None, "JAVA_HOME is required")
    java = Path(home) / "bin" / "java"
    require(java.is_file() and os.access(java, os.X_OK), "JAVA_HOME does not provide java")
    probe = subprocess.run([str(java), "-version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           env={"PATH": os.defpath, "JAVA_HOME": str(Path(home).resolve())}, timeout=10)
    version = probe.stdout + probe.stderr
    require(probe.returncode == 0 and b'version "17.' in version, "Java 17 is required")
    return java.resolve(), version


def fixture(case):
    header = b"id,name\n"
    if case == "two-regular":
        return {"input.10.csv": header + b"10,alpha\n", "input.20.csv": header + b"20,beta\n"}
    if case == "regular-and-directory":
        return {"input.10.csv": header + b"10,alpha\n", "input.15.csv": None}
    if case == "malformed-later":
        return {"input.10.csv": header + b"10,alpha\n", "input.20.csv": header + b"not-a-long,beta\n"}
    raise ValueError("unknown selected case")


def config():
    return b'''in:
  type: file
  path_prefix: input.
  parser:
    type: csv
    charset: UTF-8
    newline: LF
    delimiter: ','
    quote: '"'
    escape: '"'
    skip_header_lines: 1
    columns:
    - {name: id, type: long}
    - {name: name, type: string}
out:
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


def outputs(root):
    output = root / "output"
    return [item for item in tree(output) if item["type"] == "regular"]


def kill_group(process):
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def wait_group(process, timeout):
    """Wait once, while guaranteeing group cleanup on every return path."""
    code = None
    timed_out = False
    try:
        code = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
    finally:
        kill_group(process)
    if code is None:
        code = process.wait()
    return code, timed_out


def execute(command, root, label, environment, expected_timeout=TIMEOUT_SECONDS):
    """Capture a process and always kill its isolated process group."""
    stdout, stderr = root / (label + ".stdout"), root / (label + ".stderr")
    with stdout.open("xb") as out, stderr.open("xb") as err:
        child = subprocess.Popen(command, cwd=root, env=environment, stdout=out, stderr=err,
                                 start_new_session=True)
        # This also handles normal parent exit with a live descendant.
        code, timed_out = wait_group(child, expected_timeout)
    (root / (label + ".process.json")).write_text(json.dumps({
        "command": [str(part) for part in command], "exit": code, "timed_out": timed_out,
        "stdout": detail(stdout, root), "stderr": detail(stderr, root),
    }, sort_keys=True) + "\n", encoding="utf-8")
    return code, timed_out


def validate_case_manifest(path):
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {"case", "run_uuid", "reference", "config", "inputs", "reference_run", "native_run", "case_tree"}
    require(isinstance(value, dict) and set(value) == required and value["case"] in CASES, "case manifest structure")
    require(str(uuid.UUID(value["run_uuid"])) == value["run_uuid"], "case run identity")
    require(value["reference"] == {"sha256": JAR_SHA256}, "case reference identity")
    root = path.parent
    require(value["config"] == detail(root / "config.yml", root), "captured config changed")
    for name, contents in fixture(value["case"]).items():
        candidate = root / "input" / name
        if contents is None:
            require(candidate.is_dir() and not candidate.is_symlink(), "input directory changed")
        else:
            require(detail(candidate, root)["sha256"] == sha256(contents), "input changed")
    require(value["inputs"] == tree(root / "input"), "input inventory changed")
    for name in ("reference_run", "native_run"):
        run = value[name]
        require(isinstance(run, dict) and set(run) == {"exit", "timed_out", "outputs", "process"}, "run shape")
        require(isinstance(run["exit"], int) and isinstance(run["timed_out"], bool), "run process")
        process = run["process"]
        for key in ("stdout", "stderr"):
            recorded = process.get(key)
            require(isinstance(recorded, dict), "missing raw log")
            require(recorded == detail(root / recorded["name"], root), "raw log changed")
        output_root = root / ("reference-output" if name == "reference_run" else "native-output")
        require(run["outputs"] == outputs(output_root), "output inventory changed")
    actual = [entry for entry in tree(root) if entry["name"] != "manifest.json"]
    require(value["case_tree"] == actual, "case tree changed")
    return value


def assert_selected(value, root):
    reference, native = value["reference_run"], value["native_run"]
    require(not reference["timed_out"] and not native["timed_out"], "timeout is not an outcome")
    if value["case"] == "two-regular":
        expected = [("result000.00.csv", b"id,name\n10,alpha\n"), ("result001.00.csv", b"id,name\n20,beta\n")]
        require(reference["exit"] == native["exit"] == 0, "two regular exit")
    elif value["case"] == "regular-and-directory":
        expected = [("result000.00.csv", b"id,name\n10,alpha\n")]
        require(reference["exit"] == native["exit"] == 0, "directory exclusion exit")
    else:
        expected = [("result000.00.csv", b"id,name\n10,alpha\n")]
        require(reference["exit"] != 0 and native["exit"] != 0, "malformed later must fail")
    expected_names = [name for name, _ in expected]
    for run, output_dir in ((reference, root / "reference-output"), (native, root / "native-output")):
        require([entry["name"] for entry in run["outputs"]] == expected_names, "selected output names differ")
        for name, contents in expected:
            require((output_dir / name).read_bytes() == contents, "selected output bytes differ")
    require(reference["outputs"] == native["outputs"], "reference/native output inventory differs")


def run_case(case, run_root, jar, java, version, run_uuid, binary):
    root = run_root / "cases" / case
    root.mkdir(parents=True)
    input_dir, ref_out, native_out = root / "input", root / "reference-output", root / "native-output"
    input_dir.mkdir(); ref_out.mkdir(); native_out.mkdir()
    for name, contents in fixture(case).items():
        target = input_dir / name
        target.mkdir() if contents is None else target.write_bytes(contents)
    (root / "config.yml").write_bytes(config())
    (root / "java-version.txt").write_bytes(version)
    ref_home, ref_tmp = root / "reference-home", root / "reference-tmp"
    ref_home.mkdir(); ref_tmp.mkdir()
    ref_config = config().replace(b"path_prefix: input.", b"path_prefix: input/input.").replace(b"path_prefix: output/result", b"path_prefix: reference-output/result")
    native_config = config().replace(b"path_prefix: input.", b"path_prefix: input/input.").replace(b"path_prefix: output/result", b"path_prefix: native-output/result")
    (root / "reference.yml").write_bytes(ref_config)
    (root / "native.yml").write_bytes(native_config)
    ref_env = {"PATH": os.defpath, "JAVA_HOME": str(java.parent.parent), "HOME": str(ref_home), "TMPDIR": str(ref_tmp), "EMBULK_HOME": str(ref_home)}
    ref_command = [str(java), f"-Duser.home={ref_home}", f"-Djava.io.tmpdir={ref_tmp}", "-jar", str(jar), f"-Xembulk_home={ref_home}", "run", "reference.yml"]
    reference_exit, reference_timeout = execute(ref_command, root, "reference", ref_env)
    native_exit, native_timeout = execute([str(binary), "run", "native.yml"], root, "native", {"PATH": os.defpath})
    # Store config.yml as the common semantic profile, while raw per-side configs stay in the tree.
    manifest = {
        "case": case, "run_uuid": run_uuid, "reference": {"sha256": JAR_SHA256},
        "config": detail(root / "config.yml", root), "inputs": tree(input_dir),
        "reference_run": {"exit": reference_exit, "timed_out": reference_timeout, "outputs": outputs(ref_out),
                          "process": json.loads((root / "reference.process.json").read_text())},
        "native_run": {"exit": native_exit, "timed_out": native_timeout, "outputs": outputs(native_out),
                       "process": json.loads((root / "native.process.json").read_text())},
    }
    manifest["case_tree"] = tree(root)
    path = root / "manifest.json"
    path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
    value = validate_case_manifest(path)
    assert_selected(value, root)
    return path


def main():
    binary = Path(os.environ.get("EMBURK_BINARY", REPO / "target/debug/emburk")).resolve()
    require(binary.is_file() and not binary.is_symlink(), "EMBURK_BINARY must be a regular executable")
    jar_data = reference_bytes()
    java, version = java_command()
    root = Path(tempfile.mkdtemp(prefix="emburk-t0031-s03-differential-", dir="/private/tmp"))
    root.chmod(0o700)
    jar = root / "embulk.jar"; jar.write_bytes(jar_data); jar.chmod(0o400)
    run_uuid = str(uuid.uuid4())
    summary = {"run_uuid": run_uuid, "reference_sha256": JAR_SHA256, "binary_sha256": sha256(binary.read_bytes()), "cases": [], "result": "incomplete"}
    try:
        for case in CASES:
            manifest = run_case(case, root, jar, java, version, run_uuid, binary)
            summary["cases"].append({"case": case, "path": str(manifest.parent.relative_to(root)), "manifest_sha256": sha256(manifest.read_bytes())})
            print("T0031_S03_MATCH=" + case, flush=True)
        require(sha256(jar.read_bytes()) == JAR_SHA256, "reference snapshot changed")
        require(sha256(binary.read_bytes()) == summary["binary_sha256"], "native binary changed")
        summary["result"] = "pass"
    finally:
        summary["tree"] = tree(root)
        (root / "manifest.json").write_text(json.dumps(summary, sort_keys=True) + "\n", encoding="utf-8")
        print("T0031_S03_EVIDENCE_DIR=" + str(root), flush=True)


class DriverTests(unittest.TestCase):
    def test_cases_and_fixture_are_bounded(self):
        self.assertEqual(CASES, ("two-regular", "regular-and-directory", "malformed-later"))
        self.assertEqual(fixture("regular-and-directory")["input.15.csv"], None)

    def test_kill_group_stops_normal_exit_descendant(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "marker"
            child = "import pathlib,sys,time;time.sleep(.3);pathlib.Path(sys.argv[1]).write_text('bad')"
            parent = "import subprocess,sys;subprocess.Popen([sys.executable,'-c',sys.argv[1],sys.argv[2]])"
            process = subprocess.Popen([sys.executable, "-c", parent, child, str(marker)], start_new_session=True)
            exit_code, timed_out = wait_group(process, 2)
            time.sleep(.4)
            self.assertEqual((exit_code, timed_out), (0, False))
            self.assertFalse(marker.exists())

    def test_timeout_cleanup_stops_descendant(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "marker"
            child = "import pathlib,sys,time;time.sleep(.3);pathlib.Path(sys.argv[1]).write_text('bad')"
            parent = "import subprocess,sys,time;subprocess.Popen([sys.executable,'-c',sys.argv[1],sys.argv[2]]);time.sleep(5)"
            process = subprocess.Popen([sys.executable, "-c", parent, child, str(marker)], start_new_session=True)
            _, timed_out = wait_group(process, .05)
            time.sleep(.4)
            self.assertTrue(timed_out)
            self.assertFalse(marker.exists())

    def test_interrupted_wait_stops_descendant(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "marker"
            child = "import pathlib,sys,time;time.sleep(.3);pathlib.Path(sys.argv[1]).write_text('bad')"
            process = subprocess.Popen([sys.executable, "-c", child, str(marker)], start_new_session=True)

            class Interrupted:
                pid = process.pid

                @staticmethod
                def wait(timeout=None):
                    raise KeyboardInterrupt

            with self.assertRaises(KeyboardInterrupt):
                wait_group(Interrupted(), .01)
            process.wait(timeout=2)
            time.sleep(.4)
            self.assertFalse(marker.exists())

    def test_tree_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); (root / "regular").write_text("x")
            (root / "link").symlink_to(root / "regular")
            with self.assertRaises(ValueError): tree(root)

    def test_reference_checksum_is_pinned(self):
        with tempfile.TemporaryDirectory() as directory:
            original = os.environ.get("EMBURK_REFERENCE_JAR")
            try:
                path = Path(directory) / "wrong.jar"; path.write_bytes(b"wrong")
                os.environ["EMBURK_REFERENCE_JAR"] = str(path)
                with self.assertRaises(ValueError): reference_bytes()
            finally:
                if original is None: os.environ.pop("EMBURK_REFERENCE_JAR", None)
                else: os.environ["EMBURK_REFERENCE_JAR"] = original


if __name__ == "__main__":
    if "--unit" in sys.argv:
        sys.argv.remove("--unit")
        unittest.main()
    else:
        try:
            main()
        except (OSError, ValueError, subprocess.SubprocessError) as failure:
            print("T0031_S03_DIFFERENTIAL_ERROR=" + str(failure), file=sys.stderr)
            raise SystemExit(2)

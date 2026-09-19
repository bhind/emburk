#!/usr/bin/env python3
"""Capture a deliberately small Float64 CSV observation from Embulk.

This is an original, evidence-only black-box driver.  It neither asserts a
native policy nor derives expected output from a fixture name.  Its purpose is
to retain the bytes produced by the admitted executable so that review can
decide whether a later, separately authorized implementation is warranted.
"""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import uuid


REFERENCE_SHA256 = "e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47"
REFERENCE_BYTES = 11109700
CASES = ("finite-decimal-and-signed-zero", "unquoted-and-quoted-empty", "malformed-between-finite")
TIMEOUT_SECONDS = 90
MAX_INPUT_BYTES = 4096
MAX_CONFIG_BYTES = 8192
MAX_LOG_BYTES = 1024 * 1024
MAX_OUTPUT_FILE_BYTES = 1024 * 1024
MAX_CASE_TREE_BYTES = 3 * 1024 * 1024
MAX_SUMMARY_TREE_BYTES = 16 * 1024 * 1024
MAX_OUTPUT_RECORDS = 32
DRIVER_LABEL = "tools/t0032-float64-file-csv-oracle/run.py"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def within(path, root):
    resolved, boundary = path.resolve(), root.resolve()
    if resolved == boundary or boundary not in resolved.parents:
        raise ValueError("evidence path escapes capture root")
    return resolved


def regular(path, root):
    within(path, root)
    if path.is_symlink() or not path.is_file():
        raise ValueError("evidence item is not a regular file")
    data = path.read_bytes()
    return {"name": str(path.relative_to(root)), "size": len(data), "sha256": digest(data)}


def canonical_text(path, root, limit):
    """Verify a retained text artifact, including raw reference output/logs."""
    detail = regular(path, root)
    require(detail["size"] <= limit, "evidence item exceeds byte cap")
    data = path.read_bytes()
    try:
        data.decode("utf-8")
    except UnicodeDecodeError as failure:
        raise ValueError("evidence item is not UTF-8") from failure
    require(b"\r" not in data, "evidence item is not canonical LF")
    require(not data or data.endswith(b"\n"), "non-empty evidence item lacks final LF")
    return detail


def tree(root, cap=MAX_CASE_TREE_BYTES):
    entries, total = [], 0
    for path in sorted(root.rglob("*")):
        within(path, root)
        if path.is_symlink():
            raise ValueError("evidence tree contains symlink")
        name = str(path.relative_to(root))
        if path.is_dir():
            entries.append({"name": name, "type": "directory"})
        elif path.is_file():
            item = regular(path, root)
            total += item["size"]
            entries.append({"type": "regular", **item})
        else:
            raise ValueError("evidence tree contains special file")
    require(total <= cap, "evidence tree exceeds byte cap")
    return entries


def checked_output(root):
    files = []
    for path in sorted(root.rglob("*")):
        within(path, root)
        if path.is_symlink() or not path.is_file():
            raise ValueError("output tree contains non-regular item")
        detail = canonical_text(path, root.parent, MAX_OUTPUT_FILE_BYTES)
        lines = path.read_bytes().splitlines()
        require(len(lines) <= MAX_OUTPUT_RECORDS + 1, "output exceeds record cap")
        files.append(detail)
    return files


def reference(environment):
    raw = environment.get("EMBURK_REFERENCE_JAR")
    require(raw is not None, "EMBURK_REFERENCE_JAR is required")
    path = Path(raw)
    require(path.is_file() and not path.is_symlink(), "reference JAR must be regular")
    require(path.stat().st_size == REFERENCE_BYTES, "reference JAR size mismatch")
    contents = path.read_bytes()
    require(digest(contents) == REFERENCE_SHA256, "reference JAR checksum mismatch")
    return contents


def java17(environment):
    raw = environment.get("JAVA_HOME")
    require(raw is not None, "JAVA_HOME is required")
    home = Path(raw).resolve()
    java = home / "bin" / "java"
    require(java.is_file() and os.access(java, os.X_OK), "JAVA_HOME does not provide java")
    probe = subprocess.run([str(java), "-version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           env={"PATH": os.defpath, "JAVA_HOME": str(home)}, timeout=10)
    version = probe.stdout + probe.stderr
    require(probe.returncode == 0 and b'version "17.' in version, "Java 17 is required")
    # Java itself emits its version on stderr. Normalize only its evidence form.
    require(b"\r" not in version and version.endswith(b"\n"), "Java version output is not canonical LF")
    version.decode("utf-8")
    return java, version, {"java_home": str(home), "java_version_sha256": digest(version)}


def fixture(case):
    values = {
        "finite-decimal-and-signed-zero": b"ratio\n1.5\n-0.0\n0.0\n",
        "unquoted-and-quoted-empty": b'label,ratio\nbare,\nquoted,""\n',
        "malformed-between-finite": b"ratio\n1.5\nnot-a-double\n2.5\n",
    }
    try:
        return values[case]
    except KeyError as failure:
        raise ValueError("unknown selected case") from failure


def config(case):
    columns = b"    - {name: ratio, type: double}\n"
    if case == "unquoted-and-quoted-empty":
        columns = b"    - {name: label, type: string}\n    - {name: ratio, type: double}\n"
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


def terminate_group(process):
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def capture_process(command, root, environment):
    stdout, stderr = root / "stdout.log", root / "stderr.log"
    with stdout.open("xb") as out, stderr.open("xb") as err:
        process = subprocess.Popen(command, cwd=root, env=environment, stdout=out, stderr=err,
                                   start_new_session=True)
        timed_out = False
        try:
            exit_code = process.wait(timeout=TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            timed_out = True
            terminate_group(process)
            exit_code = process.wait()
        finally:
            terminate_group(process)
    (root / "exit.txt").write_text(f"{exit_code}\n", encoding="ascii")
    return {"command": [str(part) for part in command], "exit": exit_code, "timed_out": timed_out,
            "stdout": canonical_text(stdout, root, MAX_LOG_BYTES),
            "stderr": canonical_text(stderr, root, MAX_LOG_BYTES),
            "exit_file": canonical_text(root / "exit.txt", root, 64)}


def validate_case(path):
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {"case", "run_uuid", "reference", "environment", "java_version", "driver", "config", "input", "process", "outputs", "case_tree"}
    require(isinstance(value, dict) and set(value) == required, "case manifest structure")
    require(value["case"] in CASES and str(uuid.UUID(value["run_uuid"])) == value["run_uuid"], "case identity")
    require(value["reference"] == {"sha256": REFERENCE_SHA256}, "reference identity")
    root = path.parent
    require(value["driver"] == {"path": DRIVER_LABEL, "sha256": digest(Path(__file__).read_bytes())}, "driver identity")
    require(isinstance(value["environment"], dict) and set(value["environment"]) == {"java_home", "java_version_sha256"}, "environment identity")
    require(value["java_version"] == canonical_text(root / "java-version.txt", root, MAX_LOG_BYTES), "Java evidence changed")
    require(value["environment"]["java_version_sha256"] == value["java_version"]["sha256"], "Java linkage")
    require(value["config"] == canonical_text(root / "config.yml", root, MAX_CONFIG_BYTES), "config changed")
    require(value["input"] == canonical_text(root / "input.csv", root, MAX_INPUT_BYTES), "input changed")
    process = value["process"]
    require(isinstance(process, dict) and set(process) == {"command", "exit", "timed_out", "stdout", "stderr", "exit_file"}, "process structure")
    require(isinstance(process["command"], list) and all(isinstance(item, str) for item in process["command"]), "process command")
    require(isinstance(process["exit"], int) and isinstance(process["timed_out"], bool), "process result")
    for key, relative in (("stdout", "stdout.log"), ("stderr", "stderr.log"), ("exit_file", "exit.txt")):
        require(process[key] == canonical_text(root / relative, root, MAX_LOG_BYTES), "process evidence changed")
    require((root / "exit.txt").read_text(encoding="ascii") == str(process["exit"]) + "\n", "exit record changed")
    require(value["outputs"] == checked_output(root / "output"), "output inventory changed")
    actual = [item for item in tree(root) if item["name"] != "manifest.json"]
    require(value["case_tree"] == actual, "case tree changed")
    return value


def validate_summary(path):
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {"run_uuid", "reference", "reference_snapshot", "driver", "cases", "result", "tree"}
    require(isinstance(value, dict) and set(value) == required, "summary manifest structure")
    require(str(uuid.UUID(value["run_uuid"])) == value["run_uuid"], "summary identity")
    require(value["reference"] == {"sha256": REFERENCE_SHA256}, "summary reference")
    require(value["driver"] == {"path": DRIVER_LABEL, "sha256": digest(Path(__file__).read_bytes())}, "summary driver")
    root = path.parent
    require(value["reference_snapshot"] == regular(root / "embulk.jar", root), "reference snapshot")
    require(value["reference_snapshot"]["sha256"] == REFERENCE_SHA256, "reference snapshot checksum")
    require(value["result"] == "captured", "summary result")
    require(isinstance(value["cases"], list) and [item.get("case") if isinstance(item, dict) else None for item in value["cases"]] == list(CASES), "summary case order")
    for item, case in zip(value["cases"], CASES):
        require(set(item) == {"case", "path", "manifest_sha256"}, "summary case shape")
        require(item["path"] == f"cases/{case}", "summary case path")
        manifest = root / item["path"] / "manifest.json"
        require(manifest.is_file() and not manifest.is_symlink(), "summary case manifest")
        require(item["manifest_sha256"] == digest(manifest.read_bytes()), "summary case hash")
        captured = validate_case(manifest)
        require(captured["case"] == case and captured["run_uuid"] == value["run_uuid"], "summary linkage")
    actual = [item for item in tree(root, MAX_SUMMARY_TREE_BYTES) if item["name"] != "manifest.json"]
    require(value["tree"] == actual, "summary tree changed")
    return value


def run_case(case, capture_root, jar, java, version, environment_identity, run_uuid):
    root = capture_root / "cases" / case
    root.mkdir(parents=True, mode=0o700)
    output, home, temporary = root / "output", root / "home", root / "tmp"
    for directory in (output, home, temporary):
        directory.mkdir(mode=0o700)
    (root / "input.csv").write_bytes(fixture(case))
    (root / "config.yml").write_bytes(config(case))
    (root / "java-version.txt").write_bytes(version)
    environment = {"PATH": os.defpath, "JAVA_HOME": environment_identity["java_home"], "HOME": str(home),
                   "TMPDIR": str(temporary), "EMBULK_HOME": str(home)}
    command = [str(java), f"-Duser.home={home}", f"-Djava.io.tmpdir={temporary}", "-jar", str(jar),
               f"-Xembulk_home={home}", "run", "config.yml"]
    process = capture_process(command, root, environment)
    manifest = {"case": case, "run_uuid": run_uuid, "reference": {"sha256": REFERENCE_SHA256},
                "environment": environment_identity, "java_version": canonical_text(root / "java-version.txt", root, MAX_LOG_BYTES),
                "driver": {"path": DRIVER_LABEL, "sha256": digest(Path(__file__).read_bytes())},
                "config": canonical_text(root / "config.yml", root, MAX_CONFIG_BYTES),
                "input": canonical_text(root / "input.csv", root, MAX_INPUT_BYTES), "process": process,
                "outputs": checked_output(output)}
    manifest["case_tree"] = tree(root)
    path = root / "manifest.json"
    path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
    validate_case(path)
    return path


def main():
    jar_data = reference(os.environ)
    java, version, environment_identity = java17(os.environ)
    root = Path(tempfile.mkdtemp(prefix="emburk-t0032-s03-float64-capture-", dir="/private/tmp"))
    root.chmod(0o700)
    jar = root / "embulk.jar"
    jar.write_bytes(jar_data)
    jar.chmod(0o400)
    run_uuid = str(uuid.uuid4())
    summary = {"run_uuid": run_uuid, "reference": {"sha256": REFERENCE_SHA256},
               "reference_snapshot": regular(jar, root), "driver": {"path": DRIVER_LABEL, "sha256": digest(Path(__file__).read_bytes())},
               "cases": [], "result": "captured"}
    try:
        for case in CASES:
            manifest = run_case(case, root, jar, java, version, environment_identity, run_uuid)
            summary["cases"].append({"case": case, "path": str(manifest.parent.relative_to(root)),
                                     "manifest_sha256": digest(manifest.read_bytes())})
            print("T0032_S03_CAPTURED=" + case, flush=True)
        require(digest(jar.read_bytes()) == REFERENCE_SHA256, "reference snapshot changed")
    finally:
        summary["tree"] = tree(root, MAX_SUMMARY_TREE_BYTES)
        path = root / "manifest.json"
        path.write_text(json.dumps(summary, sort_keys=True) + "\n", encoding="utf-8")
        validate_summary(path)
        print("T0032_S03_EVIDENCE_DIR=" + str(root), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as failure:
        print("T0032_S03_CAPTURE_ERROR=" + str(failure), file=sys.stderr)
        raise SystemExit(2)

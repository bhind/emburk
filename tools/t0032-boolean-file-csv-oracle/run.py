#!/usr/bin/env python3
"""Capture three bounded Boolean File/CSV reference executions.

This original black-box oracle records raw observations from the checksum-pinned
Embulk executable.  It deliberately makes no native-policy or compatibility
claim; later work may consume these immutable capture artifacts.
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

JAR_SHA256 = "e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47"
CASES = ("canonical-true-false", "unquoted-and-quoted-empty", "invalid-between-valid")
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


def regular_detail(path, root):
    confined(path, root)
    if not path.is_file() or path.is_symlink():
        raise ValueError("evidence item is not a regular file")
    data = path.read_bytes()
    return {"name": str(path.relative_to(root)), "size": len(data), "sha256": sha256(data)}


def inventory(root):
    """Return a complete, link-free inventory rather than only selected output files."""
    entries = []
    for path in sorted(root.rglob("*")):
        confined(path, root)
        if path.is_symlink():
            raise ValueError("evidence tree contains symlink")
        name = str(path.relative_to(root))
        if path.is_dir():
            entries.append({"name": name, "type": "directory"})
        elif path.is_file():
            entries.append({"type": "regular", **regular_detail(path, root)})
        else:
            raise ValueError("evidence tree contains special file")
    return entries


def reference_bytes(environment):
    value = environment.get("EMBURK_REFERENCE_JAR")
    require(value is not None, "EMBURK_REFERENCE_JAR is required")
    path = Path(value)
    require(path.is_file() and not path.is_symlink(), "reference JAR must be a regular file")
    data = path.read_bytes()
    require(sha256(data) == JAR_SHA256, "reference JAR checksum mismatch")
    return data


def java_command(environment):
    home = environment.get("JAVA_HOME")
    require(home is not None, "JAVA_HOME is required")
    java = Path(home) / "bin" / "java"
    require(java.is_file() and os.access(java, os.X_OK), "JAVA_HOME does not provide java")
    probe = subprocess.run(
        [str(java), "-version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        env={"PATH": os.defpath, "JAVA_HOME": str(Path(home).resolve())}, timeout=10,
    )
    raw = probe.stdout + probe.stderr
    require(probe.returncode == 0 and b'version "17.' in raw, "Java 17 is required")
    return java.resolve(), raw


def fixture(case):
    values = {
        "canonical-true-false": b"flag\ntrue\nfalse\n",
        "unquoted-and-quoted-empty": b"flag\n\n\"\"\n",
        "invalid-between-valid": b"flag\ntrue\ntruthy\nfalse\n",
    }
    try:
        return values[case]
    except KeyError as failure:
        raise ValueError("unknown selected case") from failure


def config():
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
    - {name: flag, type: boolean}
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
        # Normal parent exit can leave descendants; always clean the whole group.
        kill_group(process)
    if code is None:
        code = process.wait()
    return code, timed_out


def run_process(command, root, environment):
    stdout, stderr = root / "stdout.log", root / "stderr.log"
    with stdout.open("xb") as out, stderr.open("xb") as err:
        process = subprocess.Popen(command, cwd=root, env=environment, stdout=out, stderr=err,
                                   start_new_session=True)
        exit_code, timed_out = wait_group(process, TIMEOUT_SECONDS)
    (root / "exit.txt").write_text(f"{exit_code}\n", encoding="ascii")
    return {
        "command": [str(part) for part in command], "exit": exit_code, "timed_out": timed_out,
        "stdout": regular_detail(stdout, root), "stderr": regular_detail(stderr, root),
        "exit_file": regular_detail(root / "exit.txt", root),
    }


def validate_case_manifest(path):
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {"case", "run_uuid", "reference", "java_version", "config", "input", "process", "outputs", "case_tree"}
    require(isinstance(value, dict) and set(value) == required, "case manifest structure")
    require(value["case"] in CASES and str(uuid.UUID(value["run_uuid"])) == value["run_uuid"], "case identity")
    require(value["reference"] == {"sha256": JAR_SHA256}, "reference identity")
    root = path.parent
    for key, relative in (("java_version", "java-version.txt"), ("config", "config.yml"), ("input", "input.csv")):
        require(value[key] == regular_detail(root / relative, root), "captured input changed")
    process = value["process"]
    require(isinstance(process, dict) and set(process) == {"command", "exit", "timed_out", "stdout", "stderr", "exit_file"}, "process shape")
    require(isinstance(process["command"], list) and all(isinstance(item, str) for item in process["command"]), "process command")
    require(isinstance(process["exit"], int) and isinstance(process["timed_out"], bool), "process result")
    for key, relative in (("stdout", "stdout.log"), ("stderr", "stderr.log"), ("exit_file", "exit.txt")):
        require(process[key] == regular_detail(root / relative, root), "raw process evidence changed")
    require((root / "exit.txt").read_text(encoding="ascii") == str(process["exit"]) + "\n", "exit record changed")
    require(value["outputs"] == inventory(root / "output"), "output inventory changed")
    actual = [item for item in inventory(root) if item["name"] != "manifest.json"]
    require(value["case_tree"] == actual, "case tree changed")
    return value


def run_case(case, run_root, jar, java, java_version, run_uuid):
    root = run_root / "cases" / case
    root.mkdir(parents=True, mode=0o700)
    root.chmod(0o700)
    output, home, temporary = root / "output", root / "home", root / "tmp"
    for directory in (output, home, temporary):
        directory.mkdir(mode=0o700)
        directory.chmod(0o700)
    (root / "input.csv").write_bytes(fixture(case))
    (root / "config.yml").write_bytes(config())
    (root / "java-version.txt").write_bytes(java_version)
    environment = {"PATH": os.defpath, "JAVA_HOME": str(java.parent.parent), "HOME": str(home),
                   "TMPDIR": str(temporary), "EMBULK_HOME": str(home)}
    command = [str(java), f"-Duser.home={home}", f"-Djava.io.tmpdir={temporary}", "-jar", str(jar),
               f"-Xembulk_home={home}", "run", "config.yml"]
    process = run_process(command, root, environment)
    manifest = {
        "case": case, "run_uuid": run_uuid, "reference": {"sha256": JAR_SHA256},
        "java_version": regular_detail(root / "java-version.txt", root),
        "config": regular_detail(root / "config.yml", root), "input": regular_detail(root / "input.csv", root),
        "process": process, "outputs": inventory(output),
    }
    manifest["case_tree"] = inventory(root)
    path = root / "manifest.json"
    path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
    validate_case_manifest(path)
    return path


def main():
    jar_data = reference_bytes(os.environ)
    java, version = java_command(os.environ)
    root = Path(tempfile.mkdtemp(prefix="emburk-t0032-s02-boolean-capture-", dir="/private/tmp"))
    root.chmod(0o700)
    jar = root / "embulk.jar"
    jar.write_bytes(jar_data); jar.chmod(0o400)
    run_uuid = str(uuid.uuid4())
    summary = {"run_uuid": run_uuid, "reference_sha256": JAR_SHA256, "cases": [], "result": "captured"}
    try:
        for case in CASES:
            manifest = run_case(case, root, jar, java, version, run_uuid)
            summary["cases"].append({"case": case, "path": str(manifest.parent.relative_to(root)),
                                     "manifest_sha256": sha256(manifest.read_bytes())})
            print("T0032_S02_CAPTURED=" + case, flush=True)
        require(sha256(jar.read_bytes()) == JAR_SHA256, "reference snapshot changed")
    finally:
        summary["tree"] = inventory(root)
        (root / "manifest.json").write_text(json.dumps(summary, sort_keys=True) + "\n", encoding="utf-8")
        print("T0032_S02_EVIDENCE_DIR=" + str(root), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as failure:
        print("T0032_S02_CAPTURE_ERROR=" + str(failure), file=sys.stderr)
        raise SystemExit(2)

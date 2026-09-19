#!/usr/bin/env python3
"""Capture a frozen finite-decimal CSV corpus from the pinned Embulk JAR.

The fixtures are repository-original inputs.  This driver records raw process
results; it deliberately contains no reference-output expectations.
"""
import hashlib
import json
import os
from pathlib import Path
import random
import signal
import stat
import subprocess
import tempfile
import uuid

REFERENCE_SHA256 = "e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47"
REFERENCE_BYTES = 11109700
TIMEOUT_SECONDS = 90
MAX_INPUT_BYTES = 16384
MAX_CONFIG_BYTES = 8192
MAX_LOG_BYTES = 1024 * 1024
MAX_OUTPUT_FILE_BYTES = 1024 * 1024
MAX_OUTPUT_RECORDS = 256
MAX_CASE_TREE_BYTES = 3 * 1024 * 1024
MAX_SUMMARY_TREE_BYTES = 16 * 1024 * 1024
HOLDOUT_SEED = 3205
HOLDOUT_COUNT = 64
CASES = ("family-corpus", "grammar-boundaries", "prior-null-sentinel", "seeded-holdout")
DRIVER_LABEL = "tools/t0032-finite-decimal-oracle/run.py"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def within(path, root):
    resolved, boundary = path.resolve(), root.resolve()
    require(resolved != boundary and boundary in resolved.parents, "evidence path escapes capture root")
    return resolved


def bounded_regular_bytes(path, root, limit):
    within(path, root)
    metadata = path.lstat()
    require(stat.S_ISREG(metadata.st_mode) and not path.is_symlink(), "evidence item is not a regular file")
    require(metadata.st_size <= limit, "evidence item exceeds byte cap")
    data = path.read_bytes()
    require(len(data) == metadata.st_size, "evidence item changed during read")
    return data


def regular(path, root, limit):
    data = bounded_regular_bytes(path, root, limit)
    return {"name": str(path.relative_to(root)), "size": len(data), "sha256": digest(data)}


def canonical_text(path, root, limit):
    detail = regular(path, root, limit)
    data = bounded_regular_bytes(path, root, limit)
    try:
        data.decode("utf-8")
    except UnicodeDecodeError as failure:
        raise ValueError("evidence item is not UTF-8") from failure
    require(b"\r" not in data and (not data or data.endswith(b"\n")), "evidence text is not canonical LF")
    return detail


def tree(root, cap):
    entries, total = [], 0
    for path in sorted(root.rglob("*")):
        within(path, root)
        metadata = path.lstat()
        name = str(path.relative_to(root))
        if stat.S_ISLNK(metadata.st_mode):
            raise ValueError("evidence tree contains symlink")
        if stat.S_ISDIR(metadata.st_mode):
            entries.append({"name": name, "type": "directory"})
        elif stat.S_ISREG(metadata.st_mode):
            require(metadata.st_size <= cap - total, "evidence tree exceeds byte cap")
            item = regular(path, root, cap - total)
            total += item["size"]
            entries.append({"type": "regular", **item})
        else:
            raise ValueError("evidence tree contains special file")
    return entries


def checked_output(root):
    files = []
    for path in sorted(root.rglob("*")):
        within(path, root.parent)
        metadata = path.lstat()
        require(stat.S_ISREG(metadata.st_mode) and not path.is_symlink(), "output tree contains non-regular item")
        detail = canonical_text(path, root.parent, MAX_OUTPUT_FILE_BYTES)
        require(len(bounded_regular_bytes(path, root.parent, MAX_OUTPUT_FILE_BYTES).splitlines()) <= MAX_OUTPUT_RECORDS + 1,
                "output exceeds record cap")
        files.append(detail)
    return files


def reference(environment):
    raw = environment.get("EMBURK_REFERENCE_JAR")
    require(raw is not None, "EMBURK_REFERENCE_JAR is required")
    path = Path(raw)
    require(path.is_file() and not path.is_symlink(), "reference JAR must be regular")
    require(path.stat().st_size == REFERENCE_BYTES, "reference JAR size mismatch")
    data = bounded_regular_bytes(path, path.parent, REFERENCE_BYTES)
    require(digest(data) == REFERENCE_SHA256, "reference JAR checksum mismatch")
    return data


def java17(environment):
    raw = environment.get("JAVA_HOME")
    require(raw is not None, "JAVA_HOME is required")
    home = Path(raw).resolve(); java = home / "bin" / "java"
    require(java.is_file() and not java.is_symlink() and os.access(java, os.X_OK), "JAVA_HOME does not provide java")
    probe = subprocess.run([str(java), "-version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           env={"PATH": os.defpath, "JAVA_HOME": str(home)}, timeout=10)
    version = probe.stdout + probe.stderr
    require(probe.returncode == 0 and b'version "17.' in version, "Java 17 is required")
    require(len(version) <= MAX_LOG_BYTES and b"\r" not in version and version.endswith(b"\n"), "Java version output is not canonical LF")
    version.decode("utf-8")
    return java, version, {"java_home": str(home), "java_version_sha256": digest(version)}


def holdout_values():
    """Frozen deterministic, in-domain only values; never reference output."""
    randomizer = random.Random(HOLDOUT_SEED)
    values = []
    while len(values) < HOLDOUT_COUNT:
        sign = "-" if randomizer.randrange(2) else ""
        integral = str(randomizer.randrange(0, 1_000_000))
        fractional = "" if randomizer.randrange(3) == 0 else "." + str(randomizer.randrange(0, 100)).zfill(2 if randomizer.randrange(2) else 1)
        values.append(sign + integral + fractional)
    return tuple(values)


def fixture(case):
    values = {
        "family-corpus": ("0", "-0", "3.5", "3.50", "-12.25", "42.0", "999999.99", "-999999.99", '"3.5"'),
        "grammar-boundaries": ("+3.5", "03.5", ".5", "1.", "1e2", "NaN", "Infinity", "3.141", "1000000", "-1000000.01"),
        "prior-null-sentinel": ("1.5", "", '""', "not-a-double", "2.5"),
        "seeded-holdout": holdout_values(),
    }
    try:
        return ("ratio\n" + "\n".join(values[case]) + "\n").encode("ascii")
    except KeyError as failure:
        raise ValueError("unknown selected case") from failure


def config(case):
    require(case in CASES, "unknown selected case")
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
    - {name: ratio, type: double}
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


def terminate_group(process):
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def capture_process(command, root, environment):
    stdout, stderr = root / "stdout.log", root / "stderr.log"
    with stdout.open("xb") as out, stderr.open("xb") as err:
        process = subprocess.Popen(command, cwd=root, env=environment, stdout=out, stderr=err, start_new_session=True)
        timed_out = False
        try:
            exit_code = process.wait(timeout=TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            timed_out = True; terminate_group(process); exit_code = process.wait()
        finally:
            terminate_group(process)
    (root / "exit.txt").write_text(f"{exit_code}\n", encoding="ascii")
    return {"command": [str(part) for part in command], "exit": exit_code, "timed_out": timed_out,
            "stdout": canonical_text(stdout, root, MAX_LOG_BYTES), "stderr": canonical_text(stderr, root, MAX_LOG_BYTES),
            "exit_file": canonical_text(root / "exit.txt", root, 64)}


def validate_case(path):
    value = json.loads(bounded_regular_bytes(path, path.parent, MAX_CASE_TREE_BYTES).decode("utf-8"))
    required = {"case", "run_uuid", "reference", "environment", "java_version", "driver", "generator", "config", "input", "process", "outputs", "case_tree"}
    require(isinstance(value, dict) and set(value) == required, "case manifest structure")
    require(value["case"] in CASES and str(uuid.UUID(value["run_uuid"])) == value["run_uuid"], "case identity")
    require(value["reference"] == {"sha256": REFERENCE_SHA256}, "reference identity")
    root = path.parent
    identity = {"path": DRIVER_LABEL, "sha256": digest(Path(__file__).read_bytes())}
    require(value["driver"] == identity and value["generator"] == identity, "driver or generator identity")
    require(value["java_version"] == canonical_text(root / "java-version.txt", root, MAX_LOG_BYTES), "Java evidence changed")
    require(value["environment"]["java_version_sha256"] == value["java_version"]["sha256"], "Java linkage")
    require(value["config"] == canonical_text(root / "config.yml", root, MAX_CONFIG_BYTES), "config changed")
    require(value["input"] == canonical_text(root / "input.csv", root, MAX_INPUT_BYTES), "input changed")
    process = value["process"]
    require(isinstance(process, dict) and set(process) == {"command", "exit", "timed_out", "stdout", "stderr", "exit_file"}, "process structure")
    require(isinstance(process["command"], list) and isinstance(process["exit"], int) and isinstance(process["timed_out"], bool), "process result")
    for key, relative in (("stdout", "stdout.log"), ("stderr", "stderr.log"), ("exit_file", "exit.txt")):
        require(process[key] == canonical_text(root / relative, root, MAX_LOG_BYTES), "process evidence changed")
    require(bounded_regular_bytes(root / "exit.txt", root, 64).decode("ascii") == str(process["exit"]) + "\n", "exit record changed")
    require(value["outputs"] == checked_output(root / "output"), "output inventory changed")
    require(value["case_tree"] == [item for item in tree(root, MAX_CASE_TREE_BYTES) if item["name"] != "manifest.json"], "case tree changed")
    return value


def validate_summary(path):
    value = json.loads(bounded_regular_bytes(path, path.parent, MAX_SUMMARY_TREE_BYTES).decode("utf-8"))
    required = {"run_uuid", "reference", "reference_snapshot", "driver", "generator", "cases", "result", "tree"}
    require(isinstance(value, dict) and set(value) == required, "summary manifest structure")
    require(str(uuid.UUID(value["run_uuid"])) == value["run_uuid"] and value["reference"] == {"sha256": REFERENCE_SHA256}, "summary identity")
    root = path.parent; identity = {"path": DRIVER_LABEL, "sha256": digest(Path(__file__).read_bytes())}
    require(value["driver"] == identity and value["generator"] == identity, "summary generator identity")
    require(value["reference_snapshot"] == regular(root / "embulk.jar", root, REFERENCE_BYTES), "reference snapshot")
    require(value["result"] == "captured", "summary result")
    require([item.get("case") if isinstance(item, dict) else None for item in value["cases"]] == list(CASES), "summary case order")
    for item, case in zip(value["cases"], CASES):
        require(set(item) == {"case", "path", "manifest_sha256"} and item["path"] == f"cases/{case}", "summary case shape")
        manifest = root / item["path"] / "manifest.json"
        require(item["manifest_sha256"] == digest(bounded_regular_bytes(manifest, root, MAX_CASE_TREE_BYTES)), "summary case hash")
        require(validate_case(manifest)["run_uuid"] == value["run_uuid"], "summary linkage")
    require(value["tree"] == [item for item in tree(root, MAX_SUMMARY_TREE_BYTES) if item["name"] != "manifest.json"], "summary tree changed")
    return value


def run_case(case, capture_root, jar, java, version, identity, run_uuid):
    root = capture_root / "cases" / case; root.mkdir(parents=True, mode=0o700)
    output, home, temporary = root / "output", root / "home", root / "tmp"
    for directory in (output, home, temporary): directory.mkdir(mode=0o700)
    (root / "input.csv").write_bytes(fixture(case)); (root / "config.yml").write_bytes(config(case)); (root / "java-version.txt").write_bytes(version)
    environment = {"PATH": os.defpath, "JAVA_HOME": identity["java_home"], "HOME": str(home), "TMPDIR": str(temporary), "EMBULK_HOME": str(home)}
    command = [str(java), f"-Duser.home={home}", f"-Djava.io.tmpdir={temporary}", "-jar", str(jar), f"-Xembulk_home={home}", "run", "config.yml"]
    manifest = {"case": case, "run_uuid": run_uuid, "reference": {"sha256": REFERENCE_SHA256}, "environment": identity,
                "java_version": canonical_text(root / "java-version.txt", root, MAX_LOG_BYTES), "driver": {"path": DRIVER_LABEL, "sha256": digest(Path(__file__).read_bytes())},
                "generator": {"path": DRIVER_LABEL, "sha256": digest(Path(__file__).read_bytes())}, "config": canonical_text(root / "config.yml", root, MAX_CONFIG_BYTES),
                "input": canonical_text(root / "input.csv", root, MAX_INPUT_BYTES), "process": capture_process(command, root, environment), "outputs": checked_output(output)}
    manifest["case_tree"] = tree(root, MAX_CASE_TREE_BYTES); path = root / "manifest.json"
    path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8"); validate_case(path); return path


def main():
    jar_data = reference(os.environ); java, version, identity = java17(os.environ)
    root = Path(tempfile.mkdtemp(prefix="emburk-t0032-s05-finite-decimal-capture-", dir="/private/tmp")); root.chmod(0o700)
    jar = root / "embulk.jar"; jar.write_bytes(jar_data); jar.chmod(0o400); run_uuid = str(uuid.uuid4())
    marker = {"path": DRIVER_LABEL, "sha256": digest(Path(__file__).read_bytes())}
    summary = {"run_uuid": run_uuid, "reference": {"sha256": REFERENCE_SHA256}, "reference_snapshot": regular(jar, root, REFERENCE_BYTES), "driver": marker, "generator": marker, "cases": [], "result": "captured"}
    try:
        for case in CASES:
            manifest = run_case(case, root, jar, java, version, identity, run_uuid)
            summary["cases"].append({"case": case, "path": str(manifest.parent.relative_to(root)), "manifest_sha256": digest(bounded_regular_bytes(manifest, root, MAX_CASE_TREE_BYTES))})
            print("T0032_S05_CAPTURED=" + case, flush=True)
        require(digest(bounded_regular_bytes(jar, root, REFERENCE_BYTES)) == REFERENCE_SHA256, "reference snapshot changed")
    finally:
        summary["tree"] = tree(root, MAX_SUMMARY_TREE_BYTES); path = root / "manifest.json"
        path.write_text(json.dumps(summary, sort_keys=True) + "\n", encoding="utf-8"); validate_summary(path)
        print("T0032_S05_EVIDENCE_DIR=" + str(root), flush=True)


if __name__ == "__main__":
    try: main()
    except (OSError, ValueError, subprocess.SubprocessError) as failure:
        print("T0032_S05_CAPTURE_ERROR=" + str(failure), file=os.sys.stderr); raise SystemExit(2)

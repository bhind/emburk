#!/usr/bin/env python3
"""Capture selected bundled File/CSV reference outcomes without inferring policy."""

import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import uuid

EXPECTED_JAR_SHA256 = "e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47"
JAVA_MAJOR = "17"
TIMEOUT_SECONDS = 60
CASE_NAMES = (
    "normal", "quoted-comma-multiline-unicode", "empty", "blank-null",
    "malformed-long", "missing-input", "duplicate-config-key", "existing-prefix-sentinel",
)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def confined(path: Path, root: Path) -> Path:
    resolved, boundary = path.resolve(), root.resolve()
    if resolved == boundary or boundary not in resolved.parents:
        raise ValueError("path escapes case directory")
    return resolved


def reference_jar(environment: dict[str, str]) -> Path:
    value = environment.get("EMBURK_REFERENCE_JAR")
    if not value:
        raise ValueError("EMBURK_REFERENCE_JAR is required")
    path = Path(value)
    if not path.is_file() or path.is_symlink():
        raise ValueError("reference artifact is not a regular file")
    if sha256(path.read_bytes()) != EXPECTED_JAR_SHA256:
        raise ValueError("reference artifact checksum mismatch")
    return path.resolve()


def reference_bytes(environment: dict[str, str]) -> bytes:
    value = environment.get("EMBURK_REFERENCE_JAR")
    if not value:
        raise ValueError("EMBURK_REFERENCE_JAR is required")
    path = Path(value)
    if not path.is_file() or path.is_symlink():
        raise ValueError("reference artifact is not a regular file")
    data = path.read_bytes()
    if sha256(data) != EXPECTED_JAR_SHA256:
        raise ValueError("reference artifact checksum mismatch")
    return data


def snapshot_reference(data: bytes, root: Path) -> Path:
    path = root / "embulk.jar"
    with path.open("xb") as stream:
        stream.write(data)
    path.chmod(0o400)
    if sha256(path.read_bytes()) != EXPECTED_JAR_SHA256:
        raise ValueError("reference snapshot checksum mismatch")
    return path


def java_command(environment: dict[str, str]) -> tuple[Path, bytes]:
    home = environment.get("JAVA_HOME")
    if not home:
        raise ValueError("JAVA_HOME is required")
    executable = Path(home) / "bin" / "java"
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise ValueError("JAVA_HOME does not provide java")
    version = subprocess.run([str(executable), "-version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             env={"PATH": os.defpath, "JAVA_HOME": str(Path(home).resolve())}, timeout=10, check=False)
    raw = version.stdout + version.stderr
    if version.returncode != 0 or f'version "{JAVA_MAJOR}.'.encode() not in raw:
        raise ValueError("Java 17 is required")
    return executable.resolve(), raw


def jvm_environment(case_root: Path, java_home: str) -> dict[str, str]:
    home, temporary = case_root / "home", case_root / "tmp"
    home.mkdir()
    temporary.mkdir()
    return {"PATH": os.defpath, "JAVA_HOME": java_home, "EMBULK_HOME": str(home), "HOME": str(home), "TMPDIR": str(temporary)}


def config_bytes(duplicate: bool = False) -> bytes:
    skip = b"    skip_header_lines: " + (b"2\n    skip_header_lines: 1\n" if duplicate else b"1\n")
    return (
        b"in:\n  type: file\n  path_prefix: input.csv\n  parser:\n"
        b"    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n"
        + skip
        + b"    columns:\n    - {name: id, type: long}\n    - {name: name, type: string}\n"
        + b"out:\n  type: file\n  path_prefix: output/result"
        + b"\n  file_ext: csv\n  formatter:\n    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    header_line: true\n    quote_policy: MINIMAL\nexec:\n  max_threads: 1\n  min_output_tasks: 1\n"
    )


def fixture(name: str) -> bytes:
    fixtures = {
        "normal": b"id,name\n1,Alice\n-2,Bob\n",
        "quoted-comma-multiline-unicode": "id,name\n1,\"comma, \"\"quote\"\"\"\n2,\"first\nsecond \u2603\"\n".encode(),
        "empty": b"",
        "blank-null": b"id,name\n1,\n2,\"\"\n,empty-long\n3,   \n",
        "malformed-long": b"id,name\nnot-a-long,value\n",
        "missing-input": None,
        "duplicate-config-key": b"id,name\n4,duplicate\n",
        "existing-prefix-sentinel": b"id,name\n5,sentinel\n",
    }
    return fixtures[name]


def output_inventory(output_dir: Path) -> list[dict[str, object]]:
    confined(output_dir, output_dir.parent)
    result = []
    for path in sorted(output_dir.rglob("*")):
        if path.is_file() and not path.is_symlink():
            confined(path, output_dir)
            data = path.read_bytes()
            result.append({"name": str(path.relative_to(output_dir)), "size": len(data), "sha256": sha256(data)})
    return result


def file_detail(path: Path, root: Path) -> dict[str, object]:
    confined(path, root)
    data = path.read_bytes()
    return {"name": str(path.relative_to(root)), "size": len(data), "sha256": sha256(data)}


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")


def validate_case_manifest(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {"case", "run_uuid", "reference", "java_version", "input", "config", "process", "outputs", "preexisting_outputs"}
    if not isinstance(value, dict) or set(value) != required or value["case"] not in CASE_NAMES:
        raise ValueError("manifest structure")
    if str(uuid.UUID(value["run_uuid"])) != value["run_uuid"]:
        raise ValueError("manifest UUID")
    if value["reference"] != {"sha256": EXPECTED_JAR_SHA256}:
        raise ValueError("manifest artifact")
    root = path.parent.resolve()
    for key in ("config",):
        item = value[key]
        if not isinstance(item, dict) or set(item) != {"name", "size", "sha256"}:
            raise ValueError("manifest input")
        candidate = confined(root / item["name"], root)
        if not candidate.is_file() or item != file_detail(candidate, root): raise ValueError("manifest input")
    item = value["input"]
    if not isinstance(item, dict) or set(item) != {"name", "exists", "size", "sha256"} or not isinstance(item["exists"], bool):
        raise ValueError("manifest input")
    candidate = confined(root / item["name"], root)
    if item["exists"]:
        if not candidate.is_file() or {"name": item["name"], "exists": True, "size": len(candidate.read_bytes()), "sha256": sha256(candidate.read_bytes())} != item: raise ValueError("manifest input")
    elif candidate.exists() or item != {"name": item["name"], "exists": False, "size": 0, "sha256": sha256(b"")}:
        raise ValueError("manifest input")
    java = value["java_version"]
    if not isinstance(java, dict) or set(java) != {"name", "size", "sha256"}: raise ValueError("manifest java")
    java_file = confined(root / java["name"], root)
    if not java_file.is_file() or java != file_detail(java_file, root): raise ValueError("manifest java")
    process = value["process"]
    if not isinstance(process, dict) or set(process) != {"exit", "timed_out", "stdout", "stderr"} or not isinstance(process["exit"], int) or not isinstance(process["timed_out"], bool):
        raise ValueError("manifest process")
    for key in ("stdout", "stderr"):
        item = process[key]
        if not isinstance(item, dict) or set(item) != {"name", "size", "sha256"}: raise ValueError("manifest process")
        candidate = confined(root / item["name"], root)
        if not candidate.is_file() or item != file_detail(candidate, root): raise ValueError("manifest process")
    exit_file = confined(root / "exit.txt", root)
    if not exit_file.is_file() or exit_file.read_text(encoding="ascii") != str(process["exit"]) + "\n":
        raise ValueError("manifest process")
    if not isinstance(value["outputs"], list) or not isinstance(value["preexisting_outputs"], list):
        raise ValueError("manifest outputs")
    names = set()
    for item in value["outputs"]:
        if not isinstance(item, dict) or set(item) != {"name", "size", "sha256"} or item["name"] in names: raise ValueError("manifest outputs")
        names.add(item["name"])
        candidate = confined(root / "output" / item["name"], root / "output")
        if not candidate.is_file() or item != {"name": item["name"], "size": len(candidate.read_bytes()), "sha256": sha256(candidate.read_bytes())}: raise ValueError("manifest outputs")
    previous = set()
    for item in value["preexisting_outputs"]:
        if not isinstance(item, dict) or set(item) != {"name", "size", "sha256"} or item["name"] in previous: raise ValueError("manifest outputs")
        previous.add(item["name"])
    if value["outputs"] != output_inventory(root / "output"):
        raise ValueError("manifest outputs")
    return value


def run_case(name: str, jar: Path, java: Path, java_version: bytes, run_uuid: str) -> Path:
    case_root = Path(tempfile.mkdtemp(prefix=f"emburk-t0014-{name}-", dir="/private/tmp"))
    input_path, config_path = case_root / "input.csv", case_root / "config.yml"
    output_dir = case_root / "output"
    output_dir.mkdir()
    output_prefix = output_dir / "result"
    input_data = fixture(name)
    if input_data is not None:
        input_path.write_bytes(input_data)
    if name == "existing-prefix-sentinel":
        output_prefix.write_bytes(b"original sentinel\n")
    config_path.write_bytes(config_bytes(name == "duplicate-config-key"))
    (case_root / "java-version.txt").write_bytes(java_version)
    preexisting = output_inventory(output_dir)
    java_detail = file_detail(case_root / "java-version.txt", case_root)
    input_detail = {"name": input_path.name, "exists": input_data is not None, "size": len(input_data or b""), "sha256": sha256(input_data or b"")}
    config_detail = file_detail(config_path, case_root)
    environment = jvm_environment(case_root, str(java.parent.parent))
    command = [str(java), f"-Duser.home={environment['HOME']}", "-jar", str(jar), f"-Xembulk_home={environment['EMBULK_HOME']}", "run", str(config_path)]
    stdout_path, stderr_path = case_root / "stdout.log", case_root / "stderr.log"
    with stdout_path.open("xb") as stdout, stderr_path.open("xb") as stderr:
        process = subprocess.Popen(command, stdout=stdout, stderr=stderr, env=environment, start_new_session=True, cwd=case_root)
        timed_out = False
        try:
            exit_code = process.wait(timeout=TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid, signal.SIGKILL)
            exit_code = process.wait()
    (case_root / "exit.txt").write_text(f"{exit_code}\n", encoding="ascii")
    if file_detail(config_path, case_root) != config_detail:
        raise ValueError("reference process changed captured config")
    if input_data is not None and file_detail(input_path, case_root) != {"name": input_path.name, "size": input_detail["size"], "sha256": input_detail["sha256"]}:
        raise ValueError("reference process changed captured input")
    manifest = {
        "case": name,
        "run_uuid": run_uuid,
        "reference": {"sha256": EXPECTED_JAR_SHA256},
        "java_version": java_detail,
        "input": input_detail,
        "config": config_detail,
        "process": {"exit": exit_code, "timed_out": timed_out, "stdout": file_detail(stdout_path, case_root), "stderr": file_detail(stderr_path, case_root)},
        "outputs": output_inventory(output_dir),
        "preexisting_outputs": preexisting,
    }
    write_json(case_root / "manifest.json", manifest)
    validate_case_manifest(case_root / "manifest.json")
    print(f"T0014_S01_CASE={name}|exit={exit_code}|timed_out={str(timed_out).lower()}|evidence={case_root}", flush=True)
    return case_root


def write_summary(run_root: Path, run_uuid: str, jar: Path, cases: list[dict[str, object]]) -> Path:
    summary = run_root / "manifest.json"
    write_json(summary, {"run_uuid": run_uuid, "reference_sha256": sha256(jar.read_bytes()), "cases": cases})
    return summary


def main() -> int:
    run_root = Path(tempfile.mkdtemp(prefix="emburk-t0014-run-", dir="/private/tmp"))
    jar = snapshot_reference(reference_bytes(dict(os.environ)), run_root)
    java, version = java_command(dict(os.environ))
    run_uuid = str(uuid.uuid4())
    cases = []
    for name in CASE_NAMES:
        case_root = run_case(name, jar, java, version, run_uuid)
        cases.append({"case": name, "path": str(case_root), "manifest_sha256": sha256((case_root / "manifest.json").read_bytes())})
    write_summary(run_root, run_uuid, jar, cases)
    print(f"T0014_S01_EVIDENCE_DIR={run_root}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as failure:
        print(f"T0014_S01_CAPTURE_ERROR={failure}", file=sys.stderr)
        raise SystemExit(2)

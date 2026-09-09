#!/usr/bin/env python3
"""Capture three bounded multi-file File-input observations without inferring policy."""

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
CASES = ("two-regular", "two-regular-swapped", "regular-and-directory")
OBSERVATIONS = {
    "two-regular": (("result000.00.csv", b"id,name\n10,alpha\n"), ("result001.00.csv", b"id,name\n20,beta\n")),
    "two-regular-swapped": (("result000.00.csv", b"id,name\n20,beta\n"), ("result001.00.csv", b"id,name\n10,alpha\n")),
    "regular-and-directory": (("result000.00.csv", b"id,name\n10,alpha\n"),),
}
STDOUT_PROJECTIONS = {
    "two-regular": (
        "Loading files [input.10.csv, input.20.csv]",
        "Using local thread executor with max_threads=1 / tasks=2",
        'Next config diff: {"in":{"last_path":"input.20.csv"},"out":{}',
    ),
    "two-regular-swapped": (
        "Loading files [input.10.csv, input.20.csv]",
        "Using local thread executor with max_threads=1 / tasks=2",
        'Next config diff: {"in":{"last_path":"input.20.csv"},"out":{}',
    ),
    "regular-and-directory": (
        "Loading files [input.10.csv]",
        "Using local thread executor with max_threads=1 / tasks=1",
        'Next config diff: {"in":{"last_path":"input.10.csv"},"out":{}',
    ),
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def confined(path: Path, root: Path) -> Path:
    resolved, boundary = path.resolve(), root.resolve()
    if resolved == boundary or boundary not in resolved.parents:
        raise ValueError("path escapes evidence tree")
    return resolved


def detail(path: Path, root: Path) -> dict[str, object]:
    confined(path, root)
    if not path.is_file() or path.is_symlink():
        raise ValueError("raw artifact is not a regular file")
    data = path.read_bytes()
    return {"name": str(path.relative_to(root)), "size": len(data), "sha256": sha256(data)}


def inventory(root: Path) -> list[dict[str, object]]:
    """Return a deterministic, symlink-free inventory including empty directories."""
    confined(root, root.parent)
    result = []
    for path in sorted(root.rglob("*")):
        confined(path, root)
        if path.is_symlink():
            raise ValueError("symlink in captured tree")
        name = str(path.relative_to(root))
        if path.is_dir():
            result.append({"name": name, "type": "directory"})
        elif path.is_file():
            result.append({"type": "regular", **detail(path, root)})
        else:
            raise ValueError("non-regular entry in captured tree")
    return result


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
    completed = subprocess.run(
        [str(executable), "-version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        env={"PATH": os.defpath, "JAVA_HOME": str(Path(home).resolve())}, timeout=10, check=False,
    )
    version = completed.stdout + completed.stderr
    if completed.returncode != 0 or f'version "{JAVA_MAJOR}.'.encode() not in version:
        raise ValueError("Java 17 is required")
    return executable.resolve(), version


def jvm_environment(case_root: Path, java_home: str) -> dict[str, str]:
    home, temporary = case_root / "home", case_root / "tmp"
    home.mkdir()
    temporary.mkdir()
    return {
        "PATH": os.defpath, "JAVA_HOME": java_home, "EMBULK_HOME": str(home),
        "HOME": str(home), "TMPDIR": str(temporary),
    }


def fixture(case: str) -> dict[str, bytes | None]:
    header = b"id,name\n"
    regular = {"input.10.csv": header + b"10,alpha\n", "input.20.csv": header + b"20,beta\n"}
    if case == "two-regular":
        return regular
    if case == "two-regular-swapped":
        return {"input.10.csv": regular["input.20.csv"], "input.20.csv": regular["input.10.csv"]}
    if case == "regular-and-directory":
        return {"input.10.csv": regular["input.10.csv"], "input.15.csv": None}
    raise ValueError("unknown case")


def config_bytes() -> bytes:
    return (
        b"in:\n  type: file\n  path_prefix: input.\n  parser:\n    type: csv\n"
        b"    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n"
        b"    skip_header_lines: 1\n    columns:\n    - {name: id, type: long}\n    - {name: name, type: string}\n"
        b"out:\n  type: file\n  path_prefix: output/result\n  file_ext: csv\n  formatter:\n    type: csv\n"
        b"    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n"
        b"    header_line: true\n    quote_policy: MINIMAL\nexec:\n  max_threads: 1\n  min_output_tasks: 1\n"
    )


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")


def wait_and_terminate_process_group(process: subprocess.Popen) -> tuple[int, bool]:
    """Wait for the leader and stop every descendant in its isolated process group."""
    timed_out = False
    try:
        exit_code = process.wait(timeout=TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        timed_out = True
        exit_code = None
    finally:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    if exit_code is None:
        exit_code = process.wait()
    return exit_code, timed_out


def validate_case_manifest(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {"case", "run_uuid", "reference", "java_version", "inputs", "config", "process", "outputs", "case_tree"}
    if not isinstance(value, dict) or set(value) != required or value["case"] not in CASES:
        raise ValueError("manifest structure")
    if str(uuid.UUID(value["run_uuid"])) != value["run_uuid"]:
        raise ValueError("manifest UUID")
    if value["reference"] != {"sha256": EXPECTED_JAR_SHA256}:
        raise ValueError("manifest artifact")
    root = path.parent.resolve()
    for field in ("java_version", "config"):
        item = value[field]
        if not isinstance(item, dict) or set(item) != {"name", "size", "sha256"}:
            raise ValueError("manifest raw file")
        candidate = confined(root / item["name"], root)
        if item != detail(candidate, root):
            raise ValueError("manifest raw file")
    process = value["process"]
    if not isinstance(process, dict) or set(process) != {"exit", "timed_out", "stdout", "stderr"} or not isinstance(process["exit"], int) or not isinstance(process["timed_out"], bool):
        raise ValueError("manifest process")
    for field in ("stdout", "stderr"):
        item = process[field]
        if not isinstance(item, dict) or set(item) != {"name", "size", "sha256"}:
            raise ValueError("manifest process")
        if item != detail(confined(root / item["name"], root), root):
            raise ValueError("manifest process")
    exit_file = confined(root / "exit.txt", root)
    if not exit_file.is_file() or exit_file.read_text(encoding="ascii") != f"{process['exit']}\n":
        raise ValueError("manifest process")
    for field, directory in (("inputs", root), ("outputs", root / "output")):
        items = value[field]
        actual = inventory(directory)
        if field == "inputs":
            actual = [item for item in actual if item["name"].startswith("input.")]
        if not isinstance(items, list) or items != actual:
            raise ValueError("manifest inventory")
        names = [item.get("name") for item in items if isinstance(item, dict)]
        if len(names) != len(set(names)):
            raise ValueError("manifest duplicate inventory")
    actual_tree = [item for item in inventory(root) if item["name"] != "manifest.json"]
    if not isinstance(value["case_tree"], list) or value["case_tree"] != actual_tree:
        raise ValueError("manifest case tree")
    return value


def validate_observation(value: dict[str, object], path: Path) -> None:
    """Check selected, post-capture projections without comparing variable stdout."""
    root = path.parent.resolve()
    process = value["process"]
    if process["exit"] != 0 or process["timed_out"] is not False:
        raise ValueError("observation process")
    stderr = confined(root / process["stderr"]["name"], root)
    if stderr.read_bytes() != b"":
        raise ValueError("observation stderr")
    stdout = confined(root / process["stdout"]["name"], root).read_text(encoding="utf-8")
    if any(fragment not in stdout for fragment in STDOUT_PROJECTIONS[value["case"]]):
        raise ValueError("observation stdout")
    expected = []
    for name, contents in OBSERVATIONS[value["case"]]:
        candidate = confined(root / "output" / name, root / "output")
        if not candidate.is_file() or candidate.is_symlink() or candidate.read_bytes() != contents:
            raise ValueError("observation output")
        expected.append({"type": "regular", "name": name, "size": len(contents), "sha256": sha256(contents)})
    if value["outputs"] != expected:
        raise ValueError("observation output")


def validate_summary(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict) or set(value) != {"run_uuid", "reference_sha256", "cases"}:
        raise ValueError("summary structure")
    if str(uuid.UUID(value["run_uuid"])) != value["run_uuid"] or value["reference_sha256"] != EXPECTED_JAR_SHA256:
        raise ValueError("summary identity")
    entries = value["cases"]
    if not isinstance(entries, list) or [entry.get("case") for entry in entries if isinstance(entry, dict)] != list(CASES):
        raise ValueError("summary cases")
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) != {"case", "path", "manifest_sha256"}:
            raise ValueError("summary case")
        manifest = confined(path.parent / entry["path"] / "manifest.json", path.parent)
        if sha256(manifest.read_bytes()) != entry["manifest_sha256"]:
            raise ValueError("summary manifest")
        observed = validate_case_manifest(manifest)
        if observed["case"] != entry["case"] or observed["run_uuid"] != value["run_uuid"]:
            raise ValueError("summary case")
        validate_observation(observed, manifest)
    return value


def run_case(case: str, jar: Path, java: Path, java_version: bytes, run_uuid: str, run_root: Path) -> Path:
    case_root = run_root / "cases" / case
    case_root.mkdir(parents=True)
    for name, contents in fixture(case).items():
        target = confined(case_root / name, case_root)
        if contents is None:
            target.mkdir()
        else:
            target.write_bytes(contents)
    output_dir = case_root / "output"
    output_dir.mkdir()
    config_path = case_root / "config.yml"
    config_path.write_bytes(config_bytes())
    (case_root / "java-version.txt").write_bytes(java_version)
    input_snapshot, config_snapshot = inventory(case_root), detail(config_path, case_root)
    environment = jvm_environment(case_root, str(java.parent.parent))
    command = [
        str(java), f"-Duser.home={environment['HOME']}",
        f"-Djava.io.tmpdir={environment['TMPDIR']}", "-jar", str(jar),
        f"-Xembulk_home={environment['EMBULK_HOME']}", "run", str(config_path),
    ]
    stdout_path, stderr_path = case_root / "stdout.log", case_root / "stderr.log"
    with stdout_path.open("xb") as stdout, stderr_path.open("xb") as stderr:
        process = subprocess.Popen(command, stdout=stdout, stderr=stderr, env=environment, cwd=case_root, start_new_session=True)
        exit_code, timed_out = wait_and_terminate_process_group(process)
    (case_root / "exit.txt").write_text(f"{exit_code}\n", encoding="ascii")
    if detail(config_path, case_root) != config_snapshot:
        raise ValueError("reference process changed captured config")
    # The fixture inventory is captured before execution; only its selected entries are compared.
    current_inputs = [item for item in inventory(case_root) if item["name"].startswith("input.")]
    if current_inputs != [item for item in input_snapshot if item["name"].startswith("input.")]:
        raise ValueError("reference process changed captured inputs")
    manifest = {
        "case": case, "run_uuid": run_uuid, "reference": {"sha256": EXPECTED_JAR_SHA256},
        "java_version": detail(case_root / "java-version.txt", case_root), "inputs": current_inputs,
        "config": config_snapshot,
        "process": {"exit": exit_code, "timed_out": timed_out, "stdout": detail(stdout_path, case_root), "stderr": detail(stderr_path, case_root)},
        "outputs": inventory(output_dir),
    }
    manifest["case_tree"] = inventory(case_root)
    manifest_path = case_root / "manifest.json"
    write_json(manifest_path, manifest)
    validate_case_manifest(manifest_path)
    print(f"T0014_S03_CASE={case}|exit={exit_code}|timed_out={str(timed_out).lower()}|evidence={case_root}", flush=True)
    return case_root


def main() -> int:
    run_root = Path(tempfile.mkdtemp(prefix="emburk-t0014-s03-", dir="/private/tmp"))
    run_root.chmod(0o700)
    jar = snapshot_reference(reference_bytes(dict(os.environ)), run_root)
    java, version = java_command(dict(os.environ))
    run_uuid = str(uuid.uuid4())
    entries = []
    for case in CASES:
        root = run_case(case, jar, java, version, run_uuid, run_root)
        manifest = root / "manifest.json"
        entries.append({"case": case, "path": str(root.relative_to(run_root)), "manifest_sha256": sha256(manifest.read_bytes())})
    if sha256(jar.read_bytes()) != EXPECTED_JAR_SHA256:
        raise ValueError("reference snapshot changed during execution")
    summary = run_root / "manifest.json"
    write_json(summary, {"run_uuid": run_uuid, "reference_sha256": EXPECTED_JAR_SHA256, "cases": entries})
    validate_summary(summary)
    print(f"T0014_S03_EVIDENCE_DIR={run_root}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as failure:
        print(f"T0014_S03_CAPTURE_ERROR={failure}", file=sys.stderr)
        raise SystemExit(2)

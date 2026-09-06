#!/bin/sh
set -eu
: "${EMBURK_REFERENCE_JAR:?EMBURK_REFERENCE_JAR is required}"
: "${JAVA_HOME:?JAVA_HOME is required}"
cargo build --locked --workspace
python3 -I -B - <<'PY'
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

def require(condition, message):
    if not condition:
        raise AssertionError(message)

repository = Path.cwd().resolve()
spec = importlib.util.spec_from_file_location("oracle", repository / "tools/file-csv-oracle/run.py")
oracle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oracle)
expected_cases = (
    "normal", "quoted-comma-multiline-unicode", "empty", "blank-null",
    "malformed-long", "missing-input", "duplicate-config-key", "existing-prefix-sentinel",
)
require(oracle.CASE_NAMES == expected_cases, "reference matrix changed; review required")
root = Path(tempfile.mkdtemp(prefix="emburk-t0032-differential-", dir="/private/tmp"))
print(f"T0032_S01_EVIDENCE_DIR={root}", flush=True)
jar = oracle.snapshot_reference(oracle.reference_bytes(dict(os.environ)), root)
java, version = oracle.java_command(dict(os.environ))
binary = repository / "target/debug/emburk"
run_id = str(uuid.uuid4())
summary = {
    "run_uuid": run_id,
    "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
    "binary_sha256": oracle.sha256(binary.read_bytes()),
    "cases": [],
    "result": "incomplete",
}
try:
    for name in expected_cases:
        reference = oracle.run_case(name, jar, java, version, run_id)
        observed = oracle.validate_case_manifest(reference / "manifest.json")
        require(observed["case"] == name and observed["run_uuid"] == run_id, "reference identity differs")
        require(not observed["process"]["timed_out"], "reference timeout is not an outcome")
        native = root / name
        native.mkdir()
        (native / "output").mkdir()
        shutil.copyfile(reference / "config.yml", native / "config.yml")
        if observed["input"]["exists"]:
            shutil.copyfile(reference / "input.csv", native / "input.csv")
        if name == "existing-prefix-sentinel":
            (native / "output/result").write_bytes(b"original sentinel\n")
        require(oracle.output_inventory(native / "output") == observed["preexisting_outputs"], "initial outputs differ")
        with (native / "stdout.log").open("xb") as stdout, (native / "stderr.log").open("xb") as stderr:
            process = subprocess.run(
                [str(binary), "run", "config.yml"], cwd=native,
                env={"PATH": os.defpath}, stdout=stdout, stderr=stderr, timeout=60,
            )
        (native / "exit.txt").write_text(f"{process.returncode}\n", encoding="ascii")
        outputs = oracle.output_inventory(native / "output")
        result = {
            "case": name, "reference": str(reference), "native": str(native),
            "exit": process.returncode, "outputs": outputs,
            "stdout": oracle.file_detail(native / "stdout.log", native),
            "stderr": oracle.file_detail(native / "stderr.log", native),
            "reference_manifest_sha256": oracle.sha256((reference / "manifest.json").read_bytes()),
        }
        summary["cases"].append(result)
        expected_exit = observed["process"]["exit"]
        if os.environ.get("EMBURK_TEST_DIFF_MISMATCH") == "1":
            expected_exit += 1  # Deliberate negative control; must never pass.
        require(process.returncode == expected_exit, f"{name}: exit differs")
        require(outputs == observed["outputs"], f"{name}: complete output inventory differs")
        for item in outputs:
            require((native / "output" / item["name"]).read_bytes() == (reference / "output" / item["name"]).read_bytes(), f"{name}: bytes differ")
        print(f"T0032_S01_MATCH={name}", flush=True)
    require(len(summary["cases"]) == 8, "incomplete case matrix")
    summary["result"] = "pass"
finally:
    (root / "manifest.json").write_text(json.dumps(summary, sort_keys=True) + "\n", encoding="utf-8")
PY

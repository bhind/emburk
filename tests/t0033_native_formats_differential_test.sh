#!/bin/sh
set -eu
: "${EMBURK_REFERENCE_JAR:?EMBURK_REFERENCE_JAR is required}"
: "${JAVA_HOME:?JAVA_HOME is required}"
cargo build --locked --workspace
python3 -I -B - <<'PY'
import bz2, gzip, importlib.util, json, os, shutil, subprocess, tempfile, uuid
from pathlib import Path

def require(condition, message):
    if not condition:
        raise AssertionError(message)

repository = Path.cwd().resolve()
spec = importlib.util.spec_from_file_location("oracle", repository / "tools/formats-oracle/run.py")
oracle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oracle)
cases = ("json-scalars", "gzip-csv", "bzip2-csv", "rename-then-remove", "remove-before-rename")
require(oracle.CASES == cases, "reference matrix changed")
root = Path(tempfile.mkdtemp(prefix="emburk-t0033-differential-", dir="/private/tmp"))
print(f"T0033_S01_EVIDENCE_DIR={root}", flush=True)
jar = oracle.snapshot(oracle.pinned_bytes(dict(os.environ)), root)
java, version = oracle.java(dict(os.environ))
binary = repository / "target/debug/emburk"
run_uuid = str(uuid.uuid4())
summary = {"uuid": run_uuid, "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
           "binary_sha256": oracle.digest(binary.read_bytes()), "cases": [], "result": "incomplete"}
try:
    for name in cases:
        reference = oracle.run_case(name, jar, java, version, run_uuid)
        observed = oracle.validate(reference / "manifest.json")
        require(observed["uuid"] == run_uuid and observed["case"] == name and not observed["process"]["timed_out"], "invalid reference identity/timeout")
        native = root / name
        native.mkdir()
        (native / "output").mkdir()
        shutil.copyfile(reference / "config.yml", native / "config.yml")
        input_name = observed["input"]["name"]
        shutil.copyfile(reference / input_name, native / input_name)
        with (native / "stdout.log").open("xb") as stdout, (native / "stderr.log").open("xb") as stderr:
            process = subprocess.run([str(binary), "run", "config.yml"], cwd=native,
                                     env={"PATH": os.defpath}, stdout=stdout, stderr=stderr, timeout=60)
        (native / "exit.txt").write_text(f"{process.returncode}\n", encoding="ascii")
        outputs = oracle.inventory(native / "output")
        result = {"case": name, "reference": str(reference), "native": str(native), "exit": process.returncode,
                  "outputs": outputs, "input": oracle.detail(native / input_name, native),
                  "config": oracle.detail(native / "config.yml", native),
                  "stdout": oracle.detail(native / "stdout.log", native), "stderr": oracle.detail(native / "stderr.log", native),
                  "reference_manifest_sha256": oracle.digest((reference / "manifest.json").read_bytes())}
        summary["cases"].append(result)
        expected_exit = observed["process"]["exit"] + (os.environ.get("EMBURK_TEST_DIFF_MISMATCH") == "1")
        require(process.returncode == expected_exit, f"{name}: exit mismatch")
        require([item["name"] for item in outputs] == [item["name"] for item in observed["outputs"]], f"{name}: output names mismatch")
        decoded = []
        for item in outputs:
            native_bytes = (native / "output" / item["name"]).read_bytes()
            reference_bytes = (reference / "output" / item["name"]).read_bytes()
            if name in ("gzip-csv", "bzip2-csv"):
                decode = gzip.decompress if name == "gzip-csv" else bz2.decompress
                native_bytes, reference_bytes = decode(native_bytes), decode(reference_bytes)
                decoded_path = native / (item["name"] + ".decoded")
                decoded_path.write_bytes(native_bytes)
                decoded.append(oracle.detail(decoded_path, native))
            require(native_bytes == reference_bytes, f"{name}: plain/decoded bytes mismatch")
        result["decoded"] = decoded
        print(f"T0033_S01_MATCH={name}", flush=True)
    require(len(summary["cases"]) == 5, "incomplete matrix")
    summary["result"] = "pass"
finally:
    (root / "manifest.json").write_text(json.dumps(summary, sort_keys=True) + "\n", encoding="utf-8")
PY

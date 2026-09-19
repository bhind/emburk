#!/usr/bin/env python3
"""Compare selected finite decimals after validating complete raw evidence.

Boundary refusals are native contracts, not reference parity. Hashes detect
mutation, not malicious forgery. Reuse only repository-original capture helpers.
"""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ORACLE_PATH = ROOT / "tools/t0032-finite-decimal-oracle/run.py"
HELPER_PATH = ROOT / "tests/t0032_float64_lexical_differential_test.py"
oracle = load("finite_decimal_oracle", ORACLE_PATH)
helper = load("lexical_evidence_helpers", HELPER_PATH)
require, digest = helper.require, helper.digest
MATCH_CASES = ("family-corpus", "prior-null-sentinel", "seeded-holdout")
BOUNDARIES = tuple(oracle.fixture("grammar-boundaries").splitlines()[1:])
CASES = MATCH_CASES + tuple(f"boundary-{index:02d}" for index in range(len(BOUNDARIES)))
TREE_CAP = helper.MAX_BINARY_BYTES + 20 * 1024 * 1024


def identity():
    return {str(path.relative_to(ROOT)): digest(path.read_bytes())
            for path in (Path(__file__).resolve(), ORACLE_PATH, HELPER_PATH)}


def read(path, root, cap=oracle.MAX_CASE_TREE_BYTES):
    return oracle.bounded_regular_bytes(path, root, cap)


def record(path, root, cap=oracle.MAX_CASE_TREE_BYTES):
    return oracle.regular(path, root, cap)


def inventory(root):
    return oracle.tree(root, TREE_CAP)


def without_manifest(root):
    return [item for item in inventory(root) if item["name"] != "manifest.json"]


def write_json(path, value):
    path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")


def fixture(case):
    if case in MATCH_CASES:
        return oracle.fixture(case)
    return b"ratio\n" + BOUNDARIES[CASES.index(case) - len(MATCH_CASES)] + b"\n"


def config(case):
    return oracle.config(case if case in MATCH_CASES else "grammar-boundaries")


def validate_case(path, capture, run_uuid, case):
    root = path.parent
    value = json.loads(read(path, capture))
    require(isinstance(value, dict) and set(value) == {
        "case", "run_uuid", "input", "config", "process", "output", "tree"
    }, "case manifest structure")
    require(value["case"] == case and value["run_uuid"] == run_uuid, "case identity")
    for key, name, expected in (("input", "input.csv", fixture(case)),
                                ("config", "config.yml", config(case))):
        require(value[key] == record(root / name, root), "case artifact changed")
        require(read(root / name, root) == expected, "frozen fixture/config mismatch")
    process = value["process"]
    require(isinstance(process, dict) and set(process) == {
        "command", "exit", "timed_out", "stdout", "stderr", "exit_file"
    }, "process structure")
    require(process["command"] == [str(capture / "emburk"), "run", "config.yml"], "command linkage")
    require(type(process["exit"]) is int and type(process["timed_out"]) is bool, "process result types")
    for key, name in (("stdout", "native.stdout"), ("stderr", "native.stderr"),
                      ("exit_file", "native.exit")):
        require(process[key] == record(root / name, root), "process evidence changed")
    require(read(root / "native.exit", root, 64) == (str(process["exit"]) + "\n").encode(), "exit linkage")
    require(value["output"] == oracle.checked_output(root / "output"), "output changed")
    require(value["tree"] == without_manifest(root), "case tree changed")
    return value


def validate_reference(stage):
    require(isinstance(stage, dict) and set(stage) == {"path", "manifest_sha256"}, "reference linkage shape")
    root = Path(stage["path"])
    require(root.is_absolute() and not root.is_symlink(), "reference path")
    path = root / "manifest.json"
    require(digest(read(path, root, oracle.MAX_SUMMARY_TREE_BYTES)) == stage["manifest_sha256"], "reference manifest changed")
    summary = oracle.validate_summary(path)
    require(summary["reference_snapshot"]["sha256"] == oracle.REFERENCE_SHA256, "pinned reference hash")
    for case in oracle.CASES:
        case_root = root / "cases" / case
        value = oracle.validate_case(case_root / "manifest.json")
        require(value["case"] == case, "reference case linkage")
        require(read(case_root / "input.csv", root) == oracle.fixture(case), "reference fixture mismatch")
        require(read(case_root / "config.yml", root) == oracle.config(case), "reference config mismatch")
        process = value["process"]
        java = Path(value["environment"]["java_home"]) / "bin/java"
        expected = [str(java), f"-Duser.home={case_root / 'home'}",
                    f"-Djava.io.tmpdir={case_root / 'tmp'}", "-jar", str(root / "embulk.jar"),
                    f"-Xembulk_home={case_root / 'home'}", "run", "config.yml"]
        require(process["command"] == expected, "reference command linkage")
        require(type(process["exit"]) is int and process["exit"] == 0
                and process["timed_out"] is False, "reference did not succeed")
    return root


def validate_summary_manifest(path):
    root = path.parent
    value = json.loads(read(path, root, TREE_CAP))
    require(isinstance(value, dict) and set(value) == {
        "run_uuid", "stage_a", "binary", "drivers", "cases", "result", "tree"
    }, "summary structure")
    require(str(uuid.UUID(value["run_uuid"])) == value["run_uuid"], "run identity")
    require(value["drivers"] == identity() and value["result"] in ("captured", "pass"), "summary identity")
    require(value["binary"] == record(root / "emburk", root, helper.MAX_BINARY_BYTES), "binary changed")
    reference = validate_reference(value["stage_a"])
    require(isinstance(value["cases"], list) and len(value["cases"]) == len(CASES), "case count")
    for item, case in zip(value["cases"], CASES):
        require(isinstance(item, dict) and set(item) == {"case", "path", "manifest_sha256"}, "case linkage shape")
        require(item["case"] == case and item["path"] == f"cases/{case}", "case order/path linkage")
        manifest = root / item["path"] / "manifest.json"
        require(digest(read(manifest, root)) == item["manifest_sha256"], "case manifest hash")
        validate_case(manifest, root, value["run_uuid"], case)
    require(value["tree"] == without_manifest(root), "summary tree changed")
    return value, reference


def assert_outcomes(path):
    # Validate all complete evidence before deriving an equality projection.
    value, reference = validate_summary_manifest(path)
    root = path.parent
    for case in CASES:
        native = root / "cases" / case
        result = json.loads(read(native / "manifest.json", root))["process"]
        require(not result["timed_out"], "native timeout is not an outcome")
        if case in MATCH_CASES:
            require(result["exit"] == 0, "native comparison failed")
            require(helper.output_bytes(native / "output") ==
                    helper.output_bytes(reference / "cases" / case / "output"), "selected differential mismatch")
        elif fixture(case) == b"ratio\n03.5\n":
            require(result["exit"] == 0, "leading zero was refused")
            require(helper.output_bytes(native / "output") == [{
                "name": "result000.00.csv", "type": "regular", "bytes": b"ratio\n3.5\n".hex()
            }], "leading zero canonical output")
        else:
            require(result["exit"] > 0 and not inventory(native / "output"), "boundary must fail without publication")
    return value


def main():
    source = helper.executable()
    completed = subprocess.run([sys.executable, "-I", "-B", str(ORACLE_PATH)],
                               cwd=ROOT, env=dict(os.environ), stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, timeout=oracle.TIMEOUT_SECONDS * 5)
    require(completed.returncode == 0, "fresh oracle failed: " + completed.stderr.decode("utf-8", errors="replace")[-2000:])
    marker = "T0032_S05_EVIDENCE_DIR="
    paths = [line[len(marker):] for line in completed.stdout.decode().splitlines() if line.startswith(marker)]
    require(len(paths) == 1, "fresh oracle evidence location")
    stage_root = Path(paths[0])
    stage = {"path": str(stage_root), "manifest_sha256": digest(read(stage_root / "manifest.json", stage_root, oracle.MAX_SUMMARY_TREE_BYTES))}
    validate_reference(stage)
    root = Path(tempfile.mkdtemp(prefix="emburk-t0032-s05-differential-", dir="/private/tmp"))
    root.chmod(0o700)
    binary = root / "emburk"
    binary.write_bytes(read(source, source.parent, helper.MAX_BINARY_BYTES))
    binary.chmod(0o500)
    summary = {"run_uuid": str(uuid.uuid4()), "stage_a": stage,
               "binary": record(binary, root, helper.MAX_BINARY_BYTES), "drivers": identity(),
               "cases": [], "result": "captured"}
    print(marker + str(root), flush=True)
    for case in CASES:
        current = root / "cases" / case
        current.mkdir(parents=True, mode=0o700)
        (current / "output").mkdir(mode=0o700)
        (current / "input.csv").write_bytes(fixture(case))
        (current / "config.yml").write_bytes(config(case))
        process = helper.execute([str(binary), "run", "config.yml"], current, "native", {"PATH": os.defpath})
        value = {"case": case, "run_uuid": summary["run_uuid"],
                 "input": record(current / "input.csv", current), "config": record(current / "config.yml", current),
                 "process": process, "output": oracle.checked_output(current / "output"), "tree": inventory(current)}
        manifest = current / "manifest.json"
        write_json(manifest, value)
        summary["cases"].append({"case": case, "path": f"cases/{case}", "manifest_sha256": digest(manifest.read_bytes())})
    summary["tree"] = inventory(root)
    manifest = root / "manifest.json"
    write_json(manifest, summary)
    assert_outcomes(manifest)
    summary["result"] = "pass"
    write_json(manifest, summary)
    assert_outcomes(manifest)
    print("T0032_S05_MATCH=3 selected comparisons; 1 native normalization; 9 native refusals", flush=True)
    return root


def self_test():
    # The target is executable: rejection must be for the link, not its mode.
    with tempfile.TemporaryDirectory(prefix="emburk-s05-link-", dir="/private/tmp") as temporary:
        base = Path(temporary)
        target = base / "binary"
        target.write_bytes(b"not executed\n")
        target.chmod(0o500)
        link = base / "link"
        link.symlink_to(target)
        previous = os.environ.get("EMBURK_BINARY")
        os.environ["EMBURK_BINARY"] = str(link)
        try:
            rejects(helper.executable)
        finally:
            if previous is None:
                os.environ.pop("EMBURK_BINARY")
            else:
                os.environ["EMBURK_BINARY"] = previous
    root = main()
    summary = root / "manifest.json"
    case = root / "cases" / MATCH_CASES[0]
    for path in (case / "input.csv", case / "config.yml", case / "native.stderr",
                 case / "native.exit", case / "output/result000.00.csv", case / "unexpected"):
        original = path.read_bytes() if path.exists() else None
        path.write_bytes(b"tamper\n")
        try:
            rejects(lambda: assert_outcomes(summary))
        finally:
            path.unlink() if original is None else path.write_bytes(original)
        assert_outcomes(summary)
    original = summary.read_bytes()
    mutations = (
        lambda v: v["cases"].reverse(),
        lambda v: v["cases"][0].update(manifest_sha256="0" * 64),
        lambda v: v["cases"][0].update(path="cases/../wrong"),
        lambda v: v.update(run_uuid=str(uuid.uuid4())),
        lambda v: v["stage_a"].update(manifest_sha256="0" * 64),
        lambda v: v["drivers"].update(extra="wrong"),
    )
    for mutate in mutations:
        value = json.loads(original)
        mutate(value)
        write_json(summary, value)
        try:
            rejects(lambda: assert_outcomes(summary))
        finally:
            summary.write_bytes(original)
        assert_outcomes(summary)
    print("T0032_S05_SELF_TEST=pass (13 mutation/link controls)", flush=True)


def rejects(action):
    try:
        action()
    except ValueError:
        return
    raise AssertionError("invalid evidence accepted")


if __name__ == "__main__":
    try:
        require(sys.argv[1:] in ([], ["--self-test"]), "unknown arguments")
        self_test() if sys.argv[1:] else main()
    except (OSError, ValueError, subprocess.SubprocessError) as failure:
        print("T0032_S05_DIFFERENTIAL_ERROR=" + str(failure), file=sys.stderr)
        raise SystemExit(2)

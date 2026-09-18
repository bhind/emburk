import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("t0032_boolean_oracle", ROOT / "tools/t0032-boolean-file-csv-oracle/run.py")
oracle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(oracle)


class BooleanFileCsvOracleTests(unittest.TestCase):
    def test_cases_and_fixtures_are_exactly_bounded(self):
        self.assertEqual(oracle.CASES, ("canonical-true-false", "unquoted-and-quoted-empty", "invalid-between-valid"))
        self.assertEqual(oracle.fixture("canonical-true-false"), b"flag\ntrue\nfalse\n")
        self.assertEqual(oracle.fixture("unquoted-and-quoted-empty"), b'label,flag\nbare,\nquoted,""\n')
        self.assertEqual(oracle.fixture("invalid-between-valid"), b"flag\ntrue\ntruthy\nfalse\n")

    def test_config_is_case_relative_and_boolean_only(self):
        profile = oracle.config("canonical-true-false").decode("utf-8")
        empty_profile = oracle.config("unquoted-and-quoted-empty").decode("utf-8")
        self.assertIn("{name: flag, type: boolean}", profile)
        self.assertIn("{name: label, type: string}", empty_profile)
        self.assertIn("path_prefix: input.csv", profile)
        self.assertIn("path_prefix: output/result", profile)
        self.assertNotIn("/private/tmp", profile)

    def test_manifest_detects_raw_mutation_and_extra_tree_entry(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "output").mkdir(); (root / "home").mkdir(); (root / "tmp").mkdir()
            (root / "input.csv").write_bytes(oracle.fixture("canonical-true-false"))
            (root / "config.yml").write_bytes(oracle.config("canonical-true-false"))
            (root / "java-version.txt").write_bytes(b"java 17\n")
            (root / "stdout.log").write_bytes(b""); (root / "stderr.log").write_bytes(b"")
            (root / "exit.txt").write_text("0\n", encoding="ascii")
            manifest = {"case": "canonical-true-false", "run_uuid": "00000000-0000-4000-8000-000000000000",
                        "reference": {"sha256": oracle.JAR_SHA256},
                        "java_version": oracle.regular_detail(root / "java-version.txt", root),
                        "config": oracle.regular_detail(root / "config.yml", root),
                        "input": oracle.regular_detail(root / "input.csv", root),
                        "process": {"command": ["java"], "exit": 0, "timed_out": False,
                                    "stdout": oracle.regular_detail(root / "stdout.log", root),
                                    "stderr": oracle.regular_detail(root / "stderr.log", root),
                                    "exit_file": oracle.regular_detail(root / "exit.txt", root)},
                        "outputs": oracle.inventory(root / "output")}
            manifest["case_tree"] = oracle.inventory(root)
            path = root / "manifest.json"; path.write_text(json.dumps(manifest, sort_keys=True) + "\n")
            oracle.validate_case_manifest(path)
            (root / "stdout.log").write_bytes(b"changed")
            with self.assertRaises(ValueError): oracle.validate_case_manifest(path)

    def test_summary_rejects_case_order_and_tree_mutations(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            original = oracle.JAR_SHA256
            try:
                oracle.JAR_SHA256 = oracle.sha256(b"test jar")
                (root / "embulk.jar").write_bytes(b"test jar")
                run_uuid = "00000000-0000-4000-8000-000000000000"
                for case in oracle.CASES:
                    case_root = root / "cases" / case
                    (case_root / "output").mkdir(parents=True); (case_root / "home").mkdir(); (case_root / "tmp").mkdir()
                    (case_root / "input.csv").write_bytes(oracle.fixture(case))
                    (case_root / "config.yml").write_bytes(oracle.config(case))
                    (case_root / "java-version.txt").write_bytes(b"java 17\n")
                    (case_root / "stdout.log").write_bytes(b""); (case_root / "stderr.log").write_bytes(b"")
                    (case_root / "exit.txt").write_text("0\n", encoding="ascii")
                    process = {"command": ["java"], "exit": 0, "timed_out": False,
                               "stdout": oracle.regular_detail(case_root / "stdout.log", case_root),
                               "stderr": oracle.regular_detail(case_root / "stderr.log", case_root),
                               "exit_file": oracle.regular_detail(case_root / "exit.txt", case_root)}
                    manifest = {"case": case, "run_uuid": run_uuid, "reference": {"sha256": oracle.JAR_SHA256},
                                "java_version": oracle.regular_detail(case_root / "java-version.txt", case_root),
                                "config": oracle.regular_detail(case_root / "config.yml", case_root),
                                "input": oracle.regular_detail(case_root / "input.csv", case_root),
                                "process": process, "outputs": oracle.inventory(case_root / "output")}
                    manifest["case_tree"] = oracle.inventory(case_root)
                    (case_root / "manifest.json").write_text(json.dumps(manifest, sort_keys=True) + "\n")
                cases = [{"case": case, "path": f"cases/{case}", "manifest_sha256": oracle.sha256((root / "cases" / case / "manifest.json").read_bytes())} for case in oracle.CASES]
                summary = {"run_uuid": run_uuid, "reference": {"sha256": oracle.JAR_SHA256},
                           "reference_snapshot": oracle.regular_detail(root / "embulk.jar", root),
                           "cases": cases, "result": "captured", "tree": oracle.inventory(root)}
                path = root / "manifest.json"; path.write_text(json.dumps(summary, sort_keys=True) + "\n")
                oracle.validate_summary_manifest(path)
                summary["cases"] = list(reversed(cases)); path.write_text(json.dumps(summary, sort_keys=True) + "\n")
                with self.assertRaises(ValueError): oracle.validate_summary_manifest(path)
                summary["cases"] = cases
                summary["tree"] = [item for item in oracle.inventory(root) if item["name"] != "manifest.json"]
                path.write_text(json.dumps(summary, sort_keys=True) + "\n")
                oracle.validate_summary_manifest(path)
                (root / "unexpected").write_bytes(b"x")
                with self.assertRaises(ValueError): oracle.validate_summary_manifest(path)
            finally:
                oracle.JAR_SHA256 = original


if __name__ == "__main__":
    unittest.main()

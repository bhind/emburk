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
        self.assertEqual(oracle.fixture("unquoted-and-quoted-empty"), b"flag\n\n\"\"\n")
        self.assertEqual(oracle.fixture("invalid-between-valid"), b"flag\ntrue\ntruthy\nfalse\n")

    def test_config_is_case_relative_and_boolean_only(self):
        profile = oracle.config().decode("utf-8")
        self.assertIn("{name: flag, type: boolean}", profile)
        self.assertIn("path_prefix: input.csv", profile)
        self.assertIn("path_prefix: output/result", profile)
        self.assertNotIn("/private/tmp", profile)

    def test_manifest_detects_raw_mutation_and_extra_tree_entry(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "output").mkdir(); (root / "home").mkdir(); (root / "tmp").mkdir()
            (root / "input.csv").write_bytes(oracle.fixture("canonical-true-false"))
            (root / "config.yml").write_bytes(oracle.config())
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


if __name__ == "__main__":
    unittest.main()

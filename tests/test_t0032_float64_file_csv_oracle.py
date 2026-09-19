import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("t0032_float64_oracle", ROOT / "tools/t0032-float64-file-csv-oracle/run.py")
oracle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(oracle)
DIFFERENTIAL_SPEC = importlib.util.spec_from_file_location(
    "t0032_float64_differential", ROOT / "tests/t0032_float64_file_csv_differential_test.py"
)
differential = importlib.util.module_from_spec(DIFFERENTIAL_SPEC)
DIFFERENTIAL_SPEC.loader.exec_module(differential)


class Float64FileCsvOracleTests(unittest.TestCase):
    def test_exactly_three_bounded_input_shapes(self):
        self.assertEqual(oracle.CASES, ("finite-decimal-and-signed-zero", "unquoted-and-quoted-empty", "malformed-between-finite"))
        self.assertEqual(oracle.fixture("finite-decimal-and-signed-zero"), b"ratio\n1.5\n-0.0\n0.0\n")
        self.assertEqual(oracle.fixture("unquoted-and-quoted-empty"), b'label,ratio\nbare,\nquoted,""\n')
        self.assertEqual(oracle.fixture("malformed-between-finite"), b"ratio\n1.5\nnot-a-double\n2.5\n")

    def test_double_config_is_relative_and_does_not_encode_output(self):
        ordinary = oracle.config("finite-decimal-and-signed-zero").decode("utf-8")
        empties = oracle.config("unquoted-and-quoted-empty").decode("utf-8")
        self.assertIn("{name: ratio, type: double}", ordinary)
        self.assertIn("{name: label, type: string}", empties)
        self.assertIn("path_prefix: input.csv", ordinary)
        self.assertIn("path_prefix: output/result", ordinary)
        self.assertNotIn("1.5", ordinary)
        self.assertNotIn("not-a-double", ordinary)
        self.assertNotIn("/private/tmp", ordinary)

    def test_text_validation_rejects_non_utf8_non_lf_and_oversize(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sample = root / "sample.txt"
            sample.write_bytes(b"ok\r\n")
            with self.assertRaises(ValueError):
                oracle.canonical_text(sample, root, 16)
            sample.write_bytes(b"\xff\n")
            with self.assertRaises(ValueError):
                oracle.canonical_text(sample, root, 16)
            sample.write_bytes(b"12345\n")
            with self.assertRaises(ValueError):
                oracle.canonical_text(sample, root, 5)

    def test_reference_and_binary_limits_reject_before_reading(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            jar = root / "reference.jar"; jar.write_bytes(b"jar")
            binary = root / "emburk"; binary.write_bytes(b"bin"); binary.chmod(0o500)
            saved_sha, saved_bytes = oracle.REFERENCE_SHA256, oracle.REFERENCE_BYTES
            saved_cap, saved_binary = differential.MAX_BINARY_BYTES, os.environ.get("EMBURK_BINARY")
            try:
                oracle.REFERENCE_SHA256 = oracle.digest(b"jar")
                oracle.REFERENCE_BYTES = 2
                with self.assertRaises(ValueError):
                    oracle.reference({"EMBURK_REFERENCE_JAR": str(jar)})
                oracle.REFERENCE_BYTES = 3
                self.assertEqual(oracle.reference({"EMBURK_REFERENCE_JAR": str(jar)}), b"jar")
                differential.MAX_BINARY_BYTES = 2
                os.environ["EMBURK_BINARY"] = str(binary)
                with self.assertRaises(ValueError):
                    differential.binary()
            finally:
                oracle.REFERENCE_SHA256, oracle.REFERENCE_BYTES = saved_sha, saved_bytes
                differential.MAX_BINARY_BYTES = saved_cap
                if saved_binary is None:
                    os.environ.pop("EMBURK_BINARY", None)
                else:
                    os.environ["EMBURK_BINARY"] = saved_binary

    def test_case_manifest_rejects_raw_tampering(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "output").mkdir(); (root / "home").mkdir(); (root / "tmp").mkdir()
            (root / "input.csv").write_bytes(oracle.fixture("finite-decimal-and-signed-zero"))
            (root / "config.yml").write_bytes(oracle.config("finite-decimal-and-signed-zero"))
            (root / "java-version.txt").write_bytes(b"java 17\n")
            (root / "stdout.log").write_bytes(b""); (root / "stderr.log").write_bytes(b"")
            (root / "exit.txt").write_bytes(b"0\n")
            driver = {"path": oracle.DRIVER_LABEL, "sha256": oracle.digest(Path(oracle.__file__).read_bytes())}
            process = {"command": ["java"], "exit": 0, "timed_out": False,
                       "stdout": oracle.canonical_text(root / "stdout.log", root, oracle.MAX_LOG_BYTES),
                       "stderr": oracle.canonical_text(root / "stderr.log", root, oracle.MAX_LOG_BYTES),
                       "exit_file": oracle.canonical_text(root / "exit.txt", root, 64)}
            manifest = {"case": "finite-decimal-and-signed-zero", "run_uuid": "00000000-0000-4000-8000-000000000000",
                        "reference": {"sha256": oracle.REFERENCE_SHA256},
                        "environment": {"java_home": "/test/java", "java_version_sha256": oracle.digest(b"java 17\n")},
                        "java_version": oracle.canonical_text(root / "java-version.txt", root, oracle.MAX_LOG_BYTES), "driver": driver,
                        "config": oracle.canonical_text(root / "config.yml", root, oracle.MAX_CONFIG_BYTES),
                        "input": oracle.canonical_text(root / "input.csv", root, oracle.MAX_INPUT_BYTES),
                        "process": process, "outputs": oracle.checked_output(root / "output")}
            manifest["case_tree"] = oracle.tree(root)
            path = root / "manifest.json"; path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
            oracle.validate_case(path)
            (root / "stderr.log").write_bytes(b"changed\n")
            with self.assertRaises(ValueError):
                oracle.validate_case(path)


if __name__ == "__main__":
    unittest.main()

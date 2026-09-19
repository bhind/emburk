import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("t0032_float64_lexical_oracle", ROOT / "tools/t0032-float64-lexical-oracle/run.py")
oracle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(oracle)


class Float64LexicalOracleTests(unittest.TestCase):
    def test_exactly_three_authorized_input_shapes(self):
        self.assertEqual(oracle.CASES, ("plain-decimals", "quoted-and-unquoted-decimal", "malformed-between-decimals"))
        self.assertEqual(oracle.fixture("plain-decimals"), b"ratio\n3.5\n-12.25\n")
        self.assertEqual(oracle.fixture("quoted-and-unquoted-decimal"), b'ratio\n3.5\n"3.5"\n')
        self.assertEqual(oracle.fixture("malformed-between-decimals"), b"ratio\n3.5\n3.5x\n42.0\n")

    def test_config_is_relative_and_does_not_encode_reference_output(self):
        profile = oracle.config("plain-decimals").decode("utf-8")
        self.assertIn("{name: ratio, type: double}", profile)
        self.assertIn("path_prefix: input.csv", profile)
        self.assertIn("path_prefix: output/result", profile)
        self.assertNotIn("3.5", profile)
        self.assertNotIn("42.0", profile)
        self.assertNotIn("/private/tmp", profile)

    def test_text_validation_rejects_non_utf8_non_lf_oversize_and_symlink(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); sample = root / "sample.txt"
            sample.write_bytes(b"ok\r\n")
            with self.assertRaises(ValueError): oracle.canonical_text(sample, root, 16)
            sample.write_bytes(b"\xff\n")
            with self.assertRaises(ValueError): oracle.canonical_text(sample, root, 16)
            sample.write_bytes(b"12345\n")
            with self.assertRaises(ValueError): oracle.canonical_text(sample, root, 5)
            link = root / "link.txt"; link.symlink_to(sample)
            with self.assertRaises(ValueError): oracle.canonical_text(link, root, 16)

    def test_reference_cap_rejects_before_reading_and_driver_rejects_tampering(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); jar = root / "reference.jar"; jar.write_bytes(b"jar")
            old_size, old_hash = oracle.REFERENCE_BYTES, oracle.REFERENCE_SHA256
            try:
                oracle.REFERENCE_BYTES, oracle.REFERENCE_SHA256 = 2, oracle.digest(b"jar")
                with self.assertRaises(ValueError): oracle.reference({"EMBURK_REFERENCE_JAR": str(jar)})
                oracle.REFERENCE_BYTES = 3
                self.assertEqual(oracle.reference({"EMBURK_REFERENCE_JAR": str(jar)}), b"jar")
            finally:
                oracle.REFERENCE_BYTES, oracle.REFERENCE_SHA256 = old_size, old_hash
            (root / "output").mkdir(); (root / "home").mkdir(); (root / "tmp").mkdir()
            (root / "input.csv").write_bytes(oracle.fixture("plain-decimals")); (root / "config.yml").write_bytes(oracle.config("plain-decimals"))
            (root / "java-version.txt").write_bytes(b"java 17\n"); (root / "stdout.log").write_bytes(b""); (root / "stderr.log").write_bytes(b""); (root / "exit.txt").write_bytes(b"0\n")
            manifest = {"case": "plain-decimals", "run_uuid": "00000000-0000-4000-8000-000000000000", "reference": {"sha256": oracle.REFERENCE_SHA256},
                        "environment": {"java_home": "/test/java", "java_version_sha256": oracle.digest(b"java 17\n")},
                        "java_version": oracle.canonical_text(root / "java-version.txt", root, oracle.MAX_LOG_BYTES),
                        "driver": {"path": oracle.DRIVER_LABEL, "sha256": oracle.digest(Path(oracle.__file__).read_bytes())},
                        "config": oracle.canonical_text(root / "config.yml", root, oracle.MAX_CONFIG_BYTES), "input": oracle.canonical_text(root / "input.csv", root, oracle.MAX_INPUT_BYTES),
                        "process": {"command": ["java"], "exit": 0, "timed_out": False, "stdout": oracle.canonical_text(root / "stdout.log", root, oracle.MAX_LOG_BYTES), "stderr": oracle.canonical_text(root / "stderr.log", root, oracle.MAX_LOG_BYTES), "exit_file": oracle.canonical_text(root / "exit.txt", root, 64)},
                        "outputs": oracle.checked_output(root / "output")}
            manifest["case_tree"] = oracle.tree(root, oracle.MAX_CASE_TREE_BYTES)
            path = root / "manifest.json"; path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
            oracle.validate_case(path)
            (root / "stderr.log").write_bytes(b"changed\n")
            with self.assertRaises(ValueError): oracle.validate_case(path)
            path.write_bytes(b"{\n")
            with self.assertRaises(ValueError): oracle.validate_case(path)


if __name__ == "__main__":
    unittest.main()

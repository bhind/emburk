import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("t0032_finite_decimal_oracle", ROOT / "tools/t0032-finite-decimal-oracle/run.py")
oracle = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(oracle)


class FiniteDecimalOracleTests(unittest.TestCase):
    def test_frozen_corpus_and_separate_seeded_holdout(self):
        self.assertEqual(oracle.CASES, ("family-corpus", "grammar-boundaries", "prior-null-sentinel", "seeded-holdout"))
        self.assertEqual(oracle.holdout_values(), oracle.holdout_values())
        self.assertEqual(len(oracle.holdout_values()), 64)
        self.assertEqual(oracle.fixture("seeded-holdout").count(b"\n"), 65)
        family = oracle.fixture("family-corpus")
        for value in (b"3.50", b"-0", b"999999.99", b'"3.5"'):
            self.assertIn(value, family)
        boundaries = oracle.fixture("grammar-boundaries")
        for value in (b"+3.5", b"03.5", b".5", b"1.", b"1e2", b"NaN", b"3.141"):
            self.assertIn(value, boundaries)

    def test_config_never_encodes_output_or_fixture_values(self):
        profile = oracle.config("family-corpus").decode("utf-8")
        self.assertIn("{name: ratio, type: double}", profile)
        self.assertNotIn("3.50", profile); self.assertNotIn("999999", profile); self.assertNotIn("/private/tmp", profile)
        with self.assertRaises(ValueError): oracle.fixture("unexpected")
        with self.assertRaises(ValueError): oracle.config("unexpected")

    def test_bounded_regular_and_tree_reject_bad_paths_and_caps(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); sample = root / "sample"
            sample.write_bytes(b"12345\n")
            with self.assertRaises(ValueError): oracle.canonical_text(sample, root, 5)
            link = root / "link"; link.symlink_to(sample)
            with self.assertRaises(ValueError): oracle.canonical_text(link, root, 32)
            special = root / "nested"; special.mkdir(); (special / "big").write_bytes(b"x" * 8)
            with self.assertRaises(ValueError): oracle.tree(root, 7)

    def test_manifest_tamper_and_unexpected_case_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); (root / "output").mkdir(); (root / "home").mkdir(); (root / "tmp").mkdir()
            for name, data in (("input.csv", oracle.fixture("family-corpus")), ("config.yml", oracle.config("family-corpus")), ("java-version.txt", b"java 17\n"), ("stdout.log", b""), ("stderr.log", b""), ("exit.txt", b"0\n")):
                (root / name).write_bytes(data)
            identity = {"path": oracle.DRIVER_LABEL, "sha256": oracle.digest(Path(oracle.__file__).read_bytes())}
            manifest = {"case": "family-corpus", "run_uuid": "00000000-0000-4000-8000-000000000000", "reference": {"sha256": oracle.REFERENCE_SHA256}, "environment": {"java_home": "/test/java", "java_version_sha256": oracle.digest(b"java 17\n")}, "java_version": oracle.canonical_text(root / "java-version.txt", root, oracle.MAX_LOG_BYTES), "driver": identity, "generator": identity, "config": oracle.canonical_text(root / "config.yml", root, oracle.MAX_CONFIG_BYTES), "input": oracle.canonical_text(root / "input.csv", root, oracle.MAX_INPUT_BYTES), "process": {"command": ["java"], "exit": 0, "timed_out": False, "stdout": oracle.canonical_text(root / "stdout.log", root, oracle.MAX_LOG_BYTES), "stderr": oracle.canonical_text(root / "stderr.log", root, oracle.MAX_LOG_BYTES), "exit_file": oracle.canonical_text(root / "exit.txt", root, 64)}, "outputs": oracle.checked_output(root / "output")}
            manifest["case_tree"] = oracle.tree(root, oracle.MAX_CASE_TREE_BYTES)
            path = root / "manifest.json"; path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
            oracle.validate_case(path)
            manifest["case"] = "unexpected"; path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
            with self.assertRaises(ValueError): oracle.validate_case(path)
            manifest["case"] = "family-corpus"; path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
            (root / "stderr.log").write_bytes(b"changed\n")
            with self.assertRaises(ValueError): oracle.validate_case(path)

    def test_reference_rejects_size_before_read(self):
        with tempfile.TemporaryDirectory() as temporary:
            jar = Path(temporary) / "reference.jar"; jar.write_bytes(b"jar")
            old_size, old_hash = oracle.REFERENCE_BYTES, oracle.REFERENCE_SHA256
            try:
                oracle.REFERENCE_BYTES, oracle.REFERENCE_SHA256 = 2, oracle.digest(b"jar")
                with self.assertRaises(ValueError): oracle.reference({"EMBURK_REFERENCE_JAR": str(jar)})
                oracle.REFERENCE_BYTES = 3
                self.assertEqual(oracle.reference({"EMBURK_REFERENCE_JAR": str(jar)}), b"jar")
            finally:
                oracle.REFERENCE_BYTES, oracle.REFERENCE_SHA256 = old_size, old_hash


if __name__ == "__main__": unittest.main()

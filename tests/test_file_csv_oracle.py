import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("file_csv_oracle", ROOT / "tools/file-csv-oracle/run.py")
oracle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(oracle)


class FileCsvOracleTests(unittest.TestCase):
    def write_valid_manifest(self, directory, input_exists=False):
        root = Path(directory)
        (root / "output").mkdir()
        (root / "config.yml").write_bytes(b"config\n")
        (root / "java-version.txt").write_bytes(b"java 17\n")
        (root / "stdout.log").write_bytes(b"stdout\n")
        (root / "stderr.log").write_bytes(b"")
        (root / "exit.txt").write_text("0\n", encoding="ascii")
        (root / "output" / "result.csv").write_bytes(b"id,name\n")
        if input_exists:
            (root / "input.csv").write_bytes(b"id,name\n")
        detail = lambda path: oracle.file_detail(path, root)
        manifest = {
            "case": "normal", "run_uuid": "00000000-0000-4000-8000-000000000000",
            "reference": {"sha256": oracle.EXPECTED_JAR_SHA256}, "java_version": detail(root / "java-version.txt"),
            "input": {"name": "input.csv", "exists": input_exists, "size": len(b"id,name\n") if input_exists else 0, "sha256": oracle.sha256(b"id,name\n") if input_exists else oracle.sha256(b"")},
            "config": detail(root / "config.yml"),
            "process": {"exit": 0, "timed_out": False, "stdout": detail(root / "stdout.log"), "stderr": detail(root / "stderr.log")},
            "outputs": [{"name": "result.csv", "size": len(b"id,name\n"), "sha256": oracle.sha256(b"id,name\n")}], "preexisting_outputs": [],
        }
        path = root / "manifest.json"; path.write_text(json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")
        return path, manifest

    def test_wrong_artifact_is_rejected_before_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            artifact = Path(directory) / "wrong.jar"
            artifact.write_bytes(b"not the pinned artifact")
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                oracle.reference_jar({"EMBURK_REFERENCE_JAR": str(artifact)})

    def test_incomplete_manifest_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "manifest.json"
            manifest.write_text(json.dumps({"case": "normal"}) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "manifest structure"):
                oracle.validate_case_manifest(manifest)

    def test_malformed_manifest_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "manifest.json"
            manifest.write_text("{not json}\n", encoding="utf-8")
            with self.assertRaises(json.JSONDecodeError):
                oracle.validate_case_manifest(manifest)

    def test_child_environment_does_not_forward_sentinel(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = oracle.jvm_environment(Path(directory), "/java-home")
            self.assertNotIn("T0014_SECRET_SENTINEL", environment)
            self.assertNotIn("JAVA_TOOL_OPTIONS", environment)
            self.assertEqual(set(environment), {"PATH", "JAVA_HOME", "EMBULK_HOME", "HOME", "TMPDIR"})

    def test_verified_snapshot_is_unchanged_when_source_is_replaced(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(oracle, "EXPECTED_JAR_SHA256", oracle.sha256(b"trusted")):
            source, root = Path(directory) / "reference.jar", Path(directory) / "run"
            source.write_bytes(b"trusted")
            root.mkdir()
            data = oracle.reference_bytes({"EMBURK_REFERENCE_JAR": str(source)})
            copied = oracle.snapshot_reference(data, root)
            source.write_bytes(b"replacement")
            self.assertEqual(copied.read_bytes(), b"trusted")

    def test_summary_does_not_overwrite_case_manifest(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(oracle, "EXPECTED_JAR_SHA256", oracle.sha256(b"trusted")):
            root, case = Path(directory) / "run", Path(directory) / "case"
            root.mkdir(); case.mkdir()
            original = b'{"case":"normal"}\n'
            (case / "manifest.json").write_bytes(original)
            jar = oracle.snapshot_reference(b"trusted", root)
            oracle.write_summary(root, "00000000-0000-4000-8000-000000000000", jar, [{"case": "normal", "path": str(case), "manifest_sha256": oracle.sha256(original)}])
            self.assertEqual((case / "manifest.json").read_bytes(), original)

    def test_config_uses_case_relative_paths(self):
        config = oracle.config_bytes().decode("utf-8")
        self.assertIn("path_prefix: input.csv", config)
        self.assertIn("path_prefix: output/result", config)
        self.assertNotIn("/private/tmp", config)

    def test_config_explicitly_bounds_execution_and_duplicate_key(self):
        self.assertIn("exec:\n  max_threads: 1\n  min_output_tasks: 1\n", oracle.config_bytes().decode("utf-8"))
        self.assertIn("skip_header_lines: 2\n    skip_header_lines: 1", oracle.config_bytes(True).decode("utf-8"))

    def test_manifest_rejects_changed_raw_file_and_missing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, _ = self.write_valid_manifest(directory)
            oracle.validate_case_manifest(manifest)
            (Path(directory) / "config.yml").write_bytes(b"changed\n")
            with self.assertRaises(ValueError): oracle.validate_case_manifest(manifest)
        with tempfile.TemporaryDirectory() as directory:
            manifest, _ = self.write_valid_manifest(directory)
            (Path(directory) / "output" / "result.csv").unlink()
            with self.assertRaises(ValueError): oracle.validate_case_manifest(manifest)

    def test_manifest_rejects_omitted_output_and_changed_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, value = self.write_valid_manifest(directory)
            value["outputs"] = []
            manifest.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
            with self.assertRaises(ValueError): oracle.validate_case_manifest(manifest)
        with tempfile.TemporaryDirectory() as directory:
            manifest, value = self.write_valid_manifest(directory)
            value["process"]["exit"] = 1
            manifest.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
            with self.assertRaises(ValueError): oracle.validate_case_manifest(manifest)

    def test_manifest_rejects_escaped_path_and_records_missing_input(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, value = self.write_valid_manifest(directory)
            oracle.validate_case_manifest(manifest)
            value["config"]["name"] = "../outside.yml"
            manifest.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
            with self.assertRaises(ValueError): oracle.validate_case_manifest(manifest)


if __name__ == "__main__":
    unittest.main()

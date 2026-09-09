import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("multifile_oracle", ROOT / "tools/multifile-path-prefix-oracle/run.py")
oracle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(oracle)


class MultiFilePathPrefixOracleTests(unittest.TestCase):
    def valid_case(self, directory, case="two-regular", run_uuid="00000000-0000-4000-8000-000000000000"):
        root = Path(directory)
        (root / "output").mkdir()
        for name, contents in oracle.fixture(case).items():
            target = root / name
            target.mkdir() if contents is None else target.write_bytes(contents)
        stdout = ("timestamped preface\n" + "\n".join(oracle.STDOUT_PROJECTIONS[case]) + "\n").encode()
        for name, data in {"config.yml": b"config\n", "java-version.txt": b"java 17\n", "stdout.log": stdout, "stderr.log": b"", "exit.txt": b"0\n"}.items():
            (root / name).write_bytes(data)
        for name, contents in oracle.OBSERVATIONS[case]:
            (root / "output" / name).write_bytes(contents)
        value = {"case": case, "run_uuid": run_uuid, "reference": {"sha256": oracle.EXPECTED_JAR_SHA256}, "java_version": oracle.detail(root / "java-version.txt", root), "inputs": [item for item in oracle.inventory(root) if item["name"].startswith("input.")], "config": oracle.detail(root / "config.yml", root), "process": {"exit": 0, "timed_out": False, "stdout": oracle.detail(root / "stdout.log", root), "stderr": oracle.detail(root / "stderr.log", root)}, "outputs": oracle.inventory(root / "output")}
        value["case_tree"] = oracle.inventory(root)
        path = root / "manifest.json"
        path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
        return path, value

    def test_fixture_has_exactly_three_selected_cases(self):
        self.assertEqual(oracle.CASES, ("two-regular", "two-regular-swapped", "regular-and-directory"))
        self.assertEqual(set(oracle.fixture("two-regular")), {"input.10.csv", "input.20.csv"})
        self.assertEqual(oracle.fixture("regular-and-directory")["input.15.csv"], None)

    def test_observation_has_exact_case_mappings(self):
        self.assertEqual(oracle.OBSERVATIONS, {
            "two-regular": (("result000.00.csv", b"id,name\n10,alpha\n"), ("result001.00.csv", b"id,name\n20,beta\n")),
            "two-regular-swapped": (("result000.00.csv", b"id,name\n20,beta\n"), ("result001.00.csv", b"id,name\n10,alpha\n")),
            "regular-and-directory": (("result000.00.csv", b"id,name\n10,alpha\n"),),
        })
        self.assertEqual(oracle.STDOUT_PROJECTIONS, {
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
        })

    def test_rejects_checksum_mismatch_before_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            artifact = Path(directory) / "wrong.jar"; artifact.write_bytes(b"wrong")
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                oracle.reference_bytes({"EMBURK_REFERENCE_JAR": str(artifact)})

    def test_snapshot_is_pinned_and_independent_from_source(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(oracle, "EXPECTED_JAR_SHA256", oracle.sha256(b"pinned")):
            root, source = Path(directory) / "root", Path(directory) / "source.jar"
            root.mkdir(); source.write_bytes(b"pinned")
            snapshot = oracle.snapshot_reference(oracle.reference_bytes({"EMBURK_REFERENCE_JAR": str(source)}), root)
            source.write_bytes(b"changed")
            self.assertEqual(snapshot.read_bytes(), b"pinned")

    def test_child_environment_is_allowlisted(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = oracle.jvm_environment(Path(directory), "/java-home")
            self.assertEqual(set(environment), {"PATH", "JAVA_HOME", "EMBULK_HOME", "HOME", "TMPDIR"})
            self.assertNotIn("T0014_SECRET_SENTINEL", environment)

    def test_normal_exit_descendant_cannot_mutate_evidence_after_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "late-write"
            child = "import pathlib,sys,time; time.sleep(0.4); pathlib.Path(sys.argv[1]).write_text('late')"
            parent = "import subprocess,sys; subprocess.Popen([sys.executable, '-c', sys.argv[1], sys.argv[2]])"
            process = subprocess.Popen(
                [sys.executable, "-c", parent, child, str(marker)], start_new_session=True
            )
            exit_code, timed_out = oracle.wait_and_terminate_process_group(process)
            time.sleep(0.6)
            self.assertEqual(exit_code, 0)
            self.assertFalse(timed_out)
            self.assertFalse(marker.exists())

    def test_interrupted_wait_still_terminates_descendant_process_group(self):
        with tempfile.TemporaryDirectory() as directory:
            marker, ready = Path(directory) / "late-write", Path(directory) / "ready"
            child = "import pathlib,sys,time; time.sleep(0.4); pathlib.Path(sys.argv[1]).write_text('late')"
            parent = (
                "import pathlib,subprocess,sys,time; "
                "subprocess.Popen([sys.executable, '-c', sys.argv[1], sys.argv[2]]); "
                "pathlib.Path(sys.argv[3]).write_text('ready'); time.sleep(5)"
            )
            process = subprocess.Popen(
                [sys.executable, "-c", parent, child, str(marker), str(ready)],
                start_new_session=True,
            )
            for _ in range(100):
                if ready.exists():
                    break
                time.sleep(0.01)
            self.assertTrue(ready.exists())

            class InterruptedWait:
                pid = process.pid

                @staticmethod
                def wait(timeout=None):
                    raise KeyboardInterrupt

            with self.assertRaises(KeyboardInterrupt):
                oracle.wait_and_terminate_process_group(InterruptedWait())
            process.wait(timeout=2)
            time.sleep(0.6)
            self.assertFalse(marker.exists())

    def test_manifest_rejects_changed_input_config_output_and_exit(self):
        for changed in ("input.10.csv", "config.yml", "output/result.csv", "exit.txt"):
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as directory:
                path, _ = self.valid_case(directory)
                target = Path(directory) / changed
                target.write_bytes(b"changed\n" if changed != "exit.txt" else b"1\n")
                with self.assertRaises(ValueError): oracle.validate_case_manifest(path)

    def test_manifest_rejects_extra_or_missing_and_symlink_entries(self):
        with tempfile.TemporaryDirectory() as directory:
            path, _ = self.valid_case(directory)
            (Path(directory) / "input.extra.csv").write_bytes(b"x")
            with self.assertRaises(ValueError): oracle.validate_case_manifest(path)
        with tempfile.TemporaryDirectory() as directory:
            path, _ = self.valid_case(directory)
            (Path(directory) / "input.20.csv").unlink()
            with self.assertRaises(ValueError): oracle.validate_case_manifest(path)
        with tempfile.TemporaryDirectory() as directory:
            path, _ = self.valid_case(directory)
            (Path(directory) / "output" / "link.csv").symlink_to(Path(directory) / "output" / "result.csv")
            with self.assertRaises(ValueError): oracle.validate_case_manifest(path)
        with tempfile.TemporaryDirectory() as directory:
            path, _ = self.valid_case(directory)
            (Path(directory) / "unexpected.txt").write_bytes(b"unexpected")
            with self.assertRaisesRegex(ValueError, "case tree"):
                oracle.validate_case_manifest(path)

    def test_manifest_rejects_path_escape_and_malformed_structure(self):
        with tempfile.TemporaryDirectory() as directory:
            path, value = self.valid_case(directory)
            value["config"]["name"] = "../outside.yml"
            path.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(ValueError): oracle.validate_case_manifest(path)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"; path.write_text("{}", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "structure"): oracle.validate_case_manifest(path)

    def test_observation_rejects_exit_timeout_stderr_and_output_mutation(self):
        with tempfile.TemporaryDirectory() as directory:
            path, value = self.valid_case(directory)
            oracle.validate_observation(value, path)
            for field, changed in (("exit", 1), ("timed_out", True)):
                altered = json.loads(json.dumps(value)); altered["process"][field] = changed
                with self.subTest(field=field), self.assertRaises(ValueError): oracle.validate_observation(altered, path)
            (Path(directory) / "stderr.log").write_bytes(b"unexpected\n")
            with self.assertRaises(ValueError): oracle.validate_observation(value, path)
        with tempfile.TemporaryDirectory() as directory:
            path, value = self.valid_case(directory)
            (Path(directory) / "output" / "result000.00.csv").write_bytes(b"changed\n")
            with self.assertRaises(ValueError): oracle.validate_observation(value, path)

    def test_observation_rejects_missing_or_altered_stdout_projection(self):
        with tempfile.TemporaryDirectory() as directory:
            path, value = self.valid_case(directory)
            oracle.validate_observation(value, path)
            stdout = Path(directory) / "stdout.log"
            stdout.write_bytes(b"timestamped preface\n")
            with self.assertRaises(ValueError): oracle.validate_observation(value, path)
        with tempfile.TemporaryDirectory() as directory:
            path, value = self.valid_case(directory)
            stdout = Path(directory) / "stdout.log"
            stdout.write_text(stdout.read_text().replace("tasks=2", "tasks=9"), encoding="utf-8")
            with self.assertRaises(ValueError): oracle.validate_observation(value, path)

    def test_summary_rejects_missing_extra_and_mixed_run_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); (root / "cases").mkdir()
            entries = []
            for case in oracle.CASES:
                case_root = root / "cases" / case; case_root.mkdir()
                manifest, _ = self.valid_case(case_root, case)
                entries.append({"case": case, "path": str(manifest.parent.relative_to(root)), "manifest_sha256": oracle.sha256(manifest.read_bytes())})
            summary = root / "manifest.json"
            value = {"run_uuid": "00000000-0000-4000-8000-000000000000", "reference_sha256": oracle.EXPECTED_JAR_SHA256, "cases": entries}
            summary.write_text(json.dumps(value), encoding="utf-8"); oracle.validate_summary(summary)
            value["cases"] = entries[:-1]; summary.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(ValueError): oracle.validate_summary(summary)
            value["cases"] = entries + [entries[-1]]; summary.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(ValueError): oracle.validate_summary(summary)
            value["cases"] = entries
            changed = json.loads((root / entries[0]["path"] / "manifest.json").read_text()); changed["run_uuid"] = "00000000-0000-4000-8000-000000000001"
            altered = root / entries[0]["path"] / "manifest.json"; altered.write_text(json.dumps(changed), encoding="utf-8")
            value["cases"][0]["manifest_sha256"] = oracle.sha256(altered.read_bytes()); summary.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(ValueError): oracle.validate_summary(summary)


if __name__ == "__main__":
    unittest.main()

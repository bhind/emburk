import importlib.util
import json
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = load("t0071_run", ROOT / "tools/t0071-benchmark/run.py")
validator = load("t0071_validate", ROOT / "tools/t0071-benchmark/validate.py")


class BenchmarkTests(unittest.TestCase):
    def test_generators_are_deterministic_and_match_expected_output(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            for generator, records in [(runner.generate_csv, 17), (runner.generate_json, 19)]:
                left = pathlib.Path(first) / generator.__name__
                right = pathlib.Path(second) / generator.__name__
                left.mkdir()
                right.mkdir()
                left_result = generator(left, records)
                right_result = generator(right, records)
                self.assertEqual(
                    {key: value for key, value in left_result.items() if key != "input_path"},
                    {key: value for key, value in right_result.items() if key != "input_path"},
                )

    def test_config_selects_real_paths_kind_and_worker_count(self):
        text = runner.config(pathlib.Path("/tmp/input"), pathlib.Path("/tmp/output"), "csv", 8)
        self.assertIn("max_threads: 8", text)
        self.assertIn("type: csv", text)
        self.assertIn(f"path_prefix: {json.dumps(str(pathlib.Path('/tmp/input').resolve()))}", text)
        text = runner.config(pathlib.Path("/tmp/input"), pathlib.Path("/tmp/output"), "json", 4)
        self.assertIn("max_threads: 4", text)
        self.assertIn("type: json", text)

    def test_parser_rejects_invalid_worker_sets(self):
        for value in ["", "4,8", "1,1", "1,9", "one"]:
            with self.assertRaises(Exception):
                runner.parse_workers(value)

    def test_command_failure_and_output_divergence_are_fatal(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            with self.assertRaises(runner.BenchmarkError):
                runner.execute(["/usr/bin/false"], root, 1)
            output = root / "output"
            output.write_bytes(b"wrong")
            with self.assertRaises(runner.BenchmarkError):
                runner.verify_output(output, {"output_bytes": 5, "output_sha256": "0" * 64})

    def test_validator_accepts_consistent_report_and_rejects_mutations(self):
        result = {
            "samples_seconds": [2.0],
            "median_seconds": 2.0,
            "input_mib_per_second": 0.5,
            "records_per_second": 5.0,
            "speedup_vs_1_worker": 1.0,
        }
        workload = {
            "records": 10,
            "columns": 2,
            "input_bytes": 1024 * 1024,
            "output_bytes": 10,
            "output_sha256": "a" * 64,
            "engines": {"native": {"1": result}},
        }
        report = {
            "schema": runner.SCHEMA,
            "profile": "smoke",
            "generated_at_utc": "2026-09-09T00:00:00+00:00",
            "parameters": {
                "workers": [1],
                "warmups": 0,
                "repeats": 1,
                "timeout_seconds": 1,
                "measurement": "fresh end-to-end process wall time",
            },
            "platform": {
                "system": "test",
                "release": "test",
                "machine": "test",
                "logical_cpus": 1,
                "python": "test",
                "rustc": "test",
                "cargo": "test",
            },
            "native": {
                "source_revision": "a" * 40,
                "source_dirty": False,
                "binary_sha256": "b" * 64,
                "binary_bytes": 1,
            },
            "reference": None,
            "workloads": {
                name: workload | {"native_speedup_vs_embulk_0_11_5": None}
                for name in validator.WORKLOADS
            },
        }
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "report.json"
            path.write_text(json.dumps(report))
            validator.validate(path)
            report["workloads"]["json_to_csv"]["engines"]["native"]["1"]["median_seconds"] = 3
            path.write_text(json.dumps(report))
            with self.assertRaises(validator.ValidationError):
                validator.validate(path)

    def test_smoke_profile_runs_the_release_binary_when_available(self):
        binary = ROOT / "target/release/emburk"
        if not binary.is_file():
            self.skipTest("release binary not built")
        with tempfile.TemporaryDirectory() as directory:
            report = pathlib.Path(directory) / "report.json"
            process = subprocess.run(
                [
                    "python3",
                    str(ROOT / "tools/t0071-benchmark/run.py"),
                    "--binary",
                    str(binary),
                    "--profile",
                    "smoke",
                    "--workers",
                    "1,4,8",
                    "--output",
                    str(report),
                ],
                cwd=ROOT,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            self.assertEqual(process.returncode, 0, process.stderr.decode())
            validator.validate(report)


if __name__ == "__main__":
    unittest.main()

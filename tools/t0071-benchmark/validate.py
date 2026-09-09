#!/usr/bin/env python3
"""Strictly validate a T-0071 benchmark report."""

from __future__ import annotations

import json
import math
import pathlib
import statistics
import sys


SCHEMA = "emburk-benchmark-v1"
WORKLOADS = {"quoted_csv_to_csv", "json_to_csv"}


class ValidationError(RuntimeError):
    """Raised when report evidence is malformed or internally inconsistent."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def positive_number(value: object, field: str) -> float:
    require(isinstance(value, (int, float)) and not isinstance(value, bool), f"{field} must be numeric")
    result = float(value)
    require(math.isfinite(result) and result > 0, f"{field} must be finite and positive")
    return result


def digest(value: object, field: str, length: int = 64) -> None:
    require(
        isinstance(value, str)
        and len(value) == length
        and all(character in "0123456789abcdef" for character in value),
        f"invalid {field}",
    )


def validate(path: pathlib.Path) -> dict[str, object]:
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValidationError(f"cannot read report: {error}") from error
    require(isinstance(report, dict), "report must be an object")
    require(report.get("schema") == SCHEMA, "unsupported report schema")
    require(report.get("profile") in {"smoke", "evidence"}, "invalid profile")
    require(isinstance(report.get("generated_at_utc"), str), "missing generation time")
    parameters = report.get("parameters")
    require(isinstance(parameters, dict), "missing parameters")
    workers = parameters.get("workers")
    require(isinstance(workers, list) and workers and workers[0] == 1, "workers must start with 1")
    require(
        all(isinstance(worker, int) and not isinstance(worker, bool) and 1 <= worker <= 8 for worker in workers),
        "invalid worker",
    )
    require(len(set(workers)) == len(workers), "workers must be unique")
    repeats = parameters.get("repeats")
    require(isinstance(repeats, int) and repeats > 0, "repeats must be positive")
    require(
        isinstance(parameters.get("warmups"), int) and parameters["warmups"] >= 0,
        "warmups must not be negative",
    )
    positive_number(parameters.get("timeout_seconds"), "timeout")
    require(
        parameters.get("measurement") == "fresh end-to-end process wall time",
        "measurement scope differs",
    )
    platform = report.get("platform")
    require(isinstance(platform, dict), "missing platform")
    for field in ["system", "release", "machine", "python", "rustc", "cargo"]:
        require(isinstance(platform.get(field), str) and platform[field], f"missing platform {field}")
    require(
        isinstance(platform.get("logical_cpus"), int) and platform["logical_cpus"] > 0,
        "invalid logical CPU count",
    )
    native = report.get("native")
    require(isinstance(native, dict), "missing native identity")
    digest(native.get("binary_sha256"), "native binary digest")
    digest(native.get("source_revision"), "source revision", 40)
    require(isinstance(native.get("source_dirty"), bool), "missing source dirty state")
    require(isinstance(native.get("binary_bytes"), int) and native["binary_bytes"] > 0, "invalid binary size")
    reference_identity = report.get("reference")
    if reference_identity is not None:
        require(isinstance(reference_identity, dict), "reference must be an object")
        require(reference_identity.get("version") == "0.11.5", "reference version differs")
        digest(reference_identity.get("jar_sha256"), "reference JAR digest")
        require(isinstance(reference_identity.get("java"), str), "missing Java version")
    workloads = report.get("workloads")
    require(isinstance(workloads, dict) and set(workloads) == WORKLOADS, "workload set differs")
    for workload_name, workload in workloads.items():
        require(isinstance(workload, dict), f"{workload_name} must be an object")
        for field in ["records", "columns", "input_bytes", "output_bytes"]:
            require(isinstance(workload.get(field), int) and workload[field] > 0, f"invalid {workload_name}.{field}")
        digest(workload.get("output_sha256"), f"{workload_name} output digest")
        engines = workload.get("engines")
        require(isinstance(engines, dict) and "native" in engines, f"missing {workload_name} native results")
        expected_engines = {"native"} | ({"embulk-0.11.5"} if report.get("reference") else set())
        require(set(engines) == expected_engines, f"unexpected {workload_name} engines")
        for engine_name, engine in engines.items():
            require(isinstance(engine, dict), f"invalid {workload_name}.{engine_name}")
            require(set(engine) == {str(worker) for worker in workers}, "worker result set differs")
            baseline = None
            for worker in workers:
                result = engine[str(worker)]
                require(isinstance(result, dict), "worker result must be an object")
                samples = result.get("samples_seconds")
                require(isinstance(samples, list) and len(samples) == repeats, "sample count differs")
                numeric_samples = [positive_number(value, "sample") for value in samples]
                median = positive_number(result.get("median_seconds"), "median")
                require(
                    math.isclose(median, statistics.median(numeric_samples), rel_tol=1e-12),
                    "median differs",
                )
                throughput = positive_number(result.get("input_mib_per_second"), "throughput")
                calculated = workload["input_bytes"] / (1024 * 1024) / median
                require(math.isclose(throughput, calculated, rel_tol=1e-12), "throughput differs")
                records_per_second = positive_number(
                    result.get("records_per_second"), "records per second"
                )
                require(
                    math.isclose(records_per_second, workload["records"] / median, rel_tol=1e-12),
                    "record throughput differs",
                )
                if baseline is None:
                    baseline = median
                speedup = positive_number(result.get("speedup_vs_1_worker"), "speedup")
                require(math.isclose(speedup, baseline / median, rel_tol=1e-12), "speedup differs")
        comparisons = workload.get("native_speedup_vs_embulk_0_11_5")
        if reference_identity is None:
            require(comparisons is None, "unexpected reference comparison")
        else:
            require(isinstance(comparisons, dict), "missing reference comparison")
            require(set(comparisons) == {str(worker) for worker in workers}, "comparison workers differ")
            for worker in workers:
                actual = positive_number(comparisons[str(worker)], "reference comparison")
                expected = engines["embulk-0.11.5"][str(worker)]["median_seconds"] / engines["native"][str(worker)]["median_seconds"]
                require(math.isclose(actual, expected, rel_tol=1e-12), "reference comparison differs")
    return report


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("Usage: validate.py REPORT", file=sys.stderr)
        return 2
    try:
        report = validate(pathlib.Path(argv[0]))
    except ValidationError as error:
        print(f"VALIDATION_ERROR|{error}", file=sys.stderr)
        return 1
    print(
        f"VALID|{report['schema']}|{report['profile']}|"
        f"{','.join(str(worker) for worker in report['parameters']['workers'])}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

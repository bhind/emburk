#!/usr/bin/env python3
"""Generate and run deterministic Emburk File-to-File benchmarks."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import platform
import shutil
import statistics
import subprocess
import sys
import tempfile
import time


SCHEMA = "emburk-benchmark-v1"
PINNED_EMBULK_SHA256 = (
    "e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47"
)
PROFILES = {
    "smoke": {"csv_records": 2_000, "json_records": 2_500, "warmups": 0, "repeats": 1},
    "evidence": {
        "csv_records": 120_000,
        "json_records": 150_000,
        "warmups": 1,
        "repeats": 3,
    },
}


class BenchmarkError(RuntimeError):
    """Raised when a benchmark command or correctness gate fails."""


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def yaml_string(value: pathlib.Path) -> str:
    return json.dumps(str(value.resolve()))


def config(input_path: pathlib.Path, output_prefix: pathlib.Path, kind: str, workers: int) -> str:
    columns = 16 if kind == "csv" else 8
    parser = (
        "    type: csv\n"
        "    charset: UTF-8\n"
        "    newline: LF\n"
        "    delimiter: ','\n"
        "    quote: '\"'\n"
        "    escape: '\"'\n"
        "    skip_header_lines: 1\n"
        if kind == "csv"
        else "    type: json\n"
    )
    schema = "    - {name: c0, type: long}\n" + "".join(
        f"    - {{name: c{index}, type: string}}\n" for index in range(1, columns)
    )
    return (
        "in:\n"
        "  type: file\n"
        f"  path_prefix: {yaml_string(input_path)}\n"
        "  parser:\n"
        f"{parser}"
        "    columns:\n"
        f"{schema}"
        "out:\n"
        "  type: file\n"
        f"  path_prefix: {yaml_string(output_prefix)}\n"
        "  file_ext: csv\n"
        "  formatter:\n"
        "    type: csv\n"
        "    charset: UTF-8\n"
        "    newline: LF\n"
        "    delimiter: ','\n"
        "    quote: '\"'\n"
        "    escape: '\"'\n"
        "    header_line: true\n"
        "    quote_policy: MINIMAL\n"
        "exec:\n"
        f"  max_threads: {workers}\n"
        "  min_output_tasks: 1\n"
    )


def csv_field(value: str) -> str:
    if not value or any(character in value for character in ',"\n\r'):
        return '"' + value.replace('"', '""') + '"'
    return value


def csv_row(values: list[str]) -> str:
    return ",".join(csv_field(value) for value in values) + "\n"


def generate_csv(directory: pathlib.Path, records: int) -> dict[str, object]:
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "input.csv"
    columns = 16
    with path.open("w", encoding="utf-8", newline="") as output:
        output.write(csv_row([f"c{index}" for index in range(columns)]))
        for record in range(records):
            output.write(
                csv_row(
                    [str(record)]
                    + [
                        f'value-{record:08d}-{index}, quote "{record % 97}"'
                        for index in range(1, columns)
                    ]
                )
            )
    return expected(path, path, records, columns)


def generate_json(directory: pathlib.Path, records: int) -> dict[str, object]:
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "input.json"
    expected_path = directory / "expected.csv"
    columns = 8
    with path.open("w", encoding="utf-8", newline="") as source, expected_path.open(
        "w", encoding="utf-8", newline=""
    ) as output:
        output.write(csv_row([f"c{index}" for index in range(columns)]))
        for record in range(records):
            values = [str(record)] + [
                f'value-{record:08d}-{index}, quote "{record % 97}"'
                for index in range(1, columns)
            ]
            item = {f"c{index}": int(values[index]) if index == 0 else values[index] for index in range(columns)}
            source.write(json.dumps(item, ensure_ascii=False, separators=(",", ":")) + "\n")
            output.write(csv_row(values))
    result = expected(path, expected_path, records, columns)
    expected_path.unlink()
    return result


def expected(
    input_path: pathlib.Path, expected_path: pathlib.Path, records: int, columns: int
) -> dict[str, object]:
    return {
        "input_path": input_path,
        "records": records,
        "columns": columns,
        "input_bytes": input_path.stat().st_size,
        "output_bytes": expected_path.stat().st_size,
        "output_sha256": sha256(expected_path),
    }


def execute(command: list[str], directory: pathlib.Path, timeout: float) -> float:
    started = time.perf_counter()
    process = subprocess.run(
        command,
        cwd=directory,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )
    elapsed = time.perf_counter() - started
    if process.returncode != 0:
        stderr = process.stderr.decode("utf-8", errors="replace")[-4000:]
        raise BenchmarkError(f"command exited {process.returncode}: {command!r}\n{stderr}")
    return elapsed


def verify_output(path: pathlib.Path, workload: dict[str, object]) -> None:
    if not path.is_file():
        raise BenchmarkError(f"command did not produce {path}")
    actual_size = path.stat().st_size
    actual_digest = sha256(path)
    if actual_size != workload["output_bytes"] or actual_digest != workload["output_sha256"]:
        raise BenchmarkError(
            f"output divergence: size={actual_size}, sha256={actual_digest}, "
            f"expected_size={workload['output_bytes']}, "
            f"expected_sha256={workload['output_sha256']}"
        )


def native_command(binary: pathlib.Path, config_path: pathlib.Path) -> list[str]:
    return [str(binary), "run", str(config_path)]


def reference_command(
    java: pathlib.Path,
    jar: pathlib.Path,
    config_path: pathlib.Path,
    run_directory: pathlib.Path,
) -> list[str]:
    home = run_directory / "home"
    temporary = run_directory / "tmp"
    home.mkdir()
    temporary.mkdir()
    return [
        str(java),
        f"-Duser.home={home}",
        f"-Djava.io.tmpdir={temporary}",
        "-jar",
        str(jar),
        "-X",
        f"embulk_home={home}",
        "run",
        str(config_path),
    ]


def run_once(
    root: pathlib.Path,
    engine: str,
    kind: str,
    workload: dict[str, object],
    workers: int,
    sequence: str,
    binary: pathlib.Path,
    java: pathlib.Path | None,
    jar: pathlib.Path | None,
    timeout: float,
) -> float:
    run_directory = root / "runs" / f"{engine}-{kind}-w{workers}-{sequence}"
    output_directory = run_directory / "output"
    output_directory.mkdir(parents=True)
    output_prefix = output_directory / "result"
    config_path = run_directory / "config.yml"
    config_path.write_text(
        config(pathlib.Path(workload["input_path"]), output_prefix, kind, workers),
        encoding="utf-8",
    )
    if engine == "native":
        command = native_command(binary, config_path)
    else:
        assert java is not None and jar is not None
        command = reference_command(java, jar, config_path, run_directory)
    elapsed = execute(command, run_directory, timeout)
    verify_output(output_directory / "result000.00.csv", workload)
    shutil.rmtree(run_directory)
    return elapsed


def measurements(
    root: pathlib.Path,
    engine: str,
    kind: str,
    workload: dict[str, object],
    workers: list[int],
    warmups: int,
    repeats: int,
    binary: pathlib.Path,
    java: pathlib.Path | None,
    jar: pathlib.Path | None,
    timeout: float,
) -> dict[str, object]:
    samples: dict[int, list[float]] = {worker: [] for worker in workers}
    for warmup in range(warmups):
        for worker in workers:
            run_once(
                root, engine, kind, workload, worker, f"warmup{warmup}", binary, java, jar, timeout
            )
    for repeat in range(repeats):
        order = workers if repeat % 2 == 0 else list(reversed(workers))
        for worker in order:
            samples[worker].append(
                run_once(
                    root, engine, kind, workload, worker, f"sample{repeat}", binary, java, jar, timeout
                )
            )
    baseline = statistics.median(samples[workers[0]])
    result: dict[str, object] = {}
    for worker in workers:
        median = statistics.median(samples[worker])
        mib = int(workload["input_bytes"]) / (1024 * 1024)
        result[str(worker)] = {
            "samples_seconds": samples[worker],
            "median_seconds": median,
            "input_mib_per_second": mib / median,
            "records_per_second": int(workload["records"]) / median,
            "speedup_vs_1_worker": baseline / median,
        }
    return result


def tool_version(command: list[str]) -> str:
    try:
        return subprocess.check_output(command, text=True, stderr=subprocess.STDOUT).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unavailable"


def source_revision(repository: pathlib.Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=repository, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def source_dirty(repository: pathlib.Path) -> bool | None:
    try:
        status = subprocess.check_output(
            ["git", "status", "--porcelain", "--untracked-files=no"],
            cwd=repository,
            text=True,
            stderr=subprocess.DEVNULL,
        )
        return bool(status.strip())
    except (OSError, subprocess.CalledProcessError):
        return None


def parse_workers(value: str) -> list[int]:
    try:
        workers = [int(item) for item in value.split(",")]
    except ValueError as error:
        raise argparse.ArgumentTypeError("workers must be comma-separated integers") from error
    if not workers or workers[0] != 1 or len(set(workers)) != len(workers):
        raise argparse.ArgumentTypeError("workers must be unique and start with 1")
    if any(worker < 1 or worker > 8 for worker in workers):
        raise argparse.ArgumentTypeError("workers must be between 1 and 8")
    return workers


def arguments(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=pathlib.Path, default=pathlib.Path("target/release/emburk"))
    parser.add_argument("--profile", choices=sorted(PROFILES), default="smoke")
    parser.add_argument("--workers", type=parse_workers, default=parse_workers("1,4,8"))
    parser.add_argument("--csv-records", type=int)
    parser.add_argument("--json-records", type=int)
    parser.add_argument("--warmups", type=int)
    parser.add_argument("--repeats", type=int)
    parser.add_argument("--timeout", type=float, default=180.0)
    parser.add_argument("--reference-jar", type=pathlib.Path)
    parser.add_argument("--java", type=pathlib.Path, default=pathlib.Path("java"))
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("target/t0071-benchmark.json"))
    parser.add_argument("--work-dir", type=pathlib.Path)
    return parser.parse_args(argv)


def require_positive(name: str, value: int) -> int:
    if value < 1:
        raise BenchmarkError(f"{name} must be positive")
    return value


def main(argv: list[str] | None = None) -> int:
    args = arguments(sys.argv[1:] if argv is None else argv)
    repository = pathlib.Path(__file__).resolve().parents[2]
    binary = args.binary.resolve()
    if not binary.is_file():
        raise BenchmarkError(f"release binary does not exist: {binary}")
    profile = PROFILES[args.profile]
    csv_records = require_positive("csv-records", args.csv_records or profile["csv_records"])
    json_records = require_positive("json-records", args.json_records or profile["json_records"])
    warmups = args.warmups if args.warmups is not None else profile["warmups"]
    repeats = args.repeats if args.repeats is not None else profile["repeats"]
    if warmups < 0:
        raise BenchmarkError("warmups must not be negative")
    require_positive("repeats", repeats)
    jar = args.reference_jar.resolve() if args.reference_jar else None
    java = args.java.resolve() if args.java.parent != pathlib.Path(".") else args.java
    if jar is not None:
        if not jar.is_file():
            raise BenchmarkError(f"reference JAR does not exist: {jar}")
        if sha256(jar) != PINNED_EMBULK_SHA256:
            raise BenchmarkError("reference JAR does not match pinned Embulk 0.11.5 SHA-256")
        if tool_version([str(java), "-version"]) == "unavailable":
            raise BenchmarkError(f"Java is not executable: {java}")

    temporary = None
    if args.work_dir:
        root = args.work_dir.resolve()
        root.mkdir(parents=True, exist_ok=False)
    else:
        temporary = tempfile.TemporaryDirectory(prefix="emburk-t0071-")
        root = pathlib.Path(temporary.name)
    try:
        workloads = {
            "quoted_csv_to_csv": generate_csv(root / "csv", csv_records),
            "json_to_csv": generate_json(root / "json", json_records),
        }
        engines = ["native"] + (["embulk-0.11.5"] if jar is not None else [])
        report: dict[str, object] = {
            "schema": SCHEMA,
            "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
            "profile": args.profile,
            "parameters": {
                "workers": args.workers,
                "warmups": warmups,
                "repeats": repeats,
                "timeout_seconds": args.timeout,
                "measurement": "fresh end-to-end process wall time",
            },
            "platform": {
                "system": platform.system(),
                "release": platform.release(),
                "machine": platform.machine(),
                "logical_cpus": os.cpu_count(),
                "python": platform.python_version(),
                "rustc": tool_version(["rustc", "--version"]),
                "cargo": tool_version(["cargo", "--version"]),
            },
            "native": {
                "source_revision": source_revision(repository),
                "source_dirty": source_dirty(repository),
                "binary_sha256": sha256(binary),
                "binary_bytes": binary.stat().st_size,
            },
            "reference": (
                {"version": "0.11.5", "jar_sha256": sha256(jar), "java": tool_version([str(java), "-version"])}
                if jar is not None
                else None
            ),
            "workloads": {},
        }
        for kind, workload in [("csv", workloads["quoted_csv_to_csv"]), ("json", workloads["json_to_csv"])]:
            name = "quoted_csv_to_csv" if kind == "csv" else "json_to_csv"
            entry = {key: value for key, value in workload.items() if key != "input_path"}
            entry["engines"] = {}
            for engine in engines:
                entry["engines"][engine] = measurements(
                    root,
                    engine,
                    kind,
                    workload,
                    args.workers,
                    warmups,
                    repeats,
                    binary,
                    java,
                    jar,
                    args.timeout,
                )
            entry["native_speedup_vs_embulk_0_11_5"] = (
                {
                    str(worker): entry["engines"]["embulk-0.11.5"][str(worker)][
                        "median_seconds"
                    ]
                    / entry["engines"]["native"][str(worker)]["median_seconds"]
                    for worker in args.workers
                }
                if jar is not None
                else None
            )
            report["workloads"][name] = entry
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"T-0071 benchmark: {args.profile}; report={args.output}")
        for name, workload in report["workloads"].items():
            native = workload["engines"]["native"]
            values = ", ".join(
                f"{worker}w={native[str(worker)]['input_mib_per_second']:.1f} MiB/s "
                f"({native[str(worker)]['speedup_vs_1_worker']:.2f}x)"
                for worker in args.workers
            )
            print(f"  {name}: {values}")
            if jar is not None:
                reference = workload["engines"]["embulk-0.11.5"]
                comparisons = ", ".join(
                    f"{worker}w={workload['native_speedup_vs_embulk_0_11_5'][str(worker)]:.2f}x"
                    for worker in args.workers
                )
                print(f"    native throughput vs Embulk 0.11.5: {comparisons}")
    finally:
        if temporary is not None:
            temporary.cleanup()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (BenchmarkError, subprocess.TimeoutExpired) as error:
        print(f"benchmark failed: {error}", file=sys.stderr)
        raise SystemExit(1)

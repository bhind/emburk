#!/usr/bin/env bash
set -euo pipefail
cargo build --locked -p emburk-cli
PYTHONDONTWRITEBYTECODE=1 python3 tests/t0037_guess_pipeline.py

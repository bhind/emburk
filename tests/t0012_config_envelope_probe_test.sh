#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd); runner="$root/tools/t0012-config-envelope-probe/run.sh"
if [[ $# != 1 || $1 != --capture ]]; then
  printf '%s\n' 'Stage B acceptance is unavailable pending raw review; use --capture for Stage A only.' >&2
  exit 2
fi
bash -n "$runner"
"$runner" --capture
echo 'T0012/S12 Stage A captured; Stage B validation is intentionally unavailable pending raw review.'

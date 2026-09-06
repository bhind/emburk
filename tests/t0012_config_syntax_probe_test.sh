#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner="$root/tools/t0012-config-syntax-probe/run.sh"

if [[ $# != 1 || $1 != --capture ]]; then
  printf '%s\n' 'Stage A only: usage: --capture' >&2
  exit 2
fi

bash -n "$runner"
"$runner" --capture

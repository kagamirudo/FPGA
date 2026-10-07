#!/usr/bin/env bash
# Package svd_array_axis32 as Vivado IP under ip_repo/
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v vivado >/dev/null 2>&1; then
  echo "error: 'vivado' not on PATH. Source settings64.sh first." >&2
  exit 1
fi

echo "== package_svd_ip  ($(vivado -version | head -1))"
vivado -mode batch -source "$ROOT/common/tcl/package_svd_ip.tcl"
echo "== done: $ROOT/ip_repo/svd_array_axis32"

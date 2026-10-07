#!/usr/bin/env bash
#-------------------------------------------------------------------------------
# Package SVD IP, build PS+DMA+SVD BD, implement, export XSA for Vitis.
#
# Usage:
#   ./scripts/build_svd_system.sh              # full bitgen + XSA
#   ./scripts/build_svd_system.sh --bd-only    # stop after BD (no impl)
#   ./scripts/build_svd_system.sh --fclk 25
#-------------------------------------------------------------------------------
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SKIP_IMPL=0
FCLK=25

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bd-only) SKIP_IMPL=1; shift ;;
    --fclk) FCLK="$2"; shift 2 ;;
    -h|--help)
      awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
      exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if ! command -v vivado >/dev/null 2>&1; then
  echo "error: 'vivado' not on PATH. Source settings64.sh first." >&2
  exit 1
fi

echo "== build_svd_system  fclk=${FCLK}MHz  skip_impl=$SKIP_IMPL"
"$ROOT/scripts/package_svd_ip.sh"
vivado -mode batch -source "$ROOT/common/tcl/create_svd_bd.tcl" \
  -tclargs "skip_impl=$SKIP_IMPL" "fclk_mhz=$FCLK"

if [[ "$SKIP_IMPL" -eq 0 ]]; then
  echo "== XSA: $ROOT/build/svd_system/svd_system.xsa"
fi

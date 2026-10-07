#!/usr/bin/env bash
#-------------------------------------------------------------------------------
# scripts/vivado_setup.sh — open or recreate thesis Vivado projects
#
# Usage:
#   ./scripts/vivado_setup.sh              # open both (prefer existing .xpr)
#   ./scripts/vivado_setup.sh svd          # SVD only
#   ./scripts/vivado_setup.sh lu           # LU only
#   ./scripts/vivado_setup.sh svd --force  # recreate SVD .xpr from VHDL
#   ./scripts/vivado_setup.sh svd --gui    # create/open then leave GUI up
#-------------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET="all"
FORCE=0
GUI=0

usage() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    lu|svd|all) TARGET="$1"; shift ;;
    --force|-f) FORCE=1; shift ;;
    --gui|-g)   GUI=1; shift ;;
    -h|--help)  usage 0 ;;
    *) echo "Unknown arg: $1"; usage 1 ;;
  esac
done

if ! command -v vivado >/dev/null 2>&1; then
  echo "error: 'vivado' not on PATH. Source settings64.sh first."
  exit 1
fi

TCL="$ROOT/common/tcl/create_project.tcl"
ARGS=("target=$TARGET" "force=$FORCE")

echo "== FPGA vivado_setup  ($(vivado -version | head -1))"
echo "   target=$TARGET force=$FORCE gui=$GUI"

if [[ "$GUI" -eq 1 ]]; then
  # For a single target, open the resulting .xpr in GUI after batch create
  vivado -mode batch -source "$TCL" -tclargs "${ARGS[@]}"
  if [[ "$TARGET" == "lu" ]]; then
    vivado "$ROOT/kung_lu_decom/kung_lu_decom.xpr"
  elif [[ "$TARGET" == "svd" ]]; then
    vivado "$ROOT/kung_svd/kung_svd.xpr"
  else
    echo "Opened batch create for all. Pick a project:"
    echo "  vivado kung_lu_decom/kung_lu_decom.xpr"
    echo "  vivado kung_svd/kung_svd.xpr"
  fi
else
  vivado -mode batch -source "$TCL" -tclargs "${ARGS[@]}"
fi

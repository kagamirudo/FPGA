#!/usr/bin/env bash
# Simulate svd_jacobi_blv (BLV grid, N=4 for session 3).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/sim_blv"
SRC="$ROOT/kung_svd/kung_svd.srcs/sources_1/new"
SIM="$ROOT/kung_svd/kung_svd.srcs/sim_1/new"

QUIET=0
if [[ "${1:-}" == "-q" ]]; then QUIET=1; fi

mkdir -p "$BUILD"
cd "$BUILD"
rm -rf work

# Regenerate N=4 fixtures and copy under the BLV-specific name so the
# serializer tb (svd_input.mem) is not disturbed.
"$ROOT/.venv/bin/python" "$ROOT/tools/svd_golden_ref.py" --n 4 > /dev/null
cp "$SIM/svd_input.mem" blv_input.mem
cp "$SIM/svd_sigma.mem" blv_sigma.mem

VHDL_SRCS=(
  "$SRC/svd_pkg.vhd"
  "$SRC/svd_angle_cordic.vhd"
  "$SRC/svd_gram.vhd"
  "$SRC/svd_pair_pipeline.vhd"
  "$SRC/svd_jacobi_blv.vhd"
  "$SIM/tb_jacobi_blv.vhd"
)

echo "==> blv-tb nvc analyze"
nvc --std=2008 -a "${VHDL_SRCS[@]}"
echo "==> blv-tb nvc elaborate"
nvc --std=2008 -e tb_jacobi_blv
echo "==> blv-tb nvc run (stop at 100us)"
LOG="$BUILD/sim_blv.log"
nvc --std=2008 -r tb_jacobi_blv --stop-time=100us > "$LOG" 2>&1 || true

if [[ $QUIET -eq 1 ]]; then
  grep -E "svd_jacobi_blv: |sigma\[|CYCLES |BLV CHECK" "$LOG" | sed 's/^\*\* Note: //' || true
else
  cat "$LOG"
fi

if grep -q "BLV CHECK: PASS" "$LOG"; then
  echo "==> BLV CHECK: PASS"
  exit 0
fi
echo "==> BLV CHECK: FAIL (see $LOG)"
exit 1

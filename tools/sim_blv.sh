#!/usr/bin/env bash
# Simulate svd_jacobi_blv at N in {4, 8, 16}.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/sim_blv"
SRC="$ROOT/kung_svd/kung_svd.srcs/sources_1/new"
SIM="$ROOT/kung_svd/kung_svd.srcs/sim_1/new"

N=4
QUIET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) N="$2"; shift 2 ;;
    -q) QUIET=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$BUILD"
cd "$BUILD"
rm -rf work

# Regenerate schedule package (idempotent — no-op if unchanged).
"$ROOT/.venv/bin/python" "$ROOT/tools/gen_blv_schedule_pkg.py" > /dev/null

# Regenerate fixtures at the requested N.
"$ROOT/.venv/bin/python" "$ROOT/tools/svd_golden_ref.py" --n "$N" > /dev/null
cp "$SIM/svd_input.mem" blv_input.mem
cp "$SIM/svd_sigma.mem" blv_sigma.mem

VHDL_SRCS=(
  "$SRC/svd_pkg.vhd"
  "$SRC/svd_angle_cordic.vhd"
  "$SRC/svd_gram.vhd"
  "$SRC/svd_pair_pipeline.vhd"
  "$SRC/svd_blv_schedule_pkg.vhd"
  "$SRC/svd_jacobi_blv.vhd"
  "$SIM/tb_jacobi_blv.vhd"
)

STOP="100us"
if [[ "$N" -ge 8  ]]; then STOP="500us"; fi
if [[ "$N" -ge 16 ]]; then STOP="5ms";   fi

echo "==> n=$N : nvc analyze"
nvc --std=2008 -a "${VHDL_SRCS[@]}"
echo "==> n=$N : nvc elaborate (-gN=$N)"
nvc --std=2008 -e -gN="$N" tb_jacobi_blv
echo "==> n=$N : nvc run (stop at $STOP)"
LOG="$BUILD/sim_blv_n${N}.log"
nvc --std=2008 -r tb_jacobi_blv --stop-time="$STOP" > "$LOG" 2>&1 || true

if [[ $QUIET -eq 1 ]]; then
  grep -E "svd_jacobi_blv: |sigma\[|CYCLES |BLV CHECK" "$LOG" | sed 's/^\*\* Note: //' || true
else
  cat "$LOG"
fi

if grep -q "BLV CHECK: PASS" "$LOG"; then
  echo "==> n=$N : BLV CHECK: PASS"
  exit 0
fi
echo "==> n=$N : BLV CHECK: FAIL (see $LOG)"
exit 1

#!/usr/bin/env bash
# Simulate the SVD core (through the AXI stream wrapper) with nvc and
# check against the golden reference.
#
# One-time install (macOS, Homebrew):
#   brew install nvc
#
# Usage:
#   tools/sim_svd.sh                   # analyze + elab + run at n=8 (BLV)
#   tools/sim_svd.sh -q                # terse log
#   tools/sim_svd.sh -n 4              # n=4 (regenerates .mem fixtures)
#   tools/sim_svd.sh -n 16 -q          # n=16, terse
#   tools/sim_svd.sh -c serial         # use the single-pair serializer
#                                      # (USE_BLV=false), tol = 2^-10
#   tools/sim_svd.sh -c blv            # explicit BLV grid (default)
#
# Exits non-zero on simulation failure.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/sim"
SRC="$ROOT/kung_svd/kung_svd.srcs/sources_1/new"
SIM="$ROOT/kung_svd/kung_svd.srcs/sim_1/new"

N=8
QUIET=0
CORE="blv"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) N="$2"; shift 2 ;;
    -q) QUIET=1; shift ;;
    -c) CORE="$2"; shift 2 ;;
    *)  echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$CORE" in
  blv)    USE_BLV_FLAG="-gUSE_BLV=true" ;;
  serial) USE_BLV_FLAG="-gUSE_BLV=false" ;;
  *)      echo "unknown core type: $CORE (expected blv or serial)" >&2; exit 2 ;;
esac

mkdir -p "$BUILD"
cd "$BUILD"
rm -rf work

PY="$ROOT/.venv/bin/python"
if [[ ! -x "$PY" ]]; then PY="$(command -v python3)"; fi
"$PY" "$ROOT/tools/gen_blv_schedule_pkg.py" > /dev/null
"$PY" "$ROOT/tools/svd_golden_ref.py" --n "$N" > /dev/null

cp "$SIM/svd_input.mem" .
cp "$SIM/svd_sigma.mem" .

VHDL_SRCS=(
  "$SRC/svd_pkg.vhd"
  "$SRC/svd_pe.vhd"
  "$SRC/svd_angle_cordic.vhd"
  "$SRC/svd_gram.vhd"
  "$SRC/svd_pair_pipeline.vhd"
  "$SRC/svd_blv_schedule_pkg.vhd"
  "$SRC/svd_jacobi_blv.vhd"
  "$SRC/svd_jacobi_top.vhd"
  "$SRC/svd_array_core.vhd"
  "$SRC/svd_axi_stream.vhd"
  "$SRC/svd_array.vhd"
  "$SIM/tb_svd_array.vhd"
)

echo "==> core=$CORE  n=$N : nvc analyze"
nvc --std=2008 -a "${VHDL_SRCS[@]}"

echo "==> core=$CORE  n=$N : nvc elaborate (-gN=$N $USE_BLV_FLAG)"
nvc --std=2008 -e -gN="$N" $USE_BLV_FLAG tb_svd_array

STOP="300us"
if [[ "$N" -ge 12 ]]; then STOP="5ms"; fi

echo "==> core=$CORE  n=$N : nvc run (stop at $STOP)"
LOG="$BUILD/sim_${CORE}_n${N}.log"
nvc --std=2008 -r tb_svd_array --stop-time="$STOP" > "$LOG" 2>&1 || true

if [[ $QUIET -eq 1 ]]; then
  grep -E "svd_jacobi_(top|blv): (start accepted|completed sweep)|sigma\[|CYCLES |SVD CHECK" "$LOG" \
    | sed 's/^\*\* Note: //' || true
else
  cat "$LOG"
fi

if grep -q "SVD CHECK: PASS" "$LOG"; then
  echo "==> core=$CORE  n=$N : SVD CHECK: PASS"
  exit 0
fi
echo "==> core=$CORE  n=$N : SVD CHECK: FAIL (see $LOG)"
exit 1

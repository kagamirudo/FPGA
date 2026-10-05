#!/usr/bin/env bash
# Simulate the SVD core with nvc and check against the golden reference.
#
# One-time install (macOS, Homebrew):
#   brew install nvc
#
# Usage:
#   tools/sim_svd.sh                # analyze + elab + run at n=8, print PASS/FAIL
#   tools/sim_svd.sh -q             # same, suppress VHDL `report` notes
#   tools/sim_svd.sh -n 4           # run at n=4 (regenerates .mem fixtures)
#   tools/sim_svd.sh -n 16 -q       # run at n=16, terse
#
# Exits non-zero on simulation failure. On PASS, prints the SVD_CHECK line.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/sim"
SRC="$ROOT/kung_svd/kung_svd.srcs/sources_1/new"
SIM="$ROOT/kung_svd/kung_svd.srcs/sim_1/new"

N=8
QUIET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) N="$2"; shift 2 ;;
    -q) QUIET=1; shift ;;
    *)  echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$BUILD"
cd "$BUILD"
rm -rf work

# Regenerate .mem fixtures at the requested N.
"$ROOT/.venv/bin/python" "$ROOT/tools/svd_golden_ref.py" --n "$N" > /dev/null

# Copy .mem fixtures next to the simulator CWD so textio relative paths work.
cp "$SIM/svd_input.mem" .
cp "$SIM/svd_sigma.mem" .

VHDL_SRCS=(
  "$SRC/svd_pkg.vhd"
  "$SRC/svd_pe.vhd"
  "$SRC/svd_angle_cordic.vhd"
  "$SRC/svd_gram.vhd"
  "$SRC/svd_jacobi_top.vhd"
  "$SRC/svd_array_core.vhd"
  "$SRC/svd_axi_stream.vhd"
  "$SRC/svd_array.vhd"
  "$SIM/tb_svd_array.vhd"
)

echo "==> n=$N : nvc analyze"
nvc --std=2008 -a "${VHDL_SRCS[@]}"

echo "==> n=$N : nvc elaborate (-gN=$N)"
nvc --std=2008 -e -gN="$N" tb_svd_array

# Cycle budget: scale with N^3. The TB has its own internal timeout.
STOP="300us"
if [[ "$N" -ge 12 ]]; then STOP="5ms"; fi

echo "==> n=$N : nvc run (stop at $STOP)"
LOG="$BUILD/sim_n${N}.log"
nvc --std=2008 -r tb_svd_array --stop-time="$STOP" > "$LOG" 2>&1 || true

if [[ $QUIET -eq 1 ]]; then
  grep -E "svd_jacobi_top: (start accepted|completed sweep)|sigma\[|CYCLES |SVD CHECK" "$LOG" \
    | sed 's/^\*\* Note: //' || true
else
  cat "$LOG"
fi

if grep -q "SVD CHECK: PASS" "$LOG"; then
  echo "==> n=$N : SVD CHECK: PASS"
  exit 0
fi
echo "==> n=$N : SVD CHECK: FAIL (see $LOG)"
exit 1

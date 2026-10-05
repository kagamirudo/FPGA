#!/usr/bin/env bash
# Simulate the SVD core with nvc and check against the golden reference.
#
# One-time install (macOS, Homebrew):
#   brew install nvc
#
# Usage:
#   tools/sim_svd.sh           # analyze + elab + run, print PASS/FAIL
#   tools/sim_svd.sh -q        # same, suppress VHDL `report` notes
#
# Exits non-zero on simulation failure. On PASS, prints the SVD_CHECK line.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/sim"
SRC="$ROOT/kung_svd/kung_svd.srcs/sources_1/new"
SIM="$ROOT/kung_svd/kung_svd.srcs/sim_1/new"

mkdir -p "$BUILD"
cd "$BUILD"
rm -rf work

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

echo "==> nvc --std=2008 -a (analyze)"
nvc --std=2008 -a "${VHDL_SRCS[@]}"

echo "==> nvc --std=2008 -e (elaborate)"
nvc --std=2008 -e tb_svd_array

echo "==> nvc --std=2008 -r (run, stop at 300us)"
LOG="$BUILD/sim.log"
nvc --std=2008 -r tb_svd_array --stop-time=300us > "$LOG" 2>&1 || true

if [[ "${1:-}" == "-q" ]]; then
  grep -E "svd_jacobi_top: (start accepted|completed sweep)|sigma\[|SVD CHECK" "$LOG" \
    | sed 's/^\*\* Note: //' || true
else
  cat "$LOG"
fi

if grep -q "SVD CHECK: PASS" "$LOG"; then
  echo "==> SVD CHECK: PASS"
  exit 0
fi
echo "==> SVD CHECK: FAIL (see $LOG)"
exit 1

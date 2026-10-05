#!/usr/bin/env bash
# Simulate svd_pair_pipeline standalone against the Python golden.
#
# Usage:
#   tools/sim_pair.sh        # full log
#   tools/sim_pair.sh -q     # terse: only row diff lines and PASS/FAIL

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/sim_pair"
SRC="$ROOT/kung_svd/kung_svd.srcs/sources_1/new"
SIM="$ROOT/kung_svd/kung_svd.srcs/sim_1/new"

QUIET=0
if [[ "${1:-}" == "-q" ]]; then QUIET=1; fi

mkdir -p "$BUILD"
cd "$BUILD"
rm -rf work

"$ROOT/.venv/bin/python" "$ROOT/tools/pair_pipeline_golden.py" --rows 8 --seed 42 > /dev/null
cp "$SIM/pair_input.mem"  .
cp "$SIM/pair_output.mem" .

VHDL_SRCS=(
  "$SRC/svd_pkg.vhd"
  "$SRC/svd_angle_cordic.vhd"
  "$SRC/svd_gram.vhd"
  "$SRC/svd_pair_pipeline.vhd"
  "$SIM/tb_pair_pipeline.vhd"
)

echo "==> pair-tb nvc analyze"
nvc --std=2008 -a "${VHDL_SRCS[@]}"
echo "==> pair-tb nvc elaborate"
nvc --std=2008 -e tb_pair_pipeline
echo "==> pair-tb nvc run (stop at 20us)"
LOG="$BUILD/sim_pair.log"
nvc --std=2008 -r tb_pair_pipeline --stop-time=20us > "$LOG" 2>&1 || true

if [[ $QUIET -eq 1 ]]; then
  grep -E "row [0-9]+:|PAIR CHECK" "$LOG" | sed 's/^\*\* Note: //' || true
else
  cat "$LOG"
fi

if grep -q "PAIR CHECK: PASS" "$LOG"; then
  echo "==> PAIR CHECK: PASS"
  exit 0
fi
echo "==> PAIR CHECK: FAIL (see $LOG)"
exit 1

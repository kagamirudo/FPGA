# kung_lu_decom — LU decomposition systolic array (Vivado project)

Kung-style systolic array for 4×4 LU decomposition on a nearest-neighbor
AXI4-Stream PE mesh (VHDL). Companion C-side verification harness is in
[`../kung_lu_support/`](../kung_lu_support/).

## Opening the project

Requires Vivado 2025.1 or newer.

```bash
# Option A: GUI
vivado kung_lu_decom.xpr

# Option B: batch via TCL helper
vivado -mode batch -source run.tcl
```

## File map

```
kung_lu_decom/
├── kung_lu_decom.xpr              # Vivado project file
├── run.tcl                        # Non-interactive flow helper
├── gen_stimulus.py                # Generates stimulus for the testbench
├── kung_lu_decom.srcs/
│   ├── sources_1/new/             # Synthesis sources (VHDL)
│   │   ├── lu_pkg.vhd             # Shared types (data_t, DATA_WIDTH)
│   │   ├── Div_cell.vhd           # Divide cell
│   │   ├── MA_cell.vhd            # Multiply-accumulate cell
│   │   ├── M_cell.vhd             # Multiply cell
│   │   ├── R_cell.vhd             # Register (passthrough) cell
│   │   ├── fixed_div.vhd          # Fixed-point divider used by Div_cell
│   │   └── lu_array4x4.vhd        # Top-level 4×4 PE mesh
│   └── sim_1/new/
│       ├── lu_tb.vhd              # Top-level testbench
│       └── fixed_div_tb.vhd       # Unit test for the divider
```

The Vivado-generated directories (`*.cache/`, `*.hw/`, `*.ip_user_files/`,
`*.runs/`, `*.sim/`, `*.gen/`) are gitignored. Vivado recreates them on
project open or build.

## How it works

The 4×4 array decomposes an input band matrix `A` into `L` (unit lower
triangular) and `U` (upper triangular), streaming the result out
column-by-column. Band-matrix encoding is Kung-Leiserson rate-1/3; see
[`../kung_lu_support/README.md`](../kung_lu_support/README.md) section
"Theory Background" for the full timing-and-order rules.

Correctness is verified in software by `../kung_lu_support/`'s
`test_lu_simulation.c`, which simulates the hardware output stream
(matching the timing/order of `lu_array4x4.vhd`) and asserts
`L * U = A`. Run:

```bash
cd ../kung_lu_support && make run-sim
```

## Status

- Simulation clean on a 4×4 test matrix (hand-chosen, non-pathological).
- Post-place-and-route numbers on Kintex-7 not yet collected (planned
  for weeks 1–3 of the thesis schedule — see
  [`../docs/thesis_proposal.pdf`](../docs/thesis_proposal.pdf)).
- Vitis HLS baseline not yet collected.

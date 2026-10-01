# kung_svd — One-sided Jacobi SVD systolic array (Vivado project)

8×8 one-sided Jacobi SVD prototype on a nearest-neighbor AXI4-Stream PE
mesh (VHDL). The RTL design-level README is in
[`kung_svd.srcs/sources_1/new/README.md`](kung_svd.srcs/sources_1/new/README.md).

> **Status**: compiles and simulates, but the current column-pair
> schedule has three algorithmic deviations from one-sided Jacobi SVD.
> See [`../docs/svd_algorithm_review.md`](../docs/svd_algorithm_review.md)
> for the audit and fix plan **before trusting the numerical output.**

## Opening the project

Requires Vivado 2025.1 or newer.

```bash
# Option A: GUI
vivado kung_svd.xpr

# Option B: batch TCL helpers
vivado -mode batch -source test_compile.tcl   # elaborate only
vivado -mode batch -source test_sim.tcl       # short sim
vivado -mode batch -source run_long_sim.tcl   # full sim
```

## File map

```
kung_svd/
├── kung_svd.xpr                   # Vivado project file
├── test_compile.tcl               # Compile-only flow
├── test_sim.tcl                   # Short-sim flow
├── run_long_sim.tcl               # Full-sim flow
├── kung_svd.srcs/
│   ├── sources_1/new/             # Synthesis sources (VHDL)
│   │   ├── README.md              # Per-module design notes
│   │   ├── svd_pkg.vhd            # Shared types (18-bit Q1.16)
│   │   ├── svd_pe.vhd             # Givens-rotation PE
│   │   ├── cordic_rot.vhd         # Vectoring-mode CORDIC
│   │   ├── jacobi_ctrl.vhd        # Column-pair FSM
│   │   ├── svd_array_core.vhd     # ROWS×COLS mesh + controller
│   │   ├── svd_axi_stream.vhd     # AXI4-Stream wrapper FSM
│   │   └── svd_array.vhd          # Top-level AXI wrapper
│   └── sim_1/new/
│       ├── tb_svd_array.vhd       # Structural testbench
│       ├── svd_input.mem          # Golden-reference Q1.16 input (seed=42)
│       ├── svd_sigma.mem          # Expected singular values (sorted)
│       └── svd_input.summary      # Human-readable float summary
```

The Vivado-generated directories (`*.cache/`, `*.hw/`, `*.ip_user_files/`,
`*.runs/`, `*.sim/`, `*.gen/`, `xsim/`) are gitignored.

## Golden reference

Input matrix and expected singular values live under
`kung_svd.srcs/sim_1/new/` as `.mem` files. Regenerate (and re-verify)
from [`../tools/`](../tools/):

```bash
# From the repo root:
.venv/bin/python tools/svd_golden_ref.py    # regenerate .mem files
.venv/bin/python tools/verify_golden.py     # confirm NumPy agrees → PASS
```

The current testbench streams `svd_input.mem` through the array but does
**not** yet assert against `svd_sigma.mem` — that wiring is the next
testbench change once the RTL algorithmic gaps are fixed.

## Known issues

See [`../docs/svd_algorithm_review.md`](../docs/svd_algorithm_review.md):

1. Both PE operands come from the same matrix element
   ([`svd_array_core.vhd` lines 252-257](kung_svd.srcs/sources_1/new/svd_array_core.vhd#L252-L257))
   → Givens rotation collapses to a scalar scaling.
2. CORDIC is fed row-0 scalars instead of column Gram sums
   ([lines 115-116](kung_svd.srcs/sources_1/new/svd_array_core.vhd#L115-L116))
   → angle is not the Jacobi angle.
3. (c, s) broadcast to every PE
   ([lines 132-137](kung_svd.srcs/sources_1/new/svd_array_core.vhd#L132-L137))
   → whole grid rotates, not just the active column pair.

The algorithm review documents the fix shape for each.

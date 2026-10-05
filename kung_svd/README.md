# kung_svd — One-sided Jacobi SVD systolic array (Vivado project)

8×8 one-sided Jacobi SVD on a nearest-neighbor AXI4-Stream wrapper
(VHDL). The RTL design-level README is in
[`kung_svd.srcs/sources_1/new/README.md`](kung_svd.srcs/sources_1/new/README.md).

> **Status**: numerically verified end-to-end in nvc against the
> NumPy golden reference — all 8 singular values of the seed-42
> Q1.16 test matrix match within ~1.2e-3 after 8 cyclic Jacobi sweeps.
> Reproduce with `../tools/sim_svd.sh -q`. Design rationale and the
> original algorithmic audit are in
> [`../docs/svd_algorithm_review.md`](../docs/svd_algorithm_review.md).

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

## Design

The current `svd_array_core.vhd` is a thin wrapper around
[`svd_jacobi_top.vhd`](kung_svd.srcs/sources_1/new/svd_jacobi_top.vhd),
which orchestrates one-sided Jacobi SVD as:

1. **GRAM** — `svd_gram.vhd` streams rows of the active column pair
   `(p, q)` through 3 MACs to produce α, β, γ, scaled back to Q1.16
   as `(α − β, 2γ)`.
2. **CORDIC** — `svd_angle_cordic.vhd` runs vectoring + halve +
   rotation to produce `(cos θ, sin θ)` with
   `θ = ½ · atan2(2γ, α − β)`.
3. **APPLY** — inline Givens multiplier updates the active column
   pair, one row per clock.
4. Sweep all `C(8, 2) = 28` lexicographic pairs; 8 cyclic sweeps.
5. **DRAIN** — row-major stream of final A. Column norms are the
   singular values; the testbench sorts them and compares to
   `svd_sigma.mem`.

The old broken files (`cordic_rot.vhd`, `jacobi_ctrl.vhd`) remain in
the tree, unused, for reference. See
[`../docs/svd_algorithm_review.md`](../docs/svd_algorithm_review.md)
for the original audit of what was wrong and how the new modules fix
each deviation.

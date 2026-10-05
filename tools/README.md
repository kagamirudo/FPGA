# tools — Python support scripts

Scripts that generate and verify fixed-point test fixtures for the
Vivado projects. Written in pure Python 3 + NumPy; no Vivado required.

## One-time setup

```bash
# From the repo root:
python3 -m venv .venv
.venv/bin/pip install numpy
```

The `.venv/` directory is gitignored.

## `svd_golden_ref.py`

Generates a Q1.16 test matrix and the NumPy SVD reference. Writes three
files into [`../kung_svd/kung_svd.srcs/sim_1/new/`](../kung_svd/kung_svd.srcs/sim_1/new/):

| File | Format | Purpose |
|---|---|---|
| `svd_input.mem` | 18-bit Q1.16 decimal integers, one per line, row-major | Loaded by the VHDL testbench |
| `svd_sigma.mem` | Sorted singular values (desc), Q1.16 integers | Reference the testbench asserts against |
| `svd_input.summary` | Human-readable: float matrix, singular values, reconstruction error | For spot-checking |

Usage:

```bash
.venv/bin/python tools/svd_golden_ref.py                   # default seed=42, n=8
.venv/bin/python tools/svd_golden_ref.py --seed 7 --n 4    # 4×4, different seed
```

Q1.16 range: `[-2.0, +2.0 - 2^-16]` in 18-bit two's complement, scale
`2^16 = 65536`. The generator refuses to write a value that would
overflow that range.

## `verify_golden.py`

Re-runs NumPy SVD for the same seed and asserts every value in
`svd_sigma.mem` matches within 1 ULP of Q1.16 (`±1/65536 ≈ ±1.5e-5`).
Exit status 0 on PASS, non-zero on FAIL — CI-ready.

```bash
.venv/bin/python tools/verify_golden.py
# PASS: all 8 singular values match within 1 ULP
```

Use this if you ever doubt that `svd_sigma.mem` corresponds to the
matrix in `svd_input.mem`. It catches drift between the two files
if either is edited by hand.

## `sim_svd.sh`

End-to-end simulation of the SVD core using the open-source VHDL
simulator [nvc](https://www.nickg.me.uk/nvc/). No Vivado required.

One-time setup:

```bash
brew install nvc    # macOS
```

Usage:

```bash
tools/sim_svd.sh          # full log, n=8
tools/sim_svd.sh -q       # terse: start/sweep/sigma/CYCLES lines only
tools/sim_svd.sh -n 4 -q  # run at N=4 (regenerates .mem fixtures first)
tools/sim_svd.sh -n 16 -q # run at N=16 (longer stop time, more sweeps)
```

Supported N: 4, 8, 16 (any N would work; these are the ones in the
scale study at [`../docs/scale_study.md`](../docs/scale_study.md)).

The script analyzes every VHDL source and the testbench, elaborates
`tb_svd_array`, runs to 300µs, and prints `SVD CHECK: PASS` on
success. Exits non-zero on failure. Build artefacts live in
`build/sim/` (gitignored).

Expected output snippet on PASS:

```
start accepted, load_cnt=64
completed sweep 1 ... completed sweep 7
sigma[0]: expected=91831  got=91907  diff=76  ok
...
sigma[7]: expected=4631   got=4635   diff=4   ok
SVD CHECK: PASS (all 8 singular values within tol)
```

## `sim_blv.sh`

End-to-end simulation of the BLV grid orchestrator
(`svd_jacobi_blv`) at N=4, which runs 2 pair pipelines in parallel.
Session 3 of [`docs/blv_grid_plan.md`](../docs/blv_grid_plan.md).

```bash
tools/sim_blv.sh          # full log
tools/sim_blv.sh -q       # terse
```

Expected output: `BLV CHECK: PASS` at ~604 cycles (vs serializer's
1,159 cycles for N=4 → **1.9× speedup**). Fixtures regenerated into
`blv_input.mem` / `blv_sigma.mem` so the serializer's
`svd_input.mem` is not disturbed.

## `sim_pair.sh` + `pair_pipeline_golden.py`

Standalone validation of `svd_pair_pipeline` — the self-contained
one-pair rotation unit built in session 2 of the
[BLV grid plan](../docs/blv_grid_plan.md). This is the module that
session 3 will instantiate N/2 times inside the BLV grid.

```bash
tools/sim_pair.sh          # full log
tools/sim_pair.sh -q       # terse: row diff lines + PASS/FAIL
```

The script regenerates `pair_input.mem` and `pair_output.mem` via
`pair_pipeline_golden.py` (NumPy reference for one `α = ⟨aₚ,aₚ⟩`,
`β = ⟨aq,aq⟩`, `γ = ⟨aₚ,aq⟩` + angle + Givens step), then runs the
nvc testbench. Expected: all 8 rows within ~3 ULPs of the reference.

## `round_robin_schedule.py`

Generates and verifies the Brent-Luk-Van Loan parallel Jacobi
schedule: `N-1` steps, each with `N/2` disjoint column pairs,
covering every pair of columns exactly once. This is the schedule
the planned BLV grid in [`../docs/blv_grid_plan.md`](../docs/blv_grid_plan.md)
will consume.

```bash
.venv/bin/python tools/round_robin_schedule.py --n 8
# or
.venv/bin/python tools/round_robin_schedule.py --n 16
```

Prints the schedule plus a PASS/FAIL verifier (asserts disjointness
within each step and exhaustiveness overall).

## When to re-generate

- Changing `--seed` or `--n` → re-run the generator; re-run the verifier.
- Changing Q1.16 scale (`FRACT_BITS` constant in both scripts) → re-run both.
- Not sure if the committed `.mem` files match the current script version
  → run `verify_golden.py`; if PASS, they match.

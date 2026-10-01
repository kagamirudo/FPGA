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

## When to re-generate

- Changing `--seed` or `--n` → re-run the generator; re-run the verifier.
- Changing Q1.16 scale (`FRACT_BITS` constant in both scripts) → re-run both.
- Not sure if the committed `.mem` files match the current script version
  → run `verify_golden.py`; if PASS, they match.

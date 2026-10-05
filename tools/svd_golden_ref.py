#!/usr/bin/env python3
"""Generate a Q1.16 test matrix and its NumPy SVD reference.

Writes three files for the VHDL testbench:
  svd_input.mem      - row-major 8x8 input matrix, one Q1.16 word per line
                       (18-bit two's complement, printed as decimal integer)
  svd_sigma.mem      - sorted singular values, Q1.16 decimal, one per line
  svd_input.summary  - human-readable: float matrix, singular values, V, U

Fixed-point format Q1.16 in 18-bit words:
  real_value = int_value / 2**16
  range      = [-2.0, +2.0 - 2^-16]
"""

from __future__ import annotations

import argparse
import numpy as np
from pathlib import Path


FRACT_BITS = 16
WORD_BITS = 18
SCALE = 1 << FRACT_BITS
MAX_INT = (1 << (WORD_BITS - 1)) - 1
MIN_INT = -(1 << (WORD_BITS - 1))


def to_q116(x: float) -> int:
    v = int(round(x * SCALE))
    if v > MAX_INT or v < MIN_INT:
        raise ValueError(f"value {x} out of Q1.16 range")
    return v


def from_q116(v: int) -> float:
    return v / SCALE


def gen_matrix(n: int, seed: int) -> np.ndarray:
    # The top singular value of a random n x n matrix with entries ~ U(-s, s)
    # grows as O(s * sqrt(n)). Scale the uniform range to keep the top sigma
    # well inside Q1.16's (-2, 2) range at any n in [2, 32].
    rng = np.random.default_rng(seed)
    s = 0.5 / max(1.0, (n / 8.0) ** 0.5)
    A = rng.uniform(-s, s, size=(n, n))
    Aq = np.array([[from_q116(to_q116(x)) for x in row] for row in A])
    return Aq


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=8)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--outdir", type=Path,
                    default=Path(__file__).resolve().parent.parent
                    / "kung_svd" / "kung_svd.srcs" / "sim_1" / "new")
    args = ap.parse_args()

    args.outdir.mkdir(parents=True, exist_ok=True)
    A = gen_matrix(args.n, args.seed)
    U, s, Vt = np.linalg.svd(A, full_matrices=True)

    in_path = args.outdir / "svd_input.mem"
    with in_path.open("w") as f:
        for row in A:
            for v in row:
                f.write(f"{to_q116(v)}\n")

    sig_path = args.outdir / "svd_sigma.mem"
    with sig_path.open("w") as f:
        for v in sorted(s, reverse=True):
            if v > from_q116(MAX_INT):
                raise ValueError(f"singular value {v} overflows Q1.16")
            f.write(f"{to_q116(v)}\n")

    sum_path = args.outdir / "svd_input.summary"
    with sum_path.open("w") as f:
        f.write(f"Matrix size: {args.n}x{args.n}, seed={args.seed}\n")
        f.write("Q1.16 word width 18 bits, scale 2^16.\n\n")
        f.write("A (quantized float):\n")
        for row in A:
            f.write("  " + "  ".join(f"{v:+.6f}" for v in row) + "\n")
        f.write("\nSingular values (sorted desc):\n")
        for v in sorted(s, reverse=True):
            f.write(f"  {v:+.6f}   (Q1.16 = {to_q116(v)})\n")
        f.write("\nReconstruction error ||A - U*diag(s)*V^T||_F:\n")
        err = np.linalg.norm(A - U @ np.diag(s) @ Vt)
        f.write(f"  {err:.2e}\n")

    print(f"wrote {in_path}")
    print(f"wrote {sig_path}")
    print(f"wrote {sum_path}")
    print(f"singular values: {[f'{v:+.4f}' for v in sorted(s, reverse=True)]}")


if __name__ == "__main__":
    main()

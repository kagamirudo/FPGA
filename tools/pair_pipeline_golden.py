#!/usr/bin/env python3
"""Golden reference for one svd_pair_pipeline rotation step.

Given a Q1.16 fixture of two columns (a_p, a_q) with ROWS entries each,
compute what the hardware pipeline should emit:

  alpha = sum(a_p[i]^2)
  beta  = sum(a_q[i]^2)
  gamma = sum(a_p[i] * a_q[i])
  theta = 0.5 * atan2(2*gamma, alpha - beta)
  c, s  = cos(theta), sin(theta)
  new_p[i] =  c*a_p[i] + s*a_q[i]
  new_q[i] = -s*a_p[i] + c*a_q[i]

Writes a .mem fixture (input a_p, a_q interleaved) and a human-
readable summary with the expected new_p, new_q columns and the
(c, s) angle values. The RTL testbench loads the .mem and compares.

Usage:
  .venv/bin/python tools/pair_pipeline_golden.py --rows 8 --seed 42
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np


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


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rows", type=int, default=8)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--outdir", type=Path,
                    default=Path(__file__).resolve().parent.parent
                    / "kung_svd" / "kung_svd.srcs" / "sim_1" / "new")
    args = ap.parse_args()

    rng = np.random.default_rng(args.seed)
    a_p = rng.uniform(-0.4, 0.4, size=args.rows)
    a_q = rng.uniform(-0.4, 0.4, size=args.rows)
    a_p = np.array([from_q116(to_q116(v)) for v in a_p])
    a_q = np.array([from_q116(to_q116(v)) for v in a_q])

    alpha = float(np.dot(a_p, a_p))
    beta  = float(np.dot(a_q, a_q))
    gamma = float(np.dot(a_p, a_q))

    diff = alpha - beta
    two_gamma = 2.0 * gamma
    theta = 0.5 * math.atan2(two_gamma, diff)
    c = math.cos(theta)
    s = math.sin(theta)

    new_p =  c * a_p + s * a_q
    new_q = -s * a_p + c * a_q

    args.outdir.mkdir(parents=True, exist_ok=True)
    in_path = args.outdir / "pair_input.mem"
    out_path = args.outdir / "pair_output.mem"
    sum_path = args.outdir / "pair.summary"

    # input: interleaved a_p[i] a_q[i] a_p[i+1] a_q[i+1] ...
    with in_path.open("w") as f:
        for i in range(args.rows):
            f.write(f"{to_q116(a_p[i])}\n")
            f.write(f"{to_q116(a_q[i])}\n")

    # output: interleaved new_p[i] new_q[i] ...
    with out_path.open("w") as f:
        for i in range(args.rows):
            f.write(f"{to_q116(new_p[i])}\n")
            f.write(f"{to_q116(new_q[i])}\n")

    with sum_path.open("w") as f:
        f.write(f"rows={args.rows}, seed={args.seed}\n")
        f.write(f"alpha  = {alpha:+.6f}   Q1.16={to_q116(alpha):+d}\n")
        f.write(f"beta   = {beta:+.6f}   Q1.16={to_q116(beta):+d}\n")
        f.write(f"gamma  = {gamma:+.6f}   Q1.16={to_q116(gamma):+d}\n")
        f.write(f"theta  = {theta:+.6f} rad\n")
        f.write(f"c      = {c:+.6f}   Q1.16={to_q116(c):+d}\n")
        f.write(f"s      = {s:+.6f}   Q1.16={to_q116(s):+d}\n\n")
        f.write("row    a_p         a_q         new_p       new_q\n")
        for i in range(args.rows):
            f.write(f"{i:3d}  "
                    f"{a_p[i]:+.6f}  {a_q[i]:+.6f}  "
                    f"{new_p[i]:+.6f}  {new_q[i]:+.6f}\n")

        # Verify orthogonality of new columns.
        dot = float(np.dot(new_p, new_q))
        f.write(f"\n<new_p, new_q> = {dot:+.2e}  (should be ~0)\n")

    print(f"wrote {in_path}")
    print(f"wrote {out_path}")
    print(f"wrote {sum_path}")
    print(f"c, s = {c:+.6f}, {s:+.6f}  (Q1.16: {to_q116(c)}, {to_q116(s)})")


if __name__ == "__main__":
    main()

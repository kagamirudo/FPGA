#!/usr/bin/env python3
"""Verify svd_golden_ref.py output against a fresh NumPy SVD.

Re-generates the matrix for the given seed, runs NumPy SVD, and asserts
every singular value in svd_sigma.mem matches NumPy's within 1 ULP of
Q1.16. Prints PASS / FAIL and exits non-zero on failure.

Usage:
    .venv/bin/python tools/verify_golden.py            # seed=42, n=8
    .venv/bin/python tools/verify_golden.py --seed 7
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np


FRACT_BITS = 16
SCALE = 1 << FRACT_BITS


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=8)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--memdir", type=Path,
                    default=Path(__file__).resolve().parent.parent
                    / "kung_svd" / "kung_svd.srcs" / "sim_1" / "new")
    args = ap.parse_args()

    rng = np.random.default_rng(args.seed)
    A = rng.uniform(-0.5, 0.5, size=(args.n, args.n))
    A = np.round(A * SCALE) / SCALE

    s_numpy = sorted(np.linalg.svd(A, compute_uv=False), reverse=True)
    s_numpy_q = [int(round(v * SCALE)) for v in s_numpy]

    sig_path = args.memdir / "svd_sigma.mem"
    with sig_path.open() as f:
        s_mem = [int(line.strip()) for line in f if line.strip()]

    print(f"seed={args.seed}, n={args.n}")
    print(f"source:   {sig_path}")
    print()
    print(f"  {'NumPy (Q1.16)':>15}  {'file (Q1.16)':>15}  {'diff':>5}  status")
    print(f"  {'-'*15}  {'-'*15}  {'-'*5}  ------")

    all_ok = True
    for ref, got in zip(s_numpy_q, s_mem):
        diff = abs(ref - got)
        ok = diff <= 1
        all_ok = all_ok and ok
        tag = "ok" if ok else "FAIL"
        print(f"  {ref:>15d}  {got:>15d}  {diff:>5d}  {tag}")

    if len(s_numpy_q) != len(s_mem):
        print(f"\nFAIL: length mismatch "
              f"(numpy={len(s_numpy_q)}, file={len(s_mem)})")
        return 1

    print()
    if all_ok:
        print(f"PASS: all {len(s_numpy_q)} singular values match within 1 ULP")
        return 0
    print(f"FAIL: at least one mismatch exceeded 1 ULP of Q1.16")
    return 1


if __name__ == "__main__":
    sys.exit(main())

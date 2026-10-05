#!/usr/bin/env python3
"""Round-robin (BLV) tournament schedule for parallel one-sided Jacobi.

For an N x N matrix, generate N - 1 steps (per sweep). Each step is a
set of N/2 disjoint column pairs — all pairs touch distinct columns so
they can be rotated in parallel on separate datapaths. Over the full
N - 1 steps, every one of the C(N, 2) pairs is covered exactly once.

This is the standard round-robin / "chess tournament" / BLV ordering.
See:
  Brent, Luk, Van Loan 1985 — SVD on mesh-connected processors
  Luk & Park 1989         — On parallel Jacobi orderings

For the FPGA port, each step maps to N/2 parallel Gram+CORDIC+apply
pipelines in `svd_jacobi_top`. The N - 1 steps run sequentially (one
step per Gram+CORDIC+apply latency), yielding ~N/2 x speedup at ~N/2
x hardware cost vs. the current serializer.

Usage:
    python3 tools/round_robin_schedule.py --n 8
"""

from __future__ import annotations

import argparse
import itertools


def round_robin(n: int) -> list[list[tuple[int, int]]]:
    """Return a list of N - 1 steps, each a list of N/2 disjoint pairs.

    Uses the standard circle rotation: fix column 0, rotate the rest
    (columns 1 .. N-1) around a ring of length N - 1. At step s, column
    i (for i < N/2) is paired with the column at ring position
    (N - 1 - i) under the rotation.

    For odd N, prepend a sentinel column that effectively gives one
    PE idle time each step.
    """
    if n % 2 == 1:
        raise ValueError("odd N not supported in this helper")

    steps: list[list[tuple[int, int]]] = []
    # Ring of N - 1 columns (indices 1 .. N - 1); column 0 is fixed.
    ring = list(range(1, n))
    for _ in range(n - 1):
        pairs = [(0, ring[0])]
        for i in range(1, n // 2):
            left = ring[i]
            right = ring[n - 1 - i]
            # Keep (p, q) with p < q for stable output.
            pairs.append((min(left, right), max(left, right)))
        steps.append(pairs)
        # Rotate the ring by 1.
        ring = [ring[-1]] + ring[:-1]
    return steps


def verify_schedule(steps: list[list[tuple[int, int]]], n: int) -> None:
    """Assert the schedule is valid: disjoint within step, exhaustive overall."""
    all_expected = set(itertools.combinations(range(n), 2))
    seen: set[tuple[int, int]] = set()
    for step_idx, step in enumerate(steps):
        touched: set[int] = set()
        for (p, q) in step:
            assert p < q, f"step {step_idx}: pair {(p, q)} not sorted"
            assert p not in touched and q not in touched, (
                f"step {step_idx}: pair {(p, q)} conflicts with earlier "
                f"pair in same step")
            touched.add(p)
            touched.add(q)
            assert (p, q) not in seen, (
                f"pair {(p, q)} appears twice in the schedule")
            seen.add((p, q))
    missing = all_expected - seen
    assert not missing, f"schedule misses pairs: {missing}"
    assert len(steps) == n - 1, (
        f"expected {n - 1} steps, got {len(steps)}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=8)
    args = ap.parse_args()

    steps = round_robin(args.n)
    verify_schedule(steps, args.n)

    print(f"Round-robin schedule for N={args.n}")
    print(f"  {args.n - 1} steps, {args.n // 2} parallel pairs/step")
    print(f"  Total pairs: {args.n * (args.n - 1) // 2}")
    print()
    for i, step in enumerate(steps):
        pretty = " ".join(f"({p},{q})" for (p, q) in step)
        print(f"  step {i:2d}: {pretty}")
    print()
    print(f"PASS: schedule covers every pair exactly once, no step conflicts.")


if __name__ == "__main__":
    main()

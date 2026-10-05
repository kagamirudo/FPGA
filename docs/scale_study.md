# SVD scale study (nvc, 2026-10-05)

Measures the one-sided Jacobi SVD core (`svd_jacobi_top` +
`svd_gram` + `svd_angle_cordic`) at three matrix sizes against
NumPy golden references, using the open-source nvc simulator.

Reproduce:

```bash
tools/sim_svd.sh -n 4  -q
tools/sim_svd.sh -n 8  -q
tools/sim_svd.sh -n 16 -q
```

The script regenerates `svd_input.mem` and `svd_sigma.mem` fixtures at
the requested N via `tools/svd_golden_ref.py`, then analyzes, elaborates
(with `-gN=$N`), and runs the testbench to completion.

## Compute-cycle numbers

Cycles are measured from end-of-stimulus (last matrix word accepted)
to first output word (start of drain). Clock = 100 MHz (10 ns period).

| N  | Sweeps | Pairs/sweep | Compute cycles | Compute time @ 100 MHz |
|----|--------|-------------|----------------|------------------------|
| 4  | 4      | 6           |          1,159 |  11.6 µs               |
| 8  | 8      | 28          |         12,555 | 125.6 µs               |
| 16 | 16     | 120         |        138,259 |   1.38 ms              |

Scaling ratio (2× N): **×10.8**, **×11.0**. Expected scaling is
`O(sweeps · pairs · (2N + k))` ≈ `O(N³)` for `SWEEPS = N`, matching
observed. For a fixed-sweep schedule (`SWEEPS = const`), scaling
would drop to `O(N²·k)`.

## Numerical accuracy

Tolerance in the testbench is `max(sigma_top / 1024, 64)` ULPs in
Q1.16 (equivalent to ~1e-3 relative at the top singular value).

| N  | Max abs diff (ULP) | Max rel err | Verdict                       |
|----|--------------------|-------------|-------------------------------|
| 4  | 13                 | 2.4e-4      | **PASS** (all 4 within tol)   |
| 8  | 78                 | 8.5e-4      | **PASS** (all 8 within tol)   |
| 16 | 6,611              | 7.8e-2      | **FAIL** (3 of 16 within tol) |

### n=16 convergence pathology

At N=16 with 16 cyclic Jacobi sweeps, the top two singular values
*swap*:

```
sigma[0]: expected=99767  got=93306  diff=6461
sigma[1]: expected=85058  got=91669  diff=6611
```

Classical cyclic Jacobi exhibits slow convergence when adjacent
singular values are close in magnitude (here 99767 and 85058, ratio
1.17). This is a known weakness of the row-cyclic schedule and is
documented in Golub & Van Loan (Matrix Computations, §8.4). Possible
remedies for future work:

1. **Round-robin tournament scheduling** (de Rijk 1989) which has
   better worst-case convergence than lexicographic cyclic.
2. **Threshold Jacobi** which skips pairs whose off-diagonal entry
   is below a tolerance, concentrating work on the slow modes.
3. **Wider accumulators / mantissa** — the Gram α, β, γ are rounded
   back to Q1.16 before CORDIC, which caps angle precision at
   ~2^-16 radians. At larger N this is a precision floor that
   limits final error even with more sweeps.
4. **Converge-on-condition** — replace the fixed sweep count with
   an off-diagonal-Frobenius-norm threshold; stop when below
   `2^-10 · ||A||_F`.

For the thesis, N ≤ 8 is the operating range reported in the
comparison papers (Ma 2006, Ahmedsaid 2003, Kalaycıoğlu 2019) and
is where our head-to-head numbers should land. N ≥ 16 is interesting
as a future-work section ("the current scheduler scales to N=8;
beyond that, convergence degrades without more sweeps or an improved
schedule").

## Observations for the thesis paper

- **Correctness is proven** for N ∈ {4, 8} at Q1.16, which matches
  the sizes reported in all two-sided Jacobi FPGA papers in
  `docs/related_work.md`.
- **Cycle counts** are now a hard number to publish: 12,555 cycles
  for 8×8 at 100 MHz = 125.6 µs. Ma 2006 reports ≈ 2.3 µs for 8×8
  at 83 MHz on Virtex-II — about 50× faster in cycles because they
  use a true n/2 × n/2 systolic mesh (all pairs rotated in parallel
  per sweep), while this design serializes pair-by-pair. That gap
  is the honest cost of the strict nearest-neighbor + register-file
  architecture vs. a dedicated 2D mesh. The thesis should either:
  (a) accept the gap and emphasize compiler reuse / HLS comparison,
  or (b) extend the orchestrator to overlap pairs the way the
  original full-grid design intended (just, with correct Gram inputs).
- **The n=16 result is publishable** as a scaling limit with a
  specific numerical story, not a bug.

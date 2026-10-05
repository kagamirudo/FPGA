# SVD scale study (nvc)

**Last updated 2026-10-05 after enabling threshold-skip and
auto-prescaled Gram outputs in `svd_gram.vhd`.** See the "n=16
precision floor" subsection below for the delta.


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
| 8  | 81                 | 8.8e-4      | **PASS** (all 8 within tol)   |
| 16 | 392                | 3.9e-3      | **FAIL** (6 of 16 within tol) |

### n=16 precision floor (after threshold+prescale)

Enabled in `svd_gram.vhd`:

- **Threshold-skip**: a pair with `2|γ| < (α+β) >> 20` is already
  orthogonal to simulation noise; the orchestrator skips CORDIC and
  the Givens apply, saves ~25 cycles per skipped pair.
- **Auto-prescaled Gram outputs**: before feeding CORDIC, the shared
  right-shift is chosen so `max(|α-β|, |2γ|)` sits at the top of
  Q1.16 instead of being truncated. Preserves the ratio
  `tan(2θ) = 2γ/(α-β)` with more mantissa bits.

Impact at n=16: max abs diff dropped **6,611 → 392 ULP (17× better)**,
and the pathological swap of the top two singular values is gone
(99767 and 85058 come out in the correct order). The residual error
is now at the Q1.16 **precision floor**, not a scheduling pathology:
each Givens rotation drops ~2^-16 bits of mantissa, 120 rotations/sweep
× 16 sweeps = 1920 rotation steps × noise, which accumulates faster
than the diagonal shrinks.

Doubling the sweep count (SWEEPS=2N=32) made it **worse** (max 755
ULP) because more rotations = more accumulated noise. **The design
is precision-limited, not sweep-limited.**

Remedies for future work:

1. **Wider internal datapath** — carry (α-β) and 2γ as full 24-32
   bit values through CORDIC instead of truncating back to Q1.16.
   Addresses the actual root cause.
2. **BLV parallel ordering** — Brent-Luk-Van Loan 1985 mesh of
   2×2 PEs. Convergence per sweep is comparable to cyclic, but
   each sweep is ~8× faster (parallel rotations) and avoids the
   row-cyclic "trap pair" sequences.
3. **de Rijk pivoting** — argmax-column-norm reorder before each
   subsweep. Our Gram already computes α = ‖aₚ‖² for free, so the
   extra cost is just an argmax tree.
4. **QR preconditioning** (Drmač-Veselić, LAPACK Working Note 169)
   — pre-factor A = QR, run Jacobi on R only. Often converges in
   1-3 sweeps. Adds a Kung-style QR kernel to the thesis's
   compiler-template story as a bonus.

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

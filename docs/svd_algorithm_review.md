# SVD RTL algorithm review (as of 2026-10-01)

Short, honest audit of what `kung_svd/` does today versus what one-sided
(Hestenes-style) Jacobi SVD requires. Written for Prof. Nagvajara's review
before the winter-term kickoff.

## What one-sided Jacobi SVD requires

Given a square matrix `A (n×n)` with columns `a_p, a_q`:

1. For each column pair `(p, q)`, compute the 2×2 Gram submatrix

   ```
   G_pq = [[<a_p, a_p>, <a_p, a_q>],
           [<a_p, a_q>, <a_q, a_q>]]
   ```

2. From `G_pq`, derive the Jacobi angle θ such that applying the Givens
   rotation `R(θ)` **to columns p and q of A** makes them orthogonal
   (i.e. zeros the off-diagonal entry of `G_pq`).

3. Only columns `p` and `q` are rotated — the other `n − 2` columns are
   untouched during that sub-step.

4. Sweep over all column pairs; repeat until off-diagonal mass drops below
   a tolerance (or a fixed sweep count). Column norms converge to the
   singular values; the accumulated rotations form Vᵀ; `U = A V Σ⁻¹`.

## What the current RTL does

Three deviations from one-sided Jacobi, each in [svd_array_core.vhd](../kung_svd/kung_svd.srcs/sources_1/new/svd_array_core.vhd):

### 1. PE inputs are not column pairs ([lines 252-257](../kung_svd/kung_svd.srcs/sources_1/new/svd_array_core.vhd#L252-L257))

```vhdl
a_bus(i, j) <= input_matrix(i, j);
b_bus(i, j) <= input_matrix(i, j);
```

Both operands of the Givens rotation at PE `(i, j)` are the same element.
With `svd_pe` computing `c*a - s*b`, this reduces to `(c - s) * A(i, j)` —
a scalar scaling, not a rotation. For a rotation to make sense, the PE at
row `i`, column pair index `k` should see `(A(i, p_k), A(i, q_k))`.

### 2. CORDIC fed scalars, not Gram-matrix entries ([lines 115-116](../kung_svd/kung_svd.srcs/sources_1/new/svd_array_core.vhd#L115-L116))

```vhdl
ctrl_ain <= input_matrix(0, ctrl_col_pivot);
ctrl_bin <= input_matrix(0, ctrl_col_pivot + 1);
```

CORDIC vectoring mode here is computing `atan2(A(0, q), A(0, p))`, i.e.
the angle of a single pair of matrix elements in row 0. The one-sided
Jacobi angle depends on the **column dot products**, not a single row's
entries. It should receive either (a) the three Gram entries `<a_p, a_p>`,
`<a_q, a_q>`, `<a_p, a_q>` or (b) a form that reduces to the Jacobi
angle formula

```
tan(2θ) = 2 <a_p, a_q> / (<a_p, a_p> - <a_q, a_q>)
```

### 3. (c, s) broadcast to the entire grid ([lines 132-137](../kung_svd/kung_svd.srcs/sources_1/new/svd_array_core.vhd#L132-L137))

```vhdl
for i in 0 to ROWS - 1 generate
  for j in 0 to COLS - 1 generate
    c_bus(i, j) <= ctrl_c;
    s_bus(i, j) <= ctrl_s;
```

Every PE receives the same (c, s) at the same cycle. One-sided Jacobi
rotates only two columns per sub-step, so only PEs at columns `p` and
`q` should receive the active (c, s); the rest should hold their columns.

## Why nothing currently fails loudly

- The structural testbench streams data in and prints — no assertion.
- The output drain copies `a_bus(i+1, j)` back; because `a_bus(0, j)` is
  loaded with `input_matrix(i, j)` for all `i`, and all PEs scale by the
  same factor, you get a consistent-looking output stream even though
  no actual SVD occurred.

## What to change

Rough shape of the fix, in increasing-cost order:

| Change | Where | Effort |
|---|---|---|
| Compute three Gram sums `<a_p,a_p>`, `<a_q,a_q>`, `<a_p,a_q>` for the current pair | New small reducer module driving `ctrl_ain`/`ctrl_bin` | Low |
| Derive the Jacobi angle (atan2 on the Gram-form expression) | Keep `cordic_rot` but drive it from the Gram reducer, not row 0 | Low |
| Route the active column pair's data to a 2-wide PE lane; hold the rest | Replace the current full-grid broadcast with a column-pair selector | Medium |
| Accumulate `V` (right singular vectors) by applying the same rotations to a running identity matrix | New `V` register bank, same column-pair gating | Medium |
| Convergence detection (off-diagonal norm < tol) or honest fixed-sweep schedule proof | Replace the current 8-sweep guess with a schedule-generator output | Low once above is done |

An alternative is to pivot the design to **two-sided Brent-Luk-Van Loan**
with 2×2 PE tiles — closer to the proposal's original framing and the
Hemkumar-Cavallaro / Ma 2007 reference designs. One-sided is probably
still the right call for rectangular / larger matrices, but either
direction needs the fixes above (or their two-sided analogues).

## Test infrastructure now in place

Independent of the RTL direction, the Python golden reference at
[tools/svd_golden_ref.py](../tools/svd_golden_ref.py) emits:

- `svd_input.mem` — Q1.16 input matrix, one word per line (18-bit two's
  complement, decimal)
- `svd_sigma.mem` — expected singular values, sorted descending
- `svd_input.summary` — human-readable: matrix, singular values,
  reconstruction error

Next concrete testbench change (once the RTL path exists):

1. In `tb_svd_array.vhd`, open `svd_input.mem` and stream it in instead of
   generating `1..64`.
2. During drain, read `svd_sigma.mem` and compare each output singular
   value against the expected value with tolerance `|err| < 2^-10`
   (≈ 1e-3 relative).
3. Assert false on mismatch; print PASS summary on completion.

The `.mem` format is simple enough to feed either the current path (as
a smoke test) or a corrected path (as a real verification).

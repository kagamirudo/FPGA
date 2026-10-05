# BLV grid plan: SVD architecture pivot

Multi-session rewrite plan for turning `kung_svd` from a 1-PE
serializer into a Brent-Luk-Van Loan (BLV) 2D systolic grid, with a
wider internal datapath to close the N=16 precision floor.

## Why

Current `svd_jacobi_top` serializes column-pair rotations: one Gram,
one CORDIC, one apply at a time. For N=8 we measured 12,512 cycles.
Ma et al. 2006 report ~2.3 µs at 83 MHz on Virtex-II for 8×8, i.e.
~190 cycles — a 65× gap purely because they parallelize all N/2
disjoint pairs per step on an actual 2D grid.

The BLV ordering + grid is **the architecture used by every
published cycle-competitive FPGA SVD** we cite (Ma 2006, Ahmedsaid
2003, Hemkumar & Cavallaro). Moving to it is the single biggest
lever available to the thesis.

## Target architecture

For an N × N matrix, N even:

- **(N−1) × (N/2)** schedule: N/2 disjoint column pairs rotated
  in parallel per step; N−1 steps per sweep. Verified in
  `tools/round_robin_schedule.py`.
- **Hardware grid: N/2 parallel pipelines.** Each pipeline is
  `svd_gram + svd_angle_cordic + Givens apply`, i.e. the same
  three stages we already have, just instantiated N/2 times.
- **Shared register-file matrix A.** Each pipeline reads two columns
  of A (its assigned pair for the current step) and writes them back.
  Because pairs are disjoint per step, there are no write conflicts.
- **Pair routing**: a small cross-bar / mux layer picks which two
  columns each pipeline sees. Driven by a tiny `blv_schedule_rom`
  of N−1 entries, each an array of N/2 pair indices.

For N=8:
- 4 parallel Gram + CORDIC + Givens pipelines.
- 7 steps × 8 sweeps = 56 schedule entries.
- Expected cycles ≈ 7 × 8 × (N + CORDIC_latency) = 56 × ~40 = ~2,200.
- Target speedup vs current: ~6× (serializer does one pair at a time
  so the N/2 parallelism gives the full N/2 = 4× plus steady-state
  pipelining wins).

For N=16:
- 8 parallel pipelines.
- 15 steps × 16 sweeps × ~45 cycles = ~5,400 cycles.
- Target speedup vs current (138k cycles): ~25×.

## Wider internal datapath (fix #5)

Independent of BLV grid, carry the Gram sub-expressions at
**wider precision**:

- Gram outputs (α − β, 2γ) as **Q3.29** in 32-bit words (was
  Q1.16 in 18-bit).
- CORDIC internal datapath to 32-bit (atan table and x/y/z carry).
- CORDIC outputs (c, s) still Q1.16 — only the angle derivation is
  widened, not the rotation values themselves (bounded by 1).
- Givens apply: multiply 32-bit c/s… no, keep c/s at Q1.16 but
  carry the intermediate `c*a_p + s*a_q` at full 2W bits before
  truncating back to Q1.16 (already the case in the current inline
  Givens).

This specifically fixes the "angle floor" that dominates N=16
error. Expected: close the final 400-ULP gap at N=16 → PASS at the
same 2^-10 tolerance that works for N≤8.

## Incremental rollout (5 sessions)

Each session is one commit that nvc can validate before the next
step starts. **No session leaves the tree in a broken state.**

### Session 1 (today)

- Round-robin schedule generator + verifier (`round_robin_schedule.py`).
- This plan doc.
- No RTL changes. Current serializer still passes `tools/sim_svd.sh -n 8 -q`.

### Session 2 — new PE module, old orchestrator still used ✅ **DONE**

- `svd_pair_pipeline.vhd` wraps `svd_gram + svd_angle_cordic +
  inline-Givens` as one entity. Caller-driven row addressing via
  `req_phase + req_row_idx + req_valid`, so the pipeline publishes
  which row it wants and the caller presents (in_a_p, in_a_q)
  combinationally.
- `svd_jacobi_top` is untouched and still passes the full SVD
  regression at N=8 (12,512 cycles, max 7 ULP err).
- `tb_pair_pipeline` validates one pair against a Python golden
  (`tools/pair_pipeline_golden.py`): all 8 rows match within 3 ULP.
- Reproduce with `tools/sim_pair.sh -q` → `PAIR CHECK: PASS`.

### Session 3 — grid controller, N=4 first

- New `svd_jacobi_blv.vhd` orchestrator that instantiates N/2 copies
  of `svd_pair_pipeline` and routes pairs from the schedule ROM.
- Only wired up at N=4 (2 parallel pipelines, 3 steps/sweep).
- Side-by-side: tb runs both serializer and BLV at N=4, compares
  singular values and cycle counts.

### Session 4 — scale to N=8 and N=16

- Parameterize `svd_jacobi_blv` on N.
- Add Session 2's wider-datapath variant of `svd_gram` behind a
  generic flag.
- Scale study at N ∈ {4, 8, 16}: expect PASS at all three.

### Session 5 — swap in as default, update docs

- `svd_array_core` points at `svd_jacobi_blv` by default (keep the
  serializer available via a generic for comparison).
- Update `docs/scale_study.md` with 4-row table: serializer-vs-BLV
  × N=8, N=16.
- Update `docs/related_work.md` with Ma 2006 head-to-head.

Each session's goal cycle count can be measured by `tools/sim_svd.sh
-n N -q` and reported in the commit message.

## Risks

| Risk | Mitigation |
|---|---|
| Shared register-file write contention when writes land on same cycle | Pair selector guarantees disjoint column indices per step; writes happen at step boundary, not during |
| Fmax drops with N/2 parallel multiplies (DSP48 congestion) | Pipeline the Gram MAC and the Givens multiply into 2-3 stages each; expected target ≥ 100 MHz on Kintex-7 |
| CORDIC-angle widening alters existing N=8 PASS numbers | Keep narrow and wide paths side-by-side behind a generic; narrow stays as the regression gate |
| BLV convergence per sweep slower than cyclic for small N | Luk-Park 1989: convergence is comparable; worst-case equivalent. Measure, don't assume. |
| Session 3 is where most bugs hide (routing + handshake) | Build one pipeline standalone (session 2) before any multi-pipeline wiring |

## Timeline

- Session 1: today (~2 hours including plan + schedule).
- Session 2: ~half day.
- Session 3: ~1 day (hardest session).
- Session 4: ~half day.
- Session 5: ~half day + docs.

Realistic calendar if interleaved with other work: 2 weeks.

## Expected end-state

| N | Serializer cycles | BLV cycles | Speedup | N=16 verdict |
|---|---|---|---|---|
| 4  |  1,159 | ~400 | ~3× | PASS |
| 8  | 12,512 | ~2,200 | ~6× | PASS |
| 16 | 137,545 | ~5,400 | ~25× | **PASS** (was FAIL) |

Compared to Ma 2006 at N=8:
- Ma: ~190 cycles @ 83 MHz = 2.3 µs.
- Ours (target): ~2,200 cycles @ 100 MHz = 22 µs.
- Still ~10× slower on cycles — honest, because Ma 2006 uses
  double-side Jacobi (one PE handles the diagonal transform
  entirely), while we're one-sided (two columns pass through
  separately).
- But: compiler-template reuse of the exact same AXI4-Stream nearest-
  neighbor PE used by LU, which Ma 2006 cannot claim.

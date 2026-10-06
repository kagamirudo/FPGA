# Compiler-emitted nearest-neighbor systolic arrays on FPGA

MS thesis work by Gary Pham, advised by Prof.&nbsp;Prawat Nagvajara at Drexel ECE.

The goal is a small compiler + hardware-template flow that emits
systolic PE meshes with **strict nearest-neighbor connectivity** and
**AXI4-Stream–compliant boundaries** by construction. LU decomposition
and one-sided Jacobi SVD are the two case studies driven from the same
PE template, benchmarked head-to-head against Vitis HLS on the same
C source.

The thesis proposal is in [docs/thesis_proposal.pdf](docs/thesis_proposal.pdf)
(source: [docs/thesis_proposal.tex](docs/thesis_proposal.tex)).

## Directory map

| Directory | What's inside | Start here |
|---|---|---|
| [`kung_lu_decom/`](kung_lu_decom/) | Vivado project — Kung-style 4×4 LU on an AXI4-Stream PE mesh (VHDL) | [`kung_lu_decom/README.md`](kung_lu_decom/README.md) |
| [`kung_lu_support/`](kung_lu_support/) | Portable C library + harness that generates stimulus, extracts L/U, and verifies A = L·U | [`kung_lu_support/README.md`](kung_lu_support/README.md) |
| [`kung_svd/`](kung_svd/) | Vivado project — 8×8 one-sided Jacobi SVD. Numerically verified end-to-end in nvc against NumPy golden reference. | [`kung_svd/README.md`](kung_svd/README.md) |
| [`tools/`](tools/) | Python support scripts (Q1.16 golden-reference generator, verifier) | [`tools/README.md`](tools/README.md) |
| [`docs/`](docs/) | Thesis proposal, algorithm review, related-work table | [`docs/README.md`](docs/README.md) |
| [`archive/`](archive/) | Superseded week-01 prototypes, kept for reference | — |

## Status at a glance

- **LU 4×4** — simulated end-to-end, `A = L·U` reconstruction checked
  in software via `kung_lu_support/make run-sim`.
- **SVD scale study** — simulated end-to-end in nvc at N ∈ {4, 8, 16}
  with `SWEEPS = N`, threshold-skip + auto-prescaled Gram outputs:
  - **N = 4**: PASS, 1,159 cycles, max 13 ULP diff (2.4e-4 rel err).
  - **N = 8**: PASS, 12,512 cycles, max 81 ULP diff (8.8e-4 rel err).
  - **N = 16**: FAIL (6/16 within tol), max 392 ULP diff (3.9e-3 rel
    err). Threshold+prescale closed the pathological singular-value
    swap at n=16 (6611 → 392 ULP, **17× improvement**). Residual
    error is now at the Q1.16 precision floor; closing it needs a
    wider internal datapath. See
    [`docs/scale_study.md`](docs/scale_study.md).
- **BLV grid** (`svd_jacobi_blv`, sessions 1-5 of
  [`docs/blv_grid_plan.md`](docs/blv_grid_plan.md)) — N/2 parallel
  `svd_pair_pipeline` units running the round-robin schedule from
  an auto-generated package. Now the **default core** behind
  `svd_array_core` via a `USE_BLV : boolean := true` generic that
  chains through the AXI hierarchy. Scale study at N ∈ {4, 8, 16}:

  | N | Serializer | **BLV** | Speedup | Verdict |
  |---|---|---|---|---|
  | 4 |  1,159 |   **604** |  **1.9×** | PASS |
  | 8 | 12,512 | **3,252** | **3.85×** | PASS |
  | 16 | 137,545 | **17,764** | **7.7×** | FAIL (precision floor) |

  Reproduce either core through the AXI top with
  `tools/sim_svd.sh -c {blv,serial} -n {4,8,16} -q`; the standalone
  BLV TB is `tools/sim_blv.sh -n N -q`.

  Reproduce with `tools/sim_svd.sh -n N -q`. The three algorithmic
  deviations identified in
  [`docs/svd_algorithm_review.md`](docs/svd_algorithm_review.md) have
  been fixed; the review doc now serves as the design rationale.
- **Golden reference** — Python NumPy-SVD fixtures in `.mem` form at
  [`kung_svd/kung_svd.srcs/sim_1/new/svd_{input,sigma}.mem`](kung_svd/kung_svd.srcs/sim_1/new/).
  Regenerate and self-check with `tools/svd_golden_ref.py` and
  `tools/verify_golden.py`.
- **Vitis HLS baselines, post-P&R numbers** — not yet collected
  (planned for weeks 1–3 of the winter-term schedule).

## Quick-start

```bash
# LU end-to-end (pure C, no Vivado needed)
cd kung_lu_support && make run-sim

# SVD end-to-end (pure VHDL in nvc, no Vivado needed)
brew install nvc                                 # one-time
tools/sim_svd.sh -q                              # analyze+elab+run → PASS

# Regenerate SVD golden reference (needs Python 3 + numpy)
python3 -m venv .venv && .venv/bin/pip install numpy
.venv/bin/python tools/svd_golden_ref.py
.venv/bin/python tools/verify_golden.py          # confirms PASS

# Open the Vivado projects (2025.1+)
#   kung_lu_decom/kung_lu_decom.xpr
#   kung_svd/kung_svd.xpr
```

Vivado's generated directories (`*.cache/`, `*.hw/`, `*.ip_user_files/`,
`*.runs/`, `*.sim/`, `*.gen/`) are gitignored — Vivado regenerates them
on project open or build.

## Thesis plan (abbreviated)

Six-month MS schedule starting winter term (Jan 27, 2027):

| Phase | Deliverable |
|---|---|
| Weeks 1–3 | Vitis HLS baselines for LU and SVD on the target board; SVD testbench assertions wired to the golden reference |
| Weeks 4–7 | Fix one-sided Jacobi algorithmic gaps; convergence on random 8×8 matrices |
| Weeks 8–12 | Post-P&R numbers vs. Vitis HLS and vs. Ma 2006 / UCSB 2020 / DSB-Jacobi 2025 |
| Weeks 13–20 | Compiler generalization — shared template for LU + SVD; paper draft (FCCM / FPL / TRETS) |
| Weeks 21–24 | Thesis defense; v1.0 open-source release |

Full plan, risks, and references are in the
[proposal PDF](docs/thesis_proposal.pdf).

## References & related work

See [`docs/related_work.md`](docs/related_work.md) for a comparison
table against Ma 2006, Ahmedsaid 2003, Wang 2014, Kalaycıoğlu 2019,
UCSB 2020, and DSB-Jacobi arXiv 2025. Vitis HLS and AXI4-Stream links:

- Vitis HLS UG1399 — [AXI4-Stream interfaces](https://docs.amd.com/r/en-US/ug1399-vitis-hls)
- AXI Reference Guide UG761 — [protocol signals & timing](https://www.xilinx.com/support/documents/ip_documentation/axi_ref_guide/latest/ug761_axi_reference_guide.pdf)
- AutoSA (FPGA'21) — [polyhedral compiler for systolic arrays](https://dl.acm.org/doi/10.1145/3431920.3439292), [GitHub](https://github.com/UCLA-VAST/AutoSA)

## Contributors

- **Advisor:** Prof. Prawat Nagvajara
- **Student / Lead Author:** Gary Pham

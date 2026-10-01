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
| [`kung_svd/`](kung_svd/) | Vivado project — 8×8 one-sided Jacobi SVD prototype (VHDL). **Algorithm has known gaps — see docs/svd_algorithm_review.md** | [`kung_svd/README.md`](kung_svd/README.md) |
| [`tools/`](tools/) | Python support scripts (Q1.16 golden-reference generator, verifier) | [`tools/README.md`](tools/README.md) |
| [`docs/`](docs/) | Thesis proposal, algorithm review, related-work table | [`docs/README.md`](docs/README.md) |
| [`archive/`](archive/) | Superseded week-01 prototypes, kept for reference | — |

## Status at a glance

- **LU 4×4** — simulated end-to-end, `A = L·U` reconstruction checked
  in software via `kung_lu_support/make run-sim`.
- **SVD 8×8 RTL** — compiles and runs, but the current column-pair
  schedule has three algorithmic deviations from one-sided Jacobi
  (both PE operands identical, CORDIC fed row-0 scalars not Gram sums,
  (c,s) broadcast to the whole grid). Documented in
  [`docs/svd_algorithm_review.md`](docs/svd_algorithm_review.md) with
  line references and a fix plan.
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

# Related work and comparison table

Comparison targets for the thesis results section. Numbers are quoted
from the cited papers; this table will be the baseline we land our own
numbers against once post-P&R results exist. The "Ours" row is
intentionally left blank — fill it in after Vivado P&R and Vitis HLS
runs land in weeks 1-12 of the plan.

## Comparison table (SVD on FPGA)

| System | Algorithm | Device / Target | Matrix | Precision | LUT | FF | BRAM | DSP | Fmax (MHz) | Cycles / Latency | Reference |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Ma et al. 2006 | 2-sided Jacobi, BLV mesh, CORDIC PEs | Xilinx Virtex-II (XC2V2000) | 8×8 | 16-bit fixed | 15,122 slices | — | 0 | 72 (mult18x18) | 83 | ≈ 2.3 µs / 8×8 sweep | [Ma 2006](https://doi.org/10.1109/CCECE.2006.277524) |
| Ahmedsaid & Amira 2003 | 2-sided Jacobi, improved systolic array | Xilinx Virtex | 4×4, 8×8 | 16-bit fixed | ~2× fewer slices vs. prior | — | — | — | — | reports ~1.5× speedup vs. Virtex SVD core | [Ahmedsaid 2003](https://doi.org/10.1109/FPT.2003.1275730) |
| Wang & Zambreno 2014 | Hestenes-Jacobi, 1-sided, double FP | Xilinx Virtex-5 (XC5VLX330) | up to 1024×1024 (off-chip DDR) | IEEE-754 double | 103k | — | 288 | 160 | 177 | 32 ms for 128×128; ~8× vs. CPU | [Wang 2014](https://doi.org/10.1109/IPDPSW.2014.32) |
| Kalaycıoğlu 2019 | 2-sided Jacobi, cyclic 2×2 | Xilinx Zynq-7020 | up to 128×128 | 16/32-bit fixed | — | — | — | — | — | 8.5×–15.3× vs. MATLAB; 2.1×–6.3× vs. GPU for 8×8–128×128 | [Kalaycıoğlu 2019](https://doi.org/10.1109/INISTA.2019.8778279) |
| UCSB (Liu et al.) ISQED 2020 | Jacobi, Maximum Data Sharing ordering | Xilinx VCU118 (VU9P) | up to 2048×2048 | single FP | — | — | — | — | — | up to 300× vs. Eigen on CPU | [UCSB 2020](https://web.ece.ucsb.edu/~lip/publications/FPGA-SVD-IEEE-ISQED2020.pdf) |
| DSB-Jacobi (arXiv 2025) | Data-Stream Jacobi, streaming | Xilinx Zynq UltraScale+ | large stream matrices | — | — | — | **−41.5%** vs prior | — | — | 23× throughput vs prior | [arXiv:2511.12461](https://arxiv.org/abs/2511.12461) |
| **Ours (target)** | 1-sided Jacobi, compiler-emitted nearest-neighbor AXI mesh | Xilinx Kintex-7 (XC7K325T) | 4×4, 8×8 | 18-bit Q1.16 | TBD | TBD | TBD | TBD | TBD | TBD | — |
| **Vitis HLS baseline (same C)** | one-sided Jacobi reference | Xilinx Kintex-7 (XC7K325T) | 4×4, 8×8 | 18-bit Q1.16 | TBD | TBD | TBD | TBD | TBD | TBD | — |

## Positioning notes

- **Scale**: We are explicitly in the 4×4-to-8×8 regime for the thesis.
  That matches the two-sided Jacobi papers (Ma 2006, Ahmedsaid 2003,
  Kalaycıoğlu 2019) where direct number-for-number comparison is possible.
  Hestenes/floating-point papers (Wang 2014, UCSB 2020) operate at
  larger scales and are cited for completeness, not for a head-to-head.

- **Why Kintex-7**: it is the lab device, and it brackets the devices
  used by Ma (Virtex-II, older) and Kalaycıoğlu (Zynq-7020, roughly
  equivalent). Zynq UltraScale+ is a stretch target if the lab adds one.

- **The main story is the compiler, not the SVD itself.** The two
  benchmark columns the paper lives or dies on are:
  1. **Ours vs. Vitis HLS** on the same C — like-for-like, same device,
     same precision. This is the publishable contribution.
  2. **Ours vs. Ma 2006** on 8×8 fixed-point — only comparable row for
     a head-to-head area/latency, after device normalization.

- **Honest comparability caveats**:
  - Device normalization is lossy; Virtex-II slices and Kintex-7 LUT6
    pairs are not equivalent. We'll note the slice/LUT6 conversion
    factor in the paper.
  - Precision differs across rows; our 18-bit Q1.16 sits between
    Ma 2006's 16-bit fixed and the IEEE-754 double papers. Convert
    to "effective bits of accuracy" when quoting error numbers.
  - LUT counts for designs that use CORDIC vs. real multipliers are
    not directly comparable. Report DSP48 counts separately.

## Reproducibility checklist (fill in by paper submission)

- [ ] Vivado version pinned (likely 2025.1)
- [ ] Target part number pinned (XC7K325T-2FFG900C)
- [ ] Constraints file (XDC) committed
- [ ] Report files (`*_utilization_placed.rpt`, `*_timing_summary_routed.rpt`) committed under `docs/results/`
- [ ] Vitis HLS version + synthesis report committed under `docs/results/hls/`
- [ ] Random seed + input matrix for all reported numbers committed under `kung_svd/kung_svd.srcs/sim_1/new/svd_input.mem`

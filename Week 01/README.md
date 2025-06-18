The literature on compiling nested-loop algorithms to spatial arrays of Processing Elements (PEs) is already rich, but there is still room for a toolchain that (1) assumes **only nearest-neighbour links**, (2) emits **AXI4-Stream–compliant IP** (so the core can be dropped straight into an AMD/Xilinx design), and (3) uses **Vitis HLS as a performance baseline**.  Below is a compact map of the most relevant prior work, the technologies you must digest (especially *Vitis HLS UG 1399*), and a concrete, short-term research plan that will let us demonstrate >×1 speed-ups on FIR/IIR, GEMM, 2-D filters and LU in the next few months.

---

## 1.  Key prior art

| Theme                                                                      | Representative work                                                                                      | Why it matters                                                                                                 |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **Polyhedral mapping of perfect/imperfect loop nests to regular PE grids** | J.-X. Gao *et al.* “Automatic Mapping of Nested Loops to FPGAs” ([ece.lsu.edu][1])                       | Early algorithm that schedules loops onto linear/2-D arrays and synthesises control-free dataflow.             |
|                                                                            | *AutoSA* compiler (FPGA ’21) ([cornell-zhang.github.io][2])                                              | End-to-end tool that builds systolic arrays from C; its I/O network ideas can guide our AXI-Stream interfaces. |
|                                                                            | GRAMM heuristic mapper for CGRAs (DATE ’23) ([infoscience.epfl.ch][3])                                   | Shows current state-of-the-art heuristics for graph placement in neighbour-only meshes.                        |
| **Dataflow/CGRA HLS frameworks**                                           | *TAPA* open-source HLS (FCCM ’21) ([github.com][4], [about.blaok.me][5])                                 | Generates channelised dataflow cores; great reference for stream-based RTL generation.                         |
|                                                                            | Stanford **Spatial** language & compiler (PLDI ’18) ([ppl.stanford.edu][6])                              | Demonstrates parameter-space exploration and could inspire our optimisation search.                            |
|                                                                            | **Halide→FPGA** pipelines (T2S, 2025) ([dl.acm.org][7], [arxiv.org][8])                                  | Shows how decoupling algorithm & schedule simplifies mapping and benchmarking.                                 |
| **Nearest-neighbour CGRA research**                                        | Connectivity-restricted ILP mapping ([arxiv.org][9]); graph-drawing mapper ([mpslab-asu.github.io][10])  | Highlights constraints and cost models when only N/S/E/W links exist.                                          |
| **Commercial baselines & libraries**                                       | *Vitis HLS UG 1399* (2025.1) ([docs.amd.com][11])                                                        | Our baseline for “stock HLS” performance and for packaging as AXI4-Stream IP.                                  |
|                                                                            | AMD AXI4-Stream Interconnect core ([amd.com][12]); Microchip CoreAXI4SInterconnect ([microchip.com][13]) | Ready-made fabric for chaining multiple accelerators; dictates handshake rules.                                |
|                                                                            | Vitis BLAS GEMM systolic template ([docs.amd.com][14])                                                   | Shows how AMD packages systolic arrays today (template sizing, memory width).                                  |

*Additional background:* polyhedral compilation survey ([polyhedral.info][15]); CGRA overview in Springer Encyclopedia ([link.springer.com][16]); Plasticine reconfigurable array (ISCA ’17) ([stanford-ppl.github.io][17]); data-flow graph mapping optimisation with ML ([ceca.pku.edu.cn][18]); FPGA spatial acceleration for LLMs (ASPLOS ’25) ([arxiv.org][19], [dl.acm.org][20]).

---

## 2.  Technology foundations you **must** master

### 2.1 Vitis HLS UG 1399 highlights

* § “Dataflow Optimisation” explains channel depth inference and initiation-interval constraints—vital when we auto-generate neighbour links ([xilinx.com][21], [docs.amd.com][11]).
* § “Interface Synthesis: AXI4-Stream” details side-band signals (`tkeep`, `tlast`) our compiler must emit so the core is plug-and-play with the AXI4-Stream interconnect ([docs.amd.com][11]).
* § “Module Packaging” shows how to wrap an RTL kernel as a Vitis v++ linkable IP; we will script this step.

### 2.2 AXI4-Stream interconnect

AMD’s IP exposes parameterisable crossbar, width-conversion, clock-domain crossing and back-pressure; we simply attach each edge of the PE mesh to a switch port ([amd.com][12], [microchip.com][13]).  This removes the need for a bespoke network-on-chip.

### 2.3 Systolic templates in Vitis Libraries

Studying the library GEMM core clarifies how AMD sizes PE tiles to balance BRAM bandwidth and II=1 throughput ([docs.amd.com][14]).

---

## 3.  Gaps our project will fill

1. **No end-to-end tool** today converts C loop nests directly into an AXI-Stream mesh of nearest-neighbour PEs *without* an external controller.
2. Existing frameworks (TAPA, Spatial, AutoSA) still rely on on-chip memories or explicit FIFOs between distant PEs; they do not insist on a pure mesh topology.
3. Published CGRA mappers seldom target the strict AXI-Stream handshake, nor integrate with Vitis’ v++ flow.

---

## 4.  Short-term research plan (≈ 3–4 months)

| Time-box    | Deliverable                                                                                                                                                                                             | Key tasks                                                                                              |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| **Month 1** | **Minimal compiler back-end** that: (i) parses LLVM IR; (ii) extracts polyhedral schedule; (iii) emits RTL for a single PE + neighbour ports.                                                           | Re-use PolySym-ICS algorithm for time-/space-mapping ([ece.lsu.edu][1]); template PE in SystemVerilog. |
| **Month 2** | **Mesh generator & AXI4-Stream wrapper.** Feed per-edge channels into AMD AXI interconnect IP; generate TCL for Vivado IP-packager.                                                                     | Integrate UG 1399 interface pragmas; unit-test on FIR (N=128).                                         |
| **Month 3** | **Auto-placer & router**: greedy heuristic like GRAMM (vertex-cost + Dijkstra) ([infoscience.epfl.ch][3]) to embed dependence graph onto 2-D grid; fall back to ILP for small kernels ([arxiv.org][9]). | Validate on IIR & 3×3 2-D convolution.                                                                 |
| **Month 4** | **Benchmark report.** Compare clock-cycle counts vs Vitis HLS (pragma-optimised) on FIR, IIR, GEMM 16×16, LU 32×32.                                                                                     | Use Vitis `report_utilization` & `report_timing_summary`; highlight speed-up and %DSP reduction.       |

*Success metric*: ≥ 2× cycle speed-up on at least two kernels while meeting timing at 250 MHz on Versal AI Edge ES1 silicon.

---

## 5.  Immediate reading list

| Priority | Document / Paper                                                                                                               | Comment                                    |
| -------- | ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------ |
| ⭐        | *Vitis HLS UG 1399* (2025.1) ([docs.amd.com][11])                                                                              | Interface pragmas, dataflow, IP packaging. |
| ⭐        | AutoSA FCCM ’21 paper & slides ([cornell-zhang.github.io][2])                                                                  | Best polyhedral-to-systolic reference.     |
| ⭐        | TAPA FCCM ’21 & GitHub ([github.com][4], [about.blaok.me][5])                                                                  | Open-source dataflow RTL generator.        |
| ⭐        | Spatial PLDI ’18 ([ppl.stanford.edu][6])                                                                                       | Parameterised hardware templates.          |
| •        | LSU nested-loop mapping (PPoPP ’07) ([ece.lsu.edu][1])                                                                         | Classical schedule derivation.             |
| •        | GRAMM DATE ’23, Yoon TVLSI ’09, ILP mapping (arXiv ’19) ([infoscience.epfl.ch][3], [mpslab-asu.github.io][10], [arxiv.org][9]) | Placement-routing strategies.              |
| •        | Vitis BLAS GEMM systolic reference ([docs.amd.com][14])                                                                        | Mirrors our GEMM test case.                |
| •        | Halide→FPGA scheduling papers ([dl.acm.org][7], [arxiv.org][8])                                                                | Loop-nest schedule vs hardware interface.  |

---

### Next steps for our meeting

1. **Skim the starred items**—especially UG 1399 chapters on AXI4-Stream and dataflow.
2. Come with an opinion on whether we drive the polyhedral analysis ourselves or integrate an existing engine (e.g., ISL).
3. Decide the first *x* in “\*x faster” — collect baseline cycle counts in Vitis HLS for FIR/IIR this week.

[1]: https://www.ece.lsu.edu/jxr/Publications-pdf/ppopp07.pdf?utm_source=chatgpt.com "[PDF] Automatic Mapping of Nested Loops to FPGAs - LSU"
[2]: https://cornell-zhang.github.io/tutorial-fccm21/autosa_fccm21_final.pdf?utm_source=chatgpt.com "[PDF] AutoSA: A Polyhedral Compiler for High-Performance Systolic ..."
[3]: https://infoscience.epfl.ch/record/304406/files/Zhou23%20GRAMM%20%28e-print%29.pdf?utm_source=chatgpt.com "[PDF] GRAMM: Fast CGRA Application Mapping Based on A Heuristic for ..."
[4]: https://github.com/UCLA-VAST/tapa?utm_source=chatgpt.com "UCLA-VAST/tapa - GitHub"
[5]: https://about.blaok.me/pub/fccm21-tapa.pdf?utm_source=chatgpt.com "[PDF] Extending High-Level Synthesis for Task-Parallel Programs - Yuze Chi"
[6]: https://ppl.stanford.edu/papers/pldi18_koeplinger.pdf?utm_source=chatgpt.com "[PDF] Spatial: A Language and Compiler for Application Accelerators"
[7]: https://dl.acm.org/doi/10.1145/3723046?utm_source=chatgpt.com "Productively Generating a High-Performance Linear Algebra Library ..."
[8]: https://arxiv.org/pdf/1809.04070?utm_source=chatgpt.com "[PDF] Using Halide's Scheduling Language to Analyze DNN Accelerators"
[9]: https://arxiv.org/pdf/1901.11129?utm_source=chatgpt.com "[PDF] Generic Connectivity-Based CGRA Mapping via Integer Linear ..."
[10]: https://mpslab-asu.github.io/publications/papers/Yoon2009TVLSI.pdf?utm_source=chatgpt.com "[PDF] A Graph Drawing Based Spatial Mapping Algorithm for Coarse ..."
[11]: https://docs.amd.com/r/en-US/ug1399-vitis-hls?utm_source=chatgpt.com "Vitis High-Level Synthesis User Guide (UG1399) - 2025.1 English"
[12]: https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/axi4-stream_interconnect.html?utm_source=chatgpt.com "AXI4-Stream Interconnect - AMD"
[13]: https://www.microchip.com/en-us/products/fpgas-and-plds/ip-core-tools/coreaxi4sinterconnect?utm_source=chatgpt.com "CoreAXI4SInterconnect | IP Core Tool - Microchip Technology"
[14]: https://docs.amd.com/r/en-US/Vitis_Libraries/blas/user_guide/L2/L2_gemm_content.html_1?utm_source=chatgpt.com "Systolic Array - 2025.1 English"
[15]: https://polyhedral.info/?utm_source=chatgpt.com "Polyhedral Compilation - polyhedral.info"
[16]: https://link.springer.com/rwe/10.1007/978-981-15-6401-7_50-1?utm_source=chatgpt.com "Coarse-Grained Reconfigurable Array (CGRA) - SpringerLink"
[17]: https://stanford-ppl.github.io/website/papers/isca17-raghu-plasticine.pdf?utm_source=chatgpt.com "[PDF] Plasticine: A Reconfigurable Architecture For Parallel Patterns"
[18]: https://ceca.pku.edu.cn/docs/20191124132934492133.pdf?utm_source=chatgpt.com "[PDF] Data-Flow Graph Mapping Optimization for CGRA With Deep ..."
[19]: https://arxiv.org/html/2312.15159v2?utm_source=chatgpt.com "Understanding the Potential of FPGA-Based Spatial Acceleration ..."
[20]: https://dl.acm.org/doi/abs/10.1145/3656177?utm_source=chatgpt.com "Understanding the Potential of FPGA-based Spatial Acceleration ..."
[21]: https://www.xilinx.com/support/documents/sw_manuals/xilinx2022_2/ug1399-vitis-hls.pdf?utm_source=chatgpt.com "[PDF] Vitis High-Level Synthesis User Guide - AMD"

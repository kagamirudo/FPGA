## Overview

This repository contains **research prototypes and artefacts** for a compiler that maps perfectly- and imperfectly-nested loop algorithms onto 2-D meshes of Processing Elements (PEs) that communicate **only through AXI4-Stream neighbour links**.  The compiler + template flow generates RTL that can be packaged directly as AMD Vitis™ HLS kernels, letting us compare against standard HLS IP in a like-for-like way.  The approach is inspired by recent polyhedral-to-systolic frameworks such as AutoSA ([dl.acm.org][1]) but is unique in (a) enforcing strict nearest-neighbour connectivity and (b) emitting AXI4-Stream–compliant cores out-of-the-box ([docs.amd.com][2], [docs.amd.com][3]).

## Key Features

* **Nearest-neighbour PE template** with AXI4-Stream handshake (`TVALID/TREADY/TLAST`) following UG1399 guidelines ([docs.amd.com][2], [docs.amd.com][4]).
* **Mesh generator** that scales the template to arbitrary *N × M* topologies.
* **Polyhedral mapper** (Python/ISL) translating loop schedules into PE co-ordinates.
* **Reference benchmarks**: FIR, IIR, GEMM, 2-D convolution, LU.
* **Baseline scripts** to measure cycle counts and resource use against Vitis HLS.

## Quick-Start

```bash
# Clone & enter
git clone <repo-url> && cd <repo>

# 1. Run a 4×4 mesh test in Verilator
make SIM=verilator sim            # produces dump.vcd for GTKWave

# 2. Package as an RTL kernel for Vitis
make vivado_kernel                # requires Vivado/Vitis 2025.1+

# 3. Generate a mesh net-list from an ISL schedule
python python/mapper.py examples/fir_domain.isl examples/fir_sched.isl
```

See `docs/usage.md` for alternative flows with Xcelium, VCS and xsim.

## Folder Structure

```
rtl/        SystemVerilog PE and mesh modules
tb/         Self-checking test-benches
python/     Polyhedral analysis & code-gen helpers
scripts/    Vivado & make recipes
bench/      Example kernels and schedules
docs/       Design notes and background papers
```

## Documentation & References

* **Vitis HLS User Guide UG1399** – AXI4-Stream interface rules ([docs.amd.com][2], [docs.amd.com][3]).
* **AXI Reference Guide UG761** – protocol signals & timing ([xilinx.com][5]).
* **AutoSA: A Polyhedral Compiler for High-Performance Systolic Arrays on FPGA** (FPGA’21 Best Paper) ([dl.acm.org][1]).
* AutoSA GitHub repository for build scripts ([github.com][6]).
* Additional AXI4-Stream interface notes in PG256 ([docs.amd.com][7]).

## Contributors

* **Instructor:** Prof. Prawat Nagvajara
* **Student / Lead Author:** Gary Pham

---

This README gives a high-level view; for details on algorithmic mapping, hardware micro-architecture, and result tables, consult `docs/design_notes.md` and the citation list above.

[1]: https://dl.acm.org/doi/10.1145/3431920.3439292?utm_source=chatgpt.com "A Polyhedral Compiler for High-Performance Systolic Arrays on FPGA"
[2]: https://docs.amd.com/r/en-US/ug1399-vitis-hls/How-AXI4-Stream-is-Implemented?utm_source=chatgpt.com "How AXI4-Stream is Implemented - 2025.1 English - UG1399"
[3]: https://docs.amd.com/r/en-US/ug1399-vitis-hls/How-AXI4-Stream-Works?utm_source=chatgpt.com "How AXI4-Stream Works - 2025.1 English - UG1399"
[4]: https://docs.amd.com/r/en-US/ug1399-vitis-hls/AXI4-Stream-Interfaces?utm_source=chatgpt.com "AXI4-Stream Interfaces - 2025.1 English - UG1399"
[5]: https://www.xilinx.com/support/documents/ip_documentation/axi_ref_guide/latest/ug761_axi_reference_guide.pdf?utm_source=chatgpt.com "[PDF] Xilinx, UG761 AXI Reference Guide"
[6]: https://github.com/UCLA-VAST/AutoSA?utm_source=chatgpt.com "AutoSA: Polyhedral-Based Systolic Array Compiler - GitHub"
[7]: https://docs.amd.com/r/en-US/pg256-sdfec-integrated-block/AXI4-Stream-Interface?utm_source=chatgpt.com "AXI4-Stream Interface - 1.1 English - PG256"

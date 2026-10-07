# `common/` — shared Vivado TCL

Used by [`../scripts/vivado_setup.sh`](../scripts/vivado_setup.sh).

| Path | Role |
|---|---|
| `tcl/board.tcl` | Cora Z7-07S part / board helpers |
| `tcl/create_project.tcl` | Create or open LU / SVD `.xpr` from VHDL |
| `tcl/package_svd_ip.tcl` | Package `svd_array_axis32` into `ip_repo/` |
| `tcl/create_svd_bd.tcl` | PS7 + AXI DMA + SVD BD → bitstream + XSA |

How to run: see **[`../scripts/README.md`](../scripts/README.md)**.

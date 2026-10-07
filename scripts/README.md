# Vivado setup (this repo)

One-command bootstrap for the two thesis Vivado projects on **Cora Z7-07S**
(`xc7z007sclg400-1`). Requires **Vivado 2025.1+** on `PATH`.

## Quick start

```bash
cd ~/FPGA
source /tools/Xilinx/Vivado/2025.2/settings64.sh   # adjust path/version

# Prefer existing .xpr (just validates / opens in batch)
./scripts/vivado_setup.sh svd
./scripts/vivado_setup.sh lu

# Wipe regenerable Vivado junk and recreate .xpr from VHDL sources
./scripts/vivado_setup.sh svd --force
./scripts/vivado_setup.sh lu  --force

# Recreate then open GUI
./scripts/vivado_setup.sh svd --force --gui
```

Or open projects directly:

```bash
vivado kung_svd/kung_svd.xpr
vivado kung_lu_decom/kung_lu_decom.xpr
```

## What the script does

| Flag / arg | Behavior |
|---|---|
| `svd` / `lu` / `all` | Which project (default `all`) |
| `--force` | Delete `*.xpr` + Vivado cache dirs, rebuild project from `*.srcs/**/new/*.vhd` |
| `--gui` | After batch create, launch Vivado GUI on that `.xpr` |

Shared TCL lives under [`../common/tcl/`](../common/tcl/):

| File | Role |
|---|---|
| `board.tcl` | Part / board_part / repo-root helpers |
| `create_project.tcl` | Create or open `kung_lu_decom` / `kung_svd` |
| `package_svd_ip.tcl` | Package SVD AXIS32 IP |
| `create_svd_bd.tcl` | Build Zynq system + export XSA |

### SVD IP → Vitis XSA

```bash
./scripts/package_svd_ip.sh
./scripts/build_svd_system.sh              # 25 MHz FCLK, bitgen + XSA
# XSA → ../build/svd_system/svd_system.xsa
# Then follow kung_svd_support/README.md for the Vitis C compare app
```

Without `--force`, an existing `.xpr` is opened as-is (fast path).

## After the project is open

### LU (`kung_lu_decom/`)

```bash
cd kung_lu_decom
vivado kung_lu_decom.xpr
# waveform force script (sim already open):
#   source run.tcl
```

Software check (no Vivado):

```bash
cd kung_lu_support && make run-sim
```

Details: [`../kung_lu_decom/README.md`](../kung_lu_decom/README.md).

### SVD (`kung_svd/`)

```bash
cd kung_svd
vivado -mode batch -source test_compile.tcl   # elaborate
vivado -mode batch -source test_sim.tcl       # short sim
vivado -mode batch -source run_long_sim.tcl   # longer sim
```

Golden `.mem` fixtures:

```bash
.venv/bin/python tools/svd_golden_ref.py
.venv/bin/python tools/verify_golden.py
```

Details: [`../kung_svd/README.md`](../kung_svd/README.md).

## Layout reminder

```
FPGA/
├── scripts/
│   ├── vivado_setup.sh      ← run this
│   └── README.md            ← this file
├── common/tcl/              ← shared Vivado TCL
├── kung_lu_decom/           ← LU .xpr + VHDL
├── kung_svd/                ← SVD .xpr + VHDL
├── kung_lu_support/         ← C verification (no Vivado)
└── tools/                   ← SVD golden Python
```

Vivado regenerates `*.cache/`, `*.runs/`, `*.sim/`, `*.gen/`, etc. — those are
gitignored. Edit VHDL under `*.srcs/sources_1/new/` and `*.srcs/sim_1/new/` only.

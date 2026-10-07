# kung_svd_support — SW reference + Vitis DMA compare

Pure-C one-sided Jacobi reference and a bare-metal app that drives the
packaged `svd_array_axis32` IP through AXI DMA, then compares singular
values against the NumPy golden vector (`svd_sigma.mem`, seed=42).

## Host smoke test (no board)

```bash
cd kung_svd_support
make host-test    # pure-C Jacobi vs golden σ → PASS
```

RTL regression (optional, needs `nvc`): `../tools/sim_svd.sh -q`.
Without nvc, Vivado behavioral sim of `tb_svd_array` is equivalent.

## Build hardware (XSA)

From the repo root, with Vivado on `PATH`:

```bash
./scripts/build_svd_system.sh          # FCLK0=25 MHz, bitgen + XSA
# or
./scripts/build_svd_system.sh --bd-only
```

Output: [`../build/svd_system/svd_system.xsa`](../build/svd_system/svd_system.xsa).

FCLK defaults to **25 MHz** because post-route critical path of the RTL
core is ~32 ns (~31 MHz). Raise later after Gram pipelining.

## Vitis (board) flow

1. Source Vitis settings (same install tree as Vivado), e.g.
   `source /mnt/Gary04/2025.2/Vitis/settings64.sh`
2. `vitis -w ~/vitis_svd_ws` (or GUI **File → New → Component → Platform**)
3. Create a **platform** from `build/svd_system/svd_system.xsa`
   (standalone / freertos domain on `ps7_cortexa9_0`)
4. Create an **application** component, empty C project, and add these
   sources from this directory:
   - `main.c`
   - `svd_ref.c` / `svd_ref.h`
   - `svd_check.c` / `svd_check.h`
   - `svd_hw_dma.c` / `svd_hw_dma.h`
   - `svd_test_vectors.h`
5. Link libraries: ensure BSP includes **axidma** (and `xilffs` not required).
   Do **not** define `SVD_HOST_ONLY` for the board build.
6. Build → Run / Debug on Cora Z7 (UART). Expected UART lines:
   - `SW sigma_q: …`
   - `HW sigma_q: …`
   - `HW vs golden: PASS`
   - `=== PASS ===`

## Data contract

| Item | Value |
|---|---|
| N | 8 |
| Format | Q1.16 in low 18 bits of each 32-bit beat |
| Beats | 64 row-major, **TLAST** on last |
| HW output | Rotated A; σ = sorted column L2 norms |
| Tolerance | BLV-style: `top_σ / 512`, floor 128 ULP |

## File map

| File | Role |
|---|---|
| `svd_ref.c` | Float one-sided Jacobi (C-only algo) |
| `svd_check.c` | Column-norm σ + compare helper |
| `svd_hw_dma.c` | `XAxiDma` simple-mode MM2S/S2MM |
| `main.c` | Vitis entry: SW + HW + golden compare |
| `test_host.c` | Host-only SW vs golden |
| `svd_test_vectors.h` | Embedded `svd_input.mem` / `svd_sigma.mem` |

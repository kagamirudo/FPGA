#!/usr/bin/env python3
"""Generate an add_force TCL stimulus script for lu_array4x4 (any size n).

Replaces the hand-written, N=4-only run.tcl. The band-matrix feed order
implemented in compute_band() below is a direct port of
kung_lu_support/lu_io.c's lu_io_get_input_matrix() (same formulas, documented
in kung_lu_support/README.md): for k in [0, n-1], y(tp,k)=A[t][t+k] and
y(tp,-k)=A[t+k][t] where t=(tp-2k)/3, values landing only where (tp-2k)%3==0.

Usage:
    python3 gen_stimulus.py --n 4 > run.tcl                  # default 4x4 test matrix
    python3 gen_stimulus.py --n 10 --pad-to 10 > run_10x10.tcl  # 4x4 padded into 10x10

Fixed-point format is Q(W-F).F, matching lu_pkg.vhd (W=11, F=5).
"""
import argparse

W = 11
F = 5

# The same 4x4 test matrix encoded in the existing hand-written run.tcl
# (decoded from its Q6.5 binary literals: a11=2, a12=1, a13=0, a14=2, a21=4, ...).
DEFAULT_4X4 = [
    [2, 1, 0, 2],
    [4, 5, 1, 3],
    [2, -2, 1, 7],
    [6, 9, 2, 9],
]


def pad_block_identity(a, m):
    """Embed n x n matrix a in the top-left of an m x m matrix as [[A,0],[0,I]]."""
    n = len(a)
    assert m >= n
    padded = [[0] * m for _ in range(m)]
    for i in range(n):
        for j in range(n):
            padded[i][j] = a[i][j]
    for i in range(n, m):
        padded[i][i] = 1
    return padded


def encode_q(value, w=W, f=F):
    code = int(round(value * (1 << f)))
    mask = (1 << w) - 1
    return code & mask


def to_bin(code, w=W):
    mask = (1 << w) - 1
    return format(code & mask, f"0{w}b")


def compute_band(n, a):
    """Port of lu_io_get_input_matrix: returns (band_matrix, trimmed_width).

    band_matrix[k + (n-1)][tp] holds the value fed on lane k at time tp,
    for k in [-(n-1), n-1] (lane index = k + (n-1), matching a[0..2n-2]).
    """
    band_height = 2 * n - 1
    band_width = 4 * n  # generous upper bound, trimmed below
    band = [[0] * band_width for _ in range(band_height)]

    for k in range(0, n):
        for tp in range(band_width):
            if tp < 2 * k:
                continue
            delta = tp - 2 * k
            if delta % 3 != 0:
                continue
            t = delta // 3
            ii, jj = t, t + k
            if 0 <= ii < n and 0 <= jj < n:
                band[k + (n - 1)][tp] = encode_q(a[ii][jj])
                band[-k + (n - 1)][tp] = encode_q(a[jj][ii])

    last_nonzero = 0
    for tp in range(band_width):
        if any(band[r][tp] != 0 for r in range(band_height)):
            last_nonzero = tp
    trimmed_width = last_nonzero + 1
    return band, trimmed_width


def emit_tcl(n, band, trimmed_width, trailing_idle_cycles):
    lanes = 2 * n - 1
    lines = []
    lines.append("restart")
    lines.append("add_force {/lu/ck} -radix hex {1 0ns} {0 50ps} -repeat_every 100ps")
    lines.append("add_force {/lu/reset} -radix hex {1 0ns}")
    lines.append("")
    lines.append(f"# Init all {lanes} lanes to zero (Q6.5 = {W} bits, MSB first: [{W-1}] is sign)")
    for i in range(lanes):
        lines.append(f"add_force {{/lu/a[{i}]}} -radix bin {{{'0'*W} 0ns}}")
    lines.append("")
    lines.append("run 100 ps")
    lines.append("")
    lines.append("# Deassert reset")
    lines.append("add_force {/lu/reset} -radix hex {0 0ns}")
    lines.append("")

    for tp in range(trimmed_width):
        lines.append(f"# ---- tp={tp}")
        for i in range(lanes):
            val = band[i][tp]
            lines.append(f"add_force {{/lu/a[{i}]}} -radix bin {{{to_bin(val)} 0ns}}")
        lines.append("run 100 ps")
        lines.append("")

    for _ in range(trailing_idle_cycles):
        lines.append("run 100 ps")

    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, required=True, help="matrix size fed into the array (must match lu_pkg.N)")
    ap.add_argument("--pad-to", type=int, default=None, help="pad the default 4x4 test matrix to this size via block-identity padding")
    ap.add_argument("--trailing-idle", type=int, default=5, help="idle 'run 100 ps' cycles appended at the end")
    args = ap.parse_args()

    base = DEFAULT_4X4
    if args.pad_to is not None:
        a = pad_block_identity(base, args.pad_to)
        assert args.pad_to == args.n, "--n must equal --pad-to"
    else:
        assert args.n == len(base), "for an unpadded run, --n must equal the base matrix size (4); use --pad-to for other sizes"
        a = base

    n = args.n
    band, trimmed_width = compute_band(n, a)
    print(emit_tcl(n, band, trimmed_width, args.trailing_idle), end="")


if __name__ == "__main__":
    main()

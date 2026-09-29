################################################################################
# Baseline timing constraint for the Kung-style LU systolic array.
#
# This core has never had a formal clock constraint (no .xdc existed anywhere
# in kung_lu_decom before this file), so Fmax has never been measured, only
# assumed. This 10 ns / 100 MHz starting point is a deliberately conservative
# target: run `report_timing_summary -delay_type max` after synth_1/impl_1 and
# read the actual WNS (worst negative slack) it reports. The design's true max
# frequency is 1 / (10ns - WNS) if WNS is negative, or faster than 100 MHz if
# WNS is positive/zero. Tighten this constraint and re-run once a real number
# is known, so later optimizations (divider redesign, PE folding) have a
# concrete before/after Fmax to compare against instead of guesswork.
################################################################################
create_clock -name clk -period 10.000 [get_ports clk]

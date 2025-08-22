restart
add_force {/lu/ck} -radix hex {1 0ns} {0 50ps} -repeat_every 100ps
add_force {/lu/reset} -radix hex {1 0ns}

# Init all 7 lanes to zero (Q5.5 = 11 bits, MSB first: [10] is sign)
add_force {/lu/a[0]} -radix bin {00000000000 0ns}
add_force {/lu/a[1]} -radix bin {00000000000 0ns}
add_force {/lu/a[2]} -radix bin {00000000000 0ns}
add_force {/lu/a[3]} -radix bin {00000000000 0ns}
add_force {/lu/a[4]} -radix bin {00000000000 0ns}
add_force {/lu/a[5]} -radix bin {00000000000 0ns}
add_force {/lu/a[6]} -radix bin {00000000000 0ns}

run 100 ps

# Deassert reset
add_force {/lu/reset} -radix hex {0 0ns}

# ---- Beat 1: 0,0,0,a11,0,0,0  (a11=2 -> 00000010000)
add_force {/lu/a[0]} -radix bin {00000000000 0ns}
add_force {/lu/a[1]} -radix bin {00000000000 0ns}
add_force {/lu/a[2]} -radix bin {00000000000 0ns}
add_force {/lu/a[3]} -radix bin {00001000000 0ns}
add_force {/lu/a[4]} -radix bin {00000000000 0ns}
add_force {/lu/a[5]} -radix bin {00000000000 0ns}
add_force {/lu/a[6]} -radix bin {00000000000 0ns}
run 100 ps

# ---- Beat 1/2: all lanes to zero
add_force {/lu/a[0]} -radix bin {00000000000 0ns}
add_force {/lu/a[1]} -radix bin {00000000000 0ns}
add_force {/lu/a[2]} -radix bin {00000000000 0ns}
add_force {/lu/a[3]} -radix bin {00000000000 0ns}
add_force {/lu/a[4]} -radix bin {00000000000 0ns}
add_force {/lu/a[5]} -radix bin {00000000000 0ns}
add_force {/lu/a[6]} -radix bin {00000000000 0ns}
run 100 ps

# ---- Beat 2: 0,0,a12,0,a21,0,0  (a12=1, a21=4)
add_force {/lu/a[0]} -radix bin {00000000000 0ns}
add_force {/lu/a[1]} -radix bin {00000000000 0ns}
add_force {/lu/a[2]} -radix bin {00010000000 0ns} ;# a21
add_force {/lu/a[3]} -radix bin {00000000000 0ns}
add_force {/lu/a[4]} -radix bin {00000100000 0ns} ;# a12
add_force {/lu/a[5]} -radix bin {00000000000 0ns}
add_force {/lu/a[6]} -radix bin {00000000000 0ns}
run 100 ps

# ---- Beat 3: 0,0,0,a22,0,0,0  (a22=5)
add_force {/lu/a[0]} -radix bin {00000000000 0ns}
add_force {/lu/a[1]} -radix bin {00000000000 0ns}
add_force {/lu/a[2]} -radix bin {00000000000 0ns}
add_force {/lu/a[3]} -radix bin {00010100000 0ns}
add_force {/lu/a[4]} -radix bin {00000000000 0ns}
add_force {/lu/a[5]} -radix bin {00000000000 0ns}
add_force {/lu/a[6]} -radix bin {00000000000 0ns}
run 100 ps

# ---- Beat 4: 0,a31,0,0,0,a13,0  (a31=2, a13=0)
add_force {/lu/a[0]} -radix bin {00000000000 0ns}
add_force {/lu/a[1]} -radix bin {00001000000 0ns} ;# a31
add_force {/lu/a[2]} -radix bin {00000000000 0ns}
add_force {/lu/a[3]} -radix bin {00000000000 0ns}
add_force {/lu/a[4]} -radix bin {00000000000 0ns}
add_force {/lu/a[5]} -radix bin {00000000000 0ns} ;# a13
add_force {/lu/a[6]} -radix bin {00000000000 0ns}
run 100 ps

# ---- Beat 5: 0,0,a32,0,a23,0,0  (a32=-2, a23=1)
add_force {/lu/a[0]} -radix bin {00000000000 0ns}
add_force {/lu/a[1]} -radix bin {00000000000 0ns}
add_force {/lu/a[2]} -radix bin {11111000000 0ns} ;# a32 = -2 (Q6.5)
add_force {/lu/a[3]} -radix bin {00000000000 0ns}
add_force {/lu/a[4]} -radix bin {00000100000 0ns} ;# a23 = 1
add_force {/lu/a[5]} -radix bin {00000000000 0ns}
add_force {/lu/a[6]} -radix bin {00000000000 0ns}
run 100 ps

# ---- Beat 6: a41,0,0,a33,0,0,a14  (a41=6, a33=1, a14=2)
add_force {/lu/a[0]} -radix bin {00011000000 0ns} ;# a41
add_force {/lu/a[1]} -radix bin {00000000000 0ns}
add_force {/lu/a[2]} -radix bin {00000000000 0ns}
add_force {/lu/a[3]} -radix bin {00000100000 0ns} ;# a33
add_force {/lu/a[4]} -radix bin {00000000000 0ns}
add_force {/lu/a[5]} -radix bin {00000000000 0ns}
add_force {/lu/a[6]} -radix bin {00001000000 0ns} ;# a14
run 100 ps

# ---- Beat 7: 0,a42,0,0,0,a24,0  (a42=9, a24=3)
add_force {/lu/a[0]} -radix bin {00000000000 0ns}
add_force {/lu/a[1]} -radix bin {00100100000 0ns} ;# a42
add_force {/lu/a[2]} -radix bin {00000000000 0ns}
add_force {/lu/a[3]} -radix bin {00000000000 0ns}
add_force {/lu/a[4]} -radix bin {00000000000 0ns}
add_force {/lu/a[5]} -radix bin {00001100000 0ns} ;# a24
add_force {/lu/a[6]} -radix bin {00000000000 0ns}
run 100 ps

# ---- Beat 8: 0,0,a43,0,a34,0,0  (a43=2, a34=7)
add_force {/lu/a[0]} -radix bin {00000000000 0ns}
add_force {/lu/a[1]} -radix bin {00000000000 0ns}
add_force {/lu/a[2]} -radix bin {00001000000 0ns} ;# a43
add_force {/lu/a[3]} -radix bin {00000000000 0ns}
add_force {/lu/a[4]} -radix bin {00011100000 0ns} ;# a34
add_force {/lu/a[5]} -radix bin {00000000000 0ns}
add_force {/lu/a[6]} -radix bin {00000000000 0ns}
run 100 ps

# ---- Beat 9: 0,0,0,a44,0,0,0  (a44=9)
add_force {/lu/a[0]} -radix bin {00000000000 0ns}
add_force {/lu/a[1]} -radix bin {00000000000 0ns}
add_force {/lu/a[2]} -radix bin {00000000000 0ns}
add_force {/lu/a[3]} -radix bin {00100100000 0ns} ;# a44
add_force {/lu/a[4]} -radix bin {00000000000 0ns}
add_force {/lu/a[5]} -radix bin {00000000000 0ns}
add_force {/lu/a[6]} -radix bin {00000000000 0ns}
run 100 ps

run 100 ps
run 100 ps
run 100 ps
run 100 ps
run 100 ps
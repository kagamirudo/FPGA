----------------------------------------------------------------------------
-- tb_jacobi_blv.vhd
--
-- Direct testbench for svd_jacobi_blv (no AXI wrapper). Loads a Q1.16
-- N=4 matrix from blv_input.mem, streams it in, kicks start, drains
-- the result, computes column L2 norms, sorts descending, compares to
-- blv_sigma.mem.
--
-- Fixtures (regenerate with `tools/svd_golden_ref.py --n 4`):
--   blv_input.mem   - 16 Q1.16 words, row-major
--   blv_sigma.mem   - 4 singular values, sorted desc
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.math_real.all;
library STD;
use STD.textio.all;

library work;
use work.svd_pkg.all;

entity tb_jacobi_blv is
  generic (
    N : integer := 4
  );
end entity;

architecture rtl of tb_jacobi_blv is
  constant ROWS_C     : integer := N;
  constant COLS_C     : integer := N;
  constant CLK_PERIOD : time    := 10 ns;

  signal clk        : std_logic := '0';
  signal rst_n      : std_logic := '0';
  signal din_valid  : std_logic := '0';
  signal din        : data_t    := (others => '0');
  signal start      : std_logic := '0';
  signal done_sig   : std_logic;
  signal dout_ready : std_logic := '1';
  signal dout       : data_t;
  signal dout_valid : std_logic;
  signal dout_last  : std_logic;

  type int_arr_t is array (natural range <>) of integer;
  signal drained     : int_arr_t(0 to ROWS_C*COLS_C-1) := (others => 0);
  signal recv_cnt    : integer := 0;
  signal recv_done   : boolean := false;
  signal check_done   : boolean := false;
  signal timeout_fire : boolean := false;
  signal compute_start : time := 0 ns;
  signal first_out     : time := 0 ns;

  impure function read_mem (fname : string; n : integer) return int_arr_t is
    file     f    : text open read_mode is fname;
    variable l    : line;
    variable v    : integer;
    variable out_arr : int_arr_t(0 to n-1);
  begin
    for i in 0 to n-1 loop
      readline(f, l);
      read(l, v);
      out_arr(i) := v;
    end loop;
    return out_arr;
  end function;

  function fix_sqrt (x : real) return real is
  begin
    if x < 0.0 then
      return 0.0;
    end if;
    return sqrt(x);
  end function;
begin
  dut : entity work.svd_jacobi_blv
    generic map (DATA_W => DATA_WIDTH, ROWS => ROWS_C, COLS => COLS_C,
                 SWEEPS => COLS_C)
    port map (
      clk        => clk,
      rst_n      => rst_n,
      din_valid  => din_valid,
      din        => din,
      start      => start,
      done       => done_sig,
      dout_ready => dout_ready,
      dout       => dout,
      dout_valid => dout_valid,
      dout_last  => dout_last
    );

  clk_gen : process
  begin
    while not (check_done or timeout_fire) loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process;

  stim : process
    variable inp : int_arr_t(0 to ROWS_C*COLS_C-1);
  begin
    inp := read_mem("blv_input.mem", ROWS_C*COLS_C);

    rst_n <= '0';
    wait for 5 * CLK_PERIOD;
    rst_n <= '1';
    wait for 2 * CLK_PERIOD;

    -- Stream in all words.
    for i in 0 to ROWS_C*COLS_C - 1 loop
      wait until rising_edge(clk);
      din       <= to_signed(inp(i), DATA_WIDTH);
      din_valid <= '1';
    end loop;
    wait until rising_edge(clk);
    din_valid <= '0';

    -- Kick start.
    wait until rising_edge(clk);
    start <= '1';
    compute_start <= now;
    wait until rising_edge(clk);
    start <= '0';

    wait;
  end process;

  recv : process (clk)
  begin
    if rising_edge(clk) then
      if dout_valid = '1' and dout_ready = '1' then
        if recv_cnt = 0 then
          first_out <= now;
        end if;
        if recv_cnt < ROWS_C*COLS_C then
          drained(recv_cnt) <= to_integer(dout);
          recv_cnt <= recv_cnt + 1;
        end if;
        if dout_last = '1' then
          recv_done <= true;
        end if;
      end if;
    end if;
  end process;

  check : process
    constant SCALE   : real := real(2**16);
    variable sigma_q : int_arr_t(0 to COLS_C-1);
    variable norms   : real_vector(0 to COLS_C-1);
    variable norms_q : int_arr_t(0 to COLS_C-1);
    variable acc     : real;
    variable v_real  : real;
    variable tmp     : real;
    variable passed  : boolean := true;
    variable tol_q   : integer;
    variable diff_q  : integer;
    variable l       : line;
  begin
    wait until recv_done;
    wait for 2 * CLK_PERIOD;

    sigma_q := read_mem("blv_sigma.mem", COLS_C);

    for j in 0 to COLS_C-1 loop
      acc := 0.0;
      for i in 0 to ROWS_C-1 loop
        v_real := real(drained(i*COLS_C + j)) / SCALE;
        acc    := acc + v_real * v_real;
      end loop;
      norms(j) := fix_sqrt(acc);
    end loop;

    for pass_i in 0 to COLS_C-2 loop
      for j in 0 to COLS_C-2-pass_i loop
        if norms(j) < norms(j+1) then
          tmp         := norms(j);
          norms(j)    := norms(j+1);
          norms(j+1)  := tmp;
        end if;
      end loop;
    end loop;

    for i in 0 to COLS_C-1 loop
      norms_q(i) := integer(round(norms(i) * SCALE));
    end loop;

    tol_q := sigma_q(0) / 1024;
    if tol_q < 64 then
      tol_q := 64;
    end if;

    report "---- BLV numerical check ----" severity note;
    for i in 0 to COLS_C-1 loop
      diff_q := abs(norms_q(i) - sigma_q(i));
      write(l, string'("sigma["));
      write(l, i);
      write(l, string'("]: expected="));
      write(l, sigma_q(i));
      write(l, string'("  got="));
      write(l, norms_q(i));
      write(l, string'("  diff="));
      write(l, diff_q);
      if diff_q > tol_q then
        write(l, string'("  FAIL (tol="));
        write(l, tol_q);
        write(l, string'(")"));
        passed := false;
      else
        write(l, string'("  ok"));
      end if;
      writeline(output, l);
    end loop;

    write(l, string'("CYCLES n="));
    write(l, N);
    write(l, string'("  compute="));
    write(l, (first_out - compute_start) / CLK_PERIOD);
    write(l, string'(" cycles"));
    writeline(output, l);

    if passed then
      report "BLV CHECK: PASS" severity note;
    else
      report "BLV CHECK: FAIL" severity failure;
    end if;
    check_done <= true;
    wait;
  end process;

  timeout : process
    constant TLIMIT : time := 10 us + 2 * N * N * (N - 1) * (2 * N + 25) * 10 ns * 2;
  begin
    wait for TLIMIT;
    if not check_done then
      report "tb_jacobi_blv: timeout" severity failure;
      timeout_fire <= true;
    end if;
    wait;
  end process;
end architecture rtl;

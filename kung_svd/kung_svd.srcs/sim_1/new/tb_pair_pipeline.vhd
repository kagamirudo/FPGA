----------------------------------------------------------------------------
-- tb_pair_pipeline.vhd
--
-- Standalone test for svd_pair_pipeline. The pipeline publishes
-- (req_phase, req_row_idx, req_valid); the TB drives (in_a_p, in_a_q)
-- combinationally from a pre-loaded fixture indexed by req_row_idx.
--
-- Fixtures (regenerate with `tools/pair_pipeline_golden.py`):
--   pair_input.mem   - interleaved a_p[i] a_q[i] a_p[i+1] a_q[i+1] ...
--   pair_output.mem  - interleaved expected new_p[i] new_q[i] ...
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
library STD;
use STD.textio.all;

library work;
use work.svd_pkg.all;

entity tb_pair_pipeline is
  generic (
    ROWS_C : integer := 8
  );
end entity;

architecture rtl of tb_pair_pipeline is
  constant CLK_PERIOD : time := 10 ns;

  signal clk       : std_logic := '0';
  signal rst_n     : std_logic := '0';
  signal start     : std_logic := '0';
  signal in_a_p    : data_t    := (others => '0');
  signal in_a_q    : data_t    := (others => '0');

  signal req_phase   : std_logic;
  signal req_row_idx : integer range 0 to ROWS_C;
  signal req_valid   : std_logic;

  signal out_new_p   : data_t;
  signal out_new_q   : data_t;
  signal out_row_idx : integer range 0 to ROWS_C;
  signal out_valid   : std_logic;
  signal skip        : std_logic;
  signal done        : std_logic;

  type int_arr_t is array (natural range <>) of integer;
  signal pair_in   : int_arr_t(0 to 2*ROWS_C - 1) := (others => 0);
  signal pair_exp  : int_arr_t(0 to 2*ROWS_C - 1) := (others => 0);

  signal check_done : boolean := false;

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
begin
  dut : entity work.svd_pair_pipeline
    generic map (DATA_W => DATA_WIDTH, ROWS => ROWS_C)
    port map (
      clk         => clk,
      rst_n       => rst_n,
      start       => start,
      in_a_p      => in_a_p,
      in_a_q      => in_a_q,
      req_phase   => req_phase,
      req_row_idx => req_row_idx,
      req_valid   => req_valid,
      out_new_p   => out_new_p,
      out_new_q   => out_new_q,
      out_row_idx => out_row_idx,
      out_valid   => out_valid,
      skip        => skip,
      done        => done
    );

  clk_gen : process
  begin
    while not check_done loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process;

  -- Combinational driver: whenever req_valid is high, present the row
  -- the pipeline asked for.
  drive : process (req_valid, req_row_idx, pair_in)
  begin
    if req_valid = '1' and req_row_idx < ROWS_C then
      in_a_p <= to_signed(pair_in(2 * req_row_idx),     DATA_WIDTH);
      in_a_q <= to_signed(pair_in(2 * req_row_idx + 1), DATA_WIDTH);
    else
      in_a_p <= (others => '0');
      in_a_q <= (others => '0');
    end if;
  end process;

  stim : process
  begin
    pair_in  <= read_mem("pair_input.mem",  2 * ROWS_C);
    pair_exp <= read_mem("pair_output.mem", 2 * ROWS_C);

    rst_n <= '0';
    wait for 5 * CLK_PERIOD;
    rst_n <= '1';
    wait for 2 * CLK_PERIOD;

    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';

    wait;
  end process;

  check : process (clk)
    variable l       : line;
    variable got_p   : integer;
    variable got_q   : integer;
    variable exp_p   : integer;
    variable exp_q   : integer;
    variable err_p   : integer;
    variable err_q   : integer;
    variable tol     : integer := 2048;  -- Q1.16 units; ~3e-2 relative
    variable failed  : boolean := false;
  begin
    if rising_edge(clk) then
      if out_valid = '1' then
        got_p := to_integer(out_new_p);
        got_q := to_integer(out_new_q);
        exp_p := pair_exp(2 * out_row_idx);
        exp_q := pair_exp(2 * out_row_idx + 1);
        err_p := abs(got_p - exp_p);
        err_q := abs(got_q - exp_q);
        write(l, string'("row "));
        write(l, out_row_idx);
        write(l, string'(": got_p="));
        write(l, got_p);
        write(l, string'(" exp_p="));
        write(l, exp_p);
        write(l, string'(" err_p="));
        write(l, err_p);
        write(l, string'("  got_q="));
        write(l, got_q);
        write(l, string'(" exp_q="));
        write(l, exp_q);
        write(l, string'(" err_q="));
        write(l, err_q);
        if err_p > tol or err_q > tol then
          write(l, string'("  FAIL"));
          failed := true;
        else
          write(l, string'("  ok"));
        end if;
        writeline(output, l);

        if out_row_idx = ROWS_C - 1 then
          if failed then
            report "PAIR CHECK: FAIL" severity failure;
          else
            report "PAIR CHECK: PASS (all ROWS within tol)" severity note;
          end if;
          check_done <= true;
        end if;
      end if;

      if skip = '1' and not check_done then
        report "PAIR CHECK: pipeline skipped (threshold); unexpected for this fixture"
          severity failure;
        check_done <= true;
      end if;
    end if;
  end process;

  timeout : process
  begin
    wait for 10 us;
    if not check_done then
      report "tb_pair_pipeline: timeout" severity failure;
    end if;
    wait;
  end process;
end architecture rtl;

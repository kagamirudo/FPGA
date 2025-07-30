--=======================================================================
--  tb_svd_array.vhd   --  Functional testbench for SVD AXI-Stream core
--  © 2025  Prawat Lab / Gary Pham   –   VHDL-2008
--=======================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- import DATA_WIDTH and the data_t subtype
library work;
use work.svd_pkg.all;

--============================================================
entity tb_svd_array is
end entity;

architecture rtl of tb_svd_array is
  --------------------------------------------------------------------
  --  Test parameters
  --------------------------------------------------------------------
  constant ROWS_C     : integer := 8; -- tile height
  constant COLS_C     : integer := 8; -- tile width
  constant CLK_PERIOD : time    := 10 ns; -- 100 MHz

  --------------------------------------------------------------------
  --  Clock / reset
  --------------------------------------------------------------------
  signal aclk    : std_logic := '0';
  signal aresetn : std_logic := '0';

  --------------------------------------------------------------------
  --  AXI-Stream slave (to DUT)
  --------------------------------------------------------------------
  signal s_axis_tdata  : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal s_axis_tvalid : std_logic := '0';
  signal s_axis_tlast  : std_logic := '0';
  signal s_axis_tready : std_logic;

  --------------------------------------------------------------------
  --  AXI-Stream master (from DUT)
  --------------------------------------------------------------------
  signal m_axis_tdata  : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal m_axis_tvalid : std_logic;
  signal m_axis_tlast  : std_logic;
  signal m_axis_tready : std_logic := '1';

  --------------------------------------------------------------------
  --  Control / bookkeeping
  --------------------------------------------------------------------
  signal output_cnt   : natural := 0;
  signal stim_done    : boolean := false;
  signal timeout_done : boolean := false;
  signal sim_done     : boolean := false;
begin
  ------------------------------------------------------------------
  --  Instantiate the DUT (top-level AXI wrapper)
  ------------------------------------------------------------------
  uut : entity work.svd_array_top
    generic map(
      ROWS   => ROWS_C,
      COLS   => COLS_C,
      DATA_W => DATA_WIDTH
    )
    port map
    (
      -- clock / reset
      aclk    => aclk,
      aresetn => aresetn,
      -- slave in
      s_axis_tdata  => s_axis_tdata,
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tlast  => s_axis_tlast,
      s_axis_tready => s_axis_tready,
      -- master out
      m_axis_tdata  => m_axis_tdata,
      m_axis_tvalid => m_axis_tvalid,
      m_axis_tlast  => m_axis_tlast,
      m_axis_tready => m_axis_tready
    );

  ------------------------------------------------------------------
  --  100 MHz clock
  ------------------------------------------------------------------
  clk_gen : process
  begin
    report "TB: Clock generation started" severity note;
    while not (stim_done or timeout_done) loop
      aclk <= '0';
      wait for CLK_PERIOD/2;
      aclk <= '1';
      wait for CLK_PERIOD/2;
    end loop;
    report "TB: Clock generation stopped" severity note;
    wait;
  end process;

  ------------------------------------------------------------------
  --  Stimulus: reset + push 64 words (1…64)
  ------------------------------------------------------------------
  stim : process
  begin
    -- apply reset
    aresetn <= '0';
    wait for 5 * CLK_PERIOD;
    aresetn <= '1';
    wait for 2 * CLK_PERIOD;

    report "TB: Starting to send data" severity note;

    -- send matrix row-major
    for i in 1 to ROWS_C * COLS_C loop
      s_axis_tdata  <= std_logic_vector(to_signed(i, DATA_WIDTH));
      s_axis_tvalid <= '1';
      if i = ROWS_C * COLS_C then
        s_axis_tlast <= '1';
      else
        s_axis_tlast <= '0';
      end if;

      report "TB: Sending data " & integer'image(i) & ", s_axis_tready = " & std_logic'image(s_axis_tready) severity note;
      -- wait for ready on a rising edge
      wait until rising_edge(aclk) and s_axis_tready = '1';
    end loop;

    -- de-assert valid lines
    s_axis_tvalid <= '0';
    s_axis_tlast  <= '0';
    s_axis_tdata  <= (others => '0');

    report "TB: Finished sending data, waiting for computation" severity note;

    ----------------------------------------------------------------
    -- give the core plenty of time to compute and drain
    ----------------------------------------------------------------
    wait for 50 us;
    stim_done <= true;
    report "TB finished - normal exit" severity note;
    -- std.env.stop; -- closes the sim (VHDL-2008 feature)
    wait;
  end process;

  ------------------------------------------------------------------
  --  Receive & print results
  ------------------------------------------------------------------
  recv : process (aclk)
  begin
    if rising_edge(aclk) then
      -- Debug: Print state information
      if m_axis_tvalid = '1' then
        output_cnt <= output_cnt + 1;
        report "out(" & integer'image(output_cnt) & ") = " &
          integer'image(to_integer(signed(m_axis_tdata)));

        if m_axis_tlast = '1' then
          report "------ all outputs received ------";
        end if;
      end if;
      
      -- Debug: Print when we're waiting for output
      if output_cnt = 0 and m_axis_tvalid = '0' then
        report "Waiting for output data..." severity note;
      end if;
    end if;
  end process;

    ------------------------------------------------------------------
    --  Safety timeout (50 µs)
    ------------------------------------------------------------------
    timeout : process
    begin
      report "TB: Timeout process started, will timeout at 50us" severity note;
      wait for 50 us;
      if not stim_done then
        report "Timeout - simulation forced to finish" severity warning;
        timeout_done <= true;
        -- std.env.stop; -- VHDL-2008 feature
      else
        report "TB: Normal completion, timeout not needed" severity note;
      end if;
      wait;
    end process;
  end architecture rtl;

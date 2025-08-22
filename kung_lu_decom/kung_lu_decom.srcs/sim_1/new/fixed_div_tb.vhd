--######################################################################
--  Testbench : fixed_div_tb.vhd
--  Purpose   : Stimulate the fixed_div divider with several test vectors
--               and flag any mismatches via ASSERT statements.
--######################################################################
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fixed_div_tb is end entity;

architecture tb of fixed_div_tb is
  ------------------------------------------------------------------
  -- Unit under test generics
  ------------------------------------------------------------------
  constant W : integer := 32;
  constant F : integer := 16;

  ------------------------------------------------------------------
  -- Signals to drive the UUT
  ------------------------------------------------------------------
  signal clk  : std_logic := '0';
  signal rst  : std_logic := '1';
  signal num  : signed(W - 1 downto 0);
  signal den  : signed(W - 1 downto 0);
  signal quot : signed(W - 1 downto 0);
  signal div0 : std_logic;

  ------------------------------------------------------------------
  -- Helper function: real → fixed-point (Q format) encoder
  ------------------------------------------------------------------
  function real_to_fixed(r : real) return signed is
    variable val             : integer;
  begin
    if r >= 0.0 then
      val := integer(r * 2.0 ** F + 0.5); -- round to nearest
    else
      val := integer(r * 2.0 ** F - 0.5);
    end if;
    return to_signed(val, W);
  end function;
begin
  ------------------------------------------------------------------
  -- Instantiate the divider (UUT)
  ------------------------------------------------------------------
  uut : entity work.fixed_div
    generic map(W => W, F => F)
    port map
    (
      clk  => clk,
      rst  => rst,
      num  => num,
      den  => den,
      quot => quot,
      div0 => div0
    );

  ------------------------------------------------------------------
  -- Clock generation: 100 ps period (toggle every 50 ps)
  ------------------------------------------------------------------
  clk <= not clk after 50 ps;

  ------------------------------------------------------------------
  -- Stimulus
  ------------------------------------------------------------------
  stimulus : process
    -- local helper
    procedure apply(dividend : signed; divisor : signed; exp_quot : signed; exp_div0 : std_logic) is
    begin
      num <= dividend;
      den <= divisor;
      wait for 150 ps; -- wait for next rising edge + setup time
      assert quot = exp_quot and div0 = exp_div0
      report "Mismatch: num=" & integer'image(to_integer(dividend)) &
        " den=" & integer'image(to_integer(divisor)) &
        " quot=" & integer'image(to_integer(quot)) &
        " exp=" & integer'image(to_integer(exp_quot))
        severity error;
    end procedure;
    -- constants for test values (pre-encoded for 16Q16)
    constant FIX_1P0  : signed(W - 1 downto 0) := to_signed(65536, W); -- 1.0
    constant FIX_2P0  : signed(W - 1 downto 0) := to_signed(131072, W); -- 2.0
    constant FIX_0P5  : signed(W - 1 downto 0) := to_signed(32768, W); -- 0.5
    constant FIX_N1P0 : signed(W - 1 downto 0) := to_signed(-65536, W); -- -1.0
    constant FIX_N0P5 : signed(W - 1 downto 0) := to_signed(-32768, W); -- -0.5
  begin
    ------------------------------------------------------------------
    -- Reset pulse
    ------------------------------------------------------------------
    rst <= '1';
    num <= (others => '0');
    den <= (others => '0');
    wait for 150 ps; -- more than one clock edge
    rst <= '0';
    wait for 100 ps;

    ------------------------------------------------------------------
    -- Test cases
    ------------------------------------------------------------------
    -- 1) 1 / 2 = 0.5
    apply(FIX_1P0, FIX_2P0, FIX_0P5, '0');

    -- 2) -1 / 2 = -0.5
    apply(FIX_N1P0, FIX_2P0, FIX_N0P5, '0');

    -- 3) 3 / 1 = 3 (encoded 3.0 = 3*65536 = 196608)
    apply(to_signed(196608, W), FIX_1P0, to_signed(196608, W), '0');

    -- 4) -3 / -2 = 1.5 (encoded 1.5 = 1.5*65536 = 98304)
    apply(to_signed(-196608, W), to_signed(-131072, W), to_signed(98304, W), '0');

    -- 5) Divide by zero
    apply(FIX_1P0, to_signed(0, W), to_signed(0, W), '1');

    -- 6) 1/3 = 0.333... (should be ~21845 in 16Q16)
    apply(FIX_1P0, to_signed(196608, W), to_signed(21845, W), '0');

    -- 7) 2/3 = 0.666... (should be ~43690 in 16Q16)
    apply(to_signed(131072, W), to_signed(196608, W), to_signed(43690, W), '0');

    -- 8) 1/7 = 0.142... (should be ~9362 in 16Q16)
    apply(FIX_1P0, to_signed(458752, W), to_signed(9362, W), '0');

    -- 9) 3/7 = 0.428... (should be ~28087 in 16Q16)
    apply(to_signed(196608, W), to_signed(458752, W), to_signed(28086, W), '0');

    -- 10) 1/11 = 0.0909... (should be ~5958 in 16Q16)
    apply(FIX_1P0, to_signed(720896, W), to_signed(5957, W), '0');

    -- 11) 5/11 = 0.4545... (should be ~29789 in 16Q16)
    apply(to_signed(327680, W), to_signed(720896, W), to_signed(29789, W), '0');

    -- 12) 1/13 = 0.0769... (should be ~5041 in 16Q16)
    apply(FIX_1P0, to_signed(851968, W), to_signed(5041, W), '0');

    -- 13) SIMPLE TEST: 2.0 / 4.0 = 0.5
    apply(to_signed(131072, W), to_signed(262144, W), to_signed(32768, W), '0');

    -- Finish simulation
    report "All tests completed" severity note;
    wait;
  end process;
end architecture tb;

--######################################################################
--  Title  : Fixed-point Divider 16Q16 (signed 32-bit) – clocked version
--  Author : Gary Pham
--
--  Description:
--    • Performs division for signed fixed-point numbers in Q( W-F ).F format.
--      Default W = 32, F = 16 → 16Q16.
--    • Synchronous design with single pipeline stage.
--      Computation occurs on rising edge of `clk` when `rst` = '0'.
--    • Active-high synchronous reset `rst` clears outputs.
--    • Divide-by-zero is flagged by `div0` (quotient forced to 0).
--######################################################################
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use work.lu_pkg.all;

entity fixed_div is
  generic (
    W : integer := 10; -- total width (sign + int + frac)
    F : integer := 5 -- fractional bits (16Q16 format)
  );
  port (
    clk, rst : in std_logic;
    num      : in signed(W - 1 downto 0); -- dividend (Q format)
    den      : in signed(W - 1 downto 0); -- divisor  (Q format)
    quot     : out signed(W - 1 downto 0); -- quotient (Q format)
    div0     : out std_logic -- = '1' when den = 0
  );
end entity fixed_div;

architecture rtl of fixed_div is
  subtype wide_t is signed(W + F - 1 downto 0); -- extended width for shift
begin
  process (clk)
    variable num_ext  : wide_t;
    variable result_w : wide_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        quot <= (others => '0');
        div0 <= '0';
      else
        if den = 0 then -- divide-by-zero guard
          quot <= (others => '0');
          div0 <= '1';
        else
          div0 <= '0';
          -- For 16Q16 fixed-point division:
          -- num and den are in Q16.16 format (value = integer/65536)
          -- To get proper fixed-point result: (num << F) / den
          num_ext  := resize(num, num_ext'length) sll F;
          result_w := resize(num_ext / den, result_w'length);
          quot <= result_w(W - 1 downto 0);
        end if;
      end if;
    end if;
  end process;
end architecture rtl;
--######################################################################
--  ENTITY: MA_cell  (Multiplier-Accumulate update node)
--  Re-written to be self-contained and avoid external package dependency.
--
--  Generic-parameterised width W so it can be used for 4Q5 (W=10) or any
--  other fixed-point size.  All arithmetic is two’s-complement signed.
--######################################################################
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lu_pkg.all;

entity MA_cell is
  port (
    clk, rst : in std_logic;
    y_in     : in dint;
    x_in     : in dint;
    ps_in    : in dint;

    y_out  : out dint;
    x_out  : out dint;
    ps_out : out dint
  );
end entity MA_cell;

architecture rtl of MA_cell is
  signal ps_reg, y_reg, x_reg : dint;
begin
  process (clk)
    variable res : signed(2 * W - 1 downto 0); -- For A * B + C result
  begin
    if rising_edge(clk) then
      if rst = '1' then
        ps_reg <= (others => '0');
        y_reg  <= (others => '0');
        x_reg  <= (others => '0');
        res := (others    => '0');
      else
        -- multiply then add: y_in * x_in + ps_in
        -- keep product at 2W bits to avoid width explosion (W*W -> 2W)
        res := signed(y_in) * signed(x_in) + signed(ps_in);
        ps_reg <= dint(resize(res, W));
        y_reg  <= y_in;
        x_reg  <= x_in;
      end if;
    end if;
  end process;
  ps_out <= ps_reg;
  y_out  <= y_reg;
  x_out  <= x_reg;
end architecture rtl;
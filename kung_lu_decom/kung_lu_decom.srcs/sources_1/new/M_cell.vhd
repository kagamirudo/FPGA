-------------------------------------------------------------------------------
--  ENTITY: M_cell  (pivot node)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lu_pkg.all;

entity M_cell is
  port (
    clk, rst : in std_logic;
    y_in     : in dint;
    ps_in    : in dint;

    y_out : out dint;
    x_out : out dint
  );
end entity;

architecture rtl of M_cell is
  signal ps_reg, y_reg : dint;
begin
  process (clk)
    variable res : signed(2 * W - 1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        ps_reg <= (others => '0');
        y_reg  <= (others => '0');
        res := (others    => '0');
      else
        -- multiply then add: y_in * ps_in
        res := signed(y_in) * signed(ps_in);
        ps_reg <= dint(resize(res, W));
        y_reg  <= y_in;
      end if;
    end if;
  end process;
  y_out <= y_reg;
  x_out <= ps_reg;
end architecture;

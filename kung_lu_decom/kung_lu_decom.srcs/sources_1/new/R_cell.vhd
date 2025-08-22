library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lu_pkg.all;

entity R_cell is
  port (
    clk, rst : in std_logic;
    ps_in    : in dint;
    y_out    : out dint
  );
end entity;

architecture rtl of R_cell is
  signal reg : dint;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        reg <= (others => '0');
      else
        reg <= ps_in;
      end if;
    end if;
  end process;
  y_out <= reg;
end architecture;
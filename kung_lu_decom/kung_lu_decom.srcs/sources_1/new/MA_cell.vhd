-------------------------------------------------------------------------------
--  ENTITY: MA_cell  (update node)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lu_pkg.all;

entity MA_cell is
  port (
    clk, rst  : in  std_logic;
    valid_in  : in  std_logic;
    a_in      : in  dint;    -- element from EAST
    l_in      : in  dint;    -- multiplier from WEST
    u_in      : in  dint;    -- U entry from NORTH

    a_out     : out dint;    -- updated element to WEST / SOUTH
    l_out     : out dint;    -- forward multiplier downward
    valid_out : out std_logic
  );
end entity;

architecture rtl of MA_cell is
begin
  process(clk)
    variable res : signed(2*W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst='1' then
        a_out     <= (others=>'0');
        l_out     <= (others=>'0');
        valid_out <= '0';
      elsif valid_in='1' then
        res := resize(a_in, 2*W) - resize(l_in, 2*W) * resize(u_in, 2*W);
        a_out <= resize(res, W);
        l_out <= l_in;
        valid_out <= '1';
      else
        valid_out <= '0';
      end if;
    end if;
  end process;
end architecture;
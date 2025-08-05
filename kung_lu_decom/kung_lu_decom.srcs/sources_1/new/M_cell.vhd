-------------------------------------------------------------------------------
--  ENTITY: M_cell  (pivot node)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lu_pkg.all;

entity M_cell is
  port (
    clk, rst  : in  std_logic;
    valid_in  : in  std_logic;
    a_in      : in  dint;       -- element from EAST

    u_out     : out dint;       -- to WEST (U)
    l_out     : out dint;       -- to SOUTH (L multipliers)
    valid_out : out std_logic
  );
end entity;

architecture rtl of M_cell is
  signal pivot_set : std_logic := '0';
  signal pivot_reg : dint      := (others=>'0');
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        pivot_set <= '0';
        pivot_reg <= (others=>'0');
        u_out     <= (others=>'0');
        l_out     <= (others=>'0');
        valid_out <= '0';

      elsif valid_in='1' then
        valid_out <= '1';
        if pivot_set='0' then         -- first arrival → pivot
          pivot_reg <= a_in;
          pivot_set <= '1';
          u_out     <= a_in;          -- send pivot left
          l_out     <= (others=>'0'); -- NO multiplier yet!
        else
          u_out <= a_in;              -- pass upper‑triangular entry
          if pivot_reg /= 0 then
            l_out <= resize(a_in / pivot_reg, W); -- integer divide
          else
            l_out <= (others=>'0');   -- singular pivot
          end if;
        end if;
      else
        valid_out <= '0';
      end if;
    end if;
  end process;
end architecture;

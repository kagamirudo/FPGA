library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.lu_pkg.all;

entity Div_cell is
  port (
    clk, rst : in std_logic;
    data_in  : in dint;
    y_out    : out dint
  );
end entity;

architecture rtl of Div_cell is
  -- Use base signed type for clean compatibility with fixed_div ports
  signal constant_one : signed(W - 1 downto 0) := to_signed(1, W);
  signal y_out_s      : signed(W - 1 downto 0);
  signal div0         : std_logic;
begin
  div_inst : entity work.fixed_div
    generic map(W => W, F => 5) -- set F as needed
    port map
    (
      clk => clk, rst => rst,
      num  => constant_one,
      den  => signed(data_in),
      quot => y_out_s,
      div0 => div0
    );

  -- Cast back to package subtype for external port
  y_out <= dint(y_out_s);

end architecture;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lu_pkg.all;

-- Wrapper top compatible with the provided TCL force script
-- Exposes ports: ck, reset, a[0..6]
entity lu is
  port (
    ck     : in std_logic;
    reset  : in std_logic;
    a      : in dint_vec(0 to 2 * (N - 1));
    L_out  : out dint_vec(1 to N - 1);
    U_out  : out dint_vec(0 to N - 1);
    ps_dbg : out dint_mat(0 to N - 1, 0 to N - 1)
  );
end entity lu;

architecture rtl of lu is
  -- Helper to render signed value as integer string
  function s2i(s : signed) return string is
  begin
    return integer'image(to_integer(s));
  end function;
  -- Internal copies for debug (avoid reading out ports)
  signal ps_dbg_s : dint_mat(0 to N - 1, 0 to N - 1);
  signal L_out_s  : dint_vec(1 to N - 1);
  signal U_out_s  : dint_vec(0 to N - 1);

  procedure print_outputs(prefix : string; l_vec : dint_vec; u_vec : dint_vec) is
    variable i : integer;
  begin
    for i in 1 to N - 1 loop
      report prefix & " L(" & integer'image(i) & ")=" &
        integer'image(to_integer(signed(l_vec(i)))) severity note;
    end loop;
    for i in 0 to N - 1 loop
      report prefix & " U(" & integer'image(i) & ")=" &
        integer'image(to_integer(signed(u_vec(i)))) severity note;
    end loop;
  end procedure;
begin
  dut : entity work.lu_array4x4
    generic map(n => N)
    port map
    (
      clk    => ck,
      rst    => reset,
      a_in   => a,
      L_out  => L_out_s,
      U_out  => U_out_s,
      ps_dbg => ps_dbg_s
    );

  -- Drive outward-facing debug port
  ps_dbg <= ps_dbg_s;
  L_out <= L_out_s;
  U_out <= U_out_s;

  -- Simple monitor: report inputs and outputs every rising clock
  monitor : process (ck)
    variable cyc : integer := 0;
    variable i   : integer;
    variable ii  : integer;
    variable jj  : integer;
  begin
    if rising_edge(ck) then
      cyc := cyc + 1;
      report "[cyc=" & integer'image(cyc) & "] reset=" & std_logic'image(reset) severity note;

      -- Print inputs per-lane
      for i in a'range loop
        report "a(" & integer'image(i) & ")=" & integer'image(to_integer(signed(a(i)))) severity note;
      end loop;

      -- Print outputs
      print_outputs("outputs", L_out_s, U_out_s);

      -- Print ps matrix for debug
      for ii in 0 to N - 1 loop
        for jj in 0 to N - 1 loop
          report "ps(" & integer'image(ii) & "," & integer'image(jj) & ")=" &
            integer'image(to_integer(signed(ps_dbg_s(ii, jj)))) severity note;
        end loop;
      end loop;
    end if;
  end process;
end architecture rtl;

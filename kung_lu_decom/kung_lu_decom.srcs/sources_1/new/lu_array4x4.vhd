-------------------------------------------------------------------------------
--  TOP‑LEVEL: lu_array4x4
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.lu_pkg.all;

entity lu_array4x4 is
  generic (
    n : integer := N
  );
  port (
    clk, rst : in std_logic;
    a_in     : in dint_vec(0 to 2 * (n - 1));

    L_out  : out dint_vec(1 to n - 1);
    U_out  : out dint_vec(0 to n - 1);
    ps_dbg : out dint_mat(0 to n - 1, 0 to n - 1)
  );
end entity;

architecture struct of lu_array4x4 is
  signal x  : dint_mat(1 to n - 1, 1 to n - 1) := (others => (others => (others => '0')));
  signal y  : dint_mat(1 to n - 1, 0 to n - 1) := (others => (others => (others => '0')));
  signal ps : dint_mat(0 to n - 1, 0 to n - 1) := (others => (others => (others => '0')));
begin
  ------------------------------------------------------------------
  -- Injection gates per spec
  ------------------------------------------------------------------
  a_col_injection : for i in 0 to n - 1 generate
    ps(n - 1, i) <= a_in(i);
  end generate;

  a_row_injection : for i in 0 to n - 2 generate
    ps(i, n - 1) <= a_in(2 * (n - 1) - i);
  end generate;

  l_out_injection : for i in 1 to n - 1 generate
    L_out(i) <= ps(i, 1);
  end generate;

  u_out_injection : for i in 0 to n - 1 generate
    U_out(i) <= ps(0, i);
  end generate;

  ------------------------------------------------------------------
  -- Mesh generation
  ------------------------------------------------------------------
  gen_rows : for i in 0 to n - 1 generate
    gen_cols : for j in 0 to n - 1 generate
    begin
      -- divider node: if i = 0 and j = 0 generate
      divider_inst : if i = 0 and j = 0 generate
        divider_inst : entity work.Div_cell
          port map
          (
            clk => clk, rst => rst,
            data_in => ps(i, j),
            y_out   => y(i + 1, j)
          );
      end generate;
      -- 1st column: M_cell at all nodes except divider and last node
      first_col : if j = 0 and i > 0 and i < n - 1 generate
        M_inst : entity work.M_cell
          port map
          (
            clk => clk, rst => rst,
            y_in  => y(i, j),
            ps_in => ps(i, j),
            x_out => x(i, j + 1),
            y_out => y(i + 1, j)
          );
      end generate first_col;
      -- 1st column last node: M_cell
      last_col_node : if j = 0 and i = n - 1 generate
        M_inst : entity work.M_cell
          port map
          (
            clk => clk, rst => rst,
            y_in  => y(i, j),
            ps_in => ps(i, j),
            x_out => x(i, j + 1),
            y_out => open
          );
      end generate last_col_node;
      -- last row: MA_cell at all nodes except last node
      last_row : if i = n - 1 and j > 0 and j < n - 1 generate
        MA_inst : entity work.MA_cell
          port map
          (
            clk => clk, rst => rst,
            x_in   => x(i, j),
            y_in   => y(i, j),
            ps_in  => ps(i, j),
            x_out  => x(i, j + 1),
            y_out  => open,
            ps_out => ps(i - 1, j - 1)
          );
      end generate last_row;
      -- last row's last node: MA_cell
      last_row_node : if i = n - 1 and j = n - 1 generate
        MA_inst : entity work.MA_cell
          port map
          (
            clk => clk, rst => rst,
            x_in   => x(i, j),
            y_in   => y(i, j),
            ps_in  => ps(i, j),
            x_out  => open,
            y_out  => open,
            ps_out => ps(i - 1, j - 1)
          );
      end generate last_row_node;
      -- last column inner node: MA_cell
      last_col : if j = n - 1 and i > 0 and i < n - 1 generate
        MA_inst : entity work.MA_cell
          port map
          (
            clk => clk, rst => rst,
            x_in   => x(i, j),
            y_in   => y(i, j),
            ps_in  => ps(i, j),
            x_out  => open,
            y_out  => y(i + 1, j),
            ps_out => ps(i - 1, j - 1)
          );
      end generate last_col;
      -- first row or last column's first node: R_cell
      first_row : if i = 0 and j > 0 and j < n generate
        R_inst : entity work.R_cell
          port map
          (
            clk => clk, rst => rst,
            ps_in => ps(i, j),
            y_out => y(i + 1, j)
          );
      end generate first_row;
      -- inner node: MA_cell
      inner_node : if i > 0 and i < n - 1 and j > 0 and j < n - 1 generate
        MA_inst : entity work.MA_cell
          port map
          (
            clk => clk, rst => rst,
            x_in   => x(i, j),
            y_in   => y(i, j),
            ps_in  => ps(i, j),
            x_out  => x(i, j + 1),
            y_out  => y(i + 1, j),
            ps_out => ps(i - 1, j - 1)
          );
      end generate inner_node;
    end generate gen_cols;
  end generate gen_rows;

  -- Debug wiring: expose internal ps matrix
  ps_dbg <= ps;
end architecture;
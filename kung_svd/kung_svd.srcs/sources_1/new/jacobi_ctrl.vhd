----------------------------------------------------------------------------
--  One‑sided Jacobi Controller (column‑pair schedule)
--  Generates (c, s) Givens parameters that orthogonalise column pairs in
--  the systolic grid.  Truncated fixed‑iteration schedule: every sweep
--  visits pairs (0,1) (2,3) … then (1,2) (3,4) …  Total SWEEPS generic.
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.svd_pkg.all;

entity jacobi_ctrl is
  generic (
    COLS   : integer := 8;
    DATA_W : integer := DATA_WIDTH;
    SWEEPS : integer := 8 -- Jacobi sweeps before we assert DONE
  );
  port (
    clk   : in std_logic;
    rst_n : in std_logic;
    start : in std_logic;
    done  : out std_logic;
    -- stream of matrix columns (two at a time) from array edge
    ain : in data_t; -- a = A(col_pivot , row)
    bin : in data_t; -- b = A(col_pivot+1 , row)
    -- rotation parameters broadcast back into the grid
    c_out : out data_t;
    s_out : out data_t
  );
end entity jacobi_ctrl;

architecture rtl of jacobi_ctrl is
  --------------------------------------------------------------------------
  -- Fixed‑point CORDIC to compute cos/sin(θ) where tanθ = b/a
  --------------------------------------------------------------------------
  component cordic_rot
    generic (
      W    : integer := DATA_WIDTH;
      ITER : integer := DATA_WIDTH - 2
    );
    port (
      clk       : in std_logic;
      rst_n     : in std_logic;
      start     : in std_logic;  -- Start new computation
      x_in      : in data_t;
      y_in      : in data_t;
      x_out     : out data_t; -- cos
      y_out     : out data_t; -- sin
      valid_out : out std_logic
    );
  end component;

  signal sweep_cnt          : integer range 0 to SWEEPS   := 0;
  signal pair_idx           : integer range 0 to COLS - 2 := 0;
  signal busy               : std_logic                   := '0';
  signal cordic_c, cordic_s : data_t;
  signal cordic_valid       : std_logic;
  signal cordic_start       : std_logic                   := '0';
begin
  ------------------------------------------------------------------
  -- Controller FSM: IDLE → PAIR → CORDIC → BROADCAST → next pair
  ------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        sweep_cnt <= 0;
        pair_idx  <= 0;
        busy      <= '0';
        done      <= '0';
      else
        done <= '0';
        if start = '1' and busy = '0' then
          busy      <= '1';
          sweep_cnt <= 0;
          pair_idx  <= 0;
          cordic_start <= '1';
          report "Jacobi Controller: Starting computation" severity note;
        elsif busy = '1' then
          cordic_start <= '0';
          -- iterate over column pairs
          if cordic_valid = '1' then
            -- broadcast C,S for one full column (array consumes)
            c_out <= cordic_c;
            s_out <= cordic_s;
            report "Jacobi Controller: Received CORDIC result, pair_idx=" & integer'image(pair_idx) & 
                   ", sweep_cnt=" & integer'image(sweep_cnt) severity note;
            if pair_idx < COLS - 2 then
              pair_idx <= pair_idx + 2;
              cordic_start <= '1';  -- Start next CORDIC computation
            else
              pair_idx  <= 1;
              sweep_cnt <= sweep_cnt + 1;
              report "Jacobi Controller: Completed sweep " & integer'image(sweep_cnt) severity note;
              if sweep_cnt = SWEEPS - 1 then
                busy <= '0';
                done <= '1';
                report "Jacobi Controller: Computation completed" severity note;
              else
                cordic_start <= '1';  -- Start next CORDIC computation for next sweep
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------
  -- Instantiate CORDIC to get (c,s) from (a,b)
  ------------------------------------------------------------------
  u_cordic : cordic_rot
  generic map(W => DATA_WIDTH)
  port map
  (
    clk       => clk,
    rst_n     => rst_n,
    start     => cordic_start,
    x_in      => ain,
    y_in      => bin,
    x_out     => cordic_c,
    y_out     => cordic_s,
    valid_out => cordic_valid
  );
end architecture rtl;
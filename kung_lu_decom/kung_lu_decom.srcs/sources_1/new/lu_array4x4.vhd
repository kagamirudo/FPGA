-------------------------------------------------------------------------------
--  TOP‑LEVEL: lu_array4x4
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lu_pkg.all;

entity lu_array4x4 is
    port (
      clk, rst : in  std_logic;
      a_in     : in  dint;      -- serial input (east edge)
      valid_in : in  std_logic;
  
      L_out     : out dint;     -- first column of L on south edge
      U_out     : out dint;     -- not used (placeholder)
      valid_out : out std_logic
    );
  end entity;
  
  architecture struct of lu_array4x4 is
    ------------------------------------------------------------------
    -- Nested array types from package -> row major mesh_t
    ------------------------------------------------------------------
    -- Signals for inter‑PE links.  Indexing:  row r (1..4), col c (1..4)
    -- EAST/WEST data runs right→left;  NORTH/SOUTH runs top→bottom.
    type dint_vec is array(0 to 5, 0 to 4) of dint;
    type bit_vec is array(0 to 5, 0 to 4) of std_logic;
    signal east_to_west   : dint_vec;
    signal north_to_south : dint_vec;
    signal v_e2w, v_n2s   : bit_vec;
  begin
    ------------------------------------------------------------------
    -- EAST input: only top row (r=1) gets the stream.
    ------------------------------------------------------------------
    east_to_west(1, 4) <= a_in;
    v_e2w(1, 4)        <= valid_in;
  
    feed_other_rows : for r in 2 to 4 generate
      east_to_west(r, 4) <= (others=>'0');
      v_e2w(r, 4)        <= '0';
    end generate feed_other_rows;
  
    ------------------------------------------------------------------
    -- Mesh generation
    ------------------------------------------------------------------
    gen_rows : for r in 1 to 4 generate
      gen_cols : for c in 1 to 4 generate
        constant diag : boolean := (r = c);
      begin
        -- Cells above diagonal are just wires
        skip_above_diag : if r < c generate
          east_to_west(r, c-1)   <= east_to_west(r, c);
          v_e2w(r, c-1)          <= v_e2w(r, c);
          north_to_south(r+1, c) <= north_to_south(r, c);
          v_n2s(r+1, c)          <= v_n2s(r, c);
        end generate skip_above_diag;
  
        -- Diagonal cell
        m_diag_cell : if diag generate
          M_inst : entity work.M_cell
            port map(
              clk => clk, rst => rst,
              valid_in  => v_e2w(r, c),
              a_in      => east_to_west(r, c),
              u_out     => east_to_west(r, c-1),
              l_out     => north_to_south(r+1, c),
              valid_out => v_e2w(r, c-1)
            );
          v_n2s(r+1, c) <= v_e2w(r, c);
        end generate m_diag_cell;
  
        -- Below‑diagonal update cell
        ma_below_diag : if r > c generate
          MA_inst : entity work.MA_cell
            port map(
              clk => clk, rst => rst,
              valid_in  => v_e2w(r, c),
              a_in      => east_to_west(r, c),
              l_in      => north_to_south(r, c),
              u_in      => east_to_west(r-1, c),
              a_out     => east_to_west(r, c-1),
              l_out     => north_to_south(r+1, c),
              valid_out => v_e2w(r, c-1)
            );
          v_n2s(r+1, c) <= v_e2w(r, c);
        end generate ma_below_diag;
      end generate gen_cols;
    end generate gen_rows;
  
    ------------------------------------------------------------------
    -- SOUTH edge outputs (row 4)
    ------------------------------------------------------------------
    -- South edge taps come from row index 5 (output of bottom PEs)
    L_out     <= north_to_south(4, 1);  -- first column of L
    U_out     <= east_to_west(4, 0);    -- optional
    valid_out <= v_n2s(4, 1);
  end architecture;
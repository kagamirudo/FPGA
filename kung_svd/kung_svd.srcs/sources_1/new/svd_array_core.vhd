----------------------------------------------------------------------------
-- svd_array_core.vhd
--
-- Thin wrapper that exposes svd_jacobi_top under the pre-existing
-- `svd_array` entity name/port list, so svd_axi_stream and the Vivado
-- project continue to compile without edits.
--
-- The previous full-grid broadcast design (3 algorithmic deviations
-- from one-sided Jacobi SVD, see docs/svd_algorithm_review.md) has
-- been replaced. The new orchestrator uses:
--
--   svd_gram          -> alpha, beta, gamma for a column pair
--   svd_angle_cordic  -> (cos theta, sin theta) with theta = (1/2) *
--                        atan2(2 gamma, alpha - beta)
--   svd_pe (reused)   -> one row of a 2-column Givens rotation
--
-- Status: UNTESTED. Requires GHDL or Vivado to verify numerically.
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

entity svd_array is
  generic (
    ROWS   : integer := 8;
    COLS   : integer := 8;
    DATA_W : integer := DATA_WIDTH
  );
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;

    -- streaming input (row-major)
    din_valid  : in  std_logic;
    din        : in  data_t;
    din_last   : in  std_logic;

    -- streaming output
    dout_ready : in  std_logic;
    dout       : out data_t;
    dout_valid : out std_logic;
    dout_last  : out std_logic;

    -- tile-level handshake
    start      : in  std_logic;
    done       : out std_logic
  );
end entity svd_array;

architecture rtl of svd_array is
begin
  u_jacobi : entity work.svd_jacobi_top
    generic map (
      DATA_W => DATA_W,
      ROWS   => ROWS,
      COLS   => COLS,
      -- Cyclic Jacobi convergence: 8 sweeps at N=8, scales roughly linearly.
      -- Empirical: N=16 needs ~16 sweeps to meet 2^-10 tolerance.
      SWEEPS => COLS
    )
    port map (
      clk        => clk,
      rst_n      => rst_n,
      din_valid  => din_valid,
      din        => din,
      start      => start,
      done       => done,
      dout_ready => dout_ready,
      dout       => dout,
      dout_valid => dout_valid,
      dout_last  => dout_last
    );
  -- din_last is unused; the orchestrator counts words internally.
end architecture rtl;

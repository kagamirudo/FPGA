----------------------------------------------------------------------------
-- svd_array_core.vhd
--
-- Thin wrapper that exposes either the BLV grid (`svd_jacobi_blv`,
-- default) or the single-pair serializer (`svd_jacobi_top`) under the
-- pre-existing `svd_array` entity name/port list. The AXI stream
-- wrapper and the Vivado project continue to compile unchanged.
--
--   USE_BLV = true  (default): N/2 parallel pair pipelines running the
--                              Brent-Luk-Van Loan round-robin schedule.
--                              Numbers: 1.9x / 3.85x / 7.7x speedup at
--                              N=4/8/16 vs. the serializer. See
--                              docs/scale_study.md section 2.
--
--   USE_BLV = false:           Original 1-pipeline serializer; kept for
--                              A/B comparison and regression gating.
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

entity svd_array is
  generic (
    ROWS    : integer := 8;
    COLS    : integer := 8;
    DATA_W  : integer := DATA_WIDTH;
    USE_BLV : boolean := true
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
  gen_blv : if USE_BLV generate
    u_blv : entity work.svd_jacobi_blv
      generic map (
        DATA_W => DATA_W,
        ROWS   => ROWS,
        COLS   => COLS,
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
  end generate;

  gen_serial : if not USE_BLV generate
    u_serial : entity work.svd_jacobi_top
      generic map (
        DATA_W => DATA_W,
        ROWS   => ROWS,
        COLS   => COLS,
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
  end generate;
  -- din_last is unused; the orchestrator counts words internally.
end architecture rtl;

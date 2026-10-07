----------------------------------------------------------------------------
-- svd_array_axis32.vhd
--
-- 32-bit AXI4-Stream packaging wrapper around svd_array_top (18-bit Q1.16).
-- Lower 18 bits carry the payload; upper bits are ignored on input and
-- driven to zero on output. Intended as the Vivado IP / AXI DMA top.
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.svd_pkg.all;

entity svd_array_axis32 is
  generic (
    ROWS    : integer := 8;
    COLS    : integer := 8;
    USE_BLV : boolean := true
  );
  port (
    aclk    : in  std_logic;
    aresetn : in  std_logic;

    -- Slave AXI4-Stream (from DMA MM2S)
    s_axis_tdata  : in  std_logic_vector(31 downto 0);
    s_axis_tvalid : in  std_logic;
    s_axis_tlast  : in  std_logic;
    s_axis_tready : out std_logic;

    -- Master AXI4-Stream (to DMA S2MM)
    m_axis_tdata  : out std_logic_vector(31 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tlast  : out std_logic;
    m_axis_tready : in  std_logic
  );
end entity;

architecture rtl of svd_array_axis32 is
  signal core_m_tdata : std_logic_vector(DATA_WIDTH - 1 downto 0);
begin
  u_core : entity work.svd_array_top
    generic map (
      ROWS    => ROWS,
      COLS    => COLS,
      DATA_W  => DATA_WIDTH,
      USE_BLV => USE_BLV
    )
    port map (
      aclk          => aclk,
      aresetn       => aresetn,
      s_axis_tdata  => s_axis_tdata(DATA_WIDTH - 1 downto 0),
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tlast  => s_axis_tlast,
      s_axis_tready => s_axis_tready,
      m_axis_tdata  => core_m_tdata,
      m_axis_tvalid => m_axis_tvalid,
      m_axis_tlast  => m_axis_tlast,
      m_axis_tready => m_axis_tready
    );

  m_axis_tdata <= std_logic_vector(resize(signed(core_m_tdata), 32));
end architecture;

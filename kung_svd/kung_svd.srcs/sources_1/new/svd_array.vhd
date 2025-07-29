library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

-- =========================================================================
--  SVD Array Top-Level Wrapper
--  This is the main top-level entity for the SVD systolic array
-- =========================================================================

entity svd_array_top is
  generic (
    ROWS   : integer := 8;
    COLS   : integer := 8;
    DATA_W : integer := DATA_WIDTH
  );
  port (
    -- Global
    aclk    : in std_logic;
    aresetn : in std_logic;

    -- Slave input stream
    s_axis_tdata  : in std_logic_vector(DATA_W - 1 downto 0);
    s_axis_tvalid : in std_logic;
    s_axis_tlast  : in std_logic;
    s_axis_tready : out std_logic;

    -- Master output stream
    m_axis_tdata  : out std_logic_vector(DATA_W - 1 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tlast  : out std_logic;
    m_axis_tready : in std_logic
  );
end svd_array_top;

architecture Behavioral of svd_array_top is
begin
  -- Instantiate the AXI-Stream wrapper
  u_axi_stream : entity work.svd_axi_stream
    generic map(
      ROWS   => ROWS,
      COLS   => COLS,
      DATA_W => DATA_W
    )
    port map
    (
      aclk          => aclk,
      aresetn       => aresetn,
      s_axis_tdata  => s_axis_tdata,
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tlast  => s_axis_tlast,
      s_axis_tready => s_axis_tready,
      m_axis_tdata  => m_axis_tdata,
      m_axis_tvalid => m_axis_tvalid,
      m_axis_tlast  => m_axis_tlast,
      m_axis_tready => m_axis_tready
    );
end Behavioral;

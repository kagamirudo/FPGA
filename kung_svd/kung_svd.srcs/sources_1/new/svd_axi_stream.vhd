----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/29/2025 07:29:24 AM
-- Design Name: 
-- Module Name: svd_axi_stream - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

----------------------------------------------------------------------------
--  AXI4‑Stream wrapper (minimal control FSM)
----------------------------------------------------------------------------
entity svd_axi_stream is
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
end svd_axi_stream;

architecture rtl of svd_axi_stream is
  type state_t is (IDLE, LOAD, COMPUTE, DRAIN);
  signal state, n_state : state_t;

  constant TOTAL_WORDS : natural := ROWS * COLS;
  signal load_cnt      : natural range 0 to TOTAL_WORDS;

  -- Core signals
  signal core_din_valid, core_dout_ready : std_logic;
  signal core_din_last, core_dout_last   : std_logic;
  signal core_dout_valid                 : std_logic;
  signal core_din                        : data_t;
  signal core_dout                       : data_t;
  signal core_start, core_done           : std_logic;

  -- Internal signals for output ports
  signal s_axis_tready_int : std_logic;

  signal rst_n : std_logic;
begin
  rst_n <= aresetn;

  ------------------------------------------------------------------
  -- Instantiate SVD core
  ------------------------------------------------------------------
  u_core : entity work.svd_array
    generic map(
      ROWS   => ROWS,
      COLS   => COLS,
      DATA_W => DATA_W
    )
    port map
    (
      clk        => aclk,
      rst_n      => rst_n,
      din_valid  => core_din_valid,
      din        => core_din,
      din_last   => core_din_last,
      dout_ready => core_dout_ready,
      dout       => core_dout,
      dout_valid => core_dout_valid,
      dout_last  => core_dout_last,
      start      => core_start,
      done       => core_done
    );

  ------------------------------------------------------------------
  -- State register
  ------------------------------------------------------------------
  process (aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        state    <= IDLE;
        load_cnt <= 0;
      else
        state <= n_state;
        if state = LOAD and s_axis_tvalid = '1' and s_axis_tready_int = '1' then
          load_cnt <= load_cnt + 1;
        elsif state = IDLE then
          load_cnt <= 0;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------
  -- Next‑state / output logic
  ------------------------------------------------------------------
  process (state, s_axis_tvalid, s_axis_tlast, core_done, m_axis_tready, core_dout_valid, core_dout_last)
  begin
    -- defaults
    n_state           <= state;
    core_start        <= '0';
    s_axis_tready_int <= '0';
    core_din_valid    <= '0';
    core_din_last     <= '0';
    core_dout_ready   <= m_axis_tready;

    case state is
      when IDLE =>
        if s_axis_tvalid = '1' then
          n_state <= LOAD;
        end if;

      when LOAD =>
        s_axis_tready_int <= '1';
        core_din_valid    <= s_axis_tvalid;
        core_din_last     <= s_axis_tlast;
        if s_axis_tvalid = '1' and s_axis_tready_int = '1' and s_axis_tlast = '1' then
          core_start <= '1';
          n_state    <= COMPUTE;
        end if;

      when COMPUTE =>
        -- Wait for computation to complete
        if core_done = '1' then
          n_state <= DRAIN;
        end if;

      when DRAIN =>
        -- Pass through output data from core
        core_dout_ready <= m_axis_tready;
        -- Stay in DRAIN until all data is output
        if core_dout_valid = '1' and core_dout_last = '1' and m_axis_tready = '1' then
          n_state <= IDLE;
        end if;
    end case;
  end process;

  ------------------------------------------------------------------
  -- Stream mapping
  ------------------------------------------------------------------
  core_din      <= signed(s_axis_tdata);
  m_axis_tdata  <= std_logic_vector(core_dout);
  m_axis_tvalid <= core_dout_valid;
  m_axis_tlast  <= core_dout_last;
  s_axis_tready <= s_axis_tready_int;

end architecture rtl;

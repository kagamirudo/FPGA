library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

----------------------------------------------------------------------------
--  ROWS×COLS systolic grid with Jacobi Controller
----------------------------------------------------------------------------
entity svd_array is
  generic (
    ROWS   : integer := 8;
    COLS   : integer := 8;
    DATA_W : integer := DATA_WIDTH
  );
  port (
    clk   : in std_logic;
    rst_n : in std_logic;

    -- streaming input (row‑major order)
    din_valid : in std_logic;
    din       : in data_t;
    din_last  : in std_logic;

    -- streaming output
    dout_ready : in std_logic;
    dout       : out data_t;
    dout_valid : out std_logic;
    dout_last  : out std_logic;

    -- tile‑level handshake
    start : in std_logic;
    done  : out std_logic
  );
end svd_array;

architecture Behavioral of svd_array is
  type data_mat is array (natural range <>, natural range <>) of data_t;
  signal a_bus, b_bus, c_bus, s_bus : data_mat(0 to ROWS, 0 to COLS);
  
  -- Controller signals
  signal ctrl_start, ctrl_done : std_logic;
  signal ctrl_ain, ctrl_bin    : data_t;
  signal ctrl_c, ctrl_s        : data_t;
  
  -- Matrix edge signals for controller input
  signal edge_a, edge_b : data_t;
begin
  --------------------------------------------------------------------------
  -- PE grid generation
  --------------------------------------------------------------------------
  gen_row : for i in 0 to ROWS - 1 generate
    gen_col : for j in 0 to COLS - 1 generate
      u_pe : entity work.svd_pe
        generic map(DATA_W => DATA_W)
        port map
        (
          clk   => clk,
          rst_n => rst_n,
          a_in  => a_bus(i, j),
          b_in  => b_bus(i, j),
          c_in  => c_bus(i, j),
          s_in  => s_bus(i, j),
          a_out => a_bus(i + 1, j),
          b_out => b_bus(i, j + 1),
          c_out => c_bus(i, j + 1),
          s_out => s_bus(i + 1, j)
        );
    end generate;
  end generate;

  --------------------------------------------------------------------------
  -- Instantiate Jacobi Controller
  --------------------------------------------------------------------------
  u_ctrl : entity work.jacobi_ctrl
    generic map(
      COLS   => COLS,
      DATA_W => DATA_W,
      SWEEPS => 8
    )
    port map(
      clk    => clk,
      rst_n  => rst_n,
      start  => ctrl_start,
      done   => ctrl_done,
      ain    => ctrl_ain,
      bin    => ctrl_bin,
      c_out  => ctrl_c,
      s_out  => ctrl_s
    );

  --------------------------------------------------------------------------
  -- Controller Integration Logic
  --------------------------------------------------------------------------
  -- Connect controller to matrix edge
  ctrl_ain <= a_bus(0, 0);  -- Top-left element
  ctrl_bin <= a_bus(0, 1);  -- Top-left+1 element
  
  -- Broadcast controller outputs to all PEs
  gen_ctrl_row : for i in 0 to ROWS - 1 generate
    gen_ctrl_col : for j in 0 to COLS - 1 generate
      c_bus(i, j) <= ctrl_c;
      s_bus(i, j) <= ctrl_s;
    end generate;
  end generate;

  --------------------------------------------------------------------------
  -- Control Logic
  --------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        ctrl_start <= '0';
        done       <= '0';
      else
        ctrl_start <= start;
        done       <= ctrl_done;
      end if;
    end if;
  end process;

  -- TODO: implement I/O muxing for matrix loading/unloading
  dout       <= (others => '0');
  dout_valid <= '0';
  dout_last  <= '0';
end Behavioral; 
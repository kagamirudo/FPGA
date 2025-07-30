library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

----------------------------------------------------------------------------
--  ROWS×COLS systolic grid with Jacobi Controller and I/O
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

  -- I/O Control signals
  type io_state_t is (IDLE, LOAD, COMPUTE, UNLOAD);
  signal io_state, io_next_state         : io_state_t;
  signal load_cnt, unload_cnt            : integer range 0 to ROWS * COLS;
  signal matrix_loaded, computation_done : std_logic;

  -- Matrix storage for loading/unloading
  signal input_matrix  : data_mat(0 to ROWS - 1, 0 to COLS - 1);
  signal output_matrix : data_mat(0 to ROWS - 1, 0 to COLS - 1);

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
    port map
    (
      clk   => clk,
      rst_n => rst_n,
      start => ctrl_start,
      done  => ctrl_done,
      ain   => ctrl_ain,
      bin   => ctrl_bin,
      c_out => ctrl_c,
      s_out => ctrl_s
    );

  --------------------------------------------------------------------------
  -- Controller Integration Logic
  --------------------------------------------------------------------------
  -- Connect controller to matrix edge
  ctrl_ain <= a_bus(0, 0); -- Top-left element
  ctrl_bin <= a_bus(0, 1); -- Top-left+1 element

  -- Broadcast controller outputs to all PEs
  gen_ctrl_row : for i in 0 to ROWS - 1 generate
    gen_ctrl_col : for j in 0 to COLS - 1 generate
      c_bus(i, j) <= ctrl_c;
      s_bus(i, j) <= ctrl_s;
    end generate;
  end generate;

  --------------------------------------------------------------------------
  -- I/O State Machine
  --------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        io_state         <= IDLE;
        load_cnt         <= 0;
        unload_cnt       <= 0;
        matrix_loaded    <= '0';
        computation_done <= '0';
      else
        io_state <= io_next_state;

        case io_state is
          when IDLE =>
            load_cnt         <= 0;
            unload_cnt       <= 0;
            matrix_loaded    <= '0';
            computation_done <= '0';

          when LOAD =>
            if din_valid = '1' then
              -- Store input data in matrix (row-major order)
              input_matrix(load_cnt / COLS, load_cnt mod COLS) <= din;
              load_cnt                                         <= load_cnt + 1;
              if load_cnt = ROWS * COLS - 1 then
                matrix_loaded <= '1';
                report "Matrix loaded successfully" severity note;
              end if;
            end if;

          when COMPUTE =>
            -- Matrix is loaded, computation happens in systolic array
            if ctrl_done = '1' then
              computation_done <= '1';
              report "Computation completed" severity note;
            end if;

          when UNLOAD =>
            if dout_ready = '1' then
              unload_cnt <= unload_cnt + 1;
              if unload_cnt = 0 then
                report "Starting to unload results" severity note;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Next State Logic
  --------------------------------------------------------------------------
  process (io_state, din_valid, din_last, matrix_loaded, computation_done, dout_ready, unload_cnt)
  begin
    io_next_state <= io_state;

    case io_state is
      when IDLE =>
        if din_valid = '1' then
          io_next_state <= LOAD;
        end if;

      when LOAD =>
        if din_last = '1' and din_valid = '1' then
          io_next_state <= COMPUTE;
        end if;

      when COMPUTE =>
        if computation_done = '1' then
          io_next_state <= UNLOAD;
        end if;

      when UNLOAD =>
        if unload_cnt = ROWS * COLS - 1 and dout_ready = '1' then
          io_next_state <= IDLE;
        end if;
    end case;
  end process;

  --------------------------------------------------------------------------
  -- Matrix Loading into Systolic Array
  --------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        -- Initialize systolic array buses
        for i in 0 to ROWS loop
          for j in 0 to COLS loop
            a_bus(i, j) <= (others => '0');
            b_bus(i, j) <= (others => '0');
          end loop;
        end loop;
      elsif io_state = LOAD and matrix_loaded = '1' then
        -- Load matrix into systolic array
        for i in 0 to ROWS - 1 loop
          for j in 0 to COLS - 1 loop
            a_bus(i, j) <= input_matrix(i, j);
            b_bus(i, j) <= input_matrix(i, j);
          end loop;
        end loop;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Matrix Unloading from Systolic Array
  --------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        -- Initialize output matrix
        for i in 0 to ROWS - 1 loop
          for j in 0 to COLS - 1 loop
            output_matrix(i, j) <= (others => '0');
          end loop;
        end loop;
      elsif io_state = COMPUTE and computation_done = '1' then
        -- Capture results from systolic array
        for i in 0 to ROWS - 1 loop
          for j in 0 to COLS - 1 loop
            output_matrix(i, j) <= a_bus(i + 1, j);
          end loop;
        end loop;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Output Logic
  --------------------------------------------------------------------------
  process (io_state, unload_cnt, output_matrix, dout_ready)
  begin
    dout_valid <= '0';
    dout_last  <= '0';
    dout       <= (others => '0');

    if io_state = UNLOAD then
      dout_valid <= '1';
      -- Output matrix in row-major order
      dout <= output_matrix(unload_cnt / COLS, unload_cnt mod COLS);

      if unload_cnt = ROWS * COLS - 1 then
        dout_last <= '1';
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Debug: Add some debug signals to help understand the flow
  --------------------------------------------------------------------------
  -- These signals can be monitored in simulation
  -- signal debug_io_state : io_state_t;
  -- signal debug_load_cnt : integer;
  -- signal debug_unload_cnt : integer;
  -- debug_io_state <= io_state;
  -- debug_load_cnt <= load_cnt;
  -- debug_unload_cnt <= unload_cnt;

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
        -- Start controller when matrix is loaded
        if io_state = LOAD and matrix_loaded = '1' then
          ctrl_start <= '1';
        else
          ctrl_start <= '0';
        end if;

        -- Signal completion when unloading is done
        if io_state = UNLOAD and unload_cnt = ROWS * COLS - 1 and dout_ready = '1' then
          done <= '1';
        else
          done <= '0';
        end if;
      end if;
    end if;
  end process;

end Behavioral;
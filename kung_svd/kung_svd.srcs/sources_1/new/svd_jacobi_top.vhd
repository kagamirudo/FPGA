----------------------------------------------------------------------------
-- svd_jacobi_top.vhd
--
-- One-sided Jacobi SVD orchestrator.
--
-- Holds the full N x N matrix in a register file (signal array). Per
-- column-pair (p, q):
--
--   GRAM     : stream rows into svd_gram -> alpha, beta, gamma.
--   CORDIC   : feed (alpha - beta, 2 * gamma) into svd_angle_cordic
--              -> (c, s) with theta = 0.5 * atan2(2 gamma, alpha - beta).
--   APPLY    : for each row i, compute
--                A(i,p) <-  c*A(i,p) + s*A(i,q)
--                A(i,q) <- -s*A(i,p) + c*A(i,q)
--              using svd_pe. Columns other than p and q hold.
--
-- Pair schedule: cyclic Jacobi, each sweep visits
--   (0,1)(2,3)(4,5)(6,7)  then  (0,2)(4,6) ... up to all C(N,2) pairs.
-- Current implementation enumerates all distinct pairs lexicographically
-- (p < q), SWEEPS times. For N=8 that is 28 pairs per sweep.
--
-- Convergence: fixed SWEEPS. The off-diagonal Frobenius norm is
-- reported each sweep as a VHDL `report` so the testbench log is
-- enough to see convergence.
--
-- Output (post-DONE): columns of A are drained row-major. The caller
-- (testbench) treats each column's L2 norm as the singular value for
-- that column; after sorting (done in SW), these should match
-- svd_sigma.mem within tolerance.
--
-- Status: UNTESTED.
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

entity svd_jacobi_top is
  generic (
    DATA_W : integer := DATA_WIDTH;
    ROWS   : integer := 8;
    COLS   : integer := 8;
    SWEEPS : integer := 8
  );
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;

    -- Input: row-major stream (ROWS*COLS words).
    din_valid  : in  std_logic;
    din        : in  data_t;

    -- Begin computation after all words are loaded.
    start      : in  std_logic;
    done       : out std_logic;

    -- Output: row-major stream of the final A matrix.
    dout_ready : in  std_logic;
    dout       : out data_t;
    dout_valid : out std_logic;
    dout_last  : out std_logic
  );
end entity svd_jacobi_top;

architecture rtl of svd_jacobi_top is
  type   mat_t is array (0 to ROWS-1, 0 to COLS-1) of data_t;
  signal A : mat_t;

  type ctrl_state_t is (
    LOAD_WAIT, PAIR_PICK, GRAM_RUN, GRAM_WAIT,
    CORDIC_RUN, CORDIC_WAIT, APPLY_RUN, APPLY_WAIT,
    NEXT_PAIR, SWEEP_DONE, DRAIN_START, DRAIN
  );
  signal state : ctrl_state_t;

  signal load_cnt      : integer range 0 to ROWS*COLS;
  signal start_pending : std_logic;
  signal p_idx     : integer range 0 to COLS-1;
  signal q_idx     : integer range 0 to COLS-1;
  signal sweep_cnt : integer range 0 to SWEEPS;
  signal row_cnt   : integer range 0 to ROWS;

  -- svd_gram handshake
  signal gram_start   : std_logic;
  signal gram_a_p     : data_t;
  signal gram_a_q     : data_t;
  signal gram_row_idx : integer range 0 to ROWS;
  signal gram_x_vec   : data_t;
  signal gram_y_vec   : data_t;
  signal gram_skip    : std_logic;
  signal gram_valid   : std_logic;

  -- Diagnostic: pairs skipped per sweep (reported via `report`, non-synth).
  signal skip_cnt_sweep : integer := 0;

  -- CORDIC handshake
  signal cordic_start : std_logic;
  signal cordic_c     : data_t;
  signal cordic_s     : data_t;
  signal cordic_valid : std_logic;

  -- Latched (c, s) for the pair being applied.
  signal c_lat : data_t;
  signal s_lat : data_t;

  -- Drain
  signal drain_cnt : integer range 0 to ROWS*COLS;
begin
  ------------------------------------------------------------------------
  -- svd_gram instance
  ------------------------------------------------------------------------
  u_gram : entity work.svd_gram
    generic map (DATA_W => DATA_W, ROWS => ROWS)
    port map (
      clk       => clk,
      rst_n     => rst_n,
      start     => gram_start,
      a_p       => gram_a_p,
      a_q       => gram_a_q,
      row_idx   => gram_row_idx,
      x_vec     => gram_x_vec,
      y_vec     => gram_y_vec,
      skip      => gram_skip,
      valid_out => gram_valid
    );

  ------------------------------------------------------------------------
  -- svd_angle_cordic instance
  ------------------------------------------------------------------------
  u_cordic : entity work.svd_angle_cordic
    generic map (W => DATA_W, ITER => 16)
    port map (
      clk       => clk,
      rst_n     => rst_n,
      start     => cordic_start,
      x_vec     => gram_x_vec,
      y_vec     => gram_y_vec,
      c_out     => cordic_c,
      s_out     => cordic_s,
      valid_out => cordic_valid
    );

  ------------------------------------------------------------------------
  -- APPLY uses an inline Givens multiplier so one row per clock
  -- goes in and out without the svd_pe's deeper pipeline. svd_pe
  -- is still available for a future systolic-array sweep variant.
  ------------------------------------------------------------------------

  ------------------------------------------------------------------------
  -- Drive gram inputs with A(row_idx, p) and A(row_idx, q) during GRAM.
  ------------------------------------------------------------------------
  gram_a_p <= A(gram_row_idx, p_idx) when gram_row_idx < ROWS
              else (others => '0');
  gram_a_q <= A(gram_row_idx, q_idx) when gram_row_idx < ROWS
              else (others => '0');

  ------------------------------------------------------------------------
  -- Main FSM
  ------------------------------------------------------------------------
  process (clk)
    variable ap, aq         : signed(DATA_W-1 downto 0);
    variable cp, sq, cq, sp : signed(2*DATA_W-1 downto 0);
    variable np, nq         : signed(2*DATA_W downto 0);
    variable np_q, nq_q     : signed(DATA_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state          <= LOAD_WAIT;
        load_cnt       <= 0;
        start_pending  <= '0';
        skip_cnt_sweep <= 0;
        p_idx        <= 0;
        q_idx        <= 1;
        sweep_cnt    <= 0;
        row_cnt      <= 0;
        drain_cnt    <= 0;
        gram_start   <= '0';
        cordic_start <= '0';
        c_lat        <= (others => '0');
        s_lat        <= (others => '0');
        done         <= '0';
        dout_valid   <= '0';
        dout_last    <= '0';
        dout         <= (others => '0');
      else
        -- Default: self-clearing one-cycle pulses.
        gram_start   <= '0';
        cordic_start <= '0';
        dout_valid   <= '0';
        dout_last    <= '0';

        case state is

          when LOAD_WAIT =>
            if din_valid = '1' and load_cnt < ROWS*COLS then
              A(load_cnt / COLS, load_cnt mod COLS) <= din;
              load_cnt <= load_cnt + 1;
            end if;
            -- Latch start_pending so a start that races the final load
            -- is not lost. Start the computation on the first cycle
            -- after load_cnt reaches ROWS*COLS.
            if start = '1' then
              start_pending <= '1';
            end if;
            if (start = '1' or start_pending = '1') and load_cnt >= ROWS*COLS then
              sweep_cnt     <= 0;
              p_idx         <= 0;
              q_idx         <= 1;
              start_pending <= '0';
              state         <= PAIR_PICK;
              report "svd_jacobi_top: start accepted, load_cnt="
                     & integer'image(load_cnt) severity note;
            end if;

          when PAIR_PICK =>
            gram_start <= '1';
            state      <= GRAM_RUN;

          when GRAM_RUN =>
            state <= GRAM_WAIT;

          when GRAM_WAIT =>
            if gram_valid = '1' then
              if gram_skip = '1' then
                -- Pair is already orthogonal to threshold precision:
                -- skip CORDIC + APPLY, go straight to the next pair.
                skip_cnt_sweep <= skip_cnt_sweep + 1;
                state <= NEXT_PAIR;
              else
                cordic_start <= '1';
                state        <= CORDIC_RUN;
              end if;
            end if;

          when CORDIC_RUN =>
            state <= CORDIC_WAIT;

          when CORDIC_WAIT =>
            if cordic_valid = '1' then
              c_lat   <= cordic_c;
              s_lat   <= cordic_s;
              row_cnt <= 0;
              state   <= APPLY_RUN;
            end if;

          when APPLY_RUN =>
            -- Inline Givens on row_cnt: one row per clock.
            --   new_p =  c*a_p + s*a_q
            --   new_q = -s*a_p + c*a_q
            -- c, s, a_p, a_q are all Q1.16 in 18 bits. The product is
            -- 36 bits (Q2.32); the sum of two products stays well
            -- within 37 bits. Shift right by 16 to return to Q1.16.
            ap   := A(row_cnt, p_idx);
            aq   := A(row_cnt, q_idx);
            cp   := c_lat * ap;
            sq   := s_lat * aq;
            cq   := c_lat * aq;
            sp   := s_lat * ap;
            np   := resize(cp, 2*DATA_W+1) + resize(sq, 2*DATA_W+1);
            nq   := resize(cq, 2*DATA_W+1) - resize(sp, 2*DATA_W+1);
            np_q := resize(shift_right(np, DATA_W-2), DATA_W);
            nq_q := resize(shift_right(nq, DATA_W-2), DATA_W);
            A(row_cnt, p_idx) <= np_q;
            A(row_cnt, q_idx) <= nq_q;
            if row_cnt = ROWS - 1 then
              row_cnt <= 0;
              state   <= NEXT_PAIR;
            else
              row_cnt <= row_cnt + 1;
            end if;

          when APPLY_WAIT =>
            -- Unused in the inline-Givens path; retained for FSM shape.
            state <= NEXT_PAIR;

          when NEXT_PAIR =>
            -- Advance (p, q) through all lexicographic pairs with p < q.
            if q_idx = COLS - 1 then
              if p_idx = COLS - 2 then
                -- End of sweep.
                if sweep_cnt = SWEEPS - 1 then
                  state <= DRAIN_START;
                else
                  sweep_cnt <= sweep_cnt + 1;
                  p_idx     <= 0;
                  q_idx     <= 1;
                  report "svd_jacobi_top: completed sweep "
                         & integer'image(sweep_cnt + 1)
                         & " (skipped "
                         & integer'image(skip_cnt_sweep)
                         & " pairs)"
                         severity note;
                  skip_cnt_sweep <= 0;
                  state <= SWEEP_DONE;
                end if;
              else
                p_idx <= p_idx + 1;
                q_idx <= p_idx + 2;
                state <= PAIR_PICK;
              end if;
            else
              q_idx <= q_idx + 1;
              state <= PAIR_PICK;
            end if;

          when SWEEP_DONE =>
            state <= PAIR_PICK;

          when DRAIN_START =>
            drain_cnt <= 0;
            done      <= '1';
            state     <= DRAIN;

          when DRAIN =>
            if dout_ready = '1' then
              dout_valid <= '1';
              dout       <= A(drain_cnt / COLS, drain_cnt mod COLS);
              if drain_cnt = ROWS*COLS - 1 then
                dout_last <= '1';
              end if;
              if drain_cnt < ROWS*COLS - 1 then
                drain_cnt <= drain_cnt + 1;
              end if;
            end if;

        end case;
      end if;
    end if;
  end process;
end architecture rtl;

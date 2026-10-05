----------------------------------------------------------------------------
-- svd_jacobi_blv.vhd
--
-- BLV-ordered one-sided Jacobi SVD orchestrator.
--
-- Session 3 scope: N = 4 only (2 parallel pair pipelines, 3 steps per
-- sweep). Session 4 will parameterise N.
--
-- Architecture:
--   - Shared register-file matrix A (ROWS x COLS, Q1.16).
--   - PAIR_UNITS = COLS/2 instances of svd_pair_pipeline, run in
--     lockstep (same start cycle, identical FSM latency).
--   - A tiny schedule ROM gives each pipeline its (p, q) assignment
--     at each step. For N=4 the round-robin schedule is:
--       step 0: (0,1) (2,3)
--       step 1: (0,3) (1,2)
--       step 2: (0,2) (1,3)
--     (verified by tools/round_robin_schedule.py --n 4).
--   - Pair pipelines publish req_row_idx; the orchestrator reads
--     A(req_row_idx, p_k) and A(req_row_idx, q_k) into pipeline k's
--     (in_a_p, in_a_q). Since pairs are disjoint within a step,
--     different pipelines read distinct columns -- no read conflict.
--   - On out_valid from each pipeline, the orchestrator writes
--     (out_new_p, out_new_q) back into A at (out_row_idx, p_k) and
--     (out_row_idx, q_k). Again disjoint, no write conflict.
--   - After all pipelines in a step have pulsed `done`, advance to
--     next step. After all N-1 steps, advance sweep. After SWEEPS
--     sweeps, DRAIN.
--
-- Status: UNTESTED. First real validation is tools/sim_blv.sh.
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

entity svd_jacobi_blv is
  generic (
    DATA_W : integer := DATA_WIDTH;
    ROWS   : integer := 4;
    COLS   : integer := 4;
    SWEEPS : integer := 4
  );
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;

    din_valid  : in  std_logic;
    din        : in  data_t;

    start      : in  std_logic;
    done       : out std_logic;

    dout_ready : in  std_logic;
    dout       : out data_t;
    dout_valid : out std_logic;
    dout_last  : out std_logic
  );
end entity svd_jacobi_blv;

architecture rtl of svd_jacobi_blv is
  constant PAIR_UNITS : integer := COLS / 2;
  constant STEPS      : integer := COLS - 1;

  type   mat_t is array (0 to ROWS-1, 0 to COLS-1) of data_t;
  signal A : mat_t;

  -- Schedule ROM (N=4 only in session 3).
  -- schedule(step)(unit) = (p, q).
  type pair_t  is record p, q : integer range 0 to COLS-1; end record;
  type step_t  is array (0 to PAIR_UNITS-1) of pair_t;
  type sched_t is array (0 to STEPS-1) of step_t;
  constant SCHEDULE : sched_t := (
    0 => (0 => (p => 0, q => 1), 1 => (p => 2, q => 3)),
    1 => (0 => (p => 0, q => 3), 1 => (p => 1, q => 2)),
    2 => (0 => (p => 0, q => 2), 1 => (p => 1, q => 3))
  );

  type ctrl_state_t is (
    LOAD_WAIT, STEP_START, STEP_RUN, STEP_WAIT,
    DRAIN_START, DRAIN
  );
  signal state : ctrl_state_t;

  signal load_cnt      : integer range 0 to ROWS*COLS;
  signal start_pending : std_logic;
  signal step_idx      : integer range 0 to STEPS;
  signal sweep_cnt     : integer range 0 to SWEEPS;
  signal drain_cnt     : integer range 0 to ROWS*COLS;

  -- Per-pipeline signals.
  type   sl_arr_t is array (0 to PAIR_UNITS-1) of std_logic;
  type   data_arr_t is array (0 to PAIR_UNITS-1) of data_t;
  type   idx_arr_t  is array (0 to PAIR_UNITS-1) of integer range 0 to ROWS;

  signal pu_start      : sl_arr_t   := (others => '0');
  signal pu_in_a_p     : data_arr_t;
  signal pu_in_a_q     : data_arr_t;
  signal pu_req_phase  : sl_arr_t;
  signal pu_req_rowidx : idx_arr_t;
  signal pu_req_valid  : sl_arr_t;
  signal pu_out_p      : data_arr_t;
  signal pu_out_q      : data_arr_t;
  signal pu_out_rowidx : idx_arr_t;
  signal pu_out_valid  : sl_arr_t;
  signal pu_skip       : sl_arr_t;
  signal pu_done       : sl_arr_t;

  -- Track which pipelines have finished the current step.
  signal step_done_mask : std_logic_vector(PAIR_UNITS-1 downto 0);
begin
  ------------------------------------------------------------------------
  -- Instantiate PAIR_UNITS parallel svd_pair_pipeline units.
  ------------------------------------------------------------------------
  gen_pu : for k in 0 to PAIR_UNITS-1 generate
    u_pu : entity work.svd_pair_pipeline
      generic map (DATA_W => DATA_W, ROWS => ROWS)
      port map (
        clk         => clk,
        rst_n       => rst_n,
        start       => pu_start(k),
        in_a_p      => pu_in_a_p(k),
        in_a_q      => pu_in_a_q(k),
        req_phase   => pu_req_phase(k),
        req_row_idx => pu_req_rowidx(k),
        req_valid   => pu_req_valid(k),
        out_new_p   => pu_out_p(k),
        out_new_q   => pu_out_q(k),
        out_row_idx => pu_out_rowidx(k),
        out_valid   => pu_out_valid(k),
        skip        => pu_skip(k),
        done        => pu_done(k)
      );
  end generate;

  ------------------------------------------------------------------------
  -- Combinational row data to each pipeline from the schedule + A.
  ------------------------------------------------------------------------
  gen_route : for k in 0 to PAIR_UNITS-1 generate
    process (A, pu_req_valid, pu_req_rowidx, step_idx)
      variable p : integer range 0 to COLS-1;
      variable q : integer range 0 to COLS-1;
      variable r : integer range 0 to ROWS;
    begin
      p := SCHEDULE(step_idx)(k).p;
      q := SCHEDULE(step_idx)(k).q;
      r := pu_req_rowidx(k);
      if pu_req_valid(k) = '1' and r < ROWS then
        pu_in_a_p(k) <= A(r, p);
        pu_in_a_q(k) <= A(r, q);
      else
        pu_in_a_p(k) <= (others => '0');
        pu_in_a_q(k) <= (others => '0');
      end if;
    end process;
  end generate;

  ------------------------------------------------------------------------
  -- Main FSM
  ------------------------------------------------------------------------
  process (clk)
    variable all_done : boolean;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state          <= LOAD_WAIT;
        load_cnt       <= 0;
        start_pending  <= '0';
        step_idx       <= 0;
        sweep_cnt      <= 0;
        drain_cnt      <= 0;
        step_done_mask <= (others => '0');
        done           <= '0';
        dout           <= (others => '0');
        dout_valid     <= '0';
        dout_last      <= '0';
        for k in 0 to PAIR_UNITS-1 loop
          pu_start(k) <= '0';
        end loop;
      else
        -- Default pulses.
        for k in 0 to PAIR_UNITS-1 loop
          pu_start(k) <= '0';
        end loop;
        dout_valid <= '0';
        dout_last  <= '0';

        case state is
          when LOAD_WAIT =>
            if din_valid = '1' and load_cnt < ROWS*COLS then
              A(load_cnt / COLS, load_cnt mod COLS) <= din;
              load_cnt <= load_cnt + 1;
            end if;
            if start = '1' then
              start_pending <= '1';
            end if;
            if (start = '1' or start_pending = '1') and load_cnt >= ROWS*COLS then
              sweep_cnt      <= 0;
              step_idx       <= 0;
              start_pending  <= '0';
              step_done_mask <= (others => '0');
              state          <= STEP_START;
              report "svd_jacobi_blv: start accepted, load_cnt="
                     & integer'image(load_cnt) severity note;
            end if;

          when STEP_START =>
            -- Pulse start to every pipeline in lockstep.
            for k in 0 to PAIR_UNITS-1 loop
              pu_start(k) <= '1';
            end loop;
            step_done_mask <= (others => '0');
            state <= STEP_RUN;

          when STEP_RUN =>
            -- Writeback: whenever a pipeline emits out_valid, write both
            -- columns of its assigned pair back into A.
            for k in 0 to PAIR_UNITS-1 loop
              if pu_out_valid(k) = '1' then
                A(pu_out_rowidx(k), SCHEDULE(step_idx)(k).p) <= pu_out_p(k);
                A(pu_out_rowidx(k), SCHEDULE(step_idx)(k).q) <= pu_out_q(k);
              end if;
              -- Latch each pipeline's done into a mask.
              if pu_done(k) = '1' then
                step_done_mask(k) <= '1';
              end if;
            end loop;

            -- Check if all pipelines finished this step.
            all_done := true;
            for k in 0 to PAIR_UNITS-1 loop
              if step_done_mask(k) = '0' and pu_done(k) = '0' then
                all_done := false;
              end if;
            end loop;
            if all_done then
              state <= STEP_WAIT;
            end if;

          when STEP_WAIT =>
            -- One idle cycle so each pipeline sees `start=0` and
            -- returns to IDLE before the next STEP_START.
            if step_idx = STEPS - 1 then
              step_idx <= 0;
              if sweep_cnt = SWEEPS - 1 then
                state <= DRAIN_START;
              else
                sweep_cnt <= sweep_cnt + 1;
                report "svd_jacobi_blv: completed sweep "
                       & integer'image(sweep_cnt + 1)
                       severity note;
                state <= STEP_START;
              end if;
            else
              step_idx <= step_idx + 1;
              state    <= STEP_START;
            end if;

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

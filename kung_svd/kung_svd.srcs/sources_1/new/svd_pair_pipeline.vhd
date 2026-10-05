----------------------------------------------------------------------------
-- svd_pair_pipeline.vhd
--
-- Self-contained one-sided Jacobi pipeline for a single column pair.
--
-- Caller-driven row addressing. The pipeline publishes `req_row_idx`
-- and `req_phase` indicating which row and which phase (GRAM or APPLY)
-- it wants NOW. The caller presents (in_a_p, in_a_q) for that row
-- combinationally; the pipeline samples on the next rising edge.
--
-- This mirrors how `svd_jacobi_top` already drives the serializer —
-- gram.row_idx indexes directly into the register-file matrix A.
--
--   IDLE   -> on `start`, go to GRAM.
--   GRAM   -> req_phase=GRAM, req_row_idx cycles 0..ROWS-1.
--             After the last row, if skip -> DONE_S, else CORDIC_RUN.
--   CORDIC -> no caller interaction.
--   APPLY  -> req_phase=APPLY, req_row_idx cycles 0..ROWS-1.
--             Emits (out_new_p, out_new_q, out_row_idx, out_valid)
--             each cycle.
--   DONE_S -> `done` pulses one cycle; waits for start to go low.
--
-- If gram threshold fires (`skip=1`), APPLY is bypassed and `done`
-- pulses after GRAM, with `skip=1` held through DONE_S.
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

entity svd_pair_pipeline is
  generic (
    DATA_W : integer := DATA_WIDTH;
    ROWS   : integer := 8
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    -- Kick off a new (p, q) pair.
    start     : in  std_logic;

    -- Row data in; indexed by req_row_idx + req_phase.
    in_a_p    : in  data_t;
    in_a_q    : in  data_t;

    -- The pipeline tells the caller which row it wants and in which phase.
    -- req_phase = '0' means GRAM phase, '1' means APPLY phase.
    -- req_valid = '1' when the pipeline is actively consuming a row.
    req_phase   : out std_logic;
    req_row_idx : out integer range 0 to ROWS;
    req_valid   : out std_logic;

    -- Row data out during APPLY phase.
    out_new_p   : out data_t;
    out_new_q   : out data_t;
    out_row_idx : out integer range 0 to ROWS;
    out_valid   : out std_logic;

    -- Pair-level flags.
    skip      : out std_logic;              -- threshold path
    done      : out std_logic               -- one-cycle pulse
  );
end entity svd_pair_pipeline;

architecture rtl of svd_pair_pipeline is
  -- Internal Gram and CORDIC handshakes.
  signal gram_start   : std_logic;
  signal gram_row_idx : integer range 0 to ROWS;
  signal gram_x_vec   : data_t;
  signal gram_y_vec   : data_t;
  signal gram_skip    : std_logic;
  signal gram_valid   : std_logic;

  signal cordic_start : std_logic;
  signal cordic_c     : data_t;
  signal cordic_s     : data_t;
  signal cordic_valid : std_logic;

  signal c_lat : data_t;
  signal s_lat : data_t;

  type state_t is (IDLE, GRAM_RUN, CORDIC_RUN, APPLY_RUN, DONE_S);
  signal state : state_t;

  signal apply_row : integer range 0 to ROWS;
begin
  -- svd_gram drives its own row counter; we pass the caller's in_a_p/in_a_q
  -- straight through during GRAM and let gram sample at its own pace.
  u_gram : entity work.svd_gram
    generic map (DATA_W => DATA_W, ROWS => ROWS)
    port map (
      clk       => clk,
      rst_n     => rst_n,
      start     => gram_start,
      a_p       => in_a_p,
      a_q       => in_a_q,
      row_idx   => gram_row_idx,
      x_vec     => gram_x_vec,
      y_vec     => gram_y_vec,
      skip      => gram_skip,
      valid_out => gram_valid
    );

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

  -- Row-index publishing. The caller reads these combinationally and
  -- drives in_a_p/in_a_q for the published row.
  req_phase   <= '1' when state = APPLY_RUN else '0';
  req_row_idx <= apply_row when state = APPLY_RUN else gram_row_idx;
  req_valid   <= '1' when state = GRAM_RUN or state = APPLY_RUN else '0';

  process (clk)
    variable ap, aq         : signed(DATA_W-1 downto 0);
    variable cp, sq, cq, sp : signed(2*DATA_W-1 downto 0);
    variable np, nq         : signed(2*DATA_W downto 0);
    variable np_q, nq_q     : signed(DATA_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state        <= IDLE;
        gram_start   <= '0';
        cordic_start <= '0';
        apply_row    <= 0;
        c_lat        <= (others => '0');
        s_lat        <= (others => '0');
        out_new_p    <= (others => '0');
        out_new_q    <= (others => '0');
        out_row_idx  <= 0;
        out_valid    <= '0';
        skip         <= '0';
        done         <= '0';
      else
        gram_start   <= '0';
        cordic_start <= '0';
        out_valid    <= '0';
        done         <= '0';

        case state is
          when IDLE =>
            skip <= '0';
            if start = '1' then
              gram_start <= '1';
              state      <= GRAM_RUN;
            end if;

          when GRAM_RUN =>
            if gram_valid = '1' then
              if gram_skip = '1' then
                skip  <= '1';
                done  <= '1';
                state <= DONE_S;
              else
                cordic_start <= '1';
                state        <= CORDIC_RUN;
              end if;
            end if;

          when CORDIC_RUN =>
            if cordic_valid = '1' then
              c_lat     <= cordic_c;
              s_lat     <= cordic_s;
              apply_row <= 0;
              state     <= APPLY_RUN;
            end if;

          when APPLY_RUN =>
            -- Caller presented in_a_p/in_a_q for row = apply_row this cycle.
            ap   := in_a_p;
            aq   := in_a_q;
            cp   := c_lat * ap;
            sq   := s_lat * aq;
            cq   := c_lat * aq;
            sp   := s_lat * ap;
            np   := resize(cp, 2*DATA_W+1) + resize(sq, 2*DATA_W+1);
            nq   := resize(cq, 2*DATA_W+1) - resize(sp, 2*DATA_W+1);
            np_q := resize(shift_right(np, DATA_W-2), DATA_W);
            nq_q := resize(shift_right(nq, DATA_W-2), DATA_W);
            out_new_p   <= np_q;
            out_new_q   <= nq_q;
            out_row_idx <= apply_row;
            out_valid   <= '1';
            if apply_row = ROWS - 1 then
              apply_row <= 0;
              done      <= '1';
              state     <= DONE_S;
            else
              apply_row <= apply_row + 1;
            end if;

          when DONE_S =>
            if start = '0' then
              state <= IDLE;
              skip  <= '0';
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture rtl;

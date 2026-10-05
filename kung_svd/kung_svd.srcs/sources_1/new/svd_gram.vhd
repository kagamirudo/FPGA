----------------------------------------------------------------------------
-- svd_gram.vhd
--
-- Compute the three Gram-sub-matrix entries for a column pair (p, q):
--   alpha = sum_i A(i,p) * A(i,p)
--   beta  = sum_i A(i,q) * A(i,q)
--   gamma = sum_i A(i,p) * A(i,q)
--
-- Two features beyond the straightforward reduce:
--
-- 1. Auto-prescaling (precision improvement, "fix #5").
--    The angle CORDIC uses tan(2 theta) = 2 gamma / (alpha - beta),
--    so only the RATIO of x_vec and y_vec matters. We find a shared
--    right-shift that normalises max(|alpha-beta|, |2 gamma|) into
--    the top of the Q1.16 range so CORDIC sees as many bits of
--    precision as possible. This closes the "fixed 2^-16 radian
--    angle floor" that limited convergence at larger N.
--
-- 2. Threshold-skip (convergence helper, "fix #3").
--    If 2*|gamma| is small compared to the running Frobenius norm,
--    the pair is already orthogonal (or orthogonal to simulation
--    noise) and rotating adds nothing. We raise `skip` and the
--    orchestrator moves to the next pair without touching the
--    column data. Threshold is 2*|gamma| < |alpha+beta| >> SKIP_SHIFT
--    (= norm_scale * 2^-SKIP_SHIFT). SKIP_SHIFT = 20 gives roughly
--    1e-6 relative; conservative but it catches noise-level pairs.
--
-- Fixed-point: inputs are Q1.16 in 18 bits. Multiplier is 36 bits
-- (Q2.32). Accumulators are 48 bits (16-bit N headroom).
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

entity svd_gram is
  generic (
    DATA_W     : integer := DATA_WIDTH;
    ROWS       : integer := 8;
    SKIP_SHIFT : integer := 20  -- threshold: skip if 2|gamma| < (|a|+|b|) >> this
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    start     : in  std_logic;              -- pulse to begin a new reduction
    a_p       : in  data_t;                 -- A(i, p) for the current row
    a_q       : in  data_t;                 -- A(i, q) for the current row
    row_idx   : out integer range 0 to ROWS; -- which row the reducer wants next
    x_vec     : out data_t;                 -- (alpha - beta) prescaled to Q1.16
    y_vec     : out data_t;                 -- (2 * gamma)    prescaled to Q1.16
    skip      : out std_logic;              -- 1 => pair below threshold, don't rotate
    valid_out : out std_logic
  );
end entity svd_gram;

architecture rtl of svd_gram is
  constant ACC_W : integer := 48;

  type state_t is (IDLE, ACC, FINALIZE, DONE_S);
  signal state : state_t;

  signal acc_a, acc_b, acc_g : signed(ACC_W-1 downto 0);
  signal row_cnt             : integer range 0 to ROWS;

  -- Count leading sign bits of a signed value (bits that match the sign).
  function count_lead_sign (v : signed) return integer is
    variable n   : integer := 0;
    variable sgn : std_logic;
  begin
    sgn := v(v'high);
    for i in v'high-1 downto 0 loop
      if v(i) = sgn then
        n := n + 1;
      else
        return n;
      end if;
    end loop;
    return n;
  end function;

  function abs_signed (v : signed) return signed is
  begin
    if v(v'high) = '1' then
      return -v;
    end if;
    return v;
  end function;
begin
  row_idx   <= row_cnt;
  valid_out <= '1' when state = DONE_S else '0';

  process (clk)
    variable pp, qq, pq : signed(2*DATA_W-1 downto 0);
    variable diff_full  : signed(ACC_W-1 downto 0);
    variable gamma_full : signed(ACC_W-1 downto 0);
    variable norm_scale : signed(ACC_W-1 downto 0);  -- |alpha|+|beta|
    variable mag_max    : signed(ACC_W-1 downto 0);
    variable abs_diff   : signed(ACC_W-1 downto 0);
    variable abs_gamma  : signed(ACC_W-1 downto 0);
    variable lead_bits  : integer;
    variable shift_amt  : integer;
    variable x_shifted  : signed(ACC_W-1 downto 0);
    variable y_shifted  : signed(ACC_W-1 downto 0);
    variable threshold  : signed(ACC_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state   <= IDLE;
        acc_a   <= (others => '0');
        acc_b   <= (others => '0');
        acc_g   <= (others => '0');
        row_cnt <= 0;
        x_vec   <= (others => '0');
        y_vec   <= (others => '0');
        skip    <= '0';
      else
        case state is
          when IDLE =>
            if start = '1' then
              acc_a   <= (others => '0');
              acc_b   <= (others => '0');
              acc_g   <= (others => '0');
              row_cnt <= 0;
              skip    <= '0';
              state   <= ACC;
            end if;

          when ACC =>
            pp := a_p * a_p;
            qq := a_q * a_q;
            pq := a_p * a_q;
            acc_a <= acc_a + resize(pp, ACC_W);
            acc_b <= acc_b + resize(qq, ACC_W);
            acc_g <= acc_g + resize(pq, ACC_W);
            if row_cnt = ROWS - 1 then
              state <= FINALIZE;
            end if;
            row_cnt <= row_cnt + 1;

          when FINALIZE =>
            -- Build the two CORDIC drivers at full width.
            diff_full  := acc_a - acc_b;
            gamma_full := shift_left(acc_g, 1);  -- 2 * gamma

            -- Threshold: norm_scale = alpha + beta (both non-negative sums
            -- of squares, so this is also |alpha|+|beta|).
            norm_scale := acc_a + acc_b;
            abs_gamma  := abs_signed(gamma_full);
            threshold  := shift_right(norm_scale, SKIP_SHIFT);

            if abs_gamma < threshold then
              skip  <= '1';
              x_vec <= (others => '0');
              y_vec <= (others => '0');
            else
              skip <= '0';
              -- Auto-prescale: pick a shared shift so the larger of
              -- (|diff|, |2 gamma|) occupies the top of Q1.16. The
              -- minimum shift is FRACT_BIT = DATA_W-2 = 16 (strip the
              -- fractional-squared bits introduced by the MAC). If
              -- the magnitude is still too large to fit DATA_W bits
              -- after that shift, add more. If it would fit with FEWER
              -- bits of shift (small Gram sums), keep the default
              -- shift so we don't amplify noise.
              abs_diff := abs_signed(diff_full);
              if abs_diff > abs_gamma then
                mag_max := abs_diff;
              else
                mag_max := abs_gamma;
              end if;
              lead_bits := count_lead_sign(mag_max);
              -- Shift required to leave the magnitude in bit DATA_W-2.
              shift_amt := (ACC_W - 1 - lead_bits) - (DATA_W - 2);
              -- Clamp: default to the straight Q2.32 -> Q1.16 shift of
              -- FRACT_BIT (= DATA_W - 2 = 16). Only grow the shift when
              -- the magnitude truly exceeds Q1.16 range.
              if shift_amt < DATA_W - 2 then
                shift_amt := DATA_W - 2;
              end if;
              x_shifted := shift_right(diff_full,  shift_amt);
              y_shifted := shift_right(gamma_full, shift_amt);
              x_vec <= resize(x_shifted, DATA_W);
              y_vec <= resize(y_shifted, DATA_W);
            end if;
            state <= DONE_S;

          when DONE_S =>
            if start = '0' then
              state   <= IDLE;
              row_cnt <= 0;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture rtl;

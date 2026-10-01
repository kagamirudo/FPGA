----------------------------------------------------------------------------
-- svd_gram.vhd
--
-- Compute the three Gram-sub-matrix entries for a column pair (p, q):
--   alpha = sum_i A(i,p) * A(i,p)
--   beta  = sum_i A(i,q) * A(i,q)
--   gamma = sum_i A(i,p) * A(i,q)
--
-- Sequential: one row per clock, N clocks total for an N-row register
-- file. Caller presents row i on the inputs when state = ACC.
--
-- Outputs are the two drivers the angle CORDIC wants:
--   x_vec = alpha - beta
--   y_vec = 2 * gamma
--
-- Fixed-point: inputs are Q1.16 in 18 bits. The multiplier is 36 bits
-- (Q2.32). Internal accumulators are 48 bits for 8-row headroom; after
-- the accumulation, we shift right by 16 to return to Q1.16 before
-- the subtraction / doubling.
--
-- Status: UNTESTED.
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

entity svd_gram is
  generic (
    DATA_W : integer := DATA_WIDTH;
    ROWS   : integer := 8
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    start     : in  std_logic;              -- pulse to begin a new reduction
    a_p       : in  data_t;                 -- A(i, p) for the current row
    a_q       : in  data_t;                 -- A(i, q) for the current row
    row_idx   : out integer range 0 to ROWS; -- which row the reducer wants next
    x_vec     : out data_t;                 -- alpha - beta (Q1.16)
    y_vec     : out data_t;                 -- 2 * gamma    (Q1.16)
    valid_out : out std_logic
  );
end entity svd_gram;

architecture rtl of svd_gram is
  constant ACC_W     : integer := 48;
  constant FRACT_BIT : integer := DATA_W - 2;  -- 16

  type state_t is (IDLE, ACC, FINALIZE, DONE_S);
  signal state : state_t;

  signal acc_a, acc_b, acc_g : signed(ACC_W-1 downto 0);
  signal row_cnt             : integer range 0 to ROWS;
begin
  row_idx   <= row_cnt;
  valid_out <= '1' when state = DONE_S else '0';

  process (clk)
    variable pp, qq, pq : signed(2*DATA_W-1 downto 0);
    variable diff_full  : signed(ACC_W-1 downto 0);
    variable gamma_full : signed(ACC_W-1 downto 0);
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
      else
        case state is
          when IDLE =>
            if start = '1' then
              acc_a   <= (others => '0');
              acc_b   <= (others => '0');
              acc_g   <= (others => '0');
              row_cnt <= 0;
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
            -- Shift accumulators back from Q2.32 to Q1.16 (truncate low bits).
            diff_full  := shift_right(acc_a - acc_b, FRACT_BIT);
            gamma_full := shift_right(acc_g, FRACT_BIT - 1);  -- 2 * gamma
            x_vec <= resize(diff_full, DATA_W);
            y_vec <= resize(gamma_full, DATA_W);
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

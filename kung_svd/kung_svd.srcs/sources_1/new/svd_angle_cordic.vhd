----------------------------------------------------------------------------
-- svd_angle_cordic.vhd
--
-- Two-stage CORDIC for the one-sided Jacobi angle problem:
--   Given alpha-beta and 2*gamma (the Gram-matrix sub-expressions),
--   produce (cos theta, sin theta) where theta solves
--       tan(2 theta) = 2 gamma / (alpha - beta).
--
-- Stage 1 (VECTORING): rotate (x_vec, y_vec) toward the x-axis to
-- extract 2*theta = atan2(y_vec, x_vec) into z. Arctan table values
-- are the full atan(2^-i) scaled by 2^16 (Q2.16, radians).
--
-- Halve: theta <- z >> 1 (shift right by 1 bit).
--
-- Stage 2 (ROTATION): rotate (1/K, 0) by theta to get (cos theta, sin theta).
-- K is the cumulative CORDIC gain for ITER iterations. For ITER = 16,
-- 1/K ~ 0.60725 ~ 39797 in Q1.16.
--
-- Fixed-point:
--   Inputs/outputs:  Q1.16 in 18-bit signed (data_t).
--   Internal z:      Q2.16 radians, in [-pi, +pi].
--
-- Status: UNTESTED. Requires GHDL or Vivado simulation to verify.
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

entity svd_angle_cordic is
  generic (
    W    : integer := DATA_WIDTH;
    ITER : integer := 16
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    start     : in  std_logic;
    x_vec     : in  data_t;      -- alpha - beta
    y_vec     : in  data_t;      -- 2 * gamma
    c_out     : out data_t;      -- cos(theta)
    s_out     : out data_t;      -- sin(theta)
    valid_out : out std_logic
  );
end entity svd_angle_cordic;

architecture rtl of svd_angle_cordic is
  -- Full arctan(2^-i) values in Q2.16 radians.
  -- atan(2^-i) * 2^16, rounded to nearest.
  type atan_tbl_t is array (0 to 15) of integer;
  constant ATAN_TBL : atan_tbl_t := (
    51472,  -- atan(2^0)  = 0.7854 rad
    30385,  -- atan(2^-1) = 0.4636 rad
    16055,  -- atan(2^-2) = 0.2450 rad
    8150,   -- atan(2^-3) = 0.1244 rad
    4091,   -- atan(2^-4) = 0.0624 rad
    2048,   -- atan(2^-5) = 0.0312 rad
    1024,   -- atan(2^-6) = 0.01562 rad
    512,    -- atan(2^-7) = 0.00781 rad
    256,    -- atan(2^-8)
    128,    -- atan(2^-9)
    64,
    32,
    16,
    8,
    4,
    2
  );

  -- 1/K for 16 iterations in Q1.16: round(0.60725 * 65536) = 39797
  constant K_INV_Q116 : integer := 39797;

  type state_t is (IDLE, VECTOR, HALVE, ROTATE, DONE_S);
  signal state : state_t;

  signal x_reg, y_reg : signed(W+3 downto 0);  -- headroom for sum of shifts
  signal z_reg        : signed(W+3 downto 0);  -- radians, Q2.16-ish
  signal iter_cnt     : integer range 0 to ITER;
begin
  valid_out <= '1' when state = DONE_S else '0';

  process (clk)
    variable x_v, y_v, z_v : signed(W+3 downto 0);
    variable sh            : integer;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state    <= IDLE;
        iter_cnt <= 0;
        x_reg    <= (others => '0');
        y_reg    <= (others => '0');
        z_reg    <= (others => '0');
        c_out    <= (others => '0');
        s_out    <= (others => '0');
      else
        case state is
          when IDLE =>
            if start = '1' then
              -- Load vectoring inputs, sign-extended to internal width.
              x_reg    <= resize(x_vec, W+4);
              y_reg    <= resize(y_vec, W+4);
              z_reg    <= (others => '0');
              iter_cnt <= 0;
              state    <= VECTOR;
            end if;

          when VECTOR =>
            sh := iter_cnt;
            if y_reg >= 0 then
              x_v := x_reg + shift_right(y_reg, sh);
              y_v := y_reg - shift_right(x_reg, sh);
              z_v := z_reg + to_signed(ATAN_TBL(iter_cnt), W+4);
            else
              x_v := x_reg - shift_right(y_reg, sh);
              y_v := y_reg + shift_right(x_reg, sh);
              z_v := z_reg - to_signed(ATAN_TBL(iter_cnt), W+4);
            end if;
            x_reg <= x_v;
            y_reg <= y_v;
            z_reg <= z_v;
            if iter_cnt = ITER - 1 then
              state    <= HALVE;
              iter_cnt <= 0;
            else
              iter_cnt <= iter_cnt + 1;
            end if;

          when HALVE =>
            -- theta = (1/2) * atan2(y_vec, x_vec)
            z_reg <= shift_right(z_reg, 1);
            -- Pre-scale rotation input to (1/K, 0) so that after ITER
            -- rotation steps the output is exactly (cos theta, sin theta).
            x_reg <= to_signed(K_INV_Q116, W+4);
            y_reg <= (others => '0');
            state <= ROTATE;

          when ROTATE =>
            sh := iter_cnt;
            -- Standard rotation CORDIC: drive z to zero.
            if z_reg >= 0 then
              x_v := x_reg - shift_right(y_reg, sh);
              y_v := y_reg + shift_right(x_reg, sh);
              z_v := z_reg - to_signed(ATAN_TBL(iter_cnt), W+4);
            else
              x_v := x_reg + shift_right(y_reg, sh);
              y_v := y_reg - shift_right(x_reg, sh);
              z_v := z_reg + to_signed(ATAN_TBL(iter_cnt), W+4);
            end if;
            x_reg <= x_v;
            y_reg <= y_v;
            z_reg <= z_v;
            if iter_cnt = ITER - 1 then
              -- Truncate back to data_t (Q1.16, 18 bits).
              c_out <= resize(x_v, W);
              s_out <= resize(y_v, W);
              state <= DONE_S;
            else
              iter_cnt <= iter_cnt + 1;
            end if;

          when DONE_S =>
            -- Hold until start de-asserts, then return to IDLE.
            if start = '0' then
              state <= IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture rtl;

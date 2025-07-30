library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.svd_pkg.all;

----------------------------------------------------------------------------
--  Fixed-point CORDIC Rotation
--  Computes cos(θ) and sin(θ) where tan(θ) = y_in/x_in
--  Uses iterative approximation with pre-computed arctangent table
----------------------------------------------------------------------------

entity cordic_rot is
  generic (
    W    : integer := DATA_WIDTH;
    ITER : integer := DATA_WIDTH - 2
  );
  port (
    clk       : in std_logic;
    rst_n     : in std_logic;
    start     : in std_logic;  -- Start new computation
    x_in      : in data_t;
    y_in      : in data_t;
    x_out     : out data_t; -- cos
    y_out     : out data_t; -- sin
    valid_out : out std_logic
  );
end cordic_rot;

architecture rtl of cordic_rot is
  -- CORDIC iteration signals
  signal x_reg, y_reg : data_t;
  signal z_reg        : signed(W - 1 downto 0);
  signal iter_cnt     : integer range 0 to ITER;
  signal busy         : std_logic;

  -- Pre-computed arctangent values (scaled by 2^16)
  type arctan_table_t is array (0 to ITER - 1) of signed(W - 1 downto 0);
  constant ARCTAN_TABLE : arctan_table_t := (
  -- These are approximate arctan(2^-i) values for 16-bit precision
  to_signed(25735, W), -- arctan(2^0)  = 45.0°
  to_signed(15192, W), -- arctan(2^-1) = 26.6°
  to_signed(8027, W), -- arctan(2^-2) = 14.0°
  to_signed(4087, W), -- arctan(2^-3) = 7.1°
  to_signed(2055, W), -- arctan(2^-4) = 3.6°
  to_signed(1028, W), -- arctan(2^-5) = 1.8°
  to_signed(514, W), -- arctan(2^-6) = 0.9°
  to_signed(257, W), -- arctan(2^-7) = 0.4°
  to_signed(128, W), -- arctan(2^-8) = 0.2°
  to_signed(64, W), -- arctan(2^-9) = 0.1°
  to_signed(32, W), -- arctan(2^-10) = 0.05°
  to_signed(16, W), -- arctan(2^-11) = 0.025°
  to_signed(8, W), -- arctan(2^-12) = 0.0125°
  to_signed(4, W), -- arctan(2^-13) = 0.00625°
  to_signed(2, W), -- arctan(2^-14) = 0.003125°
  to_signed(1, W) -- arctan(2^-15) = 0.001563°
  );

begin
  process (clk)
    variable x_next, y_next : data_t;
    variable z_next         : signed(W - 1 downto 0);
    variable shift_val      : integer;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        x_reg     <= (others => '0');
        y_reg     <= (others => '0');
        z_reg     <= (others => '0');
        iter_cnt  <= 0;
        busy      <= '0';
        valid_out <= '0';
      else
        valid_out <= '0';

        if busy = '0' then
          -- Start new CORDIC computation
          if start = '1' then
            x_reg    <= x_in;
            y_reg    <= y_in;
            z_reg    <= (others => '0');
            iter_cnt <= 0;
            busy     <= '1';
            report "CORDIC: Starting computation with x=" & integer'image(to_integer(x_in)) &
              ", y=" & integer'image(to_integer(y_in)) severity note;
          end if;
        else
          -- CORDIC iteration
          shift_val := iter_cnt;
          
          -- Debug: Print iteration progress
          if iter_cnt mod 4 = 0 then
            report "CORDIC: Iteration " & integer'image(iter_cnt) & 
                   ", x=" & integer'image(to_integer(x_reg)) & 
                   ", y=" & integer'image(to_integer(y_reg)) severity note;
          end if;

          if y_reg >= 0 then
            -- Rotate clockwise
            x_next := x_reg + shift_right(y_reg, shift_val);
            y_next := y_reg - shift_right(x_reg, shift_val);
            z_next := z_reg + ARCTAN_TABLE(iter_cnt);
          else
            -- Rotate counter-clockwise
            x_next := x_reg - shift_right(y_reg, shift_val);
            y_next := y_reg + shift_right(x_reg, shift_val);
            z_next := z_reg - ARCTAN_TABLE(iter_cnt);
          end if;

          x_reg <= x_next;
          y_reg <= y_next;
          z_reg <= z_next;

          if iter_cnt < ITER - 1 then
            iter_cnt <= iter_cnt + 1;
          else
            -- CORDIC complete
            busy      <= '0';
            valid_out <= '1';
            report "CORDIC: Computation completed after " & integer'image(iter_cnt + 1) & " iterations" severity note;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Output the final results
  x_out <= x_reg;
  y_out <= y_reg;

end architecture rtl;
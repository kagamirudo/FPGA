----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/29/2025 07:29:24 AM
-- Design Name: 
-- Module Name: svd_pe - Behavioral
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
--  Givens‑rotation processing element (single MAC / clk)
----------------------------------------------------------------------------
entity svd_pe is
  generic (
    DATA_W : integer := DATA_WIDTH
  );
  port (
    clk   : in std_logic;
    rst_n : in std_logic;
    a_in  : in data_t; -- top neighbour
    b_in  : in data_t; -- left neighbour
    c_in  : in data_t; -- cosine  parameter
    s_in  : in data_t; -- sine    parameter
    a_out : out data_t; -- to bottom
    b_out : out data_t; -- to right
    c_out : out data_t; -- pass‑through cos
    s_out : out data_t -- pass‑through sin
  );
end entity svd_pe;

architecture rtl of svd_pe is
  constant SHIFT      : integer := DATA_W - 2;
  signal a_mul, b_mul : signed((2 * DATA_W) - 1 downto 0);
  signal a_tmp, b_tmp : data_t;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        a_out <= (others => '0');
        b_out <= (others => '0');
        c_out <= (others => '0');
        s_out <= (others => '0');
      else
        -- Multiply‑accumulate for rotation
        a_mul <= (c_in * a_in) - (s_in * b_in);
        b_mul <= (s_in * a_in) + (c_in * b_in);
        -- truncate (keep MSBs)
        a_tmp <= a_mul(a_mul'high downto SHIFT + 2);
        b_tmp <= b_mul(b_mul'high downto SHIFT + 2);
        -- register outputs
        a_out <= a_tmp;
        b_out <= b_tmp;
        c_out <= c_in;
        s_out <= s_in;
      end if;
    end if;
  end process;
end architecture rtl;

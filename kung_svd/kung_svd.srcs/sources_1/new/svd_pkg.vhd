----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/29/2025 07:29:24 AM
-- Design Name: 
-- Module Name: svd_pkg - Behavioral
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

----------------------------------------------------------------------------
--  Shared package – fixed‑point type & constants
----------------------------------------------------------------------------
package svd_pkg is
  constant DATA_WIDTH : integer := 18; -- Q1.(W‑2)
  subtype data_t is signed(DATA_WIDTH - 1 downto 0);
end package svd_pkg;

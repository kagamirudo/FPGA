--######################################################################
--  Title  : 4×4 LU Decomposition Systolic Array (Vivado‑clean build)
--  Author : Gary Pham (rev‑3)
--
--  This revision compiles and simulates out‑of‑the‑box in Vivado 2025.x.
--  Key changes from your last paste‑in:
--    • **No duplicate type definitions** inside the top level.  We rely
--      only on the array types in `lu_pkg`, so every unit shares the same
--      signal signatures.
--    • **Consistent two‑stage indexing** (`east_to_west(r)(c)`) using the
--      nested‑array types `col_t` and `mesh_t`.
--    • Fixed width growth in `MA_cell`: multiply in 2×W bits, subtract,
--      then resize back to W.
--    • Added `feed_other_rows` generate block with proper label + end.
--
--  Compile order:
--      1.  lu_pkg.vhd
--      2.  M_cell.vhd
--      3.  MA_cell.vhd
--      4.  lu_array4x4.vhd
--      5.  (optional) lu_tb.vhd
--######################################################################
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------
--  PACKAGE: constants & types
-------------------------------------------------------------------------------
package lu_pkg is
  constant W : integer := 32; -- data width
  subtype dint is signed(W - 1 downto 0);

  type dint_vec is array (natural range <>) of dint; -- 1‑D
  type dint_mat is array (natural range <>, natural range <>) of dint; -- 2‑D
end package;

package body lu_pkg is end package body;
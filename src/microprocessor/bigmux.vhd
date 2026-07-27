library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Big Multiplexer (4-to-1, 8-bit)
-- ============================================================================
-- A multiplexer (mux) selects one of several inputs and forwards it to the
-- output. This 4-to-1 mux picks one of four 8-bit data inputs using a 2-bit
-- selector. It is pure combinational logic.
--   sel = "00" -> d0, "01" -> d1, "10" -> d2, "11" -> d3
-- ============================================================================
entity bigmux is
  port(
    d0  : in  std_logic_vector(7 downto 0);  -- input 0
    d1  : in  std_logic_vector(7 downto 0);  -- input 1
    d2  : in  std_logic_vector(7 downto 0);  -- input 2
    d3  : in  std_logic_vector(7 downto 0);  -- input 3
    sel : in  std_logic_vector(1 downto 0);  -- 2-bit selector
    y   : out std_logic_vector(7 downto 0)   -- selected output
  );
end bigmux;

architecture rtl of bigmux is
begin
  with sel select
    y <= d0 when "00",
         d1 when "01",
         d2 when "10",
         d3 when "11",
         (others => '0') when others;
end rtl;

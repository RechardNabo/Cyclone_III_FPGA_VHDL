library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Small Multiplexer (2-to-1, 8-bit)
-- ============================================================================
-- The simplest multiplexer: choose between two 8-bit inputs using a single
-- bit. When sel = '0' the output follows d0; when sel = '1' it follows d1.
-- This is used in the datapath to pick between an ALU result and an immediate
-- value for writeback.
-- ============================================================================
entity smallmux is
  port(
    d0  : in  std_logic_vector(7 downto 0);  -- input selected when sel=0
    d1  : in  std_logic_vector(7 downto 0);  -- input selected when sel=1
    sel : in  std_logic;                     -- 1-bit selector
    y   : out std_logic_vector(7 downto 0)   -- selected output
  );
end smallmux;

architecture rtl of smallmux is
begin
  y <= d1 when sel = '1' else d0;
end rtl;

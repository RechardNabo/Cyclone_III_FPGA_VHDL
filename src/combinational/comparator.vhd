-- ============================================================================
-- 8-Bit Magnitude Comparator
-- ============================================================================
-- Compares two 8-bit unsigned numbers and outputs three flags:
--   Greater : '1' when A > B
--   Equal   : '1' when A = B
--   Less    : '1' when A < B
-- Exactly one output is high at any time.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity comparator is
    port (
        A      : in  std_logic_vector(7 downto 0);  -- First 8-bit operand
        B      : in  std_logic_vector(7 downto 0);  -- Second 8-bit operand
        Greater: out std_logic;                     -- A > B flag
        Equal  : out std_logic;                     -- A = B flag
        Less   : out std_logic                      -- A < B flag
    );
end entity comparator;

architecture dataflow of comparator is
begin
    Greater <= '1' when unsigned(A) > unsigned(B) else '0';
    Equal   <= '1' when unsigned(A) = unsigned(B) else '0';
    Less    <= '1' when unsigned(A) < unsigned(B) else '0';
end architecture dataflow;

-- ============================================================================
-- 8-Bit Magnitude Comparator
-- ============================================================================
-- Compares two 8-bit unsigned numbers and outputs three flags:
--   GT : '1' when A > B
--   EQ : '1' when A = B
--   LT : '1' when A < B
-- Exactly one output is high at any time.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity magnitude_comparator is
    port (
        A  : in  std_logic_vector(7 downto 0);  -- First 8-bit operand
        B  : in  std_logic_vector(7 downto 0);  -- Second 8-bit operand
        GT : out std_logic;                     -- A > B flag
        EQ : out std_logic;                     -- A = B flag
        LT : out std_logic                      -- A < B flag
    );
end entity magnitude_comparator;

architecture dataflow of magnitude_comparator is
begin
    GT <= '1' when unsigned(A) > unsigned(B) else '0';
    EQ <= '1' when unsigned(A) = unsigned(B) else '0';
    LT <= '1' when unsigned(A) < unsigned(B) else '0';
end architecture dataflow;

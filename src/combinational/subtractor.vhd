-- ============================================================================
-- 4-Bit Subtractor with Borrow
-- ============================================================================
-- Computes A - B - Borrow_In using two's complement method.
--   Difference : 4-bit result
--   Borrow_Out : '1' when unsigned underflow occurs (A < B)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity subtractor is
    port (
        A          : in  std_logic_vector(3 downto 0);  -- Minuend
        B          : in  std_logic_vector(3 downto 0);  -- Subtrahend
        Borrow_In  : in  std_logic;                     -- Borrow input
        Difference : out std_logic_vector(3 downto 0);  -- A - B result
        Borrow_Out : out std_logic                      -- Borrow output
    );
end entity subtractor;

architecture dataflow of subtractor is
    -- 5-bit result to capture borrow
    signal temp : std_logic_vector(4 downto 0);
begin
    -- Extend to 5 bits and subtract; bit 4 is the borrow out
    temp <= std_logic_vector(
                ('0' & unsigned(A)) - ('0' & unsigned(B)) - ("0000" & Borrow_In)
            );

    Difference <= temp(3 downto 0);
    Borrow_Out <= temp(4);
end architecture dataflow;

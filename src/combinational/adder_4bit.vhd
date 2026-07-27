-- ============================================================================
-- 4-Bit Ripple Carry Adder
-- ============================================================================
-- Adds two 4-bit numbers with carry-in, produces 4-bit sum and carry-out.
-- Uses a ripple carry chain: each bit's carry feeds the next stage.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity adder_4bit is
    port (
        A    : in  std_logic_vector(3 downto 0);  -- First 4-bit operand
        B    : in  std_logic_vector(3 downto 0);  -- Second 4-bit operand
        Cin  : in  std_logic;                     -- Carry input
        Sum  : out std_logic_vector(3 downto 0);  -- 4-bit sum output
        Cout : out std_logic                      -- Carry output
    );
end entity adder_4bit;

architecture dataflow of adder_4bit is
    -- Internal carry signals between stages
    signal c1, c2, c3 : std_logic;
begin
    -- Stage 0: bit 0
    Sum(0) <= A(0) xor B(0) xor Cin;
    c1     <= (A(0) and B(0)) or (A(0) and Cin) or (B(0) and Cin);

    -- Stage 1: bit 1
    Sum(1) <= A(1) xor B(1) xor c1;
    c2     <= (A(1) and B(1)) or (A(1) and c1) or (B(1) and c1);

    -- Stage 2: bit 2
    Sum(2) <= A(2) xor B(2) xor c2;
    c3     <= (A(2) and B(2)) or (A(2) and c2) or (B(2) and c2);

    -- Stage 3: bit 3
    Sum(3) <= A(3) xor B(3) xor c3;
    Cout   <= (A(3) and B(3)) or (A(3) and c3) or (B(3) and c3);
end architecture dataflow;

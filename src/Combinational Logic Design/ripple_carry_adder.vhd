-- ============================================================================
-- 8-Bit Ripple Carry Adder
-- ============================================================================
-- Adds two 8-bit numbers with carry-in using a ripple carry chain.
-- Each full adder stage passes its carry to the next higher stage.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ripple_carry_adder is
    port (
        A    : in  std_logic_vector(7 downto 0);  -- First 8-bit operand
        B    : in  std_logic_vector(7 downto 0);  -- Second 8-bit operand
        Cin  : in  std_logic;                     -- Carry input
        Sum  : out std_logic_vector(7 downto 0);  -- 8-bit sum output
        Cout : out std_logic                      -- Carry output
    );
end entity ripple_carry_adder;

architecture dataflow of ripple_carry_adder is
    -- Internal carry chain signals (carry into each stage)
    signal c : std_logic_vector(8 downto 0);
begin
    c(0) <= Cin;

    -- Generate each full adder stage with carry ripple
    gen_stages: for i in 0 to 7 generate
        Sum(i) <= A(i) xor B(i) xor c(i);
        c(i+1) <= (A(i) and B(i)) or (A(i) and c(i)) or (B(i) and c(i));
    end generate gen_stages;

    Cout <= c(8);
end architecture dataflow;

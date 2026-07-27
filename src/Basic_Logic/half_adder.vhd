-- 1-bit half adder
-- Adds two single-bit inputs, produces a sum and carry-out
--   sum  = A XOR B   (the low bit of A+B)
--   carry = A AND B  (the high bit of A+B)
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity half_adder is
    port (
        A     : in  std_logic;  -- first 1-bit operand
        B     : in  std_logic;  -- second 1-bit operand
        sum   : out std_logic;  -- sum bit  = A XOR B
        carry : out std_logic   -- carry bit = A AND B
    );
end entity half_adder;

architecture dataflow of half_adder is
begin
    -- Sum is XOR of the two inputs
    sum   <= A xor B;
    -- Carry is AND of the two inputs
    carry <= A and B;
end architecture dataflow;

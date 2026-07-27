-- 1-bit full adder
-- Adds three 1-bit inputs (A, B, carry-in) producing sum and carry-out
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity full_adder is
    port (
        A    : in  std_logic;  -- first 1-bit operand
        B    : in  std_logic;  -- second 1-bit operand
        cin  : in  std_logic;  -- carry-in from previous stage
        sum  : out std_logic;  -- sum bit
        cout : out std_logic   -- carry-out to next stage
    );
end entity full_adder;

architecture dataflow of full_adder is
begin
    -- Sum = A XOR B XOR cin
    sum  <= A xor B xor cin;
    -- Carry-out = (A AND B) OR (cin AND (A XOR B))
    cout <= (A and B) or (cin and (A xor B));
end architecture dataflow;

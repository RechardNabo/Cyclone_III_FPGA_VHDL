-- 2-input XOR (exclusive-OR) gate
-- Output Y is '1' when A and B differ
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity XOR_gate is
    port (
        A : in  std_logic;   -- first input
        B : in  std_logic;   -- second input
        Y : out std_logic    -- output = A XOR B
    );
end entity XOR_gate;

architecture dataflow of XOR_gate is
begin
    -- Concurrent assignment: Y is '1' when inputs differ
    Y <= A xor B;
end architecture dataflow;

-- 2-input XNOR (exclusive-NOR) gate
-- Output Y is '1' when A and B are equal (inverse of XOR)
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity XNOR_gate is
    port (
        A : in  std_logic;   -- first input
        B : in  std_logic;   -- second input
        Y : out std_logic    -- output = NOT (A XOR B)
    );
end entity XNOR_gate;

architecture dataflow of XNOR_gate is
begin
    -- Concurrent assignment: Y is '1' when inputs are the same
    Y <= A xnor B;
end architecture dataflow;

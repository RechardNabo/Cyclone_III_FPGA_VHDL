-- 2-input NOR gate
-- Output Y is '1' only when both A and B are '0' (inverse of OR)
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity NOR_gate is
    port (
        A : in  std_logic;   -- first input
        B : in  std_logic;   -- second input
        Y : out std_logic    -- output = NOT (A OR B)
    );
end entity NOR_gate;

architecture dataflow of NOR_gate is
begin
    -- Concurrent assignment: Y is the inverse of A OR B
    Y <= A nor B;
end architecture dataflow;

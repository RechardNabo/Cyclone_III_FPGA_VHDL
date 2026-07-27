-- 2-input AND gate
-- Output Y is '1' only when both A and B are '1'
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity AND_gate is
    port (
        A : in  std_logic;   -- first input
        B : in  std_logic;   -- second input
        Y : out std_logic    -- output = A AND B
    );
end entity AND_gate;

architecture dataflow of AND_gate is
begin
    -- Concurrent assignment: Y follows A AND B at all times
    Y <= A and B;
end architecture dataflow;

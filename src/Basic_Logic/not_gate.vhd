-- 1-input NOT gate (inverter)
-- Output Y is the logical opposite of input A
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity not_gate is
    port (
        A : in  std_logic;   -- single input
        Y : out std_logic    -- output = NOT A
    );
end entity not_gate;

architecture dataflow of not_gate is
begin
    -- Concurrent assignment: Y is the inverse of A
    Y <= not A;
end architecture dataflow;

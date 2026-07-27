-- 2-input OR gate
-- Output Y is '1' when either A or B (or both) are '1'
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity OR_Gate is
    port (
        A : in  std_logic;   -- first input
        B : in  std_logic;   -- second input
        Y : out std_logic    -- output = A OR B
    );
end entity OR_Gate;

architecture dataflow of OR_Gate is
begin
    -- Concurrent assignment: Y follows A OR B at all times
    Y <= A or B;
end architecture dataflow;

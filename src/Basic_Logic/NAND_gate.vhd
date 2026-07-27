-- 2-input NAND gate
-- Output Y is '0' only when both A and B are '1' (inverse of AND)
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity NAND_gate is
    port (
        A : in  std_logic;   -- first input
        B : in  std_logic;   -- second input
        Y : out std_logic    -- output = NOT (A AND B)
    );
end entity NAND_gate;

architecture dataflow of NAND_gate is
begin
    -- Concurrent assignment: Y is the inverse of A AND B
    Y <= A nand B;
end architecture dataflow;

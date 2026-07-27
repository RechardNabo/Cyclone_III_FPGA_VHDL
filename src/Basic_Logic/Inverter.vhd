-- Bus inverter (generic-width NOT)
-- Inverts every bit of the input bus
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Inverter is
    generic (
        WIDTH : integer := 8   -- number of bits in the bus
    );
    port (
        A : in  std_logic_vector(WIDTH-1 downto 0);  -- input bus
        Y : out std_logic_vector(WIDTH-1 downto 0)   -- inverted output bus
    );
end entity Inverter;

architecture dataflow of Inverter is
begin
    -- Invert every bit of the input bus
    Y <= not A;
end architecture dataflow;

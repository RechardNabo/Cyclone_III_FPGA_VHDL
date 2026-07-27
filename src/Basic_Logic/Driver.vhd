-- Tri-state buffer driver (generic width, with enable)
-- When enable is '1', the output follows the input bus.
-- When enable is '0', the output is high-impedance (Z).
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Driver is
    generic (
        WIDTH : integer := 8   -- width of the data bus
    );
    port (
        D : in  std_logic_vector(WIDTH-1 downto 0);  -- data input bus
        E : in  std_logic;                           -- enable (active-high)
        Y : out std_logic_vector(WIDTH-1 downto 0)   -- tri-state output bus
    );
end entity Driver;

architecture dataflow of Driver is
begin
    -- When E='1' drive the input onto Y; otherwise high-impedance
    Y <= D when E = '1' else (others => 'Z');
end architecture dataflow;

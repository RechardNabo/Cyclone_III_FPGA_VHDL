-- 2-to-1 multiplexer (generic width)
-- Selects one of two input buses based on the select line
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity mux_2to1 is
    generic (
        WIDTH : integer := 8   -- width of each data input
    );
    port (
        D0 : in  std_logic_vector(WIDTH-1 downto 0);  -- data input 0
        D1 : in  std_logic_vector(WIDTH-1 downto 0);  -- data input 1
        S  : in  std_logic;                           -- select (0 => D0, 1 => D1)
        Y  : out std_logic_vector(WIDTH-1 downto 0)   -- selected output
    );
end entity mux_2to1;

architecture dataflow of mux_2to1 is
begin
    -- When S='0' output D0, when S='1' output D1
    Y <= D0 when S = '0' else D1;
end architecture dataflow;

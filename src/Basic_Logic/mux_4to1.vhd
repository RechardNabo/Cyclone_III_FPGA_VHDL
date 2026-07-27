-- 4-to-1 multiplexer (generic width)
-- Selects one of four input buses using a 2-bit select word
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity mux_4to1 is
    generic (
        WIDTH : integer := 8   -- width of each data input
    );
    port (
        D0 : in  std_logic_vector(WIDTH-1 downto 0);  -- data input 0
        D1 : in  std_logic_vector(WIDTH-1 downto 0);  -- data input 1
        D2 : in  std_logic_vector(WIDTH-1 downto 0);  -- data input 2
        D3 : in  std_logic_vector(WIDTH-1 downto 0);  -- data input 3
        S  : in  std_logic_vector(1 downto 0);        -- 2-bit select
        Y  : out std_logic_vector(WIDTH-1 downto 0)   -- selected output
    );
end entity mux_4to1;

architecture dataflow of mux_4to1 is
begin
    -- Select output based on the 2-bit select word
    with S select
        Y <= D0 when "00",
             D1 when "01",
             D2 when "10",
             D3 when others;
end architecture dataflow;

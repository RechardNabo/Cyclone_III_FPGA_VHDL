-- ============================================================================
-- 4-to-1 Multiplexer (4-bit data inputs)
-- ============================================================================
-- Selects one of four 4-bit input channels based on a 2-bit select line.
--   Sel = "00" -> D0, "01" -> D1, "10" -> D2, "11" -> D3
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity multiplexer_4to1 is
    port (
        D0 : in  std_logic_vector(3 downto 0);  -- Channel 0
        D1 : in  std_logic_vector(3 downto 0);  -- Channel 1
        D2 : in  std_logic_vector(3 downto 0);  -- Channel 2
        D3 : in  std_logic_vector(3 downto 0);  -- Channel 3
        Sel: in  std_logic_vector(1 downto 0);  -- 2-bit select
        Y  : out std_logic_vector(3 downto 0)   -- Selected output
    );
end entity multiplexer_4to1;

architecture behavioral of multiplexer_4to1 is
begin
    process(D0, D1, D2, D3, Sel)
    begin
        case Sel is
            when "00" => Y <= D0;
            when "01" => Y <= D1;
            when "10" => Y <= D2;
            when "11" => Y <= D3;
            when others => Y <= (others => '0');
        end case;
    end process;
end architecture behavioral;

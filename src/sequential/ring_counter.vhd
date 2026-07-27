library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- 4-bit Ring Counter with Reset
-- ============================================================================
-- A ring counter circulates a single '1' through a 4-bit shift register.
-- Reset loads "0001" (starting pattern). On each rising clock edge the
-- single '1' shifts left and wraps around from bit 3 to bit 0.
entity ring_counter is
    port (
        clk   : in  std_logic;                     -- clock
        reset : in  std_logic;                     -- sync, active-high reset
        q     : out std_logic_vector(3 downto 0)   -- ring output
    );
end entity ring_counter;

architecture rtl of ring_counter is
    signal ring : std_logic_vector(3 downto 0) := "0001";  -- start pattern
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                ring <= "0001";                 -- reload starting pattern
            else
                ring <= ring(2 downto 0) & ring(3);  -- rotate left, wrap MSB
            end if;
        end if;
    end process;

    q <= ring;
end architecture rtl;

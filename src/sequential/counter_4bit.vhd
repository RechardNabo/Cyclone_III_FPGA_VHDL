library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- 4-bit Up Counter with Enable and Synchronous Reset
-- ============================================================================
-- Counts 0..15 on each rising clock edge when enable = '1'.
-- Synchronous reset: reset takes effect on the rising clock edge.
entity counter_4bit is
    port (
        clk    : in  std_logic;                     -- clock
        reset  : in  std_logic;                     -- synchronous, active-high reset
        enable : in  std_logic;                     -- count enable (1 = count)
        count  : out std_logic_vector(3 downto 0)   -- current count value
    );
end entity counter_4bit;

architecture rtl of counter_4bit is
    signal cnt : unsigned(3 downto 0) := (others => '0');  -- internal counter
begin
    process(clk)
    begin
        -- Trigger on rising edge of clk
        if rising_edge(clk) then
            if reset = '1' then
                cnt <= (others => '0');   -- sync reset clears counter
            elsif enable = '1' then
                cnt <= cnt + 1;           -- increment when enabled
            end if;
        end if;
    end process;

    -- Drive output from internal register
    count <= std_logic_vector(cnt);
end architecture rtl;

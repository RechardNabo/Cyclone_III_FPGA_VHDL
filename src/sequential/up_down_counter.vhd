library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- 4-bit Up/Down Counter with Direction Input
-- ============================================================================
-- up_down = '1' -> count up (0..15)
-- up_down = '0' -> count down (15..0)
-- Synchronous reset: reset takes effect on the rising clock edge.
entity up_down_counter is
    port (
        clk     : in  std_logic;                     -- clock
        reset   : in  std_logic;                     -- sync, active-high reset
        up_down : in  std_logic;                     -- 1 = up, 0 = down
        count   : out std_logic_vector(3 downto 0)   -- current count
    );
end entity up_down_counter;

architecture rtl of up_down_counter is
    signal cnt : unsigned(3 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cnt <= (others => '0');        -- sync reset to zero
            elsif up_down = '1' then
                cnt <= cnt + 1;                -- count up
            else
                cnt <= cnt - 1;                -- count down (wraps)
            end if;
        end if;
    end process;

    count <= std_logic_vector(cnt);
end architecture rtl;

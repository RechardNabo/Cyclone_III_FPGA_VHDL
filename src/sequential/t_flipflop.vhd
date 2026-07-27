library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- T Flip-Flop with Asynchronous Reset
-- ============================================================================
-- When T = '1', the output toggles on each rising clock edge.
-- When T = '0', the output holds its value.
-- Asynchronous reset: reset = '1' forces Q to '0' immediately.
entity t_flipflop is
    port (
        clk   : in  std_logic;   -- clock
        reset : in  std_logic;   -- async, active-high reset
        t     : in  std_logic;   -- toggle enable
        q     : out std_logic    -- output
    );
end entity t_flipflop;

architecture rtl of t_flipflop is
    signal q_reg : std_logic := '0';
begin
    process(clk, reset)
    begin
        -- Async reset has priority
        if reset = '1' then
            q_reg <= '0';
        elsif rising_edge(clk) then
            if t = '1' then
                q_reg <= not q_reg;   -- toggle when T = 1
            end if;
        end if;
    end process;

    q <= q_reg;
end architecture rtl;

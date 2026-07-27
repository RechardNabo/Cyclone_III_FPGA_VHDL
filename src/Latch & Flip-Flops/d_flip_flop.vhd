library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- D Flip-Flop with Asynchronous Reset
-- ============================================================================
-- On rising clock edge, Q follows D.
-- Asynchronous reset: reset = '1' forces Q to '0' immediately.
entity d_flip_flop is
    port (
        clk   : in  std_logic;   -- clock
        reset : in  std_logic;   -- async, active-high reset
        d     : in  std_logic;   -- data input
        q     : out std_logic    -- data output
    );
end entity d_flip_flop;

architecture rtl of d_flip_flop is
    signal q_reg : std_logic := '0';
begin
    process(clk, reset)
    begin
        -- Async reset has priority over clock
        if reset = '1' then
            q_reg <= '0';
        elsif rising_edge(clk) then
            q_reg <= d;    -- capture D on rising edge
        end if;
    end process;

    q <= q_reg;
end architecture rtl;

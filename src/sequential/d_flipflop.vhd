library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- D Flip-Flop with Asynchronous Reset and Enable
-- ============================================================================
-- On rising clock edge, if enable = '1' the output follows D.
-- Asynchronous reset: reset = '1' forces Q to '0' immediately.
entity d_flipflop is
    port (
        clk    : in  std_logic;   -- clock
        reset  : in  std_logic;   -- async, active-high reset
        enable : in  std_logic;   -- enable: 1 = load D, 0 = hold
        d      : in  std_logic;   -- data input
        q      : out std_logic    -- data output
    );
end entity d_flipflop;

architecture rtl of d_flipflop is
    signal q_reg : std_logic := '0';   -- stored bit
begin
    process(clk, reset)
    begin
        -- Asynchronous reset has priority over clock
        if reset = '1' then
            q_reg <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                q_reg <= d;    -- capture D on rising edge when enabled
            end if;
        end if;
    end process;

    q <= q_reg;
end architecture rtl;

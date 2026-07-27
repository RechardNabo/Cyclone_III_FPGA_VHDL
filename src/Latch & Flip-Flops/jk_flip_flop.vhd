library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- JK Flip-Flop with Asynchronous Reset
-- ============================================================================
-- Truth table (on rising edge):
--   J K | Q_next
--   0 0 | hold
--   0 1 | 0
--   1 0 | 1
--   1 1 | toggle
-- Asynchronous reset: reset = '1' forces Q to '0' immediately.
entity jk_flip_flop is
    port (
        clk   : in  std_logic;   -- clock
        reset : in  std_logic;   -- async, active-high reset
        j     : in  std_logic;   -- J input
        k     : in  std_logic;   -- K input
        q     : out std_logic    -- output
    );
end entity jk_flip_flop;

architecture rtl of jk_flip_flop is
    signal q_reg : std_logic := '0';
begin
    process(clk, reset)
    begin
        -- Async reset dominates
        if reset = '1' then
            q_reg <= '0';
        elsif rising_edge(clk) then
            if j = '0' and k = '0' then
                q_reg <= q_reg;          -- hold
            elsif j = '0' and k = '1' then
                q_reg <= '0';            -- reset
            elsif j = '1' and k = '0' then
                q_reg <= '1';            -- set
            else
                q_reg <= not q_reg;      -- toggle when J=K=1
            end if;
        end if;
    end process;

    q <= q_reg;
end architecture rtl;

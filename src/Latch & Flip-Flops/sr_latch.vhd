library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- SR Latch (Set-Reset, level-sensitive)
-- ============================================================================
-- A level-sensitive (transparent) SR latch.
--   S R | Q_next
--   0 0 | hold
--   0 1 | 0 (reset)
--   1 0 | 1 (set)
--   1 1 | not allowed (both inputs high)
-- When S=R='0' the latch holds its last value (feedback).
entity sr_latch is
    port (
        s   : in  std_logic;   -- set input (active high)
        r   : in  std_logic;   -- reset input (active high)
        q   : out std_logic;   -- output
        q_n : out std_logic    -- complementary output
    );
end entity sr_latch;

architecture rtl of sr_latch is
    signal q_int : std_logic := '0';   -- internal state
begin
    -- Level-sensitive process: responds to any change on S or R
    process(s, r)
    begin
        if s = '1' and r = '1' then
            q_int <= '0';          -- invalid state forced to 0 (avoid contention)
        elsif s = '1' then
            q_int <= '1';          -- set
        elsif r = '1' then
            q_int <= '0';          -- reset
        end if;
        -- when S=R='0', no assignment -> holds previous value
    end process;

    q   <= q_int;
    q_n <= not q_int;
end architecture rtl;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Generic N-bit Up Counter with Enable
-- ============================================================================
-- Counts from 0 to 2**N-1. Generic N defaults to 8.
-- No reset: counter free-runs when enable = '1'.
entity counter_nbit is
    generic (
        N : integer := 8                             -- width of counter
    );
    port (
        clk    : in  std_logic;                       -- clock
        enable : in  std_logic;                       -- count enable
        count  : out std_logic_vector(N-1 downto 0)   -- current count
    );
end entity counter_nbit;

architecture rtl of counter_nbit is
    signal cnt : unsigned(N-1 downto 0) := (others => '0');
begin
    process(clk)
    begin
        -- Rising edge of clock updates the counter
        if rising_edge(clk) then
            if enable = '1' then
                cnt <= cnt + 1;   -- natural wraparound at 2**N
            end if;
        end if;
    end process;

    count <= std_logic_vector(cnt);
end architecture rtl;

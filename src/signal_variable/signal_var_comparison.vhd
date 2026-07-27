-- ============================================================================
-- Module: signal_var_comparison
-- Purpose: Side-by-side comparison of SIGNAL vs VARIABLE update timing
-- ----------------------------------------------------------------------------
-- Key concept for beginners:
--   SIGNAL  (<=): updates at END of process -> reads see OLD value
--   VARIABLE (: =): updates IMMEDIATELY     -> reads see NEW value
--
--   This module performs the SAME computation two ways:
--     1) Using a signal (sig_temp)   -> result_sig
--     2) Using a variable (var_temp) -> result_var
--
--   Because of the update-timing difference, result_sig and result_var
--   will DIFFER by one clock cycle, clearly showing the distinction.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity signal_var_comparison is
    port (
        clk        : in  std_logic;                     -- Clock input
        rst        : in  std_logic;                     -- Active-high reset
        d_in       : in  std_logic_vector(7 downto 0);  -- Shared data input
        result_sig : out std_logic_vector(7 downto 0);  -- Computed via signal
        result_var : out std_logic_vector(7 downto 0)   -- Computed via variable
    );
end entity signal_var_comparison;

architecture rtl of signal_var_comparison is
    -- Signal used in the signal-based computation
    signal sig_temp : std_logic_vector(7 downto 0) := (others => '0');
begin

    -- -----------------------------------------------------------------------
    -- Process A: uses a SIGNAL for intermediate storage
    --   sig_temp <= d_in;            -- scheduled, updates at process END
    --   result_sig <= sig_temp + 1;  -- reads OLD sig_temp -> one cycle behind
    -- -----------------------------------------------------------------------
    -- Process B: uses a VARIABLE for intermediate storage
    --   var_temp := d_in;            -- immediate update
    --   result_var <= var_temp + 1;  -- reads NEW var_temp -> same cycle
    -- -----------------------------------------------------------------------
    process(clk, rst)
        variable var_temp : std_logic_vector(7 downto 0) := (others => '0');
    begin
        if rst = '1' then
            sig_temp   <= (others => '0');
            result_sig <= (others => '0');
            result_var <= (others => '0');
            var_temp   := (others => '0');
        elsif rising_edge(clk) then
            -- --- Signal path (delta-delayed) ---
            sig_temp   <= d_in;  -- scheduled: old value still visible below
            result_sig <= std_logic_vector(unsigned(sig_temp) + 1);

            -- --- Variable path (immediate) ---
            var_temp   := d_in;  -- immediate: new value visible below
            result_var <= std_logic_vector(unsigned(var_temp) + 1);
        end if;
    end process;

end architecture rtl;

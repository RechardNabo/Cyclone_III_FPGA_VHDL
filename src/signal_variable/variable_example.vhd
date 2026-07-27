-- ============================================================================
-- Module: variable_example
-- Purpose: Demonstrate VHDL VARIABLE usage in a clocked process
-- ----------------------------------------------------------------------------
-- Key concept for beginners:
--   VARIABLES update IMMEDIATELY when assigned (using := operator).
--   When you assign to a variable and then read it in the same process,
--   you get the NEW value right away.
--   Variables are local to the process where they are declared.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity variable_example is
    port (
        clk     : in  std_logic;                     -- Clock input
        rst     : in  std_logic;                     -- Active-high reset
        d_in    : in  std_logic_vector(7 downto 0);  -- Data input
        q_out   : out std_logic_vector(7 downto 0);  -- Output after +1
        q_sum   : out std_logic_vector(7 downto 0)   -- Output after +2
    );
end entity variable_example;

architecture rtl of variable_example is
begin

    -- Clocked process using VARIABLES.
    -- Variables are declared inside the process (local scope).
    -- Variables update IMMEDIATELY, so subsequent reads see new values.
    process(clk, rst)
        -- Variables declared in process declarative region
        variable temp_v : std_logic_vector(7 downto 0) := (others => '0');
        variable sum_v  : std_logic_vector(7 downto 0) := (others => '0');
    begin
        if rst = '1' then
            temp_v := (others => '0');   -- immediate update
            sum_v  := (others => '0');   -- immediate update
        elsif rising_edge(clk) then
            -- temp_v gets d_in IMMEDIATELY
            temp_v := d_in;
            -- sum_v reads the NEW temp_v (not the old one) and adds 1
            sum_v  := std_logic_vector(unsigned(temp_v) + 1);
            -- Because variables update immediately, both q_out and q_sum
            -- reflect the updated values in the same clock cycle.
        end if;

        -- Transfer variable results to output signals at process end
        q_out <= temp_v;
        q_sum <= sum_v;
    end process;

end architecture rtl;

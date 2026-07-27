-- ============================================================================
-- Module: signal_example
-- Purpose: Demonstrate VHDL SIGNAL usage in a clocked process
-- ----------------------------------------------------------------------------
-- Key concept for beginners:
--   SIGNALS update at the END of a process (after a delta delay).
--   When you assign to a signal and then read it in the same process,
--   you get the OLD value, not the newly assigned one.
--   This creates a shift-register / pipeline behavior in hardware.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity signal_example is
    port (
        clk     : in  std_logic;                     -- Clock input
        rst     : in  std_logic;                     -- Active-high reset
        d_in    : in  std_logic_vector(7 downto 0);  -- Data input
        q_reg   : out std_logic_vector(7 downto 0);  -- Registered output
        q_pipe  : out std_logic_vector(7 downto 0)   -- Pipelined output
    );
end entity signal_example;

architecture rtl of signal_example is
    -- Signals are declared in the architecture (visible to whole arch)
    -- Signals represent wires or registers in real hardware
    signal reg_s   : std_logic_vector(7 downto 0) := (others => '0');
    signal pipe_s  : std_logic_vector(7 downto 0) := (others => '0');
begin

    -- Clocked process: signals are updated at the END of the process.
    -- Both assignments read the OLD values of reg_s / pipe_s because
    -- signals do not change until the process suspends.
    process(clk, rst)
    begin
        if rst = '1' then
            reg_s  <= (others => '0');   -- scheduled update
            pipe_s <= (others => '0');   -- scheduled update
        elsif rising_edge(clk) then
            -- reg_s  gets d_in (new value scheduled)
            -- pipe_s gets reg_s (OLD value of reg_s, not d_in!)
            -- This creates a 2-stage pipeline: d_in -> reg_s -> pipe_s
            reg_s  <= d_in;
            pipe_s <= reg_s;   -- reads OLD reg_s => shift register behavior
        end if;
    end process;

    -- Drive outputs from internal signals
    q_reg  <= reg_s;
    q_pipe <= pipe_s;

end architecture rtl;

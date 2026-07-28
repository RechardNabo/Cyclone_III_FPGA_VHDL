-- Testbench for LED Blinker
-- Tests 1 Hz blinking with small CLK_FREQ_HZ for fast simulation
-- LED toggles every COUNT_MAX+1 cycles where COUNT_MAX = CLK_FREQ_HZ/2 - 1
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_leds is
end entity tb_leds;

architecture test of tb_leds is

    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1';  -- active-low
    signal led_out : std_logic;

    constant CLK_PERIOD : time := 10 ns;

    -- Small clock frequency for fast simulation
    -- COUNT_MAX = CLK_FREQ_HZ/2 - 1 = 10/2 - 1 = 4
    -- LED toggles every 5 clock cycles
    constant CLK_FREQ_TB : integer := 10;
    constant COUNT_MAX   : integer := CLK_FREQ_TB / 2 - 1;  -- 4

begin

    dut : entity work.leds
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_TB
        )
        port map (
            clk     => clk,
            reset   => reset,
            led_out => led_out
        );

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process clk_proc;

    -- Stimulus process
    stim_proc : process
    begin

        ----------------------------------------------------------------
        -- Test 1: Reset (active-low) -> led_out should be '0'
        ----------------------------------------------------------------
        reset <= '0';  -- assert reset (active-low)
        wait for CLK_PERIOD * 2;
        assert led_out = '0'
            report "Test 1 failed: led_out should be 0 during reset" severity error;

        ----------------------------------------------------------------
        -- Test 2: Release reset, LED should start at '0'
        ----------------------------------------------------------------
        reset <= '1';  -- deassert reset
        wait for CLK_PERIOD;
        assert led_out = '0'
            report "Test 2 failed: led_out should be 0 after reset release" severity error;

        ----------------------------------------------------------------
        -- Test 3: After COUNT_MAX+1 cycles, LED should toggle to '1'
        ----------------------------------------------------------------
        -- We already waited 1 cycle (counter=1), need COUNT_MAX-1 more
        -- to reach counter=COUNT_MAX-1, then one more edge toggles
        wait for CLK_PERIOD * (COUNT_MAX - 1);
        assert led_out = '0'
            report "Test 3a failed: led_out should still be 0 before toggle" severity error;
        -- Next clock edge should toggle
        wait for CLK_PERIOD;
        assert led_out = '1'
            report "Test 3b failed: led_out should toggle to 1" severity error;

        ----------------------------------------------------------------
        -- Test 4: After another COUNT_MAX+1 cycles, LED should toggle to '0'
        ----------------------------------------------------------------
        wait for CLK_PERIOD * COUNT_MAX;
        assert led_out = '1'
            report "Test 4a failed: led_out should still be 1 before toggle" severity error;
        wait for CLK_PERIOD;
        assert led_out = '0'
            report "Test 4b failed: led_out should toggle back to 0" severity error;

        ----------------------------------------------------------------
        -- Test 5: Another full toggle cycle back to '1'
        ----------------------------------------------------------------
        wait for CLK_PERIOD * (COUNT_MAX + 1);
        assert led_out = '1'
            report "Test 5 failed: led_out should toggle to 1 again" severity error;

        ----------------------------------------------------------------
        -- Test 6: Reset during operation clears LED
        ----------------------------------------------------------------
        reset <= '0';  -- assert reset
        wait for CLK_PERIOD * 2;
        assert led_out = '0'
            report "Test 6 failed: led_out should be 0 after reset" severity error;

        ----------------------------------------------------------------
        -- Test 7: Release reset and verify toggling resumes
        ----------------------------------------------------------------
        reset <= '1';
        wait for CLK_PERIOD * (COUNT_MAX + 1);
        assert led_out = '1'
            report "Test 7 failed: led_out should toggle after reset release" severity error;

        report "All leds tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim_proc;

end architecture test;

-- Testbench for traffic_light FSM
-- Tests state transitions: GREEN -> YELLOW -> RED -> GREEN
-- Uses small CLK_FREQ generic to keep simulation time short
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_traffic_light is
end entity tb_traffic_light;

architecture test of tb_traffic_light is

    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal red   : std_logic;
    signal green : std_logic;
    signal yellow : std_logic;

    constant CLK_PERIOD : time := 10 ns;

    -- Use small CLK_FREQ for fast simulation
    -- GREEN_TIME = 5 * CLK_FREQ, YELLOW_TIME = 2 * CLK_FREQ, RED_TIME = 5 * CLK_FREQ
    -- With CLK_FREQ=10: green=50, yellow=20, red=50 cycles
    constant CLK_FREQ_TB : integer := 10;

begin

    dut : entity work.traffic_light
        generic map (
            CLK_FREQ => CLK_FREQ_TB
        )
        port map (
            clk    => clk,
            rst    => rst,
            red    => red,
            green  => green,
            yellow => yellow
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
        constant GREEN_TIME  : integer := 5 * CLK_FREQ_TB;  -- 50
        constant YELLOW_TIME : integer := 2 * CLK_FREQ_TB;  -- 20
        constant RED_TIME    : integer := 5 * CLK_FREQ_TB;  -- 50
    begin

        ----------------------------------------------------------------
        -- Test 1: Reset -> should be in GREEN state
        ----------------------------------------------------------------
        rst <= '1';
        wait for CLK_PERIOD * 2;
        rst <= '0';
        wait for CLK_PERIOD;
        assert green = '1'
            report "Test 1 failed: green should be 1 after reset" severity error;
        assert yellow = '0'
            report "Test 1 failed: yellow should be 0 after reset" severity error;
        assert red = '0'
            report "Test 1 failed: red should be 0 after reset" severity error;

        ----------------------------------------------------------------
        -- Test 2: Stay in GREEN for GREEN_TIME cycles, then -> YELLOW
        ----------------------------------------------------------------
        -- Already 1 cycle in green, wait remaining GREEN_TIME-2 cycles
        wait for CLK_PERIOD * (GREEN_TIME - 2);
        assert green = '1'
            report "Test 2a failed: should still be green" severity error;
        -- Next cycle should transition to yellow
        wait for CLK_PERIOD;
        assert yellow = '1'
            report "Test 2b failed: should transition to yellow" severity error;
        assert green = '0'
            report "Test 2b failed: green should be 0 in yellow state" severity error;
        assert red = '0'
            report "Test 2b failed: red should be 0 in yellow state" severity error;

        ----------------------------------------------------------------
        -- Test 3: Stay in YELLOW for YELLOW_TIME cycles, then -> RED
        ----------------------------------------------------------------
        -- Already 1 cycle in yellow, wait remaining YELLOW_TIME-2 cycles
        wait for CLK_PERIOD * (YELLOW_TIME - 2);
        assert yellow = '1'
            report "Test 3a failed: should still be yellow" severity error;
        -- Next cycle should transition to red
        wait for CLK_PERIOD;
        assert red = '1'
            report "Test 3b failed: should transition to red" severity error;
        assert green = '0'
            report "Test 3b failed: green should be 0 in red state" severity error;
        assert yellow = '0'
            report "Test 3b failed: yellow should be 0 in red state" severity error;

        ----------------------------------------------------------------
        -- Test 4: Stay in RED for RED_TIME cycles, then -> GREEN
        ----------------------------------------------------------------
        -- Already 1 cycle in red, wait remaining RED_TIME-2 cycles
        wait for CLK_PERIOD * (RED_TIME - 2);
        assert red = '1'
            report "Test 4a failed: should still be red" severity error;
        -- Next cycle should transition back to green
        wait for CLK_PERIOD;
        assert green = '1'
            report "Test 4b failed: should transition back to green" severity error;
        assert yellow = '0'
            report "Test 4b failed: yellow should be 0 in green state" severity error;
        assert red = '0'
            report "Test 4b failed: red should be 0 in green state" severity error;

        ----------------------------------------------------------------
        -- Test 5: Only one light active at any time (invariant check)
        ----------------------------------------------------------------
        assert (green = '1' and yellow = '0' and red = '0')
            report "Test 5 failed: exactly one light should be on" severity error;

        ----------------------------------------------------------------
        -- Test 6: Reset during operation returns to GREEN
        ----------------------------------------------------------------
        -- Wait a few cycles into green
        wait for CLK_PERIOD * 5;
        rst <= '1';
        wait for CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;
        assert green = '1'
            report "Test 6 failed: should return to green after reset" severity error;

        report "All traffic_light tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim_proc;

end architecture test;

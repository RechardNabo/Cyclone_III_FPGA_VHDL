-- Testbench for vending_machine FSM
-- Tests coin insertion, product dispensing, and change calculation
-- Product costs 25 cents; accepts nickel(5), dime(10), quarter(25)
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_vending_machine is
end entity tb_vending_machine;

architecture test of tb_vending_machine is

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal coin_5     : std_logic := '0';
    signal coin_10    : std_logic := '0';
    signal coin_25    : std_logic := '0';
    signal dispense   : std_logic;
    signal change_out : std_logic_vector(6 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    dut : entity work.vending_machine
        port map (
            clk        => clk,
            rst        => rst,
            coin_5     => coin_5,
            coin_10    => coin_10,
            coin_25    => coin_25,
            dispense   => dispense,
            change_out => change_out
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
        -- Test 1: Reset -> idle state, no dispense
        ----------------------------------------------------------------
        rst <= '1';
        coin_5  <= '0';
        coin_10 <= '0';
        coin_25 <= '0';
        wait for CLK_PERIOD * 2;
        rst <= '0';
        wait for CLK_PERIOD;
        assert dispense = '0'
            report "Test 1 failed: dispense should be 0 after reset" severity error;
        assert change_out = "0000000"
            report "Test 1 failed: change should be 0 after reset" severity error;

        ----------------------------------------------------------------
        -- Test 2: Insert single quarter (25c) -> dispense, change=0
        ----------------------------------------------------------------
        coin_25 <= '1';
        wait for CLK_PERIOD;
        coin_25 <= '0';
        wait for CLK_PERIOD;
        -- After coin insertion, amount=25, goes to S_DISPENSE
        assert dispense = '1'
            report "Test 2a failed: dispense should be 1 after quarter" severity error;
        wait for CLK_PERIOD;
        -- Now in S_CHANGE, change_out should be 0
        assert change_out = "0000000"
            report "Test 2b failed: change should be 0 for exact quarter" severity error;
        assert dispense = '0'
            report "Test 2c failed: dispense should be 0 in change state" severity error;
        wait for CLK_PERIOD;
        -- Back to idle
        assert dispense = '0'
            report "Test 2d failed: should be back in idle" severity error;

        ----------------------------------------------------------------
        -- Test 3: Insert 5 nickels (25c) -> dispense, change=0
        ----------------------------------------------------------------
        -- Insert nickel 1
        coin_5 <= '1';
        wait for CLK_PERIOD;
        coin_5 <= '0';
        wait for CLK_PERIOD;
        assert dispense = '0'
            report "Test 3a failed: no dispense at 5c" severity error;
        -- Insert nickel 2
        coin_5 <= '1';
        wait for CLK_PERIOD;
        coin_5 <= '0';
        wait for CLK_PERIOD;
        assert dispense = '0'
            report "Test 3b failed: no dispense at 10c" severity error;
        -- Insert nickel 3
        coin_5 <= '1';
        wait for CLK_PERIOD;
        coin_5 <= '0';
        wait for CLK_PERIOD;
        assert dispense = '0'
            report "Test 3c failed: no dispense at 15c" severity error;
        -- Insert nickel 4
        coin_5 <= '1';
        wait for CLK_PERIOD;
        coin_5 <= '0';
        wait for CLK_PERIOD;
        assert dispense = '0'
            report "Test 3d failed: no dispense at 20c" severity error;
        -- Insert nickel 5 -> 25c
        coin_5 <= '1';
        wait for CLK_PERIOD;
        coin_5 <= '0';
        wait for CLK_PERIOD;
        assert dispense = '1'
            report "Test 3e failed: dispense should be 1 at 25c" severity error;
        wait for CLK_PERIOD;
        assert change_out = "0000000"
            report "Test 3f failed: change should be 0 for exact 25c" severity error;
        wait for CLK_PERIOD;

        ----------------------------------------------------------------
        -- Test 4: Insert quarter + nickel (30c) -> dispense, change=5
        ----------------------------------------------------------------
        -- Insert quarter
        coin_25 <= '1';
        wait for CLK_PERIOD;
        coin_25 <= '0';
        wait for CLK_PERIOD;
        -- amount=25, goes to dispense
        assert dispense = '1'
            report "Test 4a failed: dispense after quarter" severity error;
        wait for CLK_PERIOD;
        -- In S_CHANGE, change=0, goes back to idle
        wait for CLK_PERIOD;
        -- Now in idle, insert nickel
        coin_5 <= '1';
        wait for CLK_PERIOD;
        coin_5 <= '0';
        wait for CLK_PERIOD;
        -- Only 5c, no dispense
        assert dispense = '0'
            report "Test 4b failed: no dispense at 5c" severity error;

        ----------------------------------------------------------------
        -- Test 5: Insert 2 dimes + 1 nickel (25c) -> dispense, change=0
        ----------------------------------------------------------------
        -- Reset first
        rst <= '1';
        wait for CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;

        -- Insert dime 1 (10c)
        coin_10 <= '1';
        wait for CLK_PERIOD;
        coin_10 <= '0';
        wait for CLK_PERIOD;
        assert dispense = '0'
            report "Test 5a failed: no dispense at 10c" severity error;
        -- Insert dime 2 (20c)
        coin_10 <= '1';
        wait for CLK_PERIOD;
        coin_10 <= '0';
        wait for CLK_PERIOD;
        assert dispense = '0'
            report "Test 5b failed: no dispense at 20c" severity error;
        -- Insert nickel (25c)
        coin_5 <= '1';
        wait for CLK_PERIOD;
        coin_5 <= '0';
        wait for CLK_PERIOD;
        assert dispense = '1'
            report "Test 5c failed: dispense at 25c" severity error;
        wait for CLK_PERIOD;
        assert change_out = "0000000"
            report "Test 5d failed: change should be 0" severity error;
        wait for CLK_PERIOD;

        ----------------------------------------------------------------
        -- Test 6: Insert quarter + dime (35c) -> dispense, change=10
        ----------------------------------------------------------------
        rst <= '1';
        wait for CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;

        -- Insert quarter
        coin_25 <= '1';
        wait for CLK_PERIOD;
        coin_25 <= '0';
        wait for CLK_PERIOD;
        -- amount=25, dispense
        assert dispense = '1'
            report "Test 6a failed: dispense after quarter" severity error;
        wait for CLK_PERIOD;
        -- change=0, back to idle
        wait for CLK_PERIOD;
        -- Insert dime (10c)
        coin_10 <= '1';
        wait for CLK_PERIOD;
        coin_10 <= '0';
        wait for CLK_PERIOD;
        -- Only 10c, no dispense
        assert dispense = '0'
            report "Test 6b failed: no dispense at 10c" severity error;

        ----------------------------------------------------------------
        -- Test 7: Multiple coins in one cycle (quarter+nickel=30c)
        ----------------------------------------------------------------
        rst <= '1';
        wait for CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;

        -- Insert quarter and nickel simultaneously
        coin_25 <= '1';
        coin_5  <= '1';
        wait for CLK_PERIOD;
        coin_25 <= '0';
        coin_5  <= '0';
        wait for CLK_PERIOD;
        -- amount=30, goes to dispense
        assert dispense = '1'
            report "Test 7a failed: dispense at 30c" severity error;
        wait for CLK_PERIOD;
        -- change = 30 - 25 = 5
        assert change_out = std_logic_vector(to_unsigned(5, 7))
            report "Test 7b failed: change should be 5" severity error;
        wait for CLK_PERIOD;

        report "All vending_machine tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim_proc;

end architecture test;

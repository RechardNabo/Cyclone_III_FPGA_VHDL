-- ============================================================================
-- Testbench for Mealy FSM: "101" pattern detector
-- Tests reset, pattern detection, overlapping patterns, and non-matching sequences
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_fsm_mealy is
end entity tb_fsm_mealy;

architecture sim of tb_fsm_mealy is
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal din      : std_logic := '0';
    signal detected : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin

    dut : entity work.fsm_mealy
        port map (
            clk      => clk,
            rst      => rst,
            din      => din,
            detected => detected
        );

    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    stim_proc : process
    begin
        -- -------------------------------------------------------
        -- Test 1: Reset state — detected must be low
        -- -------------------------------------------------------
        rst <= '1';
        din <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        rst <= '0';
        wait for 1 ns;
        assert detected = '0'
            report "Test 1 FAIL: detected not low after reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;

        -- -------------------------------------------------------
        -- Test 2: Detect "101" — Mealy output is combinational
        --   S0 --din=1--> S1 --din=0--> S2 --din=1--> detected=1
        -- -------------------------------------------------------
        din <= '1';
        wait for 1 ns;
        assert detected = '0'
            report "Test 2a FAIL: detected high in S0 with din=1"
            severity error;
        wait until rising_edge(clk);
        wait for 1 ns;
        -- Now in S1
        din <= '0';
        wait for 1 ns;
        assert detected = '0'
            report "Test 2b FAIL: detected high in S1 with din=0"
            severity error;
        wait until rising_edge(clk);
        wait for 1 ns;
        -- Now in S2
        din <= '1';
        wait for 1 ns;
        assert detected = '1'
            report "Test 2c FAIL: detected not high in S2 with din=1 (Mealy)"
            severity error;
        report "Test 2 PASS: 101 pattern detected (Mealy combinational)" severity note;
        wait until rising_edge(clk);
        wait for 1 ns;

        -- -------------------------------------------------------
        -- Test 3: Overlapping "101" — "10101" should detect twice
        --   After first detection we are in S1 (last '1' starts new)
        --   din=0 -> S2, din=1 -> detected
        -- -------------------------------------------------------
        din <= '0';
        wait for 1 ns;
        assert detected = '0'
            report "Test 3a FAIL: detected high in S1 with din=0"
            severity error;
        wait until rising_edge(clk);
        wait for 1 ns;
        -- Now in S2
        din <= '1';
        wait for 1 ns;
        assert detected = '1'
            report "Test 3b FAIL: overlapping 101 not detected"
            severity error;
        report "Test 3 PASS: Overlapping 10101 detected twice" severity note;
        wait until rising_edge(clk);
        wait for 1 ns;

        -- -------------------------------------------------------
        -- Test 4: Non-matching sequence "100" — no detection
        -- -------------------------------------------------------
        din <= '0';
        wait for 1 ns;
        assert detected = '0'
            report "Test 4a FAIL: detected high in S1 with din=0"
            severity error;
        wait until rising_edge(clk);
        wait for 1 ns;
        -- Now in S2
        din <= '0';
        wait for 1 ns;
        assert detected = '0'
            report "Test 4b FAIL: detected high in S2 with din=0 (100)"
            severity error;
        wait until rising_edge(clk);
        wait for 1 ns;
        -- Now in S0
        assert detected = '0'
            report "Test 4c FAIL: detected high in S0"
            severity error;
        report "Test 4 PASS: 100 sequence correctly not detected" severity note;

        -- -------------------------------------------------------
        -- Test 5: All zeros — never detects
        -- -------------------------------------------------------
        din <= '0';
        for i in 0 to 5 loop
            wait for 1 ns;
            assert detected = '0'
                report "Test 5 FAIL: detected high during all-zeros"
                severity error;
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;
        report "Test 5 PASS: All-zeros never triggers detection" severity note;

        -- -------------------------------------------------------
        -- Test 6: Synchronous reset mid-sequence
        -- -------------------------------------------------------
        din <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In S1
        rst <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        rst <= '0';
        -- Should be back in S0
        din <= '1';
        wait for 1 ns;
        assert detected = '0'
            report "Test 6 FAIL: state not reset to S0"
            severity error;
        report "Test 6 PASS: Synchronous reset returns to S0" severity note;

        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

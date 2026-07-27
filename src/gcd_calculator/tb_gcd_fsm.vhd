-- ============================================================================
-- Testbench for GCD Calculator - FSM Controller
-- Tests: reset, start/load, compare/subtract/swap/done state transitions
-- Drives a_ge_b and b_eq_zero status signals and checks control outputs
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_gcd_fsm is
end entity tb_gcd_fsm;

architecture sim of tb_gcd_fsm is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal start     : std_logic := '0';
    signal a_ge_b    : std_logic := '0';
    signal b_eq_zero : std_logic := '0';
    signal load_en   : std_logic;
    signal swap_en   : std_logic;
    signal sub_en    : std_logic;
    signal done      : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin

    dut : entity work.gcd_fsm
        port map (
            clk       => clk,
            reset     => reset,
            start     => start,
            a_ge_b    => a_ge_b,
            b_eq_zero => b_eq_zero,
            load_en   => load_en,
            swap_en   => swap_en,
            sub_en    => sub_en,
            done      => done
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
        -- Test 1: Reset state — all control signals low
        -- -------------------------------------------------------
        reset <= '1';
        start <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert load_en = '0' and swap_en = '0' and sub_en = '0' and done = '0'
            report "Test 1 FAIL: control signals not low after reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;
        reset <= '0';
        wait for 1 ns;

        -- -------------------------------------------------------
        -- Test 2: Start → load_en asserted, go to COMPARE
        -- -------------------------------------------------------
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        assert load_en = '1'
            report "Test 2 FAIL: load_en not asserted on start"
            severity error;
        report "Test 2 PASS: Start asserts load_en" severity note;

        -- -------------------------------------------------------
        -- Test 3: COMPARE with b_eq_zero=1 → DONE, done=1
        -- -------------------------------------------------------
        b_eq_zero <= '1';
        a_ge_b <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- Now in DONE state
        assert done = '1'
            report "Test 3 FAIL: done not asserted when b_eq_zero=1"
            severity error;
        report "Test 3 PASS: b_eq_zero → DONE, done=1" severity note;

        -- -------------------------------------------------------
        -- Test 4: DONE → IDLE, then start again
        -- -------------------------------------------------------
        b_eq_zero <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In IDLE
        assert done = '0'
            report "Test 4 FAIL: done not deasserted in IDLE"
            severity error;
        report "Test 4 PASS: DONE returns to IDLE" severity note;

        -- -------------------------------------------------------
        -- Test 5: COMPARE with a_ge_b=1 → SUBTRACT, sub_en=1
        -- -------------------------------------------------------
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        -- In COMPARE
        a_ge_b <= '1';
        b_eq_zero <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In SUBTRACT
        assert sub_en = '1'
            report "Test 5 FAIL: sub_en not asserted when a_ge_b=1"
            severity error;
        report "Test 5 PASS: a_ge_b=1 → SUBTRACT, sub_en=1" severity note;

        -- -------------------------------------------------------
        -- Test 6: SUBTRACT → COMPARE, then a_ge_b=0 → SWAP, swap_en=1
        -- -------------------------------------------------------
        a_ge_b <= '0';
        b_eq_zero <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In COMPARE
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In SWAP
        assert swap_en = '1'
            report "Test 6 FAIL: swap_en not asserted when a_ge_b=0 and b!=0"
            severity error;
        report "Test 6 PASS: a_ge_b=0 → SWAP, swap_en=1" severity note;

        -- -------------------------------------------------------
        -- Test 7: SWAP → COMPARE → done path
        -- -------------------------------------------------------
        b_eq_zero <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In COMPARE
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In DONE
        assert done = '1'
            report "Test 7 FAIL: done not asserted after swap→compare→done"
            severity error;
        report "Test 7 PASS: SWAP → COMPARE → DONE path correct" severity note;

        -- -------------------------------------------------------
        -- Test 8: Synchronous reset mid-computation
        -- -------------------------------------------------------
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        -- In COMPARE
        reset <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';
        assert done = '0' and load_en = '0' and swap_en = '0' and sub_en = '0'
            report "Test 8 FAIL: reset did not clear all signals mid-computation"
            severity error;
        report "Test 8 PASS: Synchronous reset mid-computation" severity note;

        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

-- ============================================================================
-- Testbench for Moore FSM: "101" pattern detector
-- Tests reset, pattern detection (output delayed by one clock), overlapping
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_fsm_moore is
end entity tb_fsm_moore;

architecture sim of tb_fsm_moore is
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal din      : std_logic := '0';
    signal detected : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin

    dut : entity work.fsm_moore
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
        -- Test 2: Detect "101" — Moore output appears one clock
        --   after the pattern completes (in state S3)
        --   S0 --1--> S1 --0--> S2 --1--> S3 (detected=1)
        -- -------------------------------------------------------
        din <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In S1
        din <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In S2
        din <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In S3 — detected should be high (Moore: output depends on state)
        assert detected = '1'
            report "Test 2 FAIL: detected not high in S3 after 101"
            severity error;
        report "Test 2 PASS: 101 pattern detected (Moore, state S3)" severity note;

        -- -------------------------------------------------------
        -- Test 3: detected is high for exactly one cycle
        -- -------------------------------------------------------
        din <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- S3 with din=0 goes to S2; detected should now be low
        assert detected = '0'
            report "Test 3 FAIL: detected stayed high beyond one cycle"
            severity error;
        report "Test 3 PASS: detected high for one cycle only" severity note;

        -- -------------------------------------------------------
        -- Test 4: Overlapping "10101" — detect twice
        --   After S3, din=0 -> S2, din=1 -> S3 (detected again)
        --   Current state is S2 (from Test 3)
        -- -------------------------------------------------------
        din <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In S3 — second detection
        assert detected = '1'
            report "Test 4 FAIL: overlapping 101 not detected second time"
            severity error;
        report "Test 4 PASS: Overlapping 10101 detected twice" severity note;

        -- -------------------------------------------------------
        -- Test 5: Non-matching "100" — no detection
        -- -------------------------------------------------------
        rst <= '1';
        din <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        rst <= '0';
        -- In S0
        din <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In S1
        din <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In S2
        din <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In S0 — no detection
        assert detected = '0'
            report "Test 5 FAIL: 100 sequence falsely detected"
            severity error;
        report "Test 5 PASS: 100 correctly not detected" severity note;

        -- -------------------------------------------------------
        -- Test 6: All zeros — never detects
        -- -------------------------------------------------------
        din <= '0';
        for i in 0 to 5 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert detected = '0'
                report "Test 6 FAIL: detected high during all-zeros"
                severity error;
        end loop;
        report "Test 6 PASS: All-zeros never triggers" severity note;

        -- -------------------------------------------------------
        -- Test 7: Synchronous reset mid-sequence
        -- -------------------------------------------------------
        din <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        -- In S1
        rst <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        rst <= '0';
        -- In S0
        assert detected = '0'
            report "Test 7 FAIL: reset did not return to S0"
            severity error;
        report "Test 7 PASS: Synchronous reset returns to S0" severity note;

        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

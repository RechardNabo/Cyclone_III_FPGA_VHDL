-- Testbench for sequence_detector FSM
-- Tests detection of overlapping "1101" pattern in serial bit stream
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_sequence_detector is
end entity tb_sequence_detector;

architecture test of tb_sequence_detector is

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal din      : std_logic := '0';
    signal detected : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    dut : entity work.sequence_detector
        port map (
            clk      => clk,
            rst      => rst,
            din      => din,
            detected => detected
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
        -- Test 1: Reset and verify initial state
        ----------------------------------------------------------------
        rst <= '1';
        din <= '0';
        wait for CLK_PERIOD * 2;
        rst <= '0';
        wait for CLK_PERIOD;
        assert detected = '0'
            report "Test 1 failed: detected should be 0 after reset" severity error;

        ----------------------------------------------------------------
        -- Test 2: Send "1101" -> detected should be 1
        ----------------------------------------------------------------
        -- Send '1'
        din <= '1';
        wait for CLK_PERIOD;
        assert detected = '0'
            report "Test 2a failed: detected should be 0 after first 1" severity error;
        -- Send '1'
        din <= '1';
        wait for CLK_PERIOD;
        assert detected = '0'
            report "Test 2b failed: detected should be 0 after 11" severity error;
        -- Send '0'
        din <= '0';
        wait for CLK_PERIOD;
        assert detected = '0'
            report "Test 2c failed: detected should be 0 after 110" severity error;
        -- Send '1' -> "1101" complete
        din <= '1';
        wait for CLK_PERIOD;
        assert detected = '1'
            report "Test 2d failed: detected should be 1 after 1101" severity error;

        ----------------------------------------------------------------
        -- Test 3: After detection, send '0' -> detected should be 0
        ----------------------------------------------------------------
        din <= '0';
        wait for CLK_PERIOD;
        assert detected = '0'
            report "Test 3 failed: detected should be 0 after non-match" severity error;

        ----------------------------------------------------------------
        -- Test 4: Send non-matching "1010" -> no detection
        ----------------------------------------------------------------
        din <= '1';
        wait for CLK_PERIOD;
        assert detected = '0' report "Test 4a failed" severity error;
        din <= '0';
        wait for CLK_PERIOD;
        assert detected = '0' report "Test 4b failed" severity error;
        din <= '1';
        wait for CLK_PERIOD;
        assert detected = '0' report "Test 4c failed" severity error;
        din <= '0';
        wait for CLK_PERIOD;
        assert detected = '0' report "Test 4d failed" severity error;

        ----------------------------------------------------------------
        -- Test 5: Overlapping detection "1101101"
        --          First match at position 4, second at position 7
        ----------------------------------------------------------------
        -- Reset first
        rst <= '1';
        wait for CLK_PERIOD;
        rst <= '0';

        -- Send "1101" -> first detection
        din <= '1'; wait for CLK_PERIOD;  -- bit 1
        din <= '1'; wait for CLK_PERIOD;  -- bit 2
        din <= '0'; wait for CLK_PERIOD;  -- bit 3
        din <= '1'; wait for CLK_PERIOD;  -- bit 4 -> detected
        assert detected = '1'
            report "Test 5a failed: first 1101 should detect" severity error;

        -- Continue with "101" to form "1101101" (overlapping)
        din <= '1'; wait for CLK_PERIOD;  -- bit 5 (overlapping '1')
        din <= '0'; wait for CLK_PERIOD;  -- bit 6
        din <= '1'; wait for CLK_PERIOD;  -- bit 7 -> second detection
        assert detected = '1'
            report "Test 5b failed: overlapping 1101 should detect" severity error;

        ----------------------------------------------------------------
        -- Test 6: All zeros -> no detection
        ----------------------------------------------------------------
        rst <= '1';
        wait for CLK_PERIOD;
        rst <= '0';
        din <= '0';
        wait for CLK_PERIOD * 8;
        assert detected = '0'
            report "Test 6 failed: no detection on all zeros" severity error;

        ----------------------------------------------------------------
        -- Test 7: "11101" -> should detect (extra 1 before pattern)
        ----------------------------------------------------------------
        rst <= '1';
        wait for CLK_PERIOD;
        rst <= '0';
        din <= '1'; wait for CLK_PERIOD;  -- 1
        din <= '1'; wait for CLK_PERIOD;  -- 11
        din <= '1'; wait for CLK_PERIOD;  -- 111 (stays in S2)
        din <= '0'; wait for CLK_PERIOD;  -- 1110 -> S3
        din <= '1'; wait for CLK_PERIOD;  -- 11101 -> S4 detected
        assert detected = '1'
            report "Test 7 failed: should detect 1101 within 11101" severity error;

        report "All sequence_detector tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim_proc;

end architecture test;

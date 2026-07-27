-- Testbench for counter_4bit
-- Tests 4-bit up counter with synchronous reset and enable.
-- Verifies reset, hold (enable=0), counting sequence, and wraparound.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_counter_4bit is
end entity tb_counter_4bit;

architecture sim of tb_counter_4bit is
    -- DUT signals
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '0';
    signal enable : std_logic := '0';
    signal count  : std_logic_vector(3 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin
    -- Instantiate DUT
    dut : entity work.counter_4bit
        port map (
            clk    => clk,
            reset  => reset,
            enable => enable,
            count  => count
        );

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus process
    stim_proc : process
    begin
        -- ---------------------------------------------------------------
        -- Test 1: Synchronous reset
        -- ---------------------------------------------------------------
        reset  <= '1';
        enable <= '0';
        wait for CLK_PERIOD * 2;
        wait until rising_edge(clk);
        assert count = "0000"
            report "Test 1 FAIL: reset did not clear counter, count=" &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 1 PASS: counter reset to 0" severity note;

        -- ---------------------------------------------------------------
        -- Test 2: Hold when enable=0
        -- ---------------------------------------------------------------
        reset  <= '0';
        enable <= '0';
        wait for CLK_PERIOD * 3;
        assert count = "0000"
            report "Test 2 FAIL: counter changed while enable=0, count=" &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 2 PASS: counter holds when enable=0" severity note;

        -- ---------------------------------------------------------------
        -- Test 3: Count up sequence 0->1->2->3
        -- ---------------------------------------------------------------
        reset  <= '0';
        enable <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0001"
            report "Test 3a FAIL: expected count=1, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0010"
            report "Test 3b FAIL: expected count=2, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0011"
            report "Test 3c FAIL: expected count=3, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 3 PASS: count up sequence 0->1->2->3" severity note;

        -- ---------------------------------------------------------------
        -- Test 4: Reset mid-count
        -- ---------------------------------------------------------------
        reset  <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0000"
            report "Test 4 FAIL: reset mid-count failed, count=" &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 4 PASS: reset mid-count clears to 0" severity note;

        -- ---------------------------------------------------------------
        -- Test 5: Count up and wraparound from 15 to 0
        -- ---------------------------------------------------------------
        reset  <= '0';
        enable <= '1';
        -- Count 16 cycles to go from 0 through 15 and wrap to 0
        for i in 0 to 15 loop
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;
        assert count = "0000"
            report "Test 5 FAIL: expected wraparound to 0, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 5 PASS: wraparound from 15 to 0" severity note;

        -- ---------------------------------------------------------------
        -- Test 6: Disable then re-enable (hold and resume)
        -- ---------------------------------------------------------------
        -- Count is at 0; advance to 2
        wait until rising_edge(clk);
        wait for 1 ns;
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0010"
            report "Test 6a FAIL: expected count=2, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        -- Disable for 3 cycles
        enable <= '0';
        wait for CLK_PERIOD * 3;
        assert count = "0010"
            report "Test 6b FAIL: counter changed while disabled, count=" &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        -- Re-enable and verify it resumes from 2
        enable <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0011"
            report "Test 6c FAIL: expected count=3 after re-enable, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 6 PASS: hold and resume counting" severity note;

        report "All counter_4bit tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

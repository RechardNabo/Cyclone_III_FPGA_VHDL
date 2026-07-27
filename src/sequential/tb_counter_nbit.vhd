-- Testbench for counter_nbit
-- Tests generic N-bit up counter (default N=8) with enable.
-- Verifies hold (enable=0), counting sequence, and wraparound at 2^N-1.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_counter_nbit is
end entity tb_counter_nbit;

architecture sim of tb_counter_nbit is
    -- DUT signals (default generic N = 8)
    signal clk    : std_logic := '0';
    signal enable : std_logic := '0';
    signal count  : std_logic_vector(7 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin
    -- Instantiate DUT with default generic
    dut : entity work.counter_nbit
        generic map (N => 8)
        port map (
            clk    => clk,
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
        -- Test 1: Initial state should be 0
        -- ---------------------------------------------------------------
        enable <= '0';
        wait for CLK_PERIOD * 2;
        assert count = "00000000"
            report "Test 1 FAIL: initial count not 0, count=" &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 1 PASS: initial count is 0" severity note;

        -- ---------------------------------------------------------------
        -- Test 2: Hold when enable=0
        -- ---------------------------------------------------------------
        enable <= '0';
        wait for CLK_PERIOD * 4;
        assert count = "00000000"
            report "Test 2 FAIL: counter changed while enable=0, count=" &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 2 PASS: counter holds when enable=0" severity note;

        -- ---------------------------------------------------------------
        -- Test 3: Count up sequence 0->1->2->3->4
        -- ---------------------------------------------------------------
        enable <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "00000001"
            report "Test 3a FAIL: expected count=1, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "00000010"
            report "Test 3b FAIL: expected count=2, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "00000011"
            report "Test 3c FAIL: expected count=3, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "00000100"
            report "Test 3d FAIL: expected count=4, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 3 PASS: count up sequence 0->1->2->3->4" severity note;

        -- ---------------------------------------------------------------
        -- Test 4: Disable then re-enable (hold and resume)
        -- ---------------------------------------------------------------
        enable <= '0';
        wait for CLK_PERIOD * 3;
        assert count = "00000100"
            report "Test 4a FAIL: counter changed while disabled, count=" &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        enable <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "00000101"
            report "Test 4b FAIL: expected count=5 after re-enable, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 4 PASS: hold and resume counting" severity note;

        -- ---------------------------------------------------------------
        -- Test 5: Wraparound at 255 -> 0
        -- Advance counter to 255, then verify it wraps to 0.
        -- Current count is 5; need 250 more edges to reach 255, then 1 more to wrap.
        -- ---------------------------------------------------------------
        for i in 0 to 249 loop
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;
        assert count = "11111111"
            report "Test 5a FAIL: expected count=255, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "00000000"
            report "Test 5b FAIL: expected wraparound to 0, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 5 PASS: wraparound from 255 to 0" severity note;

        -- ---------------------------------------------------------------
        -- Test 6: Count continues after wraparound
        -- ---------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "00000001"
            report "Test 6 FAIL: expected count=1 after wrap, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 6 PASS: counting continues after wraparound" severity note;

        report "All counter_nbit tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

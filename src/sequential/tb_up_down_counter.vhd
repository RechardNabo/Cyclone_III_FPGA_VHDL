-- Testbench for up_down_counter
-- Tests 4-bit up/down counter with synchronous reset and direction input.
-- Verifies reset, count up sequence, count down sequence, and wraparound.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_up_down_counter is
end entity tb_up_down_counter;

architecture sim of tb_up_down_counter is
    -- DUT signals
    signal clk     : std_logic := '0';
    signal reset   : std_logic := '0';
    signal up_down : std_logic := '1';
    signal count   : std_logic_vector(3 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin
    -- Instantiate DUT
    dut : entity work.up_down_counter
        port map (
            clk     => clk,
            reset   => reset,
            up_down => up_down,
            count   => count
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
        reset   <= '1';
        up_down <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0000"
            report "Test 1 FAIL: reset did not clear counter, count=" &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 1 PASS: counter reset to 0" severity note;

        -- ---------------------------------------------------------------
        -- Test 2: Count up sequence 0->1->2->3
        -- ---------------------------------------------------------------
        reset   <= '0';
        up_down <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0001"
            report "Test 2a FAIL: expected count=1, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0010"
            report "Test 2b FAIL: expected count=2, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0011"
            report "Test 2c FAIL: expected count=3, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 2 PASS: count up 0->1->2->3" severity note;

        -- ---------------------------------------------------------------
        -- Test 3: Switch to count down 3->2->1->0
        -- ---------------------------------------------------------------
        up_down <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0010"
            report "Test 3a FAIL: expected count=2, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0001"
            report "Test 3b FAIL: expected count=1, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0000"
            report "Test 3c FAIL: expected count=0, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 3 PASS: count down 3->2->1->0" severity note;

        -- ---------------------------------------------------------------
        -- Test 4: Count down wraparound 0->15
        -- ---------------------------------------------------------------
        up_down <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "1111"
            report "Test 4 FAIL: expected wraparound to 15, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 4 PASS: count down wraparound 0->15" severity note;

        -- ---------------------------------------------------------------
        -- Test 5: Count up wraparound 15->0
        -- ---------------------------------------------------------------
        up_down <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0000"
            report "Test 5 FAIL: expected wraparound to 0, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 5 PASS: count up wraparound 15->0" severity note;

        -- ---------------------------------------------------------------
        -- Test 6: Reset mid-count
        -- ---------------------------------------------------------------
        up_down <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0001" report "Test 6a FAIL: expected count=1" severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0010" report "Test 6b FAIL: expected count=2" severity error;

        reset <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert count = "0000"
            report "Test 6c FAIL: reset mid-count failed, count=" &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 6 PASS: reset mid-count" severity note;

        -- ---------------------------------------------------------------
        -- Test 7: Count up full cycle (0 through 15, wrap to 0)
        -- ---------------------------------------------------------------
        reset   <= '0';
        up_down <= '1';
        for i in 0 to 15 loop
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;
        assert count = "0000"
            report "Test 7 FAIL: expected full cycle wrap to 0, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 7 PASS: full up cycle 0->15->0" severity note;

        -- ---------------------------------------------------------------
        -- Test 8: Count down full cycle (0 through 15 down, wrap to 0)
        -- Start at 0, count down 16 times: 0->15->14->...->1->0
        -- ---------------------------------------------------------------
        up_down <= '0';
        for i in 0 to 15 loop
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;
        assert count = "0000"
            report "Test 8 FAIL: expected full down cycle wrap to 0, got " &
                   integer'image(to_integer(unsigned(count)))
            severity error;
        report "Test 8 PASS: full down cycle 0->15->0" severity note;

        report "All up_down_counter tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

-- Testbench for ring_counter
-- Tests 4-bit ring counter with synchronous reset.
-- Verifies reset loads "0001", rotation sequence, and wraparound.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_ring_counter is
end entity tb_ring_counter;

architecture sim of tb_ring_counter is
    -- DUT signals
    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';
    signal q     : std_logic_vector(3 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin
    -- Instantiate DUT
    dut : entity work.ring_counter
        port map (
            clk   => clk,
            reset => reset,
            q     => q
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
        -- Test 1: Synchronous reset loads "0001"
        -- ---------------------------------------------------------------
        reset <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0001"
            report "Test 1 FAIL: reset should load 0001, got q=" &
                   integer'image(to_integer(unsigned(q)))
            severity error;
        report "Test 1 PASS: reset loads 0001" severity note;

        -- ---------------------------------------------------------------
        -- Test 2: Rotation sequence 0001->0010->0100->1000
        -- ---------------------------------------------------------------
        reset <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0010"
            report "Test 2a FAIL: expected q=0010, got " &
                   integer'image(to_integer(unsigned(q)))
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0100"
            report "Test 2b FAIL: expected q=0100, got " &
                   integer'image(to_integer(unsigned(q)))
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "1000"
            report "Test 2c FAIL: expected q=1000, got " &
                   integer'image(to_integer(unsigned(q)))
            severity error;
        report "Test 2 PASS: rotation sequence 0001->0010->0100->1000" severity note;

        -- ---------------------------------------------------------------
        -- Test 3: Wraparound from 1000 back to 0001
        -- ---------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0001"
            report "Test 3 FAIL: expected wraparound to 0001, got " &
                   integer'image(to_integer(unsigned(q)))
            severity error;
        report "Test 3 PASS: wraparound 1000->0001" severity note;

        -- ---------------------------------------------------------------
        -- Test 4: Full rotation cycle (4 more edges returns to start)
        -- ---------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0010" report "Test 4a FAIL: expected q=0010" severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0100" report "Test 4b FAIL: expected q=0100" severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "1000" report "Test 4c FAIL: expected q=1000" severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0001" report "Test 4d FAIL: expected q=0001" severity error;
        report "Test 4 PASS: full rotation cycle" severity note;

        -- ---------------------------------------------------------------
        -- Test 5: Reset mid-rotation
        -- ---------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0010" report "Test 5a FAIL: expected q=0010" severity error;

        reset <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0001"
            report "Test 5b FAIL: reset mid-rotation should load 0001, got " &
                   integer'image(to_integer(unsigned(q)))
            severity error;
        report "Test 5 PASS: reset mid-rotation" severity note;

        -- ---------------------------------------------------------------
        -- Test 6: Continue rotating after reset
        -- ---------------------------------------------------------------
        reset <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0010"
            report "Test 6 FAIL: expected q=0010 after reset release, got " &
                   integer'image(to_integer(unsigned(q)))
            severity error;
        report "Test 6 PASS: rotation resumes after reset" severity note;

        report "All ring_counter tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

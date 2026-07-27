-- Testbench for jk_flipflop
-- Tests JK flip-flop with asynchronous reset.
-- Verifies all four JK modes: hold, reset, set, toggle, plus async reset.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_jk_flipflop is
end entity tb_jk_flipflop;

architecture sim of tb_jk_flipflop is
    -- DUT signals
    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';
    signal j     : std_logic := '0';
    signal k     : std_logic := '0';
    signal q     : std_logic;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin
    -- Instantiate DUT
    dut : entity work.jk_flipflop
        port map (
            clk   => clk,
            reset => reset,
            j     => j,
            k     => k,
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
        -- Test 1: Asynchronous reset
        -- ---------------------------------------------------------------
        reset <= '1';
        j     <= '0';
        k     <= '0';
        wait for CLK_PERIOD * 2;
        assert q = '0'
            report "Test 1 FAIL: async reset did not clear Q"
            severity error;
        report "Test 1 PASS: async reset clears Q to 0" severity note;

        -- ---------------------------------------------------------------
        -- Test 2: J=1, K=0 -> Set (Q=1)
        -- ---------------------------------------------------------------
        reset <= '0';
        j     <= '1';
        k     <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1'
            report "Test 2 FAIL: J=1 K=0 expected Q=1"
            severity error;
        report "Test 2 PASS: J=1 K=0 -> Set" severity note;

        -- ---------------------------------------------------------------
        -- Test 3: J=0, K=0 -> Hold (Q stays 1)
        -- ---------------------------------------------------------------
        j <= '0';
        k <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1'
            report "Test 3 FAIL: J=0 K=0 expected Q=1 (hold)"
            severity error;
        report "Test 3 PASS: J=0 K=0 -> Hold" severity note;

        -- ---------------------------------------------------------------
        -- Test 4: J=0, K=1 -> Reset (Q=0)
        -- ---------------------------------------------------------------
        j <= '0';
        k <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '0'
            report "Test 4 FAIL: J=0 K=1 expected Q=0"
            severity error;
        report "Test 4 PASS: J=0 K=1 -> Reset" severity note;

        -- ---------------------------------------------------------------
        -- Test 5: J=0, K=0 -> Hold (Q stays 0)
        -- ---------------------------------------------------------------
        j <= '0';
        k <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '0'
            report "Test 5 FAIL: J=0 K=0 expected Q=0 (hold)"
            severity error;
        report "Test 5 PASS: J=0 K=0 -> Hold (Q=0)" severity note;

        -- ---------------------------------------------------------------
        -- Test 6: J=1, K=1 -> Toggle (Q goes 0->1)
        -- ---------------------------------------------------------------
        j <= '1';
        k <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1'
            report "Test 6 FAIL: J=1 K=1 expected Q=1 (toggle from 0)"
            severity error;
        report "Test 6 PASS: J=1 K=1 -> Toggle (0->1)" severity note;

        -- ---------------------------------------------------------------
        -- Test 7: J=1, K=1 -> Toggle again (Q goes 1->0)
        -- ---------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '0'
            report "Test 7 FAIL: J=1 K=1 expected Q=0 (toggle from 1)"
            severity error;
        report "Test 7 PASS: J=1 K=1 -> Toggle (1->0)" severity note;

        -- ---------------------------------------------------------------
        -- Test 8: Multiple toggles (J=K=1 for several cycles)
        -- ---------------------------------------------------------------
        j <= '1';
        k <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1' report "Test 8a FAIL: expected Q=1" severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '0' report "Test 8b FAIL: expected Q=0" severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1' report "Test 8c FAIL: expected Q=1" severity error;
        report "Test 8 PASS: multiple toggles" severity note;

        -- ---------------------------------------------------------------
        -- Test 9: Async reset overrides everything (mid-cycle)
        -- ---------------------------------------------------------------
        reset <= '1';
        wait for 5 ns;
        assert q = '0'
            report "Test 9 FAIL: async reset should clear Q immediately"
            severity error;
        report "Test 9 PASS: async reset overrides J/K" severity note;

        -- ---------------------------------------------------------------
        -- Test 10: Reset then Set
        -- ---------------------------------------------------------------
        reset <= '0';
        j     <= '1';
        k     <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1'
            report "Test 10 FAIL: expected Q=1 after set"
            severity error;
        report "Test 10 PASS: reset then set" severity note;

        report "All jk_flipflop tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

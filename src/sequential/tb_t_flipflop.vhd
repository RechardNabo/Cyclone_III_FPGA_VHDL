-- Testbench for t_flipflop
-- Tests T flip-flop with asynchronous reset.
-- Verifies async reset, toggle mode (T=1), and hold mode (T=0).
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_t_flipflop is
end entity tb_t_flipflop;

architecture sim of tb_t_flipflop is
    -- DUT signals
    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';
    signal t     : std_logic := '0';
    signal q     : std_logic;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin
    -- Instantiate DUT
    dut : entity work.t_flipflop
        port map (
            clk   => clk,
            reset => reset,
            t     => t,
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
        t     <= '0';
        wait for CLK_PERIOD * 2;
        assert q = '0'
            report "Test 1 FAIL: async reset did not clear Q"
            severity error;
        report "Test 1 PASS: async reset clears Q to 0" severity note;

        -- ---------------------------------------------------------------
        -- Test 2: Hold when T=0
        -- ---------------------------------------------------------------
        reset <= '0';
        t     <= '0';
        wait for CLK_PERIOD * 4;
        assert q = '0'
            report "Test 2 FAIL: Q changed while T=0"
            severity error;
        report "Test 2 PASS: hold when T=0" severity note;

        -- ---------------------------------------------------------------
        -- Test 3: Toggle with T=1 (0->1)
        -- ---------------------------------------------------------------
        t <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1'
            report "Test 3 FAIL: expected Q=1 after toggle from 0"
            severity error;
        report "Test 3 PASS: toggle 0->1" severity note;

        -- ---------------------------------------------------------------
        -- Test 4: Toggle with T=1 (1->0)
        -- ---------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '0'
            report "Test 4 FAIL: expected Q=0 after toggle from 1"
            severity error;
        report "Test 4 PASS: toggle 1->0" severity note;

        -- ---------------------------------------------------------------
        -- Test 5: Multiple toggles
        -- ---------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1' report "Test 5a FAIL: expected Q=1" severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '0' report "Test 5b FAIL: expected Q=0" severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1' report "Test 5c FAIL: expected Q=1" severity error;
        report "Test 5 PASS: multiple toggles" severity note;

        -- ---------------------------------------------------------------
        -- Test 6: Hold when T=0 after toggling
        -- ---------------------------------------------------------------
        t <= '0';
        wait for CLK_PERIOD * 3;
        assert q = '1'
            report "Test 6 FAIL: Q changed while T=0 (expected hold at 1)"
            severity error;
        report "Test 6 PASS: hold at Q=1 when T=0" severity note;

        -- ---------------------------------------------------------------
        -- Test 7: Resume toggling after hold
        -- ---------------------------------------------------------------
        t <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '0'
            report "Test 7 FAIL: expected Q=0 after resume toggle"
            severity error;
        report "Test 7 PASS: resume toggle after hold" severity note;

        -- ---------------------------------------------------------------
        -- Test 8: Async reset overrides T=1 (mid-cycle)
        -- ---------------------------------------------------------------
        reset <= '1';
        t     <= '1';
        wait for 5 ns;
        assert q = '0'
            report "Test 8 FAIL: async reset should clear Q immediately"
            severity error;
        report "Test 8 PASS: async reset overrides T=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 9: Release reset and toggle
        -- ---------------------------------------------------------------
        reset <= '0';
        t     <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1'
            report "Test 9 FAIL: expected Q=1 after reset release and toggle"
            severity error;
        report "Test 9 PASS: toggle after reset release" severity note;

        report "All t_flipflop tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

-- Testbench for d_flipflop
-- Tests D flip-flop with asynchronous reset and enable.
-- Verifies async reset, load (D capture on rising edge), and hold (enable=0).
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_d_flipflop is
end entity tb_d_flipflop;

architecture sim of tb_d_flipflop is
    -- DUT signals
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '0';
    signal enable : std_logic := '0';
    signal d      : std_logic := '0';
    signal q      : std_logic;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin
    -- Instantiate DUT
    dut : entity work.d_flipflop
        port map (
            clk    => clk,
            reset  => reset,
            enable => enable,
            d      => d,
            q      => q
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
        reset  <= '1';
        enable <= '0';
        d      <= '1';
        wait for CLK_PERIOD * 2;
        assert q = '0'
            report "Test 1 FAIL: async reset did not clear Q"
            severity error;
        report "Test 1 PASS: async reset clears Q to 0" severity note;

        -- ---------------------------------------------------------------
        -- Test 2: Reset is asynchronous (takes effect without clock edge)
        -- ---------------------------------------------------------------
        reset  <= '0';
        enable <= '1';
        d      <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1'
            report "Test 2a FAIL: Q should be 1 after loading D=1"
            severity error;

        -- Assert reset asynchronously (mid-cycle, no clock edge)
        reset <= '1';
        wait for 5 ns;
        assert q = '0'
            report "Test 2b FAIL: async reset should clear Q immediately"
            severity error;
        report "Test 2 PASS: reset is asynchronous" severity note;

        -- ---------------------------------------------------------------
        -- Test 3: Load D=1 on rising edge
        -- ---------------------------------------------------------------
        reset  <= '0';
        enable <= '1';
        d      <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1'
            report "Test 3 FAIL: expected Q=1 after loading D=1"
            severity error;
        report "Test 3 PASS: load D=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 4: Load D=0 on rising edge
        -- ---------------------------------------------------------------
        d <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '0'
            report "Test 4 FAIL: expected Q=0 after loading D=0"
            severity error;
        report "Test 4 PASS: load D=0" severity note;

        -- ---------------------------------------------------------------
        -- Test 5: Hold when enable=0 (D changes but Q should not)
        -- ---------------------------------------------------------------
        enable <= '0';
        d      <= '1';
        wait for CLK_PERIOD * 3;
        assert q = '0'
            report "Test 5 FAIL: Q changed while enable=0"
            severity error;
        report "Test 5 PASS: hold when enable=0" severity note;

        -- ---------------------------------------------------------------
        -- Test 6: Re-enable and load D=1
        -- ---------------------------------------------------------------
        enable <= '1';
        d      <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1'
            report "Test 6 FAIL: expected Q=1 after re-enable and load"
            severity error;
        report "Test 6 PASS: re-enable and load D=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 7: Toggle D multiple times
        -- ---------------------------------------------------------------
        d <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '0' report "Test 7a FAIL: expected Q=0" severity error;

        d <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '1' report "Test 7b FAIL: expected Q=1" severity error;

        d <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = '0' report "Test 7c FAIL: expected Q=0" severity error;
        report "Test 7 PASS: multiple toggles" severity note;

        -- ---------------------------------------------------------------
        -- Test 8: Reset overrides enable
        -- ---------------------------------------------------------------
        reset  <= '1';
        enable <= '1';
        d      <= '1';
        wait for CLK_PERIOD * 2;
        assert q = '0'
            report "Test 8 FAIL: reset should override enable"
            severity error;
        report "Test 8 PASS: reset overrides enable" severity note;

        report "All d_flipflop tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

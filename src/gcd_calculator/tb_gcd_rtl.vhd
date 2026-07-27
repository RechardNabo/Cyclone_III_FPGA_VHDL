-- ============================================================================
-- Testbench for GCD Calculator - RTL Top-Level (FSM + Datapath integration)
-- Tests: reset, gcd(12,8)=4, gcd(15,5)=5, gcd(7,13)=1, gcd(48,18)=6
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_gcd_rtl is
end entity tb_gcd_rtl;

architecture sim of tb_gcd_rtl is
    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1';
    signal start   : std_logic := '0';
    signal a       : std_logic_vector(7 downto 0) := (others => '0');
    signal b       : std_logic_vector(7 downto 0) := (others => '0');
    signal gcd_out : std_logic_vector(7 downto 0);
    signal done    : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin

    dut : entity work.gcd_rtl
        port map (
            clk     => clk,
            reset   => reset,
            start   => start,
            a       => a,
            b       => b,
            gcd_out => gcd_out,
            done    => done
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
        -- Test 1: Reset state — done low
        -- -------------------------------------------------------
        reset <= '1';
        start <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert done = '0'
            report "Test 1 FAIL: done not low after reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;
        reset <= '0';
        wait for 1 ns;

        -- -------------------------------------------------------
        -- Test 2: gcd(12, 8) = 4
        --   Subtraction method: (12,8)→sub(4,8)→swap(8,4)→sub(4,4)→sub(0,4)→swap(4,0)→done
        -- -------------------------------------------------------
        a <= std_logic_vector(to_unsigned(12, 8));
        b <= std_logic_vector(to_unsigned(8, 8));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 40;
        assert done = '1'
            report "Test 2 FAIL: done not asserted for gcd(12,8)"
            severity error;
        assert to_integer(unsigned(gcd_out)) = 4
            report "Test 2 FAIL: gcd(12,8) = " & integer'image(to_integer(unsigned(gcd_out))) & " (expected 4)"
            severity error;
        report "Test 2 PASS: gcd(12,8) = 4" severity note;
        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 3: gcd(15, 5) = 5
        -- -------------------------------------------------------
        a <= std_logic_vector(to_unsigned(15, 8));
        b <= std_logic_vector(to_unsigned(5, 8));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 40;
        assert done = '1'
            report "Test 3 FAIL: done not asserted for gcd(15,5)"
            severity error;
        assert to_integer(unsigned(gcd_out)) = 5
            report "Test 3 FAIL: gcd(15,5) = " & integer'image(to_integer(unsigned(gcd_out))) & " (expected 5)"
            severity error;
        report "Test 3 PASS: gcd(15,5) = 5" severity note;
        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 4: gcd(7, 13) = 1 (a < b initially)
        -- -------------------------------------------------------
        a <= std_logic_vector(to_unsigned(7, 8));
        b <= std_logic_vector(to_unsigned(13, 8));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 60;
        assert done = '1'
            report "Test 4 FAIL: done not asserted for gcd(7,13)"
            severity error;
        assert to_integer(unsigned(gcd_out)) = 1
            report "Test 4 FAIL: gcd(7,13) = " & integer'image(to_integer(unsigned(gcd_out))) & " (expected 1)"
            severity error;
        report "Test 4 PASS: gcd(7,13) = 1" severity note;
        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 5: gcd(48, 18) = 6
        -- -------------------------------------------------------
        a <= std_logic_vector(to_unsigned(48, 8));
        b <= std_logic_vector(to_unsigned(18, 8));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 60;
        assert done = '1'
            report "Test 5 FAIL: done not asserted for gcd(48,18)"
            severity error;
        assert to_integer(unsigned(gcd_out)) = 6
            report "Test 5 FAIL: gcd(48,18) = " & integer'image(to_integer(unsigned(gcd_out))) & " (expected 6)"
            severity error;
        report "Test 5 PASS: gcd(48,18) = 6" severity note;
        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 6: gcd(x, 0) = x (edge case)
        -- -------------------------------------------------------
        a <= std_logic_vector(to_unsigned(33, 8));
        b <= std_logic_vector(to_unsigned(0, 8));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 10;
        assert done = '1'
            report "Test 6 FAIL: done not asserted for gcd(33,0)"
            severity error;
        assert to_integer(unsigned(gcd_out)) = 33
            report "Test 6 FAIL: gcd(33,0) = " & integer'image(to_integer(unsigned(gcd_out))) & " (expected 33)"
            severity error;
        report "Test 6 PASS: gcd(33,0) = 33" severity note;

        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

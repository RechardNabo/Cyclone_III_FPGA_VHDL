-- ============================================================================
-- Testbench for GCD Calculator - Behavioral Model (Euclidean Algorithm)
-- Tests: reset, gcd(12,8)=4, gcd(15,5)=5, gcd(7,13)=1, gcd(100,10)=10
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_gcd_behavior is
end entity tb_gcd_behavior;

architecture sim of tb_gcd_behavior is
    signal clk        : std_logic := '0';
    signal reset      : std_logic := '1';
    signal start      : std_logic := '0';
    signal a_in       : std_logic_vector(7 downto 0) := (others => '0');
    signal b_in       : std_logic_vector(7 downto 0) := (others => '0');
    signal gcd_result : std_logic_vector(7 downto 0);
    signal done       : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin

    dut : entity work.gcd_behavior
        port map (
            clk        => clk,
            reset      => reset,
            start      => start,
            a_in       => a_in,
            b_in       => b_in,
            gcd_result => gcd_result,
            done       => done
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
        -- Test 1: Reset state — done must be low
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
        -- -------------------------------------------------------
        a_in <= std_logic_vector(to_unsigned(12, 8));
        b_in <= std_logic_vector(to_unsigned(8, 8));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 20;
        assert done = '1'
            report "Test 2 FAIL: done not asserted for gcd(12,8)"
            severity error;
        assert to_integer(unsigned(gcd_result)) = 4
            report "Test 2 FAIL: gcd(12,8) = " & integer'image(to_integer(unsigned(gcd_result))) & " (expected 4)"
            severity error;
        report "Test 2 PASS: gcd(12,8) = 4" severity note;
        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 3: gcd(15, 5) = 5
        -- -------------------------------------------------------
        a_in <= std_logic_vector(to_unsigned(15, 8));
        b_in <= std_logic_vector(to_unsigned(5, 8));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 20;
        assert done = '1'
            report "Test 3 FAIL: done not asserted for gcd(15,5)"
            severity error;
        assert to_integer(unsigned(gcd_result)) = 5
            report "Test 3 FAIL: gcd(15,5) = " & integer'image(to_integer(unsigned(gcd_result))) & " (expected 5)"
            severity error;
        report "Test 3 PASS: gcd(15,5) = 5" severity note;
        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 4: gcd(7, 13) = 1 (a < b case)
        -- -------------------------------------------------------
        a_in <= std_logic_vector(to_unsigned(7, 8));
        b_in <= std_logic_vector(to_unsigned(13, 8));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 30;
        assert done = '1'
            report "Test 4 FAIL: done not asserted for gcd(7,13)"
            severity error;
        assert to_integer(unsigned(gcd_result)) = 1
            report "Test 4 FAIL: gcd(7,13) = " & integer'image(to_integer(unsigned(gcd_result))) & " (expected 1)"
            severity error;
        report "Test 4 PASS: gcd(7,13) = 1" severity note;
        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 5: gcd(100, 10) = 10
        -- -------------------------------------------------------
        a_in <= std_logic_vector(to_unsigned(100, 8));
        b_in <= std_logic_vector(to_unsigned(10, 8));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 20;
        assert done = '1'
            report "Test 5 FAIL: done not asserted for gcd(100,10)"
            severity error;
        assert to_integer(unsigned(gcd_result)) = 10
            report "Test 5 FAIL: gcd(100,10) = " & integer'image(to_integer(unsigned(gcd_result))) & " (expected 10)"
            severity error;
        report "Test 5 PASS: gcd(100,10) = 10" severity note;
        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 6: gcd(x, 0) = x (edge case: b=0 immediately)
        -- -------------------------------------------------------
        a_in <= std_logic_vector(to_unsigned(42, 8));
        b_in <= std_logic_vector(to_unsigned(0, 8));
        start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 10;
        assert done = '1'
            report "Test 6 FAIL: done not asserted for gcd(42,0)"
            severity error;
        assert to_integer(unsigned(gcd_result)) = 42
            report "Test 6 FAIL: gcd(42,0) = " & integer'image(to_integer(unsigned(gcd_result))) & " (expected 42)"
            severity error;
        report "Test 6 PASS: gcd(42,0) = 42" severity note;

        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

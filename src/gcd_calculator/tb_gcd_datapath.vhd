-- ============================================================================
-- Testbench for GCD Calculator - Datapath
-- Tests: reset, load operands, swap, subtract, comparators (a_ge_b, b_eq_zero)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_gcd_datapath is
end entity tb_gcd_datapath;

architecture sim of tb_gcd_datapath is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal a_in      : std_logic_vector(7 downto 0) := (others => '0');
    signal b_in      : std_logic_vector(7 downto 0) := (others => '0');
    signal load_en   : std_logic := '0';
    signal swap_en   : std_logic := '0';
    signal sub_en    : std_logic := '0';
    signal a_out     : std_logic_vector(7 downto 0);
    signal b_out     : std_logic_vector(7 downto 0);
    signal a_ge_b    : std_logic;
    signal b_eq_zero : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin

    dut : entity work.gcd_datapath
        port map (
            clk       => clk,
            reset     => reset,
            a_in      => a_in,
            b_in      => b_in,
            load_en   => load_en,
            swap_en   => swap_en,
            sub_en    => sub_en,
            a_out     => a_out,
            b_out     => b_out,
            a_ge_b    => a_ge_b,
            b_eq_zero => b_eq_zero
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
        -- Test 1: Reset state — registers zeroed
        -- -------------------------------------------------------
        reset <= '1';
        load_en <= '0'; swap_en <= '0'; sub_en <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';
        wait for 1 ns;
        assert a_out = x"00"
            report "Test 1 FAIL: a_out not zero after reset"
            severity error;
        assert b_out = x"00"
            report "Test 1 FAIL: b_out not zero after reset"
            severity error;
        assert b_eq_zero = '1'
            report "Test 1 FAIL: b_eq_zero not high when B=0"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;

        -- -------------------------------------------------------
        -- Test 2: Load operands A=25, B=15
        -- -------------------------------------------------------
        a_in <= std_logic_vector(to_unsigned(25, 8));
        b_in <= std_logic_vector(to_unsigned(15, 8));
        load_en <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        load_en <= '0';
        assert a_out = std_logic_vector(to_unsigned(25, 8))
            report "Test 2 FAIL: a_out not 25 after load"
            severity error;
        assert b_out = std_logic_vector(to_unsigned(15, 8))
            report "Test 2 FAIL: b_out not 15 after load"
            severity error;
        assert a_ge_b = '1'
            report "Test 2 FAIL: a_ge_b not high when A=25 > B=15"
            severity error;
        assert b_eq_zero = '0'
            report "Test 2 FAIL: b_eq_zero high when B=15"
            severity error;
        report "Test 2 PASS: Load A=25, B=15 correct" severity note;

        -- -------------------------------------------------------
        -- Test 3: Subtract — A <= A - B = 25 - 15 = 10
        -- -------------------------------------------------------
        sub_en <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        sub_en <= '0';
        assert a_out = std_logic_vector(to_unsigned(10, 8))
            report "Test 3 FAIL: a_out not 10 after subtract (25-15)"
            severity error;
        assert b_out = std_logic_vector(to_unsigned(15, 8))
            report "Test 3 FAIL: b_out changed during subtract"
            severity error;
        assert a_ge_b = '0'
            report "Test 3 FAIL: a_ge_b high when A=10 < B=15"
            severity error;
        report "Test 3 PASS: Subtract A=25-15=10 correct" severity note;

        -- -------------------------------------------------------
        -- Test 4: Swap — A and B exchange
        -- -------------------------------------------------------
        swap_en <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        swap_en <= '0';
        assert a_out = std_logic_vector(to_unsigned(15, 8))
            report "Test 4 FAIL: a_out not 15 after swap"
            severity error;
        assert b_out = std_logic_vector(to_unsigned(10, 8))
            report "Test 4 FAIL: b_out not 10 after swap"
            severity error;
        assert a_ge_b = '1'
            report "Test 4 FAIL: a_ge_b not high when A=15 > B=10"
            severity error;
        report "Test 4 PASS: Swap A<->B correct" severity note;

        -- -------------------------------------------------------
        -- Test 5: Subtract until B=0 — gcd(25,15) via subtraction
        --   A=15, B=10: sub -> A=5, B=10 (A<B)
        --   swap -> A=10, B=5
        --   sub -> A=5, B=5
        --   sub -> A=0, B=5 (A<B)
        --   swap -> A=5, B=0
        -- -------------------------------------------------------
        sub_en <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        sub_en <= '0';
        assert a_out = std_logic_vector(to_unsigned(5, 8))
            report "Test 5a FAIL: a_out not 5 after 15-10"
            severity error;

        swap_en <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        swap_en <= '0';
        assert a_out = std_logic_vector(to_unsigned(10, 8))
            report "Test 5b FAIL: a_out not 10 after swap"
            severity error;

        sub_en <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        sub_en <= '0';
        assert a_out = std_logic_vector(to_unsigned(5, 8))
            report "Test 5c FAIL: a_out not 5 after 10-5"
            severity error;

        sub_en <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        sub_en <= '0';
        assert a_out = std_logic_vector(to_unsigned(0, 8))
            report "Test 5d FAIL: a_out not 0 after 5-5"
            severity error;

        swap_en <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        swap_en <= '0';
        assert a_out = std_logic_vector(to_unsigned(5, 8))
            report "Test 5e FAIL: a_out not 5 (gcd) after final swap"
            severity error;
        assert b_eq_zero = '1'
            report "Test 5f FAIL: b_eq_zero not high when B=0"
            severity error;
        report "Test 5 PASS: Full subtraction GCD sequence, gcd(25,15)=5" severity note;

        -- -------------------------------------------------------
        -- Test 6: Hold (no control signals) — registers keep value
        -- -------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert a_out = std_logic_vector(to_unsigned(5, 8))
            report "Test 6 FAIL: a_out changed while holding"
            severity error;
        assert b_out = std_logic_vector(to_unsigned(0, 8))
            report "Test 6 FAIL: b_out changed while holding"
            severity error;
        report "Test 6 PASS: Hold preserves register values" severity note;

        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

-- ============================================================================
-- Testbench for Big Multiplexer (4-to-1, 8-bit)
-- ============================================================================
-- Tests all four select positions of the 4-to-1 multiplexer to verify that
-- the correct input is forwarded to the output for each sel value.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_bigmux is
end entity tb_bigmux;

architecture sim of tb_bigmux is

    signal d0  : std_logic_vector(7 downto 0) := x"11";
    signal d1  : std_logic_vector(7 downto 0) := x"22";
    signal d2  : std_logic_vector(7 downto 0) := x"33";
    signal d3  : std_logic_vector(7 downto 0) := x"44";
    signal sel : std_logic_vector(1 downto 0) := "00";
    signal y   : std_logic_vector(7 downto 0);

begin

    -- Instantiate DUT
    dut : entity work.bigmux
        port map (
            d0  => d0,
            d1  => d1,
            d2  => d2,
            d3  => d3,
            sel => sel,
            y   => y
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- -------------------------------------------------------
        -- Test 1: sel = "00" should select d0
        -- -------------------------------------------------------
        sel <= "00";
        wait for 10 ns;
        assert y = x"11"
            report "Test 1 FAIL: sel=00 expected 0x11"
            severity error;
        report "Test 1 PASS: sel=00 selects d0 (0x11)" severity note;

        -- -------------------------------------------------------
        -- Test 2: sel = "01" should select d1
        -- -------------------------------------------------------
        sel <= "01";
        wait for 10 ns;
        assert y = x"22"
            report "Test 2 FAIL: sel=01 expected 0x22"
            severity error;
        report "Test 2 PASS: sel=01 selects d1 (0x22)" severity note;

        -- -------------------------------------------------------
        -- Test 3: sel = "10" should select d2
        -- -------------------------------------------------------
        sel <= "10";
        wait for 10 ns;
        assert y = x"33"
            report "Test 3 FAIL: sel=10 expected 0x33"
            severity error;
        report "Test 3 PASS: sel=10 selects d2 (0x33)" severity note;

        -- -------------------------------------------------------
        -- Test 4: sel = "11" should select d3
        -- -------------------------------------------------------
        sel <= "11";
        wait for 10 ns;
        assert y = x"44"
            report "Test 4 FAIL: sel=11 expected 0x44"
            severity error;
        report "Test 4 PASS: sel=11 selects d3 (0x44)" severity note;

        -- -------------------------------------------------------
        -- Test 5: Change input data and verify output follows
        -- -------------------------------------------------------
        d0  <= x"AA";
        d1  <= x"BB";
        d2  <= x"CC";
        d3  <= x"DD";
        sel <= "10";
        wait for 10 ns;
        assert y = x"CC"
            report "Test 5 FAIL: sel=10 with new data expected 0xCC"
            severity error;
        report "Test 5 PASS: Output tracks updated input data" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

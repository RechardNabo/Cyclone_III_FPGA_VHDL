-- ============================================================================
-- Testbench for Small Multiplexer (2-to-1, 8-bit)
-- ============================================================================
-- Tests both select positions of the 2-to-1 multiplexer to verify that
-- the correct input is forwarded to the output for sel=0 and sel=1.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_smallmux is
end entity tb_smallmux;

architecture sim of tb_smallmux is

    signal d0  : std_logic_vector(7 downto 0) := x"11";
    signal d1  : std_logic_vector(7 downto 0) := x"22";
    signal sel : std_logic := '0';
    signal y   : std_logic_vector(7 downto 0);

begin

    -- Instantiate DUT
    dut : entity work.smallmux
        port map (
            d0  => d0,
            d1  => d1,
            sel => sel,
            y   => y
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- -------------------------------------------------------
        -- Test 1: sel = '0' should select d0
        -- -------------------------------------------------------
        sel <= '0';
        wait for 10 ns;
        assert y = x"11"
            report "Test 1 FAIL: sel=0 expected 0x11"
            severity error;
        report "Test 1 PASS: sel=0 selects d0 (0x11)" severity note;

        -- -------------------------------------------------------
        -- Test 2: sel = '1' should select d1
        -- -------------------------------------------------------
        sel <= '1';
        wait for 10 ns;
        assert y = x"22"
            report "Test 2 FAIL: sel=1 expected 0x22"
            severity error;
        report "Test 2 PASS: sel=1 selects d1 (0x22)" severity note;

        -- -------------------------------------------------------
        -- Test 3: Change input data, verify output follows
        -- -------------------------------------------------------
        d0  <= x"AA";
        d1  <= x"BB";
        sel <= '0';
        wait for 10 ns;
        assert y = x"AA"
            report "Test 3 FAIL: sel=0 with new data expected 0xAA"
            severity error;
        report "Test 3 PASS: sel=0 tracks updated d0 (0xAA)" severity note;

        -- -------------------------------------------------------
        -- Test 4: Switch to d1 with new data
        -- -------------------------------------------------------
        sel <= '1';
        wait for 10 ns;
        assert y = x"BB"
            report "Test 4 FAIL: sel=1 with new data expected 0xBB"
            severity error;
        report "Test 4 PASS: sel=1 tracks updated d1 (0xBB)" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

-- ============================================================================
-- Testbench for Program Counter (PC)
-- ============================================================================
-- Tests PC reset to zero, increment when en=1, hold when en=0, and load
-- (jump) when load=1. Verifies basic sequential execution and jump behavior.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_pc is
end entity tb_pc;

architecture sim of tb_pc is

    signal clk  : std_logic := '0';
    signal rst  : std_logic := '0';
    signal en   : std_logic := '0';
    signal load : std_logic := '0';
    signal d    : std_logic_vector(7 downto 0) := (others => '0');
    signal q    : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.pc
        port map (
            clk  => clk,
            rst  => rst,
            en   => en,
            load => load,
            d    => d,
            q    => q
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
        -- -------------------------------------------------------
        -- Test 1: Reset clears PC to 0x00
        -- -------------------------------------------------------
        rst  <= '1';
        en   <= '0';
        load <= '0';
        wait for CLK_PERIOD;
        assert q = x"00"
            report "Test 1 FAIL: PC not zero after reset"
            severity error;
        report "Test 1 PASS: PC reset to 0x00" severity note;

        -- -------------------------------------------------------
        -- Test 2: Increment PC by 1 for three cycles (en=1)
        -- -------------------------------------------------------
        rst  <= '0';
        en   <= '1';
        load <= '0';
        wait for CLK_PERIOD;
        assert q = x"01"
            report "Test 2a FAIL: PC should be 0x01 after first increment"
            severity error;
        wait for CLK_PERIOD;
        assert q = x"02"
            report "Test 2b FAIL: PC should be 0x02 after second increment"
            severity error;
        wait for CLK_PERIOD;
        assert q = x"03"
            report "Test 2c FAIL: PC should be 0x03 after third increment"
            severity error;
        report "Test 2 PASS: PC incremented 0x01 -> 0x02 -> 0x03" severity note;

        -- -------------------------------------------------------
        -- Test 3: Hold PC when en=0 and load=0
        -- -------------------------------------------------------
        en   <= '0';
        load <= '0';
        wait for CLK_PERIOD;
        assert q = x"03"
            report "Test 3 FAIL: PC should hold at 0x03"
            severity error;
        report "Test 3 PASS: PC holds at 0x03 when disabled" severity note;

        -- -------------------------------------------------------
        -- Test 4: Load (jump) to 0x20 when load=1
        -- -------------------------------------------------------
        load <= '1';
        d    <= x"20";
        wait for CLK_PERIOD;
        assert q = x"20"
            report "Test 4 FAIL: PC should jump to 0x20"
            severity error;
        report "Test 4 PASS: PC jumped to 0x20" severity note;

        -- -------------------------------------------------------
        -- Test 5: After load, resume incrementing from 0x20
        -- -------------------------------------------------------
        load <= '0';
        en   <= '1';
        wait for CLK_PERIOD;
        assert q = x"21"
            report "Test 5 FAIL: PC should be 0x21 after increment from 0x20"
            severity error;
        report "Test 5 PASS: PC incremented to 0x21 after jump" severity note;

        -- -------------------------------------------------------
        -- Test 6: Reset again clears to 0x00
        -- -------------------------------------------------------
        rst  <= '1';
        en   <= '0';
        load <= '0';
        wait for CLK_PERIOD;
        assert q = x"00"
            report "Test 6 FAIL: PC not zero after second reset"
            severity error;
        report "Test 6 PASS: PC reset to 0x00 again" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

-- Testbench for switches module
-- Tests 2-FF synchronizer with multiple switch input patterns
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_switches is
end entity tb_switches;

architecture test of tb_switches is

    signal clk    : std_logic := '0';
    signal sw_in  : std_logic_vector(9 downto 0) := (others => '0');
    signal sw_out : std_logic_vector(9 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    dut : entity work.switches
        generic map (
            SYNC_ENABLE => true
        )
        port map (
            clk    => clk,
            sw_in  => sw_in,
            sw_out => sw_out
        );

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process clk_proc;

    -- Stimulus process
    stim_proc : process
    begin

        ----------------------------------------------------------------
        -- Test 1: Initial output should be 0 after 2 clock edges
        ----------------------------------------------------------------
        sw_in <= (others => '0');
        wait for CLK_PERIOD * 3;
        assert sw_out = "0000000000"
            report "Test 1 failed: sw_out should be 0 after sync" severity error;

        ----------------------------------------------------------------
        -- Test 2: Apply all-ones, check after 2 clock edges
        ----------------------------------------------------------------
        sw_in <= (others => '1');
        wait for CLK_PERIOD;  -- sync1 captures input
        wait for CLK_PERIOD;  -- sync2 captures sync1
        assert sw_out = "1111111111"
            report "Test 2 failed: sw_out should be all 1s after 2 clocks" severity error;

        ----------------------------------------------------------------
        -- Test 3: Apply alternating pattern 1010101010
        ----------------------------------------------------------------
        sw_in <= "1010101010";
        wait for CLK_PERIOD * 2;
        assert sw_out = "1010101010"
            report "Test 3 failed: sw_out should be 1010101010" severity error;

        ----------------------------------------------------------------
        -- Test 4: Apply single bit set (bit 5)
        ----------------------------------------------------------------
        sw_in <= "0000010000";
        wait for CLK_PERIOD * 2;
        assert sw_out = "0000010000"
            report "Test 4 failed: sw_out should have bit 5 set" severity error;

        ----------------------------------------------------------------
        -- Test 5: Apply 0x3FF (all ones) then 0x000, check transition
        ----------------------------------------------------------------
        sw_in <= (others => '1');
        wait for CLK_PERIOD * 2;
        assert sw_out = "1111111111"
            report "Test 5a failed: sw_out should be all 1s" severity error;
        sw_in <= (others => '0');
        wait for CLK_PERIOD * 2;
        assert sw_out = "0000000000"
            report "Test 5b failed: sw_out should be all 0s" severity error;

        ----------------------------------------------------------------
        -- Test 6: Rapidly changing inputs - check final value syncs
        ----------------------------------------------------------------
        sw_in <= "1100110011";
        wait for CLK_PERIOD;
        sw_in <= "0011001100";
        wait for CLK_PERIOD;
        sw_in <= "1111000011";
        wait for CLK_PERIOD * 2;
        assert sw_out = "1111000011"
            report "Test 6 failed: sw_out should sync to final value" severity error;

        ----------------------------------------------------------------
        -- Test 7: Mixed pattern 0x1AA
        ----------------------------------------------------------------
        sw_in <= "0110101010";
        wait for CLK_PERIOD * 2;
        assert sw_out = "0110101010"
            report "Test 7 failed: sw_out should be 0110101010" severity error;

        report "All switches tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim_proc;

end architecture test;

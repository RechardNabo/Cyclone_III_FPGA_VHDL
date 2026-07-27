-- ============================================================================
-- Testbench for Output Buffer (obuf)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_obuf is
end entity tb_obuf;

architecture behavioral of tb_obuf is
    signal clk  : std_logic := '0';
    signal rst  : std_logic;
    signal load : std_logic;
    signal d    : std_logic_vector(7 downto 0);
    signal q    : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 10 ns;
begin
    -- Instantiate the DUT
    DUT : entity work.obuf
        port map (
            clk  => clk,
            rst  => rst,
            load => load,
            d    => d,
            q    => q
        );

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- Stimulus process
    process
    begin
        -- Test 1: Reset should clear output to 0
        rst <= '1'; load <= '0'; d <= "11111111";
        wait for CLK_PERIOD;
        assert q = "00000000"
            report "Test 1 FAILED: reset should clear q to 0"
            severity error;

        -- Test 2: Load a value after reset deasserted
        rst <= '0'; load <= '1'; d <= "10101010";
        wait for CLK_PERIOD;
        assert q = "10101010"
            report "Test 2 FAILED: load=1 should latch 10101010"
            severity error;

        -- Test 3: Load another value
        load <= '1'; d <= "11001100";
        wait for CLK_PERIOD;
        assert q = "11001100"
            report "Test 3 FAILED: load=1 should latch 11001100"
            severity error;

        -- Test 4: load=0, changing d should not affect q
        load <= '0'; d <= "00110011";
        wait for CLK_PERIOD;
        assert q = "11001100"
            report "Test 4 FAILED: load=0 should hold previous value"
            severity error;

        -- Test 5: Load a new value again
        load <= '1'; d <= "00001111";
        wait for CLK_PERIOD;
        assert q = "00001111"
            report "Test 5 FAILED: load=1 should latch 00001111"
            severity error;

        -- Test 6: Reset again mid-operation
        rst <= '1'; load <= '1'; d <= "11110000";
        wait for CLK_PERIOD;
        assert q = "00000000"
            report "Test 6 FAILED: reset should override load"
            severity error;

        report "All obuf tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;

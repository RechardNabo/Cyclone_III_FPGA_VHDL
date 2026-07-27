-- ============================================================================
-- Testbench for Instruction Register (IR)
-- ============================================================================
-- Tests that the IR latches data on the rising clock edge when load=1,
-- holds its value when load=0, and resets to zero on rst=1.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_ir is
end entity tb_ir;

architecture sim of tb_ir is

    signal clk  : std_logic := '0';
    signal rst  : std_logic := '0';
    signal load : std_logic := '0';
    signal d    : std_logic_vector(7 downto 0) := (others => '0');
    signal q    : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.ir
        port map (
            clk  => clk,
            rst  => rst,
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
        -- Test 1: Reset clears the IR to 0x00
        -- -------------------------------------------------------
        rst  <= '1';
        load <= '0';
        d    <= x"FF";
        wait for CLK_PERIOD;
        assert q = x"00"
            report "Test 1 FAIL: IR not zero after reset"
            severity error;
        report "Test 1 PASS: IR reset to 0x00" severity note;

        -- -------------------------------------------------------
        -- Test 2: Load 0x3C when load=1
        -- -------------------------------------------------------
        rst  <= '0';
        load <= '1';
        d    <= x"3C";
        wait for CLK_PERIOD;
        assert q = x"3C"
            report "Test 2 FAIL: IR should latch 0x3C"
            severity error;
        report "Test 2 PASS: IR latched 0x3C" severity note;

        -- -------------------------------------------------------
        -- Test 3: Hold value when load=0 (d changes but q stays)
        -- -------------------------------------------------------
        load <= '0';
        d    <= x"99";
        wait for CLK_PERIOD;
        assert q = x"3C"
            report "Test 3 FAIL: IR should hold 0x3C when load=0"
            severity error;
        report "Test 3 PASS: IR holds 0x3C when load=0" severity note;

        -- -------------------------------------------------------
        -- Test 4: Load a new value 0xA5
        -- -------------------------------------------------------
        load <= '1';
        d    <= x"A5";
        wait for CLK_PERIOD;
        assert q = x"A5"
            report "Test 4 FAIL: IR should latch 0xA5"
            severity error;
        report "Test 4 PASS: IR latched 0xA5" severity note;

        -- -------------------------------------------------------
        -- Test 5: Reset again clears to 0x00
        -- -------------------------------------------------------
        rst  <= '1';
        load <= '0';
        wait for CLK_PERIOD;
        assert q = x"00"
            report "Test 5 FAIL: IR not zero after second reset"
            severity error;
        report "Test 5 PASS: IR reset to 0x00 again" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

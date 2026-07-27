-- ============================================================================
-- Testbench for Signal Example
-- Demonstrates SIGNAL update-at-end-of-process (pipeline) behavior
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_signal_example is
end entity tb_signal_example;

architecture sim of tb_signal_example is

    -- DUT signals
    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal d_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal q_reg  : std_logic_vector(7 downto 0);
    signal q_pipe : std_logic_vector(7 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.signal_example
        port map (
            clk    => clk,
            rst    => rst,
            d_in   => d_in,
            q_reg  => q_reg,
            q_pipe => q_pipe
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
        -- Test 1: Reset state
        -- -------------------------------------------------------
        rst   <= '1';
        d_in  <= (others => '0');
        wait for CLK_PERIOD * 3;
        assert q_reg = x"00"
            report "Test 1 FAIL: q_reg not zero after reset"
            severity error;
        assert q_pipe = x"00"
            report "Test 1 FAIL: q_pipe not zero after reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;

        -- -------------------------------------------------------
        -- Test 2: Pipeline behavior - d_in=0x42
        --   Cycle 1: reg_s gets 0x42, pipe_s gets old reg_s (0x00)
        --   So after 1 clock: q_reg=0x42, q_pipe=0x00
        -- -------------------------------------------------------
        rst   <= '0';
        wait for CLK_PERIOD;
        d_in  <= x"42";
        wait for CLK_PERIOD;
        assert q_reg = x"42"
            report "Test 2 FAIL: q_reg not 0x42 after first clock"
            severity error;
        assert q_pipe = x"00"
            report "Test 2 FAIL: q_pipe not 0x00 after first clock (should be old value)"
            severity error;
        report "Test 2: After cycle 1: q_reg=0x" & integer'image(to_integer(unsigned(q_reg))) &
               ", q_pipe=0x" & integer'image(to_integer(unsigned(q_pipe))) severity note;
        report "Test 2 PASS: Pipeline delay - q_pipe lags by one cycle" severity note;

        -- -------------------------------------------------------
        -- Test 3: Next cycle - pipe should now have 0x42
        -- -------------------------------------------------------
        d_in  <= x"99";
        wait for CLK_PERIOD;
        assert q_reg = x"99"
            report "Test 3 FAIL: q_reg not 0x99 after second clock"
            severity error;
        assert q_pipe = x"42"
            report "Test 3 FAIL: q_pipe not 0x42 after second clock (should be prev reg)"
            severity error;
        report "Test 3: After cycle 2: q_reg=0x" & integer'image(to_integer(unsigned(q_reg))) &
               ", q_pipe=0x" & integer'image(to_integer(unsigned(q_pipe))) severity note;
        report "Test 3 PASS: q_pipe now has previous q_reg value" severity note;

        -- -------------------------------------------------------
        -- Test 4: One more cycle to confirm pipeline
        -- -------------------------------------------------------
        d_in  <= x"AA";
        wait for CLK_PERIOD;
        assert q_reg = x"AA"
            report "Test 4 FAIL: q_reg not 0xAA"
            severity error;
        assert q_pipe = x"99"
            report "Test 4 FAIL: q_pipe not 0x99 (should be previous reg value)"
            severity error;
        report "Test 4 PASS: Pipeline confirmed: q_pipe = previous q_reg" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

-- ============================================================================
-- Testbench for Variable Example
-- Demonstrates immediate VARIABLE update behavior
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_variable_example is
end entity tb_variable_example;

architecture sim of tb_variable_example is

    -- DUT signals
    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal d_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal q_out : std_logic_vector(7 downto 0);
    signal q_sum : std_logic_vector(7 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.variable_example
        port map (
            clk   => clk,
            rst   => rst,
            d_in  => d_in,
            q_out => q_out,
            q_sum => q_sum
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
        assert q_out = x"00"
            report "Test 1 FAIL: q_out not zero after reset"
            severity error;
        assert q_sum = x"00"
            report "Test 1 FAIL: q_sum not zero after reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;

        -- -------------------------------------------------------
        -- Test 2: d_in=0x10 -> q_out=0x10, q_sum=0x11 (same cycle!)
        -- Variables update immediately, so q_sum = d_in + 1
        -- -------------------------------------------------------
        rst   <= '0';
        wait for CLK_PERIOD;
        d_in  <= x"10";
        wait for CLK_PERIOD;
        assert q_out = x"10"
            report "Test 2 FAIL: q_out not 0x10"
            severity error;
        assert q_sum = x"11"
            report "Test 2 FAIL: q_sum not 0x11 (variable should update immediately)"
            severity error;
        report "Test 2: d_in=0x10, q_out=0x" & integer'image(to_integer(unsigned(q_out))) &
               ", q_sum=0x" & integer'image(to_integer(unsigned(q_sum))) severity note;
        report "Test 2 PASS: Variable updates immediately (q_sum=d_in+1)" severity note;

        -- -------------------------------------------------------
        -- Test 3: d_in=0x7F -> q_out=0x7F, q_sum=0x80
        -- -------------------------------------------------------
        d_in  <= x"7F";
        wait for CLK_PERIOD;
        assert q_out = x"7F"
            report "Test 3 FAIL: q_out not 0x7F"
            severity error;
        assert q_sum = x"80"
            report "Test 3 FAIL: q_sum not 0x80"
            severity error;
        report "Test 3 PASS: d_in=0x7F -> q_out=0x7F, q_sum=0x80" severity note;

        -- -------------------------------------------------------
        -- Test 4: d_in=0xFF -> q_out=0xFF, q_sum=0x00 (wrap)
        -- -------------------------------------------------------
        d_in  <= x"FF";
        wait for CLK_PERIOD;
        assert q_out = x"FF"
            report "Test 4 FAIL: q_out not 0xFF"
            severity error;
        assert q_sum = x"00"
            report "Test 4 FAIL: q_sum not 0x00 (should wrap around)"
            severity error;
        report "Test 4 PASS: d_in=0xFF -> q_out=0xFF, q_sum=0x00 (wrap)" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

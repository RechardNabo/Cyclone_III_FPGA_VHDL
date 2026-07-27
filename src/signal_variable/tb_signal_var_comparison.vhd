-- ============================================================================
-- Testbench for Signal vs Variable Comparison
-- Demonstrates the timing difference between SIGNAL and VARIABLE
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_signal_var_comparison is
end entity tb_signal_var_comparison;

architecture sim of tb_signal_var_comparison is

    -- DUT signals
    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal d_in       : std_logic_vector(7 downto 0) := (others => '0');
    signal result_sig : std_logic_vector(7 downto 0);
    signal result_var : std_logic_vector(7 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.signal_var_comparison
        port map (
            clk        => clk,
            rst        => rst,
            d_in       => d_in,
            result_sig => result_sig,
            result_var => result_var
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
        assert result_sig = x"00"
            report "Test 1 FAIL: result_sig not zero after reset"
            severity error;
        assert result_var = x"00"
            report "Test 1 FAIL: result_var not zero after reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;

        -- -------------------------------------------------------
        -- Test 2: d_in=0x10
        --   VARIABLE path: result_var = d_in + 1 = 0x11 (same cycle)
        --   SIGNAL path: result_sig = old_sig_temp + 1 = 0x01 (one cycle behind)
        -- -------------------------------------------------------
        rst   <= '0';
        wait for CLK_PERIOD;
        d_in  <= x"10";
        wait for CLK_PERIOD;

        -- Variable path: immediate -> result_var = 0x10 + 1 = 0x11
        assert result_var = x"11"
            report "Test 2 FAIL: result_var not 0x11 (variable should be immediate)"
            severity error;

        -- Signal path: delayed -> result_sig = 0x00 + 1 = 0x01 (old sig_temp was 0)
        assert result_sig = x"01"
            report "Test 2 FAIL: result_sig not 0x01 (signal should be one cycle behind)"
            severity error;

        report "Test 2: d_in=0x10, result_var=0x" & integer'image(to_integer(unsigned(result_var))) &
               ", result_sig=0x" & integer'image(to_integer(unsigned(result_sig))) severity note;
        report "Test 2 PASS: Variable immediate (0x11), Signal delayed (0x01)" severity note;

        -- -------------------------------------------------------
        -- Test 3: d_in=0x20
        --   VARIABLE: result_var = 0x21 (same cycle)
        --   SIGNAL: result_sig = 0x10 + 1 = 0x11 (previous d_in)
        -- -------------------------------------------------------
        d_in  <= x"20";
        wait for CLK_PERIOD;
        assert result_var = x"21"
            report "Test 3 FAIL: result_var not 0x21"
            severity error;
        assert result_sig = x"11"
            report "Test 3 FAIL: result_sig not 0x11 (should be prev d_in + 1)"
            severity error;
        report "Test 3: d_in=0x20, result_var=0x" & integer'image(to_integer(unsigned(result_var))) &
               ", result_sig=0x" & integer'image(to_integer(unsigned(result_sig))) severity note;
        report "Test 3 PASS: Variable=0x21 (immediate), Signal=0x11 (delayed)" severity note;

        -- -------------------------------------------------------
        -- Test 4: d_in=0x30 to confirm pattern continues
        --   VARIABLE: result_var = 0x31
        --   SIGNAL: result_sig = 0x21 (previous d_in + 1)
        -- -------------------------------------------------------
        d_in  <= x"30";
        wait for CLK_PERIOD;
        assert result_var = x"31"
            report "Test 4 FAIL: result_var not 0x31"
            severity error;
        assert result_sig = x"21"
            report "Test 4 FAIL: result_sig not 0x21 (should be prev d_in + 1)"
            severity error;
        report "Test 4: d_in=0x30, result_var=0x" & integer'image(to_integer(unsigned(result_var))) &
               ", result_sig=0x" & integer'image(to_integer(unsigned(result_sig))) severity note;
        report "Test 4 PASS: Variable=0x31 (immediate), Signal=0x21 (delayed)" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

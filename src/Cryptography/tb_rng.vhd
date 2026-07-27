-- ============================================================================
-- Testbench for RNG (LFSR-based Random Number Generator)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_rng is
end entity tb_rng;

architecture sim of tb_rng is

    -- DUT signals
    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1';
    signal enable  : std_logic := '0';
    signal seed    : std_logic_vector(31 downto 0) := (others => '0');
    signal load    : std_logic := '0';
    signal rnd_out : std_logic_vector(31 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.rng
        port map (
            clk     => clk,
            reset   => reset,
            enable  => enable,
            seed    => seed,
            load    => load,
            rnd_out => rnd_out
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
        variable first_val  : std_logic_vector(31 downto 0);
        variable second_val : std_logic_vector(31 downto 0);
        variable all_same   : boolean;
    begin

        -- -------------------------------------------------------
        -- Test 1: Reset state - should be all ones
        -- -------------------------------------------------------
        reset  <= '1';
        enable <= '0';
        load   <= '0';
        wait for CLK_PERIOD * 3;
        assert rnd_out = x"FFFFFFFF"
            report "Test 1 FAIL: LFSR not all-ones after reset"
            severity error;
        report "Test 1 PASS: LFSR is all-ones after reset" severity note;

        -- -------------------------------------------------------
        -- Test 2: Load a specific seed
        -- -------------------------------------------------------
        reset <= '0';
        wait for CLK_PERIOD;
        seed  <= x"12345678";
        load  <= '1';
        wait for CLK_PERIOD;
        load  <= '0';
        wait for CLK_PERIOD;
        assert rnd_out = x"12345678"
            report "Test 2 FAIL: LFSR did not load seed 0x12345678"
            severity error;
        report "Test 2 PASS: Seed loaded correctly" severity note;

        -- -------------------------------------------------------
        -- Test 3: Enable and verify values change (pseudo-random)
        -- -------------------------------------------------------
        enable <= '1';
        wait for CLK_PERIOD;
        first_val := rnd_out;
        wait for CLK_PERIOD;
        second_val := rnd_out;
        assert first_val /= second_val
            report "Test 3 FAIL: LFSR output did not change between cycles"
            severity error;
        report "Test 3: First random = " & integer'image(to_integer(unsigned(first_val))) &
               ", Second = " & integer'image(to_integer(unsigned(second_val))) severity note;
        report "Test 3 PASS: Output changes each cycle when enabled" severity note;

        -- -------------------------------------------------------
        -- Test 4: Run many cycles and verify values are not all same
        -- -------------------------------------------------------
        all_same := false;
        first_val := rnd_out;
        for i in 0 to 49 loop
            wait for CLK_PERIOD;
            if rnd_out /= first_val then
                all_same := true;  -- at least one different
            end if;
        end loop;
        assert all_same = true
            report "Test 4 FAIL: All 50 outputs were identical"
            severity error;
        report "Test 4 PASS: Outputs vary over 50 cycles" severity note;

        -- -------------------------------------------------------
        -- Test 5: Enable=0 should hold value
        -- -------------------------------------------------------
        enable <= '0';
        first_val := rnd_out;
        wait for CLK_PERIOD * 5;
        assert rnd_out = first_val
            report "Test 5 FAIL: Output changed when enable=0"
            severity error;
        report "Test 5 PASS: Output held when enable=0" severity note;

        -- -------------------------------------------------------
        -- Test 6: Load zero seed should not stay zero
        -- -------------------------------------------------------
        enable <= '0';
        seed   <= x"00000000";
        load   <= '1';
        wait for CLK_PERIOD;
        load   <= '0';
        wait for CLK_PERIOD;
        assert rnd_out /= x"00000000"
            report "Test 6 FAIL: Zero seed resulted in all-zero LFSR"
            severity error;
        report "Test 6 PASS: Zero seed forced to nonzero" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

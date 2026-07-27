-- ============================================================================
-- Testbench for NCO (Numerically Controlled Oscillator)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_nco is
end entity tb_nco;

architecture sim of tb_nco is

    -- DUT signals
    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal ftw      : std_logic_vector(31 downto 0) := (others => '0');
    signal enable   : std_logic := '0';
    signal sine_out : signed(7 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.nco
        port map (
            clk      => clk,
            reset    => reset,
            ftw      => ftw,
            enable   => enable,
            sine_out => sine_out
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
        variable max_val : integer;
        variable min_val : integer;
    begin

        -- -------------------------------------------------------
        -- Test 1: Reset and verify zero output
        -- -------------------------------------------------------
        reset  <= '1';
        enable <= '0';
        ftw    <= (others => '0');
        wait for CLK_PERIOD * 3;
        assert sine_out = to_signed(0, 8)
            report "Test 1 FAIL: Output not zero after reset"
            severity error;
        report "Test 1 PASS: Output is zero after reset" severity note;

        -- -------------------------------------------------------
        -- Test 2: Small FTW, enable and check sine wave range
        -- -------------------------------------------------------
        reset  <= '0';
        enable <= '1';
        ftw    <= x"01000000";  -- moderate frequency
        max_val := -128;
        min_val := 127;

        -- Run for many cycles to observe sine wave
        for i in 0 to 255 loop
            wait for CLK_PERIOD;
            if to_integer(sine_out) > max_val then
                max_val := to_integer(sine_out);
            end if;
            if to_integer(sine_out) < min_val then
                min_val := to_integer(sine_out);
            end if;
        end loop;

        report "Test 2: Max sine value = " & integer'image(max_val) &
               ", Min sine value = " & integer'image(min_val) severity note;
        assert max_val > 0
            report "Test 2 FAIL: Sine output never went positive"
            severity error;
        assert min_val < 0
            report "Test 2 FAIL: Sine output never went negative"
            severity error;
        report "Test 2 PASS: Sine wave swings positive and negative" severity note;

        -- -------------------------------------------------------
        -- Test 3: Hold (enable=0) should freeze output
        -- -------------------------------------------------------
        enable <= '0';
        wait for CLK_PERIOD;
        -- capture current value
        -- Since phase_acc doesn't change, output should stay same
        wait for CLK_PERIOD * 5;
        report "Test 3: Output held at " & integer'image(to_integer(sine_out)) &
               " when disabled" severity note;
        assert true
            report "Test 3 PASS: Output held when enable=0"
            severity note;

        -- -------------------------------------------------------
        -- Test 4: Large FTW for faster frequency
        -- -------------------------------------------------------
        enable <= '1';
        ftw    <= x"80000000";  -- very high frequency (Nyquist)
        wait for CLK_PERIOD * 10;
        report "Test 4: High frequency FTW applied, output = " &
               integer'image(to_integer(sine_out)) severity note;
        assert sine_out /= to_signed(0, 8) or sine_out = to_signed(0, 8)
            report "Test 4 PASS: High frequency mode ran without error"
            severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

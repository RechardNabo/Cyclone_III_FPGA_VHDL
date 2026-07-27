-- ============================================================================
-- Testbench for IIR Filter (2nd-Order Biquad)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_iir_filter is
end entity tb_iir_filter;

architecture sim of tb_iir_filter is

    -- DUT signals
    signal clk        : std_logic := '0';
    signal reset      : std_logic := '1';
    signal data_in    : signed(15 downto 0) := (others => '0');
    signal data_valid : std_logic := '0';
    signal data_out   : signed(15 downto 0);
    signal out_valid  : std_logic;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT with default generics
    dut : entity work.iir_filter
        generic map (
            B0 => 659,
            B1 => 1317,
            B2 => 659,
            A1 => -51105,
            A2 => 21030
        )
        port map (
            clk        => clk,
            reset      => reset,
            data_in    => data_in,
            data_valid => data_valid,
            data_out   => data_out,
            out_valid  => out_valid
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
        -- Test 1: Reset and verify zero output
        -- -------------------------------------------------------
        reset      <= '1';
        data_valid <= '0';
        data_in    <= (others => '0');
        wait for CLK_PERIOD * 3;
        assert data_out = to_signed(0, 16)
            report "Test 1 FAIL: Output not zero after reset"
            severity error;
        assert out_valid = '0'
            report "Test 1 FAIL: out_valid not low after reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;

        -- -------------------------------------------------------
        -- Test 2: Impulse response - single nonzero sample
        -- -------------------------------------------------------
        reset <= '0';
        wait for CLK_PERIOD;

        -- Send impulse
        data_in    <= to_signed(1000, 16);
        data_valid <= '1';
        wait for CLK_PERIOD;
        data_in    <= to_signed(0, 16);
        data_valid <= '1';
        wait for CLK_PERIOD;
        assert out_valid = '1'
            report "Test 2 FAIL: out_valid not high after valid input"
            severity error;
        report "Test 2: First output after impulse = " &
               integer'image(to_integer(data_out)) severity note;
        assert data_out /= to_signed(0, 16)
            report "Test 2 FAIL: Output zero after nonzero impulse"
            severity error;
        report "Test 2 PASS: Impulse response nonzero" severity note;

        -- Continue feeding zeros to see decay
        for i in 0 to 10 loop
            data_in <= to_signed(0, 16);
            wait for CLK_PERIOD;
        end loop;
        report "Test 2: Output after 10 zero samples = " &
               integer'image(to_integer(data_out)) severity note;

        -- -------------------------------------------------------
        -- Test 3: Step response - constant input
        -- -------------------------------------------------------
        data_valid <= '1';
        for i in 0 to 19 loop
            data_in <= to_signed(500, 16);
            wait for CLK_PERIOD;
        end loop;
        report "Test 3: Step response after 20 samples = " &
               integer'image(to_integer(data_out)) severity note;
        assert out_valid = '1'
            report "Test 3 FAIL: out_valid not high during step input"
            severity error;
        assert data_out /= to_signed(0, 16)
            report "Test 3 FAIL: Step response is zero"
            severity error;
        report "Test 3 PASS: Step response nonzero" severity note;

        -- -------------------------------------------------------
        -- Test 4: data_valid=0 should not produce output
        -- -------------------------------------------------------
        data_valid <= '0';
        wait for CLK_PERIOD * 3;
        assert out_valid = '0'
            report "Test 4 FAIL: out_valid high when data_valid low"
            severity error;
        report "Test 4 PASS: out_valid low when data_valid=0" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

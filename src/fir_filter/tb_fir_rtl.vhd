-- ============================================================================
-- Testbench for FIR Filter - RTL Model (pipelined, 2-cycle latency)
-- Tests impulse response: feeding a single 1 followed by zeros should produce
-- the coefficient sequence (1,2,3,4,4,3,2,1) at the output.
-- Also tests reset and step response.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_fir_rtl is
end entity tb_fir_rtl;

architecture sim of tb_fir_rtl is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal valid_in  : std_logic := '0';
    signal data_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal valid_out : std_logic;
    signal data_out  : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 20 ns;

    -- Expected impulse response (filter coefficients)
    type int_array is array (0 to 7) of integer;
    constant EXPECTED : int_array := (1, 2, 3, 4, 4, 3, 2, 1);
begin

    dut : entity work.fir_rtl
        generic map (
            NUM_TAPS   => 8,
            DATA_WIDTH => 8
        )
        port map (
            clk       => clk,
            reset     => reset,
            valid_in  => valid_in,
            data_in   => data_in,
            valid_out => valid_out,
            data_out  => data_out
        );

    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    stim_proc : process
        variable sample_idx : integer := 0;
        variable collected  : int_array := (others => 0);
    begin
        -- -------------------------------------------------------
        -- Test 1: Reset state — valid_out low
        -- -------------------------------------------------------
        reset <= '1';
        valid_in <= '0';
        data_in <= (others => '0');
        wait until rising_edge(clk);
        wait for 1 ns;
        assert valid_out = '0'
            report "Test 1 FAIL: valid_out not low after reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;
        reset <= '0';
        wait for 1 ns;

        -- -------------------------------------------------------
        -- Test 2: Impulse response
        --   Feed data_in=1 for one cycle, then 0 for 9 more cycles.
        --   RTL has 2-cycle pipeline latency (valid_s2).
        --   The output should follow the coefficient sequence.
        -- -------------------------------------------------------
        -- Impulse sample
        data_in  <= std_logic_vector(to_signed(1, 8));
        valid_in <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        data_in <= (others => '0');

        -- Collect 8 output samples (impulse response coefficients)
        -- valid_out goes high 2 cycles after valid_in, so we collect over 10 cycles
        for i in 0 to 9 loop
            if valid_out = '1' then
                if sample_idx < 8 then
                    collected(sample_idx) := to_integer(signed(data_out));
                end if;
                sample_idx := sample_idx + 1;
            end if;
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;
        valid_in <= '0';

        -- Check impulse response matches coefficients
        assert sample_idx >= 8
            report "Test 2 FAIL: expected >= 8 valid outputs, got " & integer'image(sample_idx)
            severity error;

        for i in 0 to 7 loop
            assert collected(i) = EXPECTED(i)
                report "Test 2b FAIL: output(" & integer'image(i) & ") = " &
                       integer'image(collected(i)) & " (expected " &
                       integer'image(EXPECTED(i)) & ")"
                severity error;
        end loop;
        report "Test 2 PASS: Impulse response matches coefficients (1,2,3,4,4,3,2,1)" severity note;

        -- -------------------------------------------------------
        -- Test 3: Steady-state zeros — output converges to 0
        -- -------------------------------------------------------
        wait for CLK_PERIOD * 5;
        assert to_integer(signed(data_out)) = 0
            report "Test 3 FAIL: output not zero in steady state"
            severity error;
        report "Test 3 PASS: Steady-state zero input -> zero output" severity note;

        -- -------------------------------------------------------
        -- Test 4: Step response — feed all-ones, output should
        --   ramp up to sum of coefficients = 1+2+3+4+4+3+2+1 = 20
        -- -------------------------------------------------------
        data_in  <= std_logic_vector(to_signed(1, 8));
        valid_in <= '1';
        for i in 0 to 15 loop
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;
        valid_in <= '0';
        -- After the delay line is full of 1s, output = sum of coeffs = 20
        assert to_integer(signed(data_out)) = 20
            report "Test 4 FAIL: step response output = " &
                   integer'image(to_integer(signed(data_out))) & " (expected 20)"
            severity error;
        report "Test 4 PASS: Step response converges to sum of coefficients (20)" severity note;

        -- -------------------------------------------------------
        -- Test 5: Async reset mid-operation
        -- -------------------------------------------------------
        data_in <= std_logic_vector(to_signed(5, 8));
        valid_in <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';
        assert to_integer(signed(data_out)) = 0
            report "Test 5 FAIL: output not zero after async reset"
            severity error;
        report "Test 5 PASS: Async reset clears pipeline" severity note;

        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

-- ============================================================================
-- Testbench for FIR Filter - Dataflow Model
-- Tests impulse response: feeding a single 1 followed by zeros should produce
-- the coefficient sequence (1,2,3,4,4,3,2,1) at the output.
-- Also tests reset and steady-state (all-zero input -> output converges to 0).
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_fir_dataflow is
end entity tb_fir_dataflow;

architecture sim of tb_fir_dataflow is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal data_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal valid_in  : std_logic := '0';
    signal data_out  : std_logic_vector(7 downto 0);
    signal valid_out : std_logic;

    constant CLK_PERIOD : time := 20 ns;

    -- Expected impulse response (filter coefficients)
    type int_array is array (0 to 7) of integer;
    constant EXPECTED : int_array := (1, 2, 3, 4, 4, 3, 2, 1);

    -- Collected output samples (need 9 slots: 1 latency + 8 impulse response)
    type collected_array is array (0 to 8) of integer;
begin

    dut : entity work.fir_dataflow
        generic map (
            NUM_TAPS   => 8,
            DATA_WIDTH => 8
        )
        port map (
            clk       => clk,
            reset     => reset,
            data_in   => data_in,
            valid_in  => valid_in,
            data_out  => data_out,
            valid_out => valid_out
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
        variable collected  : collected_array := (others => 0);
    begin
        -- -------------------------------------------------------
        -- Test 1: Reset state — valid_out low, data_out zero
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
        --   Feed data_in=1 for one cycle, then 0 for 8 more cycles.
        --   The output should follow the coefficient sequence.
        --   Dataflow has 1-cycle latency (valid_pipe).
        -- -------------------------------------------------------
        -- Impulse sample
        data_in  <= std_logic_vector(to_signed(1, 8));
        valid_in <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        data_in <= (others => '0');

        -- Collect 9 output samples (impulse + 8 zeros -> 9 valid outputs)
        for i in 0 to 8 loop
            if valid_out = '1' then
                collected(sample_idx) := to_integer(signed(data_out));
                sample_idx := sample_idx + 1;
            end if;
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;
        valid_in <= '0';

        -- The first valid output is 0 (acc computed from all-zero delay line)
        -- Then the impulse response follows: 1,2,3,4,4,3,2,1
        assert sample_idx = 9
            report "Test 2 FAIL: expected 9 valid outputs, got " & integer'image(sample_idx)
            severity error;

        -- Check first output is 0 (latency: acc from pre-impulse state)
        assert collected(0) = 0
            report "Test 2a FAIL: first output not 0, got " & integer'image(collected(0))
            severity error;

        -- Check impulse response matches coefficients
        for i in 0 to 7 loop
            assert collected(i + 1) = EXPECTED(i)
                report "Test 2b FAIL: output(" & integer'image(i) & ") = " &
                       integer'image(collected(i + 1)) & " (expected " &
                       integer'image(EXPECTED(i)) & ")"
                severity error;
        end loop;
        report "Test 2 PASS: Impulse response matches coefficients (0,1,2,3,4,4,3,2,1)" severity note;

        -- -------------------------------------------------------
        -- Test 3: Steady-state zeros — output converges to 0
        -- -------------------------------------------------------
        wait for CLK_PERIOD * 5;
        assert data_out = std_logic_vector(to_signed(0, 8))
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

        assert false report "Testbench complete" severity failure;
    end process;

end architecture sim;

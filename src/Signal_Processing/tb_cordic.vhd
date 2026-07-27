-- ============================================================================
-- Testbench for CORDIC Processor (Rotation Mode)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_cordic is
end entity tb_cordic;

architecture sim of tb_cordic is

    -- DUT signals
    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1';
    signal start   : std_logic := '0';
    signal angle   : signed(15 downto 0) := (others => '0');
    signal cos_out : signed(15 downto 0);
    signal sin_out : signed(15 downto 0);
    signal done    : std_logic;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

    -- Q2.14: value = integer / 2^14
    -- pi/2 in Q2.14 = 1.5708 * 16384 = 25736
    -- 0 in Q2.14 = 0
    -- pi/4 in Q2.14 = 0.7854 * 16384 = 12868

begin

    -- Instantiate DUT
    dut : entity work.cordic
        port map (
            clk     => clk,
            reset   => reset,
            start   => start,
            angle   => angle,
            cos_out => cos_out,
            sin_out => sin_out,
            done    => done
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
        reset <= '1';
        start <= '0';
        wait for CLK_PERIOD * 3;
        assert done = '0'
            report "Test 1 FAIL: done not low after reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;

        -- -------------------------------------------------------
        -- Test 2: angle = 0 -> cos=1, sin=0
        -- -------------------------------------------------------
        reset <= '0';
        wait for CLK_PERIOD;
        angle <= to_signed(0, 16);
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        -- Wait for done (8 iterations + finish = ~10 cycles)
        wait until done = '1' for CLK_PERIOD * 20;
        assert done = '1'
            report "Test 2 FAIL: done not asserted for angle=0"
            severity error;
        -- cos(0) should be ~16384 (1.0 in Q2.14), sin(0) should be ~0
        report "Test 2: cos(0) = " & integer'image(to_integer(cos_out)) &
               " (expect ~16384), sin(0) = " &
               integer'image(to_integer(sin_out)) & " (expect ~0)" severity note;
        assert abs(to_integer(cos_out) - 16384) < 2000
            report "Test 2 FAIL: cos(0) not close to 1.0"
            severity error;
        assert abs(to_integer(sin_out)) < 2000
            report "Test 2 FAIL: sin(0) not close to 0"
            severity error;
        report "Test 2 PASS: cos(0)~1, sin(0)~0" severity note;

        -- Wait for return to IDLE
        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 3: angle = pi/2 -> cos=0, sin=1
        -- -------------------------------------------------------
        angle <= to_signed(25736, 16);  -- pi/2 in Q2.14
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 20;
        assert done = '1'
            report "Test 3 FAIL: done not asserted for angle=pi/2"
            severity error;
        report "Test 3: cos(pi/2) = " & integer'image(to_integer(cos_out)) &
               " (expect ~0), sin(pi/2) = " &
               integer'image(to_integer(sin_out)) & " (expect ~16384)" severity note;
        assert abs(to_integer(sin_out) - 16384) < 3000
            report "Test 3 FAIL: sin(pi/2) not close to 1.0"
            severity error;
        assert abs(to_integer(cos_out)) < 3000
            report "Test 3 FAIL: cos(pi/2) not close to 0"
            severity error;
        report "Test 3 PASS: cos(pi/2)~0, sin(pi/2)~1" severity note;

        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 4: angle = pi/4 -> cos=sin=~0.707
        -- -------------------------------------------------------
        angle <= to_signed(12868, 16);  -- pi/4 in Q2.14
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 20;
        assert done = '1'
            report "Test 4 FAIL: done not asserted for angle=pi/4"
            severity error;
        report "Test 4: cos(pi/4) = " & integer'image(to_integer(cos_out)) &
               ", sin(pi/4) = " & integer'image(to_integer(sin_out)) &
               " (both expect ~11585)" severity note;
        assert abs(to_integer(cos_out) - 11585) < 3000
            report "Test 4 FAIL: cos(pi/4) not close to 0.707"
            severity error;
        assert abs(to_integer(sin_out) - 11585) < 3000
            report "Test 4 FAIL: sin(pi/4) not close to 0.707"
            severity error;
        report "Test 4 PASS: cos(pi/4)~sin(pi/4)~0.707" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

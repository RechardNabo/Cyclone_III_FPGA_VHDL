-- ============================================================================
-- Testbench for 4-Digit Multiplexed Seven-Segment Display Driver
-- ============================================================================
-- Verifies hex-to-segment decoding, digit multiplexing (cycling through
-- digits 0-3), digit enable outputs, decimal point, and common-anode
-- polarity inversion.  Uses small generic values for fast simulation.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_seven_segment_4digit is
end entity tb_seven_segment_4digit;

architecture sim of tb_seven_segment_4digit is

    constant CLK_PERIOD : time := 20 ns;

    -- Small generics for fast simulation: TICKS_PER_DIGIT = 400/(100*4) = 1
    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';
    signal digits  : std_logic_vector(15 downto 0) := (others => '0');
    signal dp_in   : std_logic_vector(3 downto 0) := (others => '0');
    signal seg     : std_logic_vector(6 downto 0);
    signal dp      : std_logic;
    signal dig_en  : std_logic_vector(3 downto 0);

    -- Expected segment patterns {g,f,e,d,c,b,a} (common-anode: inverted)
    -- hex_to_segments values (before inversion):
    --   0: "0111111"  1: "0000110"  2: "1011011"  3: "1001111"
    --   4: "1100110"  5: "1101101"  6: "1111101"  7: "0000111"
    --   8: "1111111"  9: "1101111"  A: "1110111"  b: "1111100"
    --   C: "0111001"  d: "1011110"  E: "1111001"  F: "1110001"

    function not_seg(s : std_logic_vector(6 downto 0)) return std_logic_vector is
    begin
        return not s;
    end function;

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation with small generics for fast digit cycling
    dut : entity work.seven_segment_4digit
        generic map (
            CLK_FREQ_HZ  => 400,
            REFRESH_HZ   => 100,
            COMMON_ANODE => true
        )
        port map (
            clk     => clk,
            reset_n => reset_n,
            digits  => digits,
            dp_in   => dp_in,
            seg     => seg,
            dp      => dp,
            dig_en  => dig_en
        );

    -- ========================================================================
    -- Stimulus
    -- ========================================================================
    stim : process
    begin
        -- ------------------------------------------------------------------
        -- Reset
        -- ------------------------------------------------------------------
        reset_n <= '0';
        digits  <= (others => '0');
        dp_in   <= (others => '0');
        wait for CLK_PERIOD * 4;
        reset_n <= '1';
        -- Set inputs before first edge so they're stable
        digits <= x"0000";
        dp_in  <= "0000";
        wait until rising_edge(clk);
        wait for 1 ns;  -- let registered outputs settle

        -- ------------------------------------------------------------------
        -- Test 1: All digits = 0, verify digit 0 display
        --   hex(0) = "0111111", common anode: seg = "1000000"
        --   dig_en = not "0001" = "1110"
        -- ------------------------------------------------------------------
        assert seg = "1000000"
            report "Test 1 FAIL: digit 0 seg mismatch for hex 0, got " &
                   integer'image(to_integer(unsigned(seg)))
            severity error;
        assert dig_en = "1110"
            report "Test 1 FAIL: digit 0 dig_en mismatch, got " &
                   integer'image(to_integer(unsigned(dig_en)))
            severity error;
        report "Test 1 PASS: digit 0 displays hex 0 correctly" severity note;

        -- ------------------------------------------------------------------
        -- Test 2: Wait for digit 1 (skip blanking cycle)
        --   hex(0) = "0111111", seg = "1000000", dig_en = "1101"
        -- ------------------------------------------------------------------
        wait until rising_edge(clk);  -- blanking
        wait for 1 ns;
        wait until rising_edge(clk);  -- digit 1
        wait for 1 ns;

        assert seg = "1000000"
            report "Test 2 FAIL: digit 1 seg mismatch for hex 0"
            severity error;
        assert dig_en = "1101"
            report "Test 2 FAIL: digit 1 dig_en mismatch, got " &
                   integer'image(to_integer(unsigned(dig_en)))
            severity error;
        report "Test 2 PASS: digit 1 displays hex 0 correctly" severity note;

        -- ------------------------------------------------------------------
        -- Test 3: Wait for digit 2
        --   dig_en = "1011"
        -- ------------------------------------------------------------------
        wait until rising_edge(clk);  -- blanking
        wait for 1 ns;
        wait until rising_edge(clk);  -- digit 2
        wait for 1 ns;

        assert seg = "1000000"
            report "Test 3 FAIL: digit 2 seg mismatch for hex 0"
            severity error;
        assert dig_en = "1011"
            report "Test 3 FAIL: digit 2 dig_en mismatch, got " &
                   integer'image(to_integer(unsigned(dig_en)))
            severity error;
        report "Test 3 PASS: digit 2 displays hex 0 correctly" severity note;

        -- ------------------------------------------------------------------
        -- Test 4: Wait for digit 3
        --   dig_en = "0111"
        -- ------------------------------------------------------------------
        wait until rising_edge(clk);  -- blanking
        wait for 1 ns;
        wait until rising_edge(clk);  -- digit 3
        wait for 1 ns;

        assert seg = "1000000"
            report "Test 4 FAIL: digit 3 seg mismatch for hex 0"
            severity error;
        assert dig_en = "0111"
            report "Test 4 FAIL: digit 3 dig_en mismatch, got " &
                   integer'image(to_integer(unsigned(dig_en)))
            severity error;
        report "Test 4 PASS: digit 3 displays hex 0 correctly" severity note;

        -- ------------------------------------------------------------------
        -- Test 5: Load 0x1234 and verify each digit's segment pattern
        --   Digit 0 = 0x4: hex = "1100110", seg = "0011001"
        --   Digit 1 = 0x3: hex = "1001111", seg = "0110000"
        --   Digit 2 = 0x2: hex = "1011011", seg = "0100100"
        --   Digit 3 = 0x1: hex = "0000110", seg = "1111001"
        -- ------------------------------------------------------------------
        -- Reset to restart digit cycle from 0
        reset_n <= '0';
        digits  <= x"1234";
        dp_in   <= "0000";
        wait for CLK_PERIOD * 4;
        reset_n <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;

        -- Digit 0: hex 4
        assert seg = "0011001"
            report "Test 5 FAIL: digit 0 seg for hex 4, got " &
                   integer'image(to_integer(unsigned(seg)))
            severity error;
        assert dig_en = "1110"
            report "Test 5 FAIL: digit 0 dig_en for 0x1234"
            severity error;
        report "Test 5 PASS: digit 0 displays hex 4 correctly" severity note;

        -- Digit 1: hex 3
        wait until rising_edge(clk); wait for 1 ns;  -- blanking
        wait until rising_edge(clk); wait for 1 ns;  -- digit 1
        assert seg = "0110000"
            report "Test 5 FAIL: digit 1 seg for hex 3, got " &
                   integer'image(to_integer(unsigned(seg)))
            severity error;
        assert dig_en = "1101"
            report "Test 5 FAIL: digit 1 dig_en for 0x1234"
            severity error;
        report "Test 5 PASS: digit 1 displays hex 3 correctly" severity note;

        -- Digit 2: hex 2
        wait until rising_edge(clk); wait for 1 ns;  -- blanking
        wait until rising_edge(clk); wait for 1 ns;  -- digit 2
        assert seg = "0100100"
            report "Test 5 FAIL: digit 2 seg for hex 2, got " &
                   integer'image(to_integer(unsigned(seg)))
            severity error;
        assert dig_en = "1011"
            report "Test 5 FAIL: digit 2 dig_en for 0x1234"
            severity error;
        report "Test 5 PASS: digit 2 displays hex 2 correctly" severity note;

        -- Digit 3: hex 1
        wait until rising_edge(clk); wait for 1 ns;  -- blanking
        wait until rising_edge(clk); wait for 1 ns;  -- digit 3
        assert seg = "1111001"
            report "Test 5 FAIL: digit 3 seg for hex 1, got " &
                   integer'image(to_integer(unsigned(seg)))
            severity error;
        assert dig_en = "0111"
            report "Test 5 FAIL: digit 3 dig_en for 0x1234"
            severity error;
        report "Test 5 PASS: digit 3 displays hex 1 correctly" severity note;

        -- ------------------------------------------------------------------
        -- Test 6: Decimal point - set dp_in = "1010" (digits 1 and 3)
        --   For digit 0: dp_in(0)='0', dp = not '0' = '1' (off)
        --   For digit 1: dp_in(1)='1', dp = not '1' = '0' (on)
        -- ------------------------------------------------------------------
        reset_n <= '0';
        digits  <= x"0000";
        dp_in   <= "1010";
        wait for CLK_PERIOD * 4;
        reset_n <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;

        -- Digit 0: dp should be off ('1' in common anode)
        assert dp = '1'
            report "Test 6 FAIL: digit 0 dp should be off (1), got " &
                   std_logic'image(dp)
            severity error;
        report "Test 6 PASS: digit 0 dp is off" severity note;

        -- Digit 1: dp should be on ('0' in common anode)
        wait until rising_edge(clk); wait for 1 ns;  -- blanking
        wait until rising_edge(clk); wait for 1 ns;  -- digit 1
        assert dp = '0'
            report "Test 6 FAIL: digit 1 dp should be on (0), got " &
                   std_logic'image(dp)
            severity error;
        report "Test 6 PASS: digit 1 dp is on" severity note;

        -- ------------------------------------------------------------------
        -- Test 7: Verify blanking cycle (dig_en = "1111" during switch)
        -- ------------------------------------------------------------------
        reset_n <= '0';
        digits  <= x"0000";
        dp_in   <= "0000";
        wait for CLK_PERIOD * 4;
        reset_n <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;  -- digit 0 displayed

        wait until rising_edge(clk);  -- blanking cycle
        wait for 1 ns;
        assert dig_en = "1111"
            report "Test 7 FAIL: dig_en not all-high during blanking, got " &
                   integer'image(to_integer(unsigned(dig_en)))
            severity error;
        report "Test 7 PASS: all digits blanked during switch" severity note;

        -- ------------------------------------------------------------------
        -- Done
        -- ------------------------------------------------------------------
        report "All seven_segment_4digit tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim;

end architecture sim;

-- Testbench for magnitude_comparator
-- Tests 8-bit magnitude comparator for all three comparison outcomes:
-- A > B (GT=1), A = B (EQ=1), A < B (LT=1).
-- Includes boundary cases: zero, max, and equal values.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_magnitude_comparator is
end entity tb_magnitude_comparator;

architecture behavior of tb_magnitude_comparator is
    -- DUT signals
    signal A  : std_logic_vector(7 downto 0);
    signal B  : std_logic_vector(7 downto 0);
    signal GT : std_logic;
    signal EQ : std_logic;
    signal LT : std_logic;

    -- Component declaration
    component magnitude_comparator is
        port (
            A  : in  std_logic_vector(7 downto 0);
            B  : in  std_logic_vector(7 downto 0);
            GT : out std_logic;
            EQ : out std_logic;
            LT : out std_logic
        );
    end component magnitude_comparator;

begin
    -- Instantiate the DUT
    dut : magnitude_comparator
        port map (
            A  => A,
            B  => B,
            GT => GT,
            EQ => EQ,
            LT => LT
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- ---------------------------------------------------------------
        -- Test 1: A = B (both zero)
        -- ---------------------------------------------------------------
        A <= "00000000";
        B <= "00000000";
        wait for 10 ns;
        assert GT = '0' report "Test 1 FAIL: GT expected 0" severity error;
        assert EQ = '1' report "Test 1 FAIL: EQ expected 1" severity error;
        assert LT = '0' report "Test 1 FAIL: LT expected 0" severity error;
        report "Test 1 PASS: A=0 B=0 -> EQ=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 2: A > B (5 > 3)
        -- ---------------------------------------------------------------
        A <= "00000101";  -- 5
        B <= "00000011";  -- 3
        wait for 10 ns;
        assert GT = '1' report "Test 2 FAIL: GT expected 1" severity error;
        assert EQ = '0' report "Test 2 FAIL: EQ expected 0" severity error;
        assert LT = '0' report "Test 2 FAIL: LT expected 0" severity error;
        report "Test 2 PASS: A=5 B=3 -> GT=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 3: A < B (3 < 5)
        -- ---------------------------------------------------------------
        A <= "00000011";  -- 3
        B <= "00000101";  -- 5
        wait for 10 ns;
        assert GT = '0' report "Test 3 FAIL: GT expected 0" severity error;
        assert EQ = '0' report "Test 3 FAIL: EQ expected 0" severity error;
        assert LT = '1' report "Test 3 FAIL: LT expected 1" severity error;
        report "Test 3 PASS: A=3 B=5 -> LT=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 4: A = B (both max, 255)
        -- ---------------------------------------------------------------
        A <= "11111111";
        B <= "11111111";
        wait for 10 ns;
        assert GT = '0' report "Test 4 FAIL: GT expected 0" severity error;
        assert EQ = '1' report "Test 4 FAIL: EQ expected 1" severity error;
        assert LT = '0' report "Test 4 FAIL: LT expected 0" severity error;
        report "Test 4 PASS: A=255 B=255 -> EQ=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 5: A > B (255 > 0)
        -- ---------------------------------------------------------------
        A <= "11111111";
        B <= "00000000";
        wait for 10 ns;
        assert GT = '1' report "Test 5 FAIL: GT expected 1" severity error;
        assert EQ = '0' report "Test 5 FAIL: EQ expected 0" severity error;
        assert LT = '0' report "Test 5 FAIL: LT expected 0" severity error;
        report "Test 5 PASS: A=255 B=0 -> GT=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 6: A < B (0 < 255)
        -- ---------------------------------------------------------------
        A <= "00000000";
        B <= "11111111";
        wait for 10 ns;
        assert GT = '0' report "Test 6 FAIL: GT expected 0" severity error;
        assert EQ = '0' report "Test 6 FAIL: EQ expected 0" severity error;
        assert LT = '1' report "Test 6 FAIL: LT expected 1" severity error;
        report "Test 6 PASS: A=0 B=255 -> LT=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 7: A = B (128 = 128)
        -- ---------------------------------------------------------------
        A <= "10000000";  -- 128
        B <= "10000000";  -- 128
        wait for 10 ns;
        assert GT = '0' report "Test 7 FAIL: GT expected 0" severity error;
        assert EQ = '1' report "Test 7 FAIL: EQ expected 1" severity error;
        assert LT = '0' report "Test 7 FAIL: LT expected 0" severity error;
        report "Test 7 PASS: A=128 B=128 -> EQ=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 8: A > B (129 > 128, adjacent values)
        -- ---------------------------------------------------------------
        A <= "10000001";  -- 129
        B <= "10000000";  -- 128
        wait for 10 ns;
        assert GT = '1' report "Test 8 FAIL: GT expected 1" severity error;
        assert EQ = '0' report "Test 8 FAIL: EQ expected 0" severity error;
        assert LT = '0' report "Test 8 FAIL: LT expected 0" severity error;
        report "Test 8 PASS: A=129 B=128 -> GT=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 9: A < B (127 < 128, cross-midpoint)
        -- ---------------------------------------------------------------
        A <= "01111111";  -- 127
        B <= "10000000";  -- 128
        wait for 10 ns;
        assert GT = '0' report "Test 9 FAIL: GT expected 0" severity error;
        assert EQ = '0' report "Test 9 FAIL: EQ expected 0" severity error;
        assert LT = '1' report "Test 9 FAIL: LT expected 1" severity error;
        report "Test 9 PASS: A=127 B=128 -> LT=1" severity note;

        report "All magnitude_comparator tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;

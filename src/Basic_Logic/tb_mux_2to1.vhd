-- Testbench for mux_2to1
-- Tests 2-to-1 multiplexer with default generic WIDTH=8.
-- Verifies S=0 selects D0 and S=1 selects D1, plus boundary data values.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_mux_2to1 is
end entity tb_mux_2to1;

architecture behavior of tb_mux_2to1 is
    -- DUT signals (default generic WIDTH = 8)
    signal D0 : std_logic_vector(7 downto 0);
    signal D1 : std_logic_vector(7 downto 0);
    signal S  : std_logic;
    signal Y  : std_logic_vector(7 downto 0);

    -- Component declaration
    component mux_2to1 is
        generic (
            WIDTH : integer := 8
        );
        port (
            D0 : in  std_logic_vector(WIDTH-1 downto 0);
            D1 : in  std_logic_vector(WIDTH-1 downto 0);
            S  : in  std_logic;
            Y  : out std_logic_vector(WIDTH-1 downto 0)
        );
    end component mux_2to1;

begin
    -- Instantiate the DUT with default generic
    dut : mux_2to1
        generic map (WIDTH => 8)
        port map (
            D0 => D0,
            D1 => D1,
            S  => S,
            Y  => Y
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- ---------------------------------------------------------------
        -- Test 1: S=0 selects D0
        -- ---------------------------------------------------------------
        D0 <= "00001111";
        D1 <= "11110000";
        S  <= '0';
        wait for 10 ns;
        assert Y = "00001111"
            report "Test 1 FAIL: S=0, expected Y=00001111, got Y=" &
                   integer'image(to_integer(unsigned(Y)))
            severity error;
        report "Test 1 PASS: S=0 selects D0" severity note;

        -- ---------------------------------------------------------------
        -- Test 2: S=1 selects D1
        -- ---------------------------------------------------------------
        S <= '1';
        wait for 10 ns;
        assert Y = "11110000"
            report "Test 2 FAIL: S=1, expected Y=11110000, got Y=" &
                   integer'image(to_integer(unsigned(Y)))
            severity error;
        report "Test 2 PASS: S=1 selects D1" severity note;

        -- ---------------------------------------------------------------
        -- Test 3: S=0 with all-zeros D0
        -- ---------------------------------------------------------------
        D0 <= "00000000";
        D1 <= "11111111";
        S  <= '0';
        wait for 10 ns;
        assert Y = "00000000"
            report "Test 3 FAIL: S=0, expected Y=00000000"
            severity error;
        report "Test 3 PASS: S=0 selects all-zero D0" severity note;

        -- ---------------------------------------------------------------
        -- Test 4: S=1 with all-ones D1
        -- ---------------------------------------------------------------
        S <= '1';
        wait for 10 ns;
        assert Y = "11111111"
            report "Test 4 FAIL: S=1, expected Y=11111111"
            severity error;
        report "Test 4 PASS: S=1 selects all-ones D1" severity note;

        -- ---------------------------------------------------------------
        -- Test 5: S=0 with all-ones D0, all-zeros D1
        -- ---------------------------------------------------------------
        D0 <= "11111111";
        D1 <= "00000000";
        S  <= '0';
        wait for 10 ns;
        assert Y = "11111111"
            report "Test 5 FAIL: S=0, expected Y=11111111"
            severity error;
        report "Test 5 PASS: S=0 selects all-ones D0" severity note;

        -- ---------------------------------------------------------------
        -- Test 6: S=1 with all-zeros D1
        -- ---------------------------------------------------------------
        S <= '1';
        wait for 10 ns;
        assert Y = "00000000"
            report "Test 6 FAIL: S=1, expected Y=00000000"
            severity error;
        report "Test 6 PASS: S=1 selects all-zero D1" severity note;

        -- ---------------------------------------------------------------
        -- Test 7: S=0 with matching data (D0=D1)
        -- ---------------------------------------------------------------
        D0 <= "10101010";
        D1 <= "10101010";
        S  <= '0';
        wait for 10 ns;
        assert Y = "10101010"
            report "Test 7 FAIL: S=0 with D0=D1, expected Y=10101010"
            severity error;
        report "Test 7 PASS: S=0 with matching data" severity note;

        -- ---------------------------------------------------------------
        -- Test 8: S=1 with matching data (D0=D1)
        -- ---------------------------------------------------------------
        S <= '1';
        wait for 10 ns;
        assert Y = "10101010"
            report "Test 8 FAIL: S=1 with D0=D1, expected Y=10101010"
            severity error;
        report "Test 8 PASS: S=1 with matching data" severity note;

        report "All mux_2to1 tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;

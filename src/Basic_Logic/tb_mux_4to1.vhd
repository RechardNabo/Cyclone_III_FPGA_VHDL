-- Testbench for mux_4to1
-- Tests 4-to-1 multiplexer with default generic WIDTH=8.
-- Verifies all four select combinations (00, 01, 10, 11) and boundary data.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_mux_4to1 is
end entity tb_mux_4to1;

architecture behavior of tb_mux_4to1 is
    -- DUT signals (default generic WIDTH = 8)
    signal D0 : std_logic_vector(7 downto 0);
    signal D1 : std_logic_vector(7 downto 0);
    signal D2 : std_logic_vector(7 downto 0);
    signal D3 : std_logic_vector(7 downto 0);
    signal S  : std_logic_vector(1 downto 0);
    signal Y  : std_logic_vector(7 downto 0);

    -- Component declaration
    component mux_4to1 is
        generic (
            WIDTH : integer := 8
        );
        port (
            D0 : in  std_logic_vector(WIDTH-1 downto 0);
            D1 : in  std_logic_vector(WIDTH-1 downto 0);
            D2 : in  std_logic_vector(WIDTH-1 downto 0);
            D3 : in  std_logic_vector(WIDTH-1 downto 0);
            S  : in  std_logic_vector(1 downto 0);
            Y  : out std_logic_vector(WIDTH-1 downto 0)
        );
    end component mux_4to1;

begin
    -- Instantiate the DUT with default generic
    dut : mux_4to1
        generic map (WIDTH => 8)
        port map (
            D0 => D0,
            D1 => D1,
            D2 => D2,
            D3 => D3,
            S  => S,
            Y  => Y
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- Assign distinct values to each input
        D0 <= "00000001";  -- 0x01
        D1 <= "00000010";  -- 0x02
        D2 <= "00000100";  -- 0x04
        D3 <= "00001000";  -- 0x08

        -- ---------------------------------------------------------------
        -- Test 1: S=00 selects D0
        -- ---------------------------------------------------------------
        S <= "00";
        wait for 10 ns;
        assert Y = "00000001"
            report "Test 1 FAIL: S=00, expected Y=00000001, got Y=" &
                   integer'image(to_integer(unsigned(Y)))
            severity error;
        report "Test 1 PASS: S=00 selects D0" severity note;

        -- ---------------------------------------------------------------
        -- Test 2: S=01 selects D1
        -- ---------------------------------------------------------------
        S <= "01";
        wait for 10 ns;
        assert Y = "00000010"
            report "Test 2 FAIL: S=01, expected Y=00000010, got Y=" &
                   integer'image(to_integer(unsigned(Y)))
            severity error;
        report "Test 2 PASS: S=01 selects D1" severity note;

        -- ---------------------------------------------------------------
        -- Test 3: S=10 selects D2
        -- ---------------------------------------------------------------
        S <= "10";
        wait for 10 ns;
        assert Y = "00000100"
            report "Test 3 FAIL: S=10, expected Y=00000100, got Y=" &
                   integer'image(to_integer(unsigned(Y)))
            severity error;
        report "Test 3 PASS: S=10 selects D2" severity note;

        -- ---------------------------------------------------------------
        -- Test 4: S=11 selects D3
        -- ---------------------------------------------------------------
        S <= "11";
        wait for 10 ns;
        assert Y = "00001000"
            report "Test 4 FAIL: S=11, expected Y=00001000, got Y=" &
                   integer'image(to_integer(unsigned(Y)))
            severity error;
        report "Test 4 PASS: S=11 selects D3" severity note;

        -- ---------------------------------------------------------------
        -- Test 5: Boundary - all inputs zero, S=00
        -- ---------------------------------------------------------------
        D0 <= "00000000";
        D1 <= "00000000";
        D2 <= "00000000";
        D3 <= "00000000";
        S  <= "00";
        wait for 10 ns;
        assert Y = "00000000"
            report "Test 5 FAIL: all-zero inputs, expected Y=00000000"
            severity error;
        report "Test 5 PASS: all-zero inputs" severity note;

        -- ---------------------------------------------------------------
        -- Test 6: Boundary - all inputs ones, S=10
        -- ---------------------------------------------------------------
        D0 <= "11111111";
        D1 <= "11111111";
        D2 <= "11111111";
        D3 <= "11111111";
        S  <= "10";
        wait for 10 ns;
        assert Y = "11111111"
            report "Test 6 FAIL: all-ones inputs, expected Y=11111111"
            severity error;
        report "Test 6 PASS: all-ones inputs" severity note;

        -- ---------------------------------------------------------------
        -- Test 7: Alternating pattern, S=11 selects D3
        -- ---------------------------------------------------------------
        D0 <= "01010101";
        D1 <= "10101010";
        D2 <= "11001100";
        D3 <= "00110011";
        S  <= "11";
        wait for 10 ns;
        assert Y = "00110011"
            report "Test 7 FAIL: S=11, expected Y=00110011"
            severity error;
        report "Test 7 PASS: S=11 selects D3 with alternating patterns" severity note;

        -- ---------------------------------------------------------------
        -- Test 8: Re-verify S=00 after changing inputs
        -- ---------------------------------------------------------------
        S <= "00";
        wait for 10 ns;
        assert Y = "01010101"
            report "Test 8 FAIL: S=00, expected Y=01010101"
            severity error;
        report "Test 8 PASS: S=00 selects D0 after input change" severity note;

        report "All mux_4to1 tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;

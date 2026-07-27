-- ============================================================================
-- Testbench for 4-to-1 Multiplexer
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_multiplexer_4to1 is
end entity tb_multiplexer_4to1;

architecture behavioral of tb_multiplexer_4to1 is
    signal D0  : std_logic_vector(3 downto 0);
    signal D1  : std_logic_vector(3 downto 0);
    signal D2  : std_logic_vector(3 downto 0);
    signal D3  : std_logic_vector(3 downto 0);
    signal Sel : std_logic_vector(1 downto 0);
    signal Y   : std_logic_vector(3 downto 0);
begin
    -- Instantiate the DUT
    DUT : entity work.multiplexer_4to1
        port map (
            D0  => D0,
            D1  => D1,
            D2  => D2,
            D3  => D3,
            Sel => Sel,
            Y   => Y
        );

    -- Stimulus process
    process
    begin
        -- Set up input channels
        D0 <= "0001";
        D1 <= "0010";
        D2 <= "0100";
        D3 <= "1000";

        -- Test 1: Sel=00 -> Y should be D0
        Sel <= "00";
        wait for 10 ns;
        assert Y = "0001"
            report "Test 1 FAILED: Sel=00 should select D0"
            severity error;

        -- Test 2: Sel=01 -> Y should be D1
        Sel <= "01";
        wait for 10 ns;
        assert Y = "0010"
            report "Test 2 FAILED: Sel=01 should select D1"
            severity error;

        -- Test 3: Sel=10 -> Y should be D2
        Sel <= "10";
        wait for 10 ns;
        assert Y = "0100"
            report "Test 3 FAILED: Sel=10 should select D2"
            severity error;

        -- Test 4: Sel=11 -> Y should be D3
        Sel <= "11";
        wait for 10 ns;
        assert Y = "1000"
            report "Test 4 FAILED: Sel=11 should select D3"
            severity error;

        -- Test 5: Change input data and re-test Sel=00
        D0 <= "1111";
        D1 <= "1010";
        D2 <= "0101";
        D3 <= "0011";
        Sel <= "00";
        wait for 10 ns;
        assert Y = "1111"
            report "Test 5 FAILED: Sel=00 should select updated D0"
            severity error;

        -- Test 6: Sel=01 with new data
        Sel <= "01";
        wait for 10 ns;
        assert Y = "1010"
            report "Test 6 FAILED: Sel=01 should select updated D1"
            severity error;

        report "All multiplexer_4to1 tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;

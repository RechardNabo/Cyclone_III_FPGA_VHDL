-- ============================================================================
-- Testbench for 8-Bit Barrel Shifter (Typical Combinational Components)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_barrel_shifter_tc is
end entity tb_barrel_shifter_tc;

architecture behavioral of tb_barrel_shifter_tc is
    signal Data_In  : std_logic_vector(7 downto 0);
    signal Shift_Amt: std_logic_vector(2 downto 0);
    signal Mode     : std_logic_vector(1 downto 0);
    signal Data_Out : std_logic_vector(7 downto 0);
begin
    -- Instantiate the DUT
    DUT : entity work.barrel_shifter
        port map (
            Data_In   => Data_In,
            Shift_Amt => Shift_Amt,
            Mode      => Mode,
            Data_Out  => Data_Out
        );

    -- Stimulus process
    process
    begin
        -- Test 1: Logical shift left by 1: 01010101 -> 10101010
        Data_In <= "01010101"; Shift_Amt <= "001"; Mode <= "00";
        wait for 10 ns;
        assert Data_Out = "10101010"
            report "Test 1 FAILED: LSL 01010101 by 1 should be 10101010"
            severity error;

        -- Test 2: Logical shift right by 4: 11110000 -> 00001111
        Data_In <= "11110000"; Shift_Amt <= "100"; Mode <= "01";
        wait for 10 ns;
        assert Data_Out = "00001111"
            report "Test 2 FAILED: LSR 11110000 by 4 should be 00001111"
            severity error;

        -- Test 3: Rotate left by 4: 11001100 -> 11001100 (rotate by half)
        Data_In <= "11001100"; Shift_Amt <= "100"; Mode <= "10";
        wait for 10 ns;
        assert Data_Out = "11001100"
            report "Test 3 FAILED: ROL 11001100 by 4 should be 11001100"
            severity error;

        -- Test 4: Rotate right by 1: 00000001 -> 10000000
        Data_In <= "00000001"; Shift_Amt <= "001"; Mode <= "11";
        wait for 10 ns;
        assert Data_Out = "10000000"
            report "Test 4 FAILED: ROR 00000001 by 1 should be 10000000"
            severity error;

        -- Test 5: Logical shift right by 0 (no shift): 10101010 -> 10101010
        Data_In <= "10101010"; Shift_Amt <= "000"; Mode <= "01";
        wait for 10 ns;
        assert Data_Out = "10101010"
            report "Test 5 FAILED: LSR by 0 should be unchanged"
            severity error;

        -- Test 6: Rotate left by 5: 00001111 -> 11100001
        Data_In <= "00001111"; Shift_Amt <= "101"; Mode <= "10";
        wait for 10 ns;
        assert Data_Out = "11100001"
            report "Test 6 FAILED: ROL 00001111 by 5 should be 11100001"
            severity error;

        report "All barrel_shifter_tc tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;

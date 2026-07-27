-- ============================================================================
-- Testbench for 8-Bit Barrel Shifter
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_barrel_shifter is
end entity tb_barrel_shifter;

architecture behavioral of tb_barrel_shifter is
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
        -- Test 1: Logical shift left by 2: 00001111 -> 00111100
        Data_In <= "00001111"; Shift_Amt <= "010"; Mode <= "00";
        wait for 10 ns;
        assert Data_Out = "00111100"
            report "Test 1 FAILED: LSL 00001111 by 2 should be 00111100"
            severity error;

        -- Test 2: Logical shift right by 3: 11110000 -> 00011110
        Data_In <= "11110000"; Shift_Amt <= "011"; Mode <= "01";
        wait for 10 ns;
        assert Data_Out = "00011110"
            report "Test 2 FAILED: LSR 11110000 by 3 should be 00011110"
            severity error;

        -- Test 3: Rotate left by 3: 10110001 -> 10001101
        Data_In <= "10110001"; Shift_Amt <= "011"; Mode <= "10";
        wait for 10 ns;
        assert Data_Out = "10001101"
            report "Test 3 FAILED: ROL 10110001 by 3 should be 10001101"
            severity error;

        -- Test 4: Rotate right by 2: 11000011 -> 11110000
        Data_In <= "11000011"; Shift_Amt <= "010"; Mode <= "11";
        wait for 10 ns;
        assert Data_Out = "11110000"
            report "Test 4 FAILED: ROR 11000011 by 2 should be 11110000"
            severity error;

        -- Test 5: Logical shift left by 0 (no shift): 10101010 -> 10101010
        Data_In <= "10101010"; Shift_Amt <= "000"; Mode <= "00";
        wait for 10 ns;
        assert Data_Out = "10101010"
            report "Test 5 FAILED: LSL by 0 should be unchanged"
            severity error;

        -- Test 6: Rotate left by 7: 00000001 -> 10000000
        Data_In <= "00000001"; Shift_Amt <= "111"; Mode <= "10";
        wait for 10 ns;
        assert Data_Out = "10000000"
            report "Test 6 FAILED: ROL 00000001 by 7 should be 10000000"
            severity error;

        report "All barrel_shifter tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;

-- ============================================================================
-- Testbench for Microprocessor ALU (8-bit)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_alu_mp is
end entity tb_alu_mp;

architecture behavioral of tb_alu_mp is
    signal a      : std_logic_vector(7 downto 0);
    signal b      : std_logic_vector(7 downto 0);
    signal op     : std_logic_vector(2 downto 0);
    signal result : std_logic_vector(7 downto 0);
    signal zero   : std_logic;
    signal carry  : std_logic;
begin
    -- Instantiate the DUT
    DUT : entity work.alu
        port map (
            a      => a,
            b      => b,
            op     => op,
            result => result,
            zero   => zero,
            carry  => carry
        );

    -- Stimulus process
    process
    begin
        -- Test 1: ADD 100 + 200 = 44 with carry=1
        a <= "01100100"; b <= "11001000"; op <= "000";
        wait for 10 ns;
        assert result = "00101100"
            report "Test 1 FAILED: 100+200 should be 44"
            severity error;
        assert carry = '1'
            report "Test 1 FAILED: 100+200 carry should be 1"
            severity error;
        assert zero = '0'
            report "Test 1 FAILED: 100+200 zero should be 0"
            severity error;

        -- Test 2: SUB 200 - 100 = 100, carry=0
        a <= "11001000"; b <= "01100100"; op <= "001";
        wait for 10 ns;
        assert result = "01100100"
            report "Test 2 FAILED: 200-100 should be 100"
            severity error;
        assert carry = '0'
            report "Test 2 FAILED: 200-100 carry should be 0"
            severity error;

        -- Test 3: AND 0xF0 AND 0x0F = 0x00, zero=1
        a <= "11110000"; b <= "00001111"; op <= "010";
        wait for 10 ns;
        assert result = "00000000"
            report "Test 3 FAILED: 0xF0 AND 0x0F should be 0x00"
            severity error;
        assert zero = '1'
            report "Test 3 FAILED: AND result zero should be 1"
            severity error;

        -- Test 4: OR 0xF0 OR 0x0F = 0xFF
        a <= "11110000"; b <= "00001111"; op <= "011";
        wait for 10 ns;
        assert result = "11111111"
            report "Test 4 FAILED: 0xF0 OR 0x0F should be 0xFF"
            severity error;

        -- Test 5: XOR 0xFF XOR 0x0F = 0xF0
        a <= "11111111"; b <= "00001111"; op <= "100";
        wait for 10 ns;
        assert result = "11110000"
            report "Test 5 FAILED: 0xFF XOR 0x0F should be 0xF0"
            severity error;

        -- Test 6: NOT 0x55 = 0xAA
        a <= "01010101"; b <= "00000000"; op <= "101";
        wait for 10 ns;
        assert result = "10101010"
            report "Test 6 FAILED: NOT 0x55 should be 0xAA"
            severity error;

        -- Test 7: LSL 0x81 by 1 = 0x02
        a <= "10000001"; b <= "00000000"; op <= "110";
        wait for 10 ns;
        assert result = "00000010"
            report "Test 7 FAILED: LSL 0x81 by 1 should be 0x02"
            severity error;

        -- Test 8: LSR 0x81 by 1 = 0x40
        a <= "10000001"; b <= "00000000"; op <= "111";
        wait for 10 ns;
        assert result = "01000000"
            report "Test 8 FAILED: LSR 0x81 by 1 should be 0x40"
            severity error;

        report "All microprocessor alu tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;

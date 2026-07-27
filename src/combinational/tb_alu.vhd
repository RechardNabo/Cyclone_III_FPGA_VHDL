-- ============================================================================
-- Testbench for 4-Bit ALU
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_alu is
end entity tb_alu;

architecture behavioral of tb_alu is
    signal A      : std_logic_vector(3 downto 0);
    signal B      : std_logic_vector(3 downto 0);
    signal Op     : std_logic_vector(2 downto 0);
    signal Result : std_logic_vector(3 downto 0);
    signal Zero   : std_logic;
begin
    -- Instantiate the DUT
    DUT : entity work.alu
        port map (
            A      => A,
            B      => B,
            Op     => Op,
            Result => Result,
            Zero   => Zero
        );

    -- Stimulus process
    process
    begin
        -- Test 1: ADD 5 + 3 = 8, Zero=0
        A <= "0101"; B <= "0011"; Op <= "000";
        wait for 10 ns;
        assert Result = "1000"
            report "Test 1 FAILED: 5+3 should be 8"
            severity error;
        assert Zero = '0'
            report "Test 1 FAILED: 5+3 Zero should be 0"
            severity error;

        -- Test 2: SUB 3 - 5 = 14 (two's complement), Zero=0
        A <= "0011"; B <= "0101"; Op <= "001";
        wait for 10 ns;
        assert Result = "1110"
            report "Test 2 FAILED: 3-5 should be 14 (two's complement)"
            severity error;
        assert Zero = '0'
            report "Test 2 FAILED: 3-5 Zero should be 0"
            severity error;

        -- Test 3: AND 1100 AND 1010 = 1000
        A <= "1100"; B <= "1010"; Op <= "010";
        wait for 10 ns;
        assert Result = "1000"
            report "Test 3 FAILED: 1100 AND 1010 should be 1000"
            severity error;

        -- Test 4: OR 1100 OR 1010 = 1110
        A <= "1100"; B <= "1010"; Op <= "011";
        wait for 10 ns;
        assert Result = "1110"
            report "Test 4 FAILED: 1100 OR 1010 should be 1110"
            severity error;

        -- Test 5: XOR 1100 XOR 1010 = 0110
        A <= "1100"; B <= "1010"; Op <= "100";
        wait for 10 ns;
        assert Result = "0110"
            report "Test 5 FAILED: 1100 XOR 1010 should be 0110"
            severity error;

        -- Test 6: NOT 1010 = 0101
        A <= "1010"; B <= "0000"; Op <= "101";
        wait for 10 ns;
        assert Result = "0101"
            report "Test 6 FAILED: NOT 1010 should be 0101"
            severity error;

        -- Test 7: SHL 0001 by 1 = 0010
        A <= "0001"; B <= "0000"; Op <= "110";
        wait for 10 ns;
        assert Result = "0010"
            report "Test 7 FAILED: SHL 0001 by 1 should be 0010"
            severity error;

        -- Test 8: SHR 1000 by 1 = 0100
        A <= "1000"; B <= "0000"; Op <= "111";
        wait for 10 ns;
        assert Result = "0100"
            report "Test 8 FAILED: SHR 1000 by 1 should be 0100"
            severity error;

        -- Test 9: SUB 5 - 5 = 0, Zero=1
        A <= "0101"; B <= "0101"; Op <= "001";
        wait for 10 ns;
        assert Result = "0000"
            report "Test 9 FAILED: 5-5 should be 0"
            severity error;
        assert Zero = '1'
            report "Test 9 FAILED: 5-5 Zero should be 1"
            severity error;

        report "All alu tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;

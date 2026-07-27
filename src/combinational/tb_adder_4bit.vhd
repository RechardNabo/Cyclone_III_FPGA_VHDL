-- ============================================================================
-- Testbench for 4-Bit Ripple Carry Adder
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_adder_4bit is
end entity tb_adder_4bit;

architecture behavioral of tb_adder_4bit is
    signal A    : std_logic_vector(3 downto 0);
    signal B    : std_logic_vector(3 downto 0);
    signal Cin  : std_logic;
    signal Sum  : std_logic_vector(3 downto 0);
    signal Cout : std_logic;
begin
    -- Instantiate the DUT
    DUT : entity work.adder_4bit
        port map (
            A    => A,
            B    => B,
            Cin  => Cin,
            Sum  => Sum,
            Cout => Cout
        );

    -- Stimulus process
    process
        variable exp : unsigned(4 downto 0);
    begin
        -- Test 1: 0 + 0 + 0 = 0, Cout=0
        A <= "0000"; B <= "0000"; Cin <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) + ('0' & unsigned(B)) + ("0000" & Cin);
        assert Sum = std_logic_vector(exp(3 downto 0))
            report "Test 1 FAILED: 0+0 sum mismatch"
            severity error;
        assert Cout = exp(4)
            report "Test 1 FAILED: 0+0 cout mismatch"
            severity error;

        -- Test 2: 15 + 1 + 0 = 0, Cout=1
        A <= "1111"; B <= "0001"; Cin <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) + ('0' & unsigned(B)) + ("0000" & Cin);
        assert Sum = std_logic_vector(exp(3 downto 0))
            report "Test 2 FAILED: 15+1 sum mismatch"
            severity error;
        assert Cout = exp(4)
            report "Test 2 FAILED: 15+1 cout mismatch"
            severity error;

        -- Test 3: 7 + 8 + 0 = 15, Cout=0
        A <= "0111"; B <= "1000"; Cin <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) + ('0' & unsigned(B)) + ("0000" & Cin);
        assert Sum = std_logic_vector(exp(3 downto 0))
            report "Test 3 FAILED: 7+8 sum mismatch"
            severity error;
        assert Cout = exp(4)
            report "Test 3 FAILED: 7+8 cout mismatch"
            severity error;

        -- Test 4: 15 + 15 + 1 = 15, Cout=1
        A <= "1111"; B <= "1111"; Cin <= '1';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) + ('0' & unsigned(B)) + ("0000" & Cin);
        assert Sum = std_logic_vector(exp(3 downto 0))
            report "Test 4 FAILED: 15+15+1 sum mismatch"
            severity error;
        assert Cout = exp(4)
            report "Test 4 FAILED: 15+15+1 cout mismatch"
            severity error;

        -- Test 5: 5 + 10 + 0 = 15, Cout=0
        A <= "0101"; B <= "1010"; Cin <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) + ('0' & unsigned(B)) + ("0000" & Cin);
        assert Sum = std_logic_vector(exp(3 downto 0))
            report "Test 5 FAILED: 5+10 sum mismatch"
            severity error;
        assert Cout = exp(4)
            report "Test 5 FAILED: 5+10 cout mismatch"
            severity error;

        -- Test 6: 9 + 9 + 0 = 2, Cout=1
        A <= "1001"; B <= "1001"; Cin <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) + ('0' & unsigned(B)) + ("0000" & Cin);
        assert Sum = std_logic_vector(exp(3 downto 0))
            report "Test 6 FAILED: 9+9 sum mismatch"
            severity error;
        assert Cout = exp(4)
            report "Test 6 FAILED: 9+9 cout mismatch"
            severity error;

        report "All adder_4bit tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;

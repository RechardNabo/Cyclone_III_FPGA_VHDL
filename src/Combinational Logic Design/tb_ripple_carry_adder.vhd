-- ============================================================================
-- Testbench for 8-Bit Ripple Carry Adder
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_ripple_carry_adder is
end entity tb_ripple_carry_adder;

architecture behavioral of tb_ripple_carry_adder is
    signal A    : std_logic_vector(7 downto 0);
    signal B    : std_logic_vector(7 downto 0);
    signal Cin  : std_logic;
    signal Sum  : std_logic_vector(7 downto 0);
    signal Cout : std_logic;

    -- Expected results
    signal exp_sum  : std_logic_vector(8 downto 0);
begin
    -- Instantiate the DUT
    DUT : entity work.ripple_carry_adder
        port map (
            A    => A,
            B    => B,
            Cin  => Cin,
            Sum  => Sum,
            Cout => Cout
        );

    -- Stimulus process
    process
        variable exp : unsigned(8 downto 0);
    begin
        -- Test 1: 0 + 0 + 0 = 0, Cout=0
        A <= "00000000"; B <= "00000000"; Cin <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) + ('0' & unsigned(B)) + ("00000000" & Cin);
        assert Sum = std_logic_vector(exp(7 downto 0))
            report "Test 1 FAILED: 0+0 sum mismatch"
            severity error;
        assert Cout = exp(8)
            report "Test 1 FAILED: 0+0 cout mismatch"
            severity error;

        -- Test 2: 255 + 1 + 0 = 0 with Cout=1
        A <= "11111111"; B <= "00000001"; Cin <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) + ('0' & unsigned(B)) + ("00000000" & Cin);
        assert Sum = std_logic_vector(exp(7 downto 0))
            report "Test 2 FAILED: 255+1 sum mismatch"
            severity error;
        assert Cout = exp(8)
            report "Test 2 FAILED: 255+1 cout mismatch"
            severity error;

        -- Test 3: 100 + 200 + 0 = 44 with Cout=1
        A <= "01100100"; B <= "11001000"; Cin <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) + ('0' & unsigned(B)) + ("00000000" & Cin);
        assert Sum = std_logic_vector(exp(7 downto 0))
            report "Test 3 FAILED: 100+200 sum mismatch"
            severity error;
        assert Cout = exp(8)
            report "Test 3 FAILED: 100+200 cout mismatch"
            severity error;

        -- Test 4: 127 + 128 + 0 = 255 with Cout=0
        A <= "01111111"; B <= "10000000"; Cin <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) + ('0' & unsigned(B)) + ("00000000" & Cin);
        assert Sum = std_logic_vector(exp(7 downto 0))
            report "Test 4 FAILED: 127+128 sum mismatch"
            severity error;
        assert Cout = exp(8)
            report "Test 4 FAILED: 127+128 cout mismatch"
            severity error;

        -- Test 5: 255 + 255 + 1 = 255 with Cout=1
        A <= "11111111"; B <= "11111111"; Cin <= '1';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) + ('0' & unsigned(B)) + ("00000000" & Cin);
        assert Sum = std_logic_vector(exp(7 downto 0))
            report "Test 5 FAILED: 255+255+1 sum mismatch"
            severity error;
        assert Cout = exp(8)
            report "Test 5 FAILED: 255+255+1 cout mismatch"
            severity error;

        -- Test 6: 85 + 170 + 0 = 255 with Cout=0
        A <= "01010101"; B <= "10101010"; Cin <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) + ('0' & unsigned(B)) + ("00000000" & Cin);
        assert Sum = std_logic_vector(exp(7 downto 0))
            report "Test 6 FAILED: 85+170 sum mismatch"
            severity error;
        assert Cout = exp(8)
            report "Test 6 FAILED: 85+170 cout mismatch"
            severity error;

        report "All ripple_carry_adder tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;

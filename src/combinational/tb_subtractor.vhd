-- ============================================================================
-- Testbench for 4-Bit Subtractor with Borrow
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_subtractor is
end entity tb_subtractor;

architecture behavioral of tb_subtractor is
    signal A          : std_logic_vector(3 downto 0);
    signal B          : std_logic_vector(3 downto 0);
    signal Borrow_In  : std_logic;
    signal Difference : std_logic_vector(3 downto 0);
    signal Borrow_Out : std_logic;
begin
    -- Instantiate the DUT
    DUT : entity work.subtractor
        port map (
            A          => A,
            B          => B,
            Borrow_In  => Borrow_In,
            Difference => Difference,
            Borrow_Out => Borrow_Out
        );

    -- Stimulus process
    process
        variable exp : unsigned(4 downto 0);
    begin
        -- Test 1: 9 - 3 - 0 = 6, no borrow
        A <= "1001"; B <= "0011"; Borrow_In <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) - ('0' & unsigned(B)) - ("0000" & Borrow_In);
        assert Difference = std_logic_vector(exp(3 downto 0))
            report "Test 1 FAILED: 9-3 diff mismatch"
            severity error;
        assert Borrow_Out = exp(4)
            report "Test 1 FAILED: 9-3 borrow mismatch"
            severity error;

        -- Test 2: 3 - 9 - 0 = 10 with borrow (underflow)
        A <= "0011"; B <= "1001"; Borrow_In <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) - ('0' & unsigned(B)) - ("0000" & Borrow_In);
        assert Difference = std_logic_vector(exp(3 downto 0))
            report "Test 2 FAILED: 3-9 diff mismatch"
            severity error;
        assert Borrow_Out = exp(4)
            report "Test 2 FAILED: 3-9 borrow mismatch"
            severity error;

        -- Test 3: 15 - 15 - 0 = 0, no borrow
        A <= "1111"; B <= "1111"; Borrow_In <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) - ('0' & unsigned(B)) - ("0000" & Borrow_In);
        assert Difference = std_logic_vector(exp(3 downto 0))
            report "Test 3 FAILED: 15-15 diff mismatch"
            severity error;
        assert Borrow_Out = exp(4)
            report "Test 3 FAILED: 15-15 borrow mismatch"
            severity error;

        -- Test 4: 0 - 0 - 1 = 15 with borrow
        A <= "0000"; B <= "0000"; Borrow_In <= '1';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) - ('0' & unsigned(B)) - ("0000" & Borrow_In);
        assert Difference = std_logic_vector(exp(3 downto 0))
            report "Test 4 FAILED: 0-0-1 diff mismatch"
            severity error;
        assert Borrow_Out = exp(4)
            report "Test 4 FAILED: 0-0-1 borrow mismatch"
            severity error;

        -- Test 5: 8 - 4 - 0 = 4, no borrow
        A <= "1000"; B <= "0100"; Borrow_In <= '0';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) - ('0' & unsigned(B)) - ("0000" & Borrow_In);
        assert Difference = std_logic_vector(exp(3 downto 0))
            report "Test 5 FAILED: 8-4 diff mismatch"
            severity error;
        assert Borrow_Out = exp(4)
            report "Test 5 FAILED: 8-4 borrow mismatch"
            severity error;

        -- Test 6: 5 - 5 - 1 = 15 with borrow
        A <= "0101"; B <= "0101"; Borrow_In <= '1';
        wait for 10 ns;
        exp := ('0' & unsigned(A)) - ('0' & unsigned(B)) - ("0000" & Borrow_In);
        assert Difference = std_logic_vector(exp(3 downto 0))
            report "Test 6 FAILED: 5-5-1 diff mismatch"
            severity error;
        assert Borrow_Out = exp(4)
            report "Test 6 FAILED: 5-5-1 borrow mismatch"
            severity error;

        report "All subtractor tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;

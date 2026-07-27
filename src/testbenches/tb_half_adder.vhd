library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_half_adder is
end entity tb_half_adder;

architecture sim of tb_half_adder is
    signal A, B   : std_logic := '0';
    signal sum    : std_logic;
    signal carry  : std_logic;
begin
    dut : entity work.half_adder
        port map (A => A, B => B, sum => sum, carry => carry);

    stim : process
    begin
        -- Test 0+0
        A <= '0'; B <= '0';
        wait for 20 ns;
        assert sum = '0' report "FAIL: sum 0+0" severity error;
        assert carry = '0' report "FAIL: carry 0+0" severity error;

        -- Test 0+1
        A <= '0'; B <= '1';
        wait for 20 ns;
        assert sum = '1' report "FAIL: sum 0+1" severity error;
        assert carry = '0' report "FAIL: carry 0+1" severity error;

        -- Test 1+0
        A <= '1'; B <= '0';
        wait for 20 ns;
        assert sum = '1' report "FAIL: sum 1+0" severity error;
        assert carry = '0' report "FAIL: carry 1+0" severity error;

        -- Test 1+1
        A <= '1'; B <= '1';
        wait for 20 ns;
        assert sum = '0' report "FAIL: sum 1+1" severity error;
        assert carry = '1' report "FAIL: carry 1+1" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

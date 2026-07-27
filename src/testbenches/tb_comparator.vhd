library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_comparator is
end entity tb_comparator;

architecture sim of tb_comparator is
    signal A, B : std_logic_vector(7 downto 0) := (others => '0');
    signal Greater, Equal, Less : std_logic;
begin
    dut : entity work.comparator
        port map (
            A => A, B => B,
            Greater => Greater, Equal => Equal, Less => Less
        );

    stim : process
    begin
        -- Test A > B
        A <= x"FF"; B <= x"00";
        wait for 20 ns;
        assert Greater = '1' report "FAIL: A>B greater" severity error;
        assert Equal   = '0' report "FAIL: A>B equal" severity error;
        assert Less    = '0' report "FAIL: A>B less" severity error;

        -- Test A = B
        A <= x"55"; B <= x"55";
        wait for 20 ns;
        assert Greater = '0' report "FAIL: A=B greater" severity error;
        assert Equal   = '1' report "FAIL: A=B equal" severity error;
        assert Less    = '0' report "FAIL: A=B less" severity error;

        -- Test A < B
        A <= x"01"; B <= x"02";
        wait for 20 ns;
        assert Greater = '0' report "FAIL: A<B greater" severity error;
        assert Equal   = '0' report "FAIL: A<B equal" severity error;
        assert Less    = '1' report "FAIL: A<B less" severity error;

        -- Test A = B = 0
        A <= x"00"; B <= x"00";
        wait for 20 ns;
        assert Equal = '1' report "FAIL: 0=0 equal" severity error;

        -- Test A = B = max
        A <= x"FF"; B <= x"FF";
        wait for 20 ns;
        assert Equal = '1' report "FAIL: FF=FF equal" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

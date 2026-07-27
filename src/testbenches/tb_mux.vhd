library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_mux is
end entity tb_mux;

architecture sim of tb_mux is
    signal D0, D1, D2, D3 : std_logic_vector(7 downto 0) := (others => '0');
    signal S              : std_logic_vector(1 downto 0) := "00";
    signal Y              : std_logic_vector(7 downto 0);
begin
    dut : entity work.mux_4to1
        generic map (WIDTH => 8)
        port map (D0 => D0, D1 => D1, D2 => D2, D3 => D3, S => S, Y => Y);

    stim : process
    begin
        D0 <= x"11"; D1 <= x"22"; D2 <= x"33"; D3 <= x"44";

        -- Select D0
        S <= "00";
        wait for 20 ns;
        assert Y = x"11" report "FAIL: Y should be D0" severity error;

        -- Select D1
        S <= "01";
        wait for 20 ns;
        assert Y = x"22" report "FAIL: Y should be D1" severity error;

        -- Select D2
        S <= "10";
        wait for 20 ns;
        assert Y = x"33" report "FAIL: Y should be D2" severity error;

        -- Select D3
        S <= "11";
        wait for 20 ns;
        assert Y = x"44" report "FAIL: Y should be D3" severity error;

        -- Change inputs and re-verify D0
        D0 <= x"AA"; D1 <= x"BB"; D2 <= x"CC"; D3 <= x"DD";
        S <= "00";
        wait for 20 ns;
        assert Y = x"AA" report "FAIL: Y should be new D0" severity error;

        S <= "11";
        wait for 20 ns;
        assert Y = x"DD" report "FAIL: Y should be new D3" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

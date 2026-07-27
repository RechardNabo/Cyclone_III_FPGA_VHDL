library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_basic_logic is
end entity tb_basic_logic;

architecture sim of tb_basic_logic is
    signal A, B, CIN, SEL : std_logic := '0';
    signal D0, D1 : std_logic_vector(3 downto 0) := (others => '0');
    signal Y_AND, Y_OR, Y_NOT, Y_XOR : std_logic;
    signal HA_SUM, HA_CRY, FA_SUM, FA_COUT : std_logic;
    signal Y_MUX : std_logic_vector(3 downto 0);
begin
    dut : entity work.Basic_Logic_Top
        port map (
            A => A, B => B, CIN => CIN,
            D0 => D0, D1 => D1, SEL => SEL,
            Y_AND => Y_AND, Y_OR => Y_OR, Y_NOT => Y_NOT, Y_XOR => Y_XOR,
            HA_SUM => HA_SUM, HA_CRY => HA_CRY,
            FA_SUM => FA_SUM, FA_COUT => FA_COUT,
            Y_MUX => Y_MUX
        );

    stim : process
    begin
        -- Test 1: A=0, B=0
        A <= '0'; B <= '0'; CIN <= '0'; SEL <= '0';
        D0 <= "1010"; D1 <= "0101";
        wait for 20 ns;
        assert Y_AND = '0' report "FAIL: AND 0,0" severity error;
        assert Y_OR  = '0' report "FAIL: OR 0,0" severity error;
        assert Y_NOT = '1' report "FAIL: NOT 0" severity error;
        assert Y_XOR = '0' report "FAIL: XOR 0,0" severity error;
        assert HA_SUM = '0' and HA_CRY = '0' report "FAIL: HA 0,0" severity error;
        assert FA_SUM = '0' and FA_COUT = '0' report "FAIL: FA 0,0,0" severity error;
        assert Y_MUX = "1010" report "FAIL: MUX sel=0" severity error;

        -- Test 2: A=1, B=0
        A <= '1'; B <= '0'; CIN <= '0'; SEL <= '1';
        wait for 20 ns;
        assert Y_AND = '0' report "FAIL: AND 1,0" severity error;
        assert Y_OR  = '1' report "FAIL: OR 1,0" severity error;
        assert Y_NOT = '0' report "FAIL: NOT 1" severity error;
        assert Y_XOR = '1' report "FAIL: XOR 1,0" severity error;
        assert HA_SUM = '1' and HA_CRY = '0' report "FAIL: HA 1,0" severity error;
        assert FA_SUM = '1' and FA_COUT = '0' report "FAIL: FA 1,0,0" severity error;
        assert Y_MUX = "0101" report "FAIL: MUX sel=1" severity error;

        -- Test 3: A=1, B=1, CIN=1
        A <= '1'; B <= '1'; CIN <= '1';
        wait for 20 ns;
        assert Y_AND = '1' report "FAIL: AND 1,1" severity error;
        assert Y_OR  = '1' report "FAIL: OR 1,1" severity error;
        assert Y_XOR = '0' report "FAIL: XOR 1,1" severity error;
        assert HA_SUM = '0' and HA_CRY = '1' report "FAIL: HA 1,1" severity error;
        assert FA_SUM = '1' and FA_COUT = '1' report "FAIL: FA 1,1,1" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

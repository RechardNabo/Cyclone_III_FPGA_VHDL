-- Testbench for Basic_Logic_Top
-- Tests all A/B input combinations, full-adder carry-in,
-- and 2-to-1 mux select for the top-level basic logic module.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_basic_logic_top is
end entity tb_basic_logic_top;

architecture behavior of tb_basic_logic_top is
    -- DUT signals
    signal A       : std_logic;
    signal B       : std_logic;
    signal CIN     : std_logic;
    signal D0      : std_logic_vector(3 downto 0);
    signal D1      : std_logic_vector(3 downto 0);
    signal SEL     : std_logic;
    signal Y_AND   : std_logic;
    signal Y_OR    : std_logic;
    signal Y_NOT   : std_logic;
    signal Y_XOR   : std_logic;
    signal HA_SUM  : std_logic;
    signal HA_CRY  : std_logic;
    signal FA_SUM  : std_logic;
    signal FA_COUT : std_logic;
    signal Y_MUX   : std_logic_vector(3 downto 0);

    -- Component declaration
    component Basic_Logic_Top is
        port (
            A       : in  std_logic;
            B       : in  std_logic;
            CIN     : in  std_logic;
            D0      : in  std_logic_vector(3 downto 0);
            D1      : in  std_logic_vector(3 downto 0);
            SEL     : in  std_logic;
            Y_AND   : out std_logic;
            Y_OR    : out std_logic;
            Y_NOT   : out std_logic;
            Y_XOR   : out std_logic;
            HA_SUM  : out std_logic;
            HA_CRY  : out std_logic;
            FA_SUM  : out std_logic;
            FA_COUT : out std_logic;
            Y_MUX   : out std_logic_vector(3 downto 0)
        );
    end component Basic_Logic_Top;

begin
    -- Instantiate the DUT
    dut : Basic_Logic_Top
        port map (
            A       => A,
            B       => B,
            CIN     => CIN,
            D0      => D0,
            D1      => D1,
            SEL     => SEL,
            Y_AND   => Y_AND,
            Y_OR    => Y_OR,
            Y_NOT   => Y_NOT,
            Y_XOR   => Y_XOR,
            HA_SUM  => HA_SUM,
            HA_CRY  => HA_CRY,
            FA_SUM  => FA_SUM,
            FA_COUT => FA_COUT,
            Y_MUX   => Y_MUX
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- Set mux inputs to known values for all tests
        D0 <= "0101";
        D1 <= "1010";

        -- ---------------------------------------------------------------
        -- Test 1: A=0, B=0, CIN=0
        -- ---------------------------------------------------------------
        A <= '0'; B <= '0'; CIN <= '0'; SEL <= '0';
        wait for 10 ns;
        assert Y_AND = '0'   report "Test 1 FAIL: Y_AND expected 0"   severity error;
        assert Y_OR  = '0'   report "Test 1 FAIL: Y_OR expected 0"    severity error;
        assert Y_NOT = '1'   report "Test 1 FAIL: Y_NOT expected 1"   severity error;
        assert Y_XOR = '0'   report "Test 1 FAIL: Y_XOR expected 0"   severity error;
        assert HA_SUM = '0'  report "Test 1 FAIL: HA_SUM expected 0"  severity error;
        assert HA_CRY = '0'  report "Test 1 FAIL: HA_CRY expected 0"  severity error;
        assert FA_SUM = '0'  report "Test 1 FAIL: FA_SUM expected 0"  severity error;
        assert FA_COUT = '0' report "Test 1 FAIL: FA_COUT expected 0" severity error;
        assert Y_MUX = "0101" report "Test 1 FAIL: Y_MUX expected 0101 (SEL=0)" severity error;
        report "Test 1 PASS: A=0 B=0 CIN=0 SEL=0" severity note;

        -- ---------------------------------------------------------------
        -- Test 2: A=0, B=1, CIN=0
        -- ---------------------------------------------------------------
        A <= '0'; B <= '1'; CIN <= '0'; SEL <= '1';
        wait for 10 ns;
        assert Y_AND = '0'   report "Test 2 FAIL: Y_AND expected 0"   severity error;
        assert Y_OR  = '1'   report "Test 2 FAIL: Y_OR expected 1"    severity error;
        assert Y_NOT = '1'   report "Test 2 FAIL: Y_NOT expected 1"   severity error;
        assert Y_XOR = '1'   report "Test 2 FAIL: Y_XOR expected 1"   severity error;
        assert HA_SUM = '1'  report "Test 2 FAIL: HA_SUM expected 1"  severity error;
        assert HA_CRY = '0'  report "Test 2 FAIL: HA_CRY expected 0"  severity error;
        assert FA_SUM = '1'  report "Test 2 FAIL: FA_SUM expected 1"  severity error;
        assert FA_COUT = '0' report "Test 2 FAIL: FA_COUT expected 0" severity error;
        assert Y_MUX = "1010" report "Test 2 FAIL: Y_MUX expected 1010 (SEL=1)" severity error;
        report "Test 2 PASS: A=0 B=1 CIN=0 SEL=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 3: A=1, B=0, CIN=0
        -- ---------------------------------------------------------------
        A <= '1'; B <= '0'; CIN <= '0'; SEL <= '0';
        wait for 10 ns;
        assert Y_AND = '0'   report "Test 3 FAIL: Y_AND expected 0"   severity error;
        assert Y_OR  = '1'   report "Test 3 FAIL: Y_OR expected 1"    severity error;
        assert Y_NOT = '0'   report "Test 3 FAIL: Y_NOT expected 0"   severity error;
        assert Y_XOR = '1'   report "Test 3 FAIL: Y_XOR expected 1"   severity error;
        assert HA_SUM = '1'  report "Test 3 FAIL: HA_SUM expected 1"  severity error;
        assert HA_CRY = '0'  report "Test 3 FAIL: HA_CRY expected 0"  severity error;
        assert FA_SUM = '1'  report "Test 3 FAIL: FA_SUM expected 1"  severity error;
        assert FA_COUT = '0' report "Test 3 FAIL: FA_COUT expected 0" severity error;
        assert Y_MUX = "0101" report "Test 3 FAIL: Y_MUX expected 0101 (SEL=0)" severity error;
        report "Test 3 PASS: A=1 B=0 CIN=0 SEL=0" severity note;

        -- ---------------------------------------------------------------
        -- Test 4: A=1, B=1, CIN=0
        -- ---------------------------------------------------------------
        A <= '1'; B <= '1'; CIN <= '0'; SEL <= '1';
        wait for 10 ns;
        assert Y_AND = '1'   report "Test 4 FAIL: Y_AND expected 1"   severity error;
        assert Y_OR  = '1'   report "Test 4 FAIL: Y_OR expected 1"    severity error;
        assert Y_NOT = '0'   report "Test 4 FAIL: Y_NOT expected 0"   severity error;
        assert Y_XOR = '0'   report "Test 4 FAIL: Y_XOR expected 0"   severity error;
        assert HA_SUM = '0'  report "Test 4 FAIL: HA_SUM expected 0"  severity error;
        assert HA_CRY = '1'  report "Test 4 FAIL: HA_CRY expected 1"  severity error;
        assert FA_SUM = '0'  report "Test 4 FAIL: FA_SUM expected 0"  severity error;
        assert FA_COUT = '1' report "Test 4 FAIL: FA_COUT expected 1" severity error;
        assert Y_MUX = "1010" report "Test 4 FAIL: Y_MUX expected 1010 (SEL=1)" severity error;
        report "Test 4 PASS: A=1 B=1 CIN=0 SEL=1" severity note;

        -- ---------------------------------------------------------------
        -- Test 5: A=1, B=1, CIN=1 (full adder carry chain)
        -- ---------------------------------------------------------------
        A <= '1'; B <= '1'; CIN <= '1'; SEL <= '0';
        wait for 10 ns;
        assert FA_SUM = '1'  report "Test 5 FAIL: FA_SUM expected 1"  severity error;
        assert FA_COUT = '1' report "Test 5 FAIL: FA_COUT expected 1" severity error;
        report "Test 5 PASS: A=1 B=1 CIN=1 full adder" severity note;

        -- ---------------------------------------------------------------
        -- Test 6: A=0, B=0, CIN=1 (full adder with carry-in only)
        -- ---------------------------------------------------------------
        A <= '0'; B <= '0'; CIN <= '1'; SEL <= '1';
        wait for 10 ns;
        assert FA_SUM = '1'  report "Test 6 FAIL: FA_SUM expected 1"  severity error;
        assert FA_COUT = '0' report "Test 6 FAIL: FA_COUT expected 0" severity error;
        report "Test 6 PASS: A=0 B=0 CIN=1 full adder" severity note;

        -- ---------------------------------------------------------------
        -- Test 7: A=0, B=1, CIN=1 (full adder sum=0, carry=1)
        -- ---------------------------------------------------------------
        A <= '0'; B <= '1'; CIN <= '1'; SEL <= '0';
        wait for 10 ns;
        assert FA_SUM = '0'  report "Test 7 FAIL: FA_SUM expected 0"  severity error;
        assert FA_COUT = '1' report "Test 7 FAIL: FA_COUT expected 1" severity error;
        report "Test 7 PASS: A=0 B=1 CIN=1 full adder" severity note;

        report "All Basic_Logic_Top tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;

-- Testbench for 32-bit ALU
-- Tests multiple operations: ADD, SUB, AND, OR, XOR, NOT, SLL, SRL, SRA,
--                            ROL, ROR, CMP, INC, DEC, MUL, PASS
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_alu_32bit is
end entity tb_alu_32bit;

architecture test of tb_alu_32bit is

    constant OP_ADD  : std_logic_vector(3 downto 0) := "0000";
    constant OP_SUB  : std_logic_vector(3 downto 0) := "0001";
    constant OP_AND  : std_logic_vector(3 downto 0) := "0010";
    constant OP_OR   : std_logic_vector(3 downto 0) := "0011";
    constant OP_XOR  : std_logic_vector(3 downto 0) := "0100";
    constant OP_NOT  : std_logic_vector(3 downto 0) := "0101";
    constant OP_SLL  : std_logic_vector(3 downto 0) := "0110";
    constant OP_SRL  : std_logic_vector(3 downto 0) := "0111";
    constant OP_SRA  : std_logic_vector(3 downto 0) := "1000";
    constant OP_ROL  : std_logic_vector(3 downto 0) := "1001";
    constant OP_ROR  : std_logic_vector(3 downto 0) := "1010";
    constant OP_CMP  : std_logic_vector(3 downto 0) := "1011";
    constant OP_INC  : std_logic_vector(3 downto 0) := "1100";
    constant OP_DEC  : std_logic_vector(3 downto 0) := "1101";
    constant OP_MUL  : std_logic_vector(3 downto 0) := "1110";
    constant OP_PASS : std_logic_vector(3 downto 0) := "1111";

    signal a        : std_logic_vector(31 downto 0) := (others => '0');
    signal b        : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_op   : std_logic_vector(3 downto 0) := (others => '0');
    signal result   : std_logic_vector(31 downto 0);
    signal zero     : std_logic;
    signal carry    : std_logic;
    signal overflow : std_logic;
    signal negative : std_logic;
    signal parity   : std_logic;

begin

    dut : entity work.alu_32bit
        port map (
            a        => a,
            b        => b,
            alu_op   => alu_op,
            result   => result,
            zero     => zero,
            carry    => carry,
            overflow => overflow,
            negative => negative,
            parity   => parity
        );

    stim_proc : process
    begin

        -- Test 1: ADD  0x00000005 + 0x00000003 = 0x00000008
        a      <= x"00000005";
        b      <= x"00000003";
        alu_op <= OP_ADD;
        wait for 10 ns;
        assert result = x"00000008"
            report "ADD test failed: expected 0x00000008" severity error;
        assert carry = '0'
            report "ADD carry test failed: expected 0" severity error;

        -- Test 2: SUB  0x0000000A - 0x00000003 = 0x00000007
        a      <= x"0000000A";
        b      <= x"00000003";
        alu_op <= OP_SUB;
        wait for 10 ns;
        assert result = x"00000007"
            report "SUB test failed: expected 0x00000007" severity error;

        -- Test 3: AND  0xFFFF0000 AND 0x0000FFFF = 0x00000000
        a      <= x"FFFF0000";
        b      <= x"0000FFFF";
        alu_op <= OP_AND;
        wait for 10 ns;
        assert result = x"00000000"
            report "AND test failed: expected 0x00000000" severity error;
        assert zero = '1'
            report "AND zero flag failed: expected 1" severity error;

        -- Test 4: OR  0xFFFF0000 OR 0x0000FFFF = 0xFFFFFFFF
        a      <= x"FFFF0000";
        b      <= x"0000FFFF";
        alu_op <= OP_OR;
        wait for 10 ns;
        assert result = x"FFFFFFFF"
            report "OR test failed: expected 0xFFFFFFFF" severity error;

        -- Test 5: XOR  0xFFFFFFFF XOR 0x000000FF = 0xFFFFFF00
        a      <= x"FFFFFFFF";
        b      <= x"000000FF";
        alu_op <= OP_XOR;
        wait for 10 ns;
        assert result = x"FFFFFF00"
            report "XOR test failed: expected 0xFFFFFF00" severity error;

        -- Test 6: NOT  NOT 0x00000000 = 0xFFFFFFFF
        a      <= x"00000000";
        alu_op <= OP_NOT;
        wait for 10 ns;
        assert result = x"FFFFFFFF"
            report "NOT test failed: expected 0xFFFFFFFF" severity error;

        -- Test 7: SLL  0x00000001 << 1 = 0x00000002
        a      <= x"00000001";
        alu_op <= OP_SLL;
        wait for 10 ns;
        assert result = x"00000002"
            report "SLL test failed: expected 0x00000002" severity error;

        -- Test 8: SRL  0x80000000 >> 1 = 0x40000000
        a      <= x"80000000";
        alu_op <= OP_SRL;
        wait for 10 ns;
        assert result = x"40000000"
            report "SRL test failed: expected 0x40000000" severity error;

        -- Test 9: SRA  0x80000000 >> 1 (arith) = 0xC0000000
        a      <= x"80000000";
        alu_op <= OP_SRA;
        wait for 10 ns;
        assert result = x"C0000000"
            report "SRA test failed: expected 0xC0000000" severity error;

        -- Test 10: ROL  0x80000000 rotate left = 0x00000001
        a      <= x"80000000";
        alu_op <= OP_ROL;
        wait for 10 ns;
        assert result = x"00000001"
            report "ROL test failed: expected 0x00000001" severity error;

        -- Test 11: ROR  0x00000001 rotate right = 0x80000000
        a      <= x"00000001";
        alu_op <= OP_ROR;
        wait for 10 ns;
        assert result = x"80000000"
            report "ROR test failed: expected 0x80000000" severity error;

        -- Test 12: CMP  0x00000100 - 0x00000100 = 0x00000000, zero=1
        a      <= x"00000100";
        b      <= x"00000100";
        alu_op <= OP_CMP;
        wait for 10 ns;
        assert result = x"00000000"
            report "CMP test failed: expected 0x00000000" severity error;
        assert zero = '1'
            report "CMP zero flag failed: expected 1" severity error;

        -- Test 13: INC  0xFFFFFFFF + 1 = 0x00000000, carry=1
        a      <= x"FFFFFFFF";
        alu_op <= OP_INC;
        wait for 10 ns;
        assert result = x"00000000"
            report "INC test failed: expected 0x00000000" severity error;
        assert carry = '1'
            report "INC carry flag failed: expected 1" severity error;

        -- Test 14: DEC  0x00000000 - 1 = 0xFFFFFFFF
        a      <= x"00000000";
        alu_op <= OP_DEC;
        wait for 10 ns;
        assert result = x"FFFFFFFF"
            report "DEC test failed: expected 0xFFFFFFFF" severity error;

        -- Test 15: MUL  0x00000003 * 0x00000004 = 0x0000000C
        a      <= x"00000003";
        b      <= x"00000004";
        alu_op <= OP_MUL;
        wait for 10 ns;
        assert result = x"0000000C"
            report "MUL test failed: expected 0x0000000C" severity error;

        -- Test 16: PASS  pass A through = 0xDEADBEEF
        a      <= x"DEADBEEF";
        alu_op <= OP_PASS;
        wait for 10 ns;
        assert result = x"DEADBEEF"
            report "PASS test failed: expected 0xDEADBEEF" severity error;

        -- Test 17: ADD with carry  0xFFFFFFFF + 0x00000001 = 0x00000000, carry=1
        a      <= x"FFFFFFFF";
        b      <= x"00000001";
        alu_op <= OP_ADD;
        wait for 10 ns;
        assert result = x"00000000"
            report "ADD carry test failed: expected 0x00000000" severity error;
        assert carry = '1'
            report "ADD carry flag failed: expected 1" severity error;

        report "All 32-bit ALU tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim_proc;

end architecture test;

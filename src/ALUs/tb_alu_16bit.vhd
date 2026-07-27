-- Testbench for 16-bit ALU
-- Tests multiple operations: ADD, SUB, AND, OR, XOR, NOT, SLL, SRL, SRA,
--                            ROL, ROR, CMP, INC, DEC, MUL, PASS
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_alu_16bit is
end entity tb_alu_16bit;

architecture test of tb_alu_16bit is

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

    signal a        : std_logic_vector(15 downto 0) := (others => '0');
    signal b        : std_logic_vector(15 downto 0) := (others => '0');
    signal alu_op   : std_logic_vector(3 downto 0) := (others => '0');
    signal result   : std_logic_vector(15 downto 0);
    signal zero     : std_logic;
    signal carry    : std_logic;
    signal overflow : std_logic;
    signal negative : std_logic;
    signal parity   : std_logic;

begin

    dut : entity work.alu_16bit
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

        -- Test 1: ADD  0x0005 + 0x0003 = 0x0008
        a      <= x"0005";
        b      <= x"0003";
        alu_op <= OP_ADD;
        wait for 10 ns;
        assert result = x"0008"
            report "ADD test failed: expected 0x0008" severity error;
        assert carry = '0'
            report "ADD carry test failed: expected 0" severity error;

        -- Test 2: SUB  0x000A - 0x0003 = 0x0007
        a      <= x"000A";
        b      <= x"0003";
        alu_op <= OP_SUB;
        wait for 10 ns;
        assert result = x"0007"
            report "SUB test failed: expected 0x0007" severity error;

        -- Test 3: AND  0xFF00 AND 0x00FF = 0x0000
        a      <= x"FF00";
        b      <= x"00FF";
        alu_op <= OP_AND;
        wait for 10 ns;
        assert result = x"0000"
            report "AND test failed: expected 0x0000" severity error;
        assert zero = '1'
            report "AND zero flag failed: expected 1" severity error;

        -- Test 4: OR  0xFF00 OR 0x00FF = 0xFFFF
        a      <= x"FF00";
        b      <= x"00FF";
        alu_op <= OP_OR;
        wait for 10 ns;
        assert result = x"FFFF"
            report "OR test failed: expected 0xFFFF" severity error;

        -- Test 5: XOR  0xFFFF XOR 0x00FF = 0xFF00
        a      <= x"FFFF";
        b      <= x"00FF";
        alu_op <= OP_XOR;
        wait for 10 ns;
        assert result = x"FF00"
            report "XOR test failed: expected 0xFF00" severity error;

        -- Test 6: NOT  NOT 0x0000 = 0xFFFF
        a      <= x"0000";
        alu_op <= OP_NOT;
        wait for 10 ns;
        assert result = x"FFFF"
            report "NOT test failed: expected 0xFFFF" severity error;

        -- Test 7: SLL  0x0001 << 1 = 0x0002
        a      <= x"0001";
        alu_op <= OP_SLL;
        wait for 10 ns;
        assert result = x"0002"
            report "SLL test failed: expected 0x0002" severity error;

        -- Test 8: SRL  0x8000 >> 1 = 0x4000
        a      <= x"8000";
        alu_op <= OP_SRL;
        wait for 10 ns;
        assert result = x"4000"
            report "SRL test failed: expected 0x4000" severity error;

        -- Test 9: SRA  0x8000 >> 1 (arith) = 0xC000
        a      <= x"8000";
        alu_op <= OP_SRA;
        wait for 10 ns;
        assert result = x"C000"
            report "SRA test failed: expected 0xC000" severity error;

        -- Test 10: ROL  0x8000 rotate left = 0x0001
        a      <= x"8000";
        alu_op <= OP_ROL;
        wait for 10 ns;
        assert result = x"0001"
            report "ROL test failed: expected 0x0001" severity error;

        -- Test 11: ROR  0x0001 rotate right = 0x8000
        a      <= x"0001";
        alu_op <= OP_ROR;
        wait for 10 ns;
        assert result = x"8000"
            report "ROR test failed: expected 0x8000" severity error;

        -- Test 12: CMP  0x0010 - 0x0010 = 0x0000, zero=1
        a      <= x"0010";
        b      <= x"0010";
        alu_op <= OP_CMP;
        wait for 10 ns;
        assert result = x"0000"
            report "CMP test failed: expected 0x0000" severity error;
        assert zero = '1'
            report "CMP zero flag failed: expected 1" severity error;

        -- Test 13: INC  0xFFFF + 1 = 0x0000, carry=1
        a      <= x"FFFF";
        alu_op <= OP_INC;
        wait for 10 ns;
        assert result = x"0000"
            report "INC test failed: expected 0x0000" severity error;
        assert carry = '1'
            report "INC carry flag failed: expected 1" severity error;

        -- Test 14: DEC  0x0000 - 1 = 0xFFFF
        a      <= x"0000";
        alu_op <= OP_DEC;
        wait for 10 ns;
        assert result = x"FFFF"
            report "DEC test failed: expected 0xFFFF" severity error;

        -- Test 15: MUL  0x0003 * 0x0004 = 0x000C
        a      <= x"0003";
        b      <= x"0004";
        alu_op <= OP_MUL;
        wait for 10 ns;
        assert result = x"000C"
            report "MUL test failed: expected 0x000C" severity error;

        -- Test 16: PASS  pass A through = 0xBEEF
        a      <= x"BEEF";
        alu_op <= OP_PASS;
        wait for 10 ns;
        assert result = x"BEEF"
            report "PASS test failed: expected 0xBEEF" severity error;

        -- Test 17: ADD with carry  0xFFFF + 0x0001 = 0x0000, carry=1
        a      <= x"FFFF";
        b      <= x"0001";
        alu_op <= OP_ADD;
        wait for 10 ns;
        assert result = x"0000"
            report "ADD carry test failed: expected 0x0000" severity error;
        assert carry = '1'
            report "ADD carry flag failed: expected 1" severity error;

        report "All 16-bit ALU tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim_proc;

end architecture test;

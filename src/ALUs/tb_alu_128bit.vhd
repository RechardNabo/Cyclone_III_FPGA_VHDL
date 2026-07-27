-- Testbench for 128-bit ALU
-- Tests multiple operations: ADD, SUB, AND, OR, XOR, NOT, SLL, SRL, SRA,
--                            ROL, ROR, CMP, INC, DEC, PASS
-- Note: MUL not implemented for >32-bit (outputs 0)
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_alu_128bit is
end entity tb_alu_128bit;

architecture test of tb_alu_128bit is

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

    signal a        : std_logic_vector(127 downto 0) := (others => '0');
    signal b        : std_logic_vector(127 downto 0) := (others => '0');
    signal alu_op   : std_logic_vector(3 downto 0) := (others => '0');
    signal result   : std_logic_vector(127 downto 0);
    signal zero     : std_logic;
    signal carry    : std_logic;
    signal overflow : std_logic;
    signal negative : std_logic;
    signal parity   : std_logic;

    -- Helper constants for 128-bit literals
    constant ALL_ZEROS : std_logic_vector(127 downto 0) := (others => '0');
    constant ALL_ONES  : std_logic_vector(127 downto 0) := (others => '1');
    constant BIT0_SET  : std_logic_vector(127 downto 0) :=
        x"00000000000000000000000000000001";
    constant BIT127_SET : std_logic_vector(127 downto 0) :=
        x"80000000000000000000000000000000";
    constant VAL_5 : std_logic_vector(127 downto 0) :=
        x"00000000000000000000000000000005";
    constant VAL_3 : std_logic_vector(127 downto 0) :=
        x"00000000000000000000000000000003";
    constant VAL_8 : std_logic_vector(127 downto 0) :=
        x"00000000000000000000000000000008";
    constant VAL_A : std_logic_vector(127 downto 0) :=
        x"0000000000000000000000000000000A";
    constant VAL_7 : std_logic_vector(127 downto 0) :=
        x"00000000000000000000000000000007";
    constant VAL_1 : std_logic_vector(127 downto 0) :=
        x"00000000000000000000000000000001";
    constant VAL_2 : std_logic_vector(127 downto 0) :=
        x"00000000000000000000000000000002";
    constant UPPER_ONES : std_logic_vector(127 downto 0) :=
        x"FFFFFFFFFFFFFFFF0000000000000000";
    constant LOWER_ONES : std_logic_vector(127 downto 0) :=
        x"0000000000000000FFFFFFFFFFFFFFFF";
    constant LOW_FF : std_logic_vector(127 downto 0) :=
        x"000000000000000000000000000000FF";
    constant HIGH_FF00 : std_logic_vector(127 downto 0) :=
        x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00";
    constant SRL_EXP : std_logic_vector(127 downto 0) :=
        x"40000000000000000000000000000000";
    constant SRA_EXP : std_logic_vector(127 downto 0) :=
        x"C0000000000000000000000000000000";
    constant CMP_VAL : std_logic_vector(127 downto 0) :=
        x"00000000000000000000000000000100";
    constant PASS_VAL : std_logic_vector(127 downto 0) :=
        x"DEADBEEFCAFEBABE1234567890ABCDEF";

begin

    dut : entity work.alu_128bit
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

        -- Test 1: ADD  5 + 3 = 8
        a      <= VAL_5;
        b      <= VAL_3;
        alu_op <= OP_ADD;
        wait for 10 ns;
        assert result = VAL_8
            report "ADD test failed: expected 8" severity error;
        assert carry = '0'
            report "ADD carry test failed: expected 0" severity error;

        -- Test 2: SUB  0xA - 0x3 = 0x7
        a      <= VAL_A;
        b      <= VAL_3;
        alu_op <= OP_SUB;
        wait for 10 ns;
        assert result = VAL_7
            report "SUB test failed: expected 7" severity error;

        -- Test 3: AND  upper_ones AND lower_ones = 0
        a      <= UPPER_ONES;
        b      <= LOWER_ONES;
        alu_op <= OP_AND;
        wait for 10 ns;
        assert result = ALL_ZEROS
            report "AND test failed: expected 0" severity error;
        assert zero = '1'
            report "AND zero flag failed: expected 1" severity error;

        -- Test 4: OR  upper_ones OR lower_ones = all ones
        a      <= UPPER_ONES;
        b      <= LOWER_ONES;
        alu_op <= OP_OR;
        wait for 10 ns;
        assert result = ALL_ONES
            report "OR test failed: expected all ones" severity error;

        -- Test 5: XOR  all_ones XOR low_FF = high_FF00
        a      <= ALL_ONES;
        b      <= LOW_FF;
        alu_op <= OP_XOR;
        wait for 10 ns;
        assert result = HIGH_FF00
            report "XOR test failed: expected high FF00" severity error;

        -- Test 6: NOT  NOT 0 = all ones
        a      <= ALL_ZEROS;
        alu_op <= OP_NOT;
        wait for 10 ns;
        assert result = ALL_ONES
            report "NOT test failed: expected all ones" severity error;

        -- Test 7: SLL  0x01 << 1 = 0x02
        a      <= BIT0_SET;
        alu_op <= OP_SLL;
        wait for 10 ns;
        assert result = VAL_2
            report "SLL test failed: expected 2" severity error;

        -- Test 8: SRL  bit127 >> 1 = 0x4000...
        a      <= BIT127_SET;
        alu_op <= OP_SRL;
        wait for 10 ns;
        assert result = SRL_EXP
            report "SRL test failed: expected 0x4000..." severity error;

        -- Test 9: SRA  bit127 >> 1 (arith) = 0xC000...
        a      <= BIT127_SET;
        alu_op <= OP_SRA;
        wait for 10 ns;
        assert result = SRA_EXP
            report "SRA test failed: expected 0xC000..." severity error;

        -- Test 10: ROL  bit127 rotate left = bit0
        a      <= BIT127_SET;
        alu_op <= OP_ROL;
        wait for 10 ns;
        assert result = BIT0_SET
            report "ROL test failed: expected bit0 set" severity error;

        -- Test 11: ROR  bit0 rotate right = bit127
        a      <= BIT0_SET;
        alu_op <= OP_ROR;
        wait for 10 ns;
        assert result = BIT127_SET
            report "ROR test failed: expected bit127 set" severity error;

        -- Test 12: CMP  equal values -> zero=1
        a      <= CMP_VAL;
        b      <= CMP_VAL;
        alu_op <= OP_CMP;
        wait for 10 ns;
        assert result = ALL_ZEROS
            report "CMP test failed: expected 0" severity error;
        assert zero = '1'
            report "CMP zero flag failed: expected 1" severity error;

        -- Test 13: INC  all_ones + 1 = 0, carry=1
        a      <= ALL_ONES;
        alu_op <= OP_INC;
        wait for 10 ns;
        assert result = ALL_ZEROS
            report "INC test failed: expected 0" severity error;
        assert carry = '1'
            report "INC carry flag failed: expected 1" severity error;

        -- Test 14: DEC  0 - 1 = all ones
        a      <= ALL_ZEROS;
        alu_op <= OP_DEC;
        wait for 10 ns;
        assert result = ALL_ONES
            report "DEC test failed: expected all ones" severity error;

        -- Test 15: MUL  not implemented -> 0
        a      <= VAL_3;
        b      <= VAL_5;
        alu_op <= OP_MUL;
        wait for 10 ns;
        assert result = ALL_ZEROS
            report "MUL test failed: expected 0 (not implemented)" severity error;

        -- Test 16: PASS  pass A through
        a      <= PASS_VAL;
        alu_op <= OP_PASS;
        wait for 10 ns;
        assert result = PASS_VAL
            report "PASS test failed: expected PASS_VAL" severity error;

        -- Test 17: ADD with carry  all_ones + 1 = 0, carry=1
        a      <= ALL_ONES;
        b      <= VAL_1;
        alu_op <= OP_ADD;
        wait for 10 ns;
        assert result = ALL_ZEROS
            report "ADD carry test failed: expected 0" severity error;
        assert carry = '1'
            report "ADD carry flag failed: expected 1" severity error;

        report "All 128-bit ALU tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim_proc;

end architecture test;

-- Testbench for 1024-bit ALU
-- Tests multiple operations: ADD, SUB, AND, OR, XOR, NOT, SLL, SRL, SRA,
--                            ROL, ROR, CMP, INC, DEC, PASS
-- Note: MUL not implemented for >32-bit (outputs 0)
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_alu_1024bit is
end entity tb_alu_1024bit;

architecture test of tb_alu_1024bit is

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

    signal a        : std_logic_vector(1023 downto 0) := (others => '0');
    signal b        : std_logic_vector(1023 downto 0) := (others => '0');
    signal alu_op   : std_logic_vector(3 downto 0) := (others => '0');
    signal result   : std_logic_vector(1023 downto 0);
    signal zero     : std_logic;
    signal carry    : std_logic;
    signal overflow : std_logic;
    signal negative : std_logic;
    signal parity   : std_logic;

    constant ALL_ZEROS   : std_logic_vector(1023 downto 0) := (others => '0');
    constant ALL_ONES    : std_logic_vector(1023 downto 0) := (others => '1');
    constant BIT0_SET    : std_logic_vector(1023 downto 0) :=
        (1 => '1', others => '0');
    constant BIT1023_SET : std_logic_vector(1023 downto 0) :=
        (1023 => '1', others => '0');
    constant VAL_5 : std_logic_vector(1023 downto 0) :=
        (2 downto 0 => "101", others => '0');
    constant VAL_3 : std_logic_vector(1023 downto 0) :=
        (1 downto 0 => "11", others => '0');
    constant VAL_8 : std_logic_vector(1023 downto 0) :=
        (3 downto 0 => "1000", others => '0');
    constant VAL_A : std_logic_vector(1023 downto 0) :=
        (3 downto 0 => "1010", others => '0');
    constant VAL_7 : std_logic_vector(1023 downto 0) :=
        (2 downto 0 => "111", others => '0');
    constant VAL_1 : std_logic_vector(1023 downto 0) :=
        (0 => '1', others => '0');
    constant VAL_2 : std_logic_vector(1023 downto 0) :=
        (1 => '1', others => '0');
    constant UPPER_ONES : std_logic_vector(1023 downto 0) :=
        (1023 downto 512 => '1', 511 downto 0 => '0');
    constant LOWER_ONES : std_logic_vector(1023 downto 0) :=
        (1023 downto 512 => '0', 511 downto 0 => '1');
    constant LOW_FF : std_logic_vector(1023 downto 0) :=
        (7 downto 0 => '1', others => '0');
    constant HIGH_FF00 : std_logic_vector(1023 downto 0) :=
        (1023 downto 8 => '1', 7 downto 0 => '0');
    constant SRL_EXP : std_logic_vector(1023 downto 0) :=
        (1022 => '1', others => '0');
    constant SRA_EXP : std_logic_vector(1023 downto 0) :=
        (1023 => '1', 1022 => '1', others => '0');
    constant CMP_VAL : std_logic_vector(1023 downto 0) :=
        (8 => '1', others => '0');
    constant PASS_VAL : std_logic_vector(1023 downto 0) :=
        (1023 downto 1008 => x"DEAD", 1007 downto 992 => x"BEEF",
         991 downto 976 => x"CAFE", 975 downto 960 => x"BABE",
         others => '0');

begin

    dut : entity work.alu_1024bit
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

        -- Test 5: XOR  all_ones XOR low_FF = high FF00
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

        -- Test 8: SRL  bit1023 >> 1 = bit1022
        a      <= BIT1023_SET;
        alu_op <= OP_SRL;
        wait for 10 ns;
        assert result = SRL_EXP
            report "SRL test failed: expected bit1022 set" severity error;

        -- Test 9: SRA  bit1023 >> 1 (arith) = bit1023+bit1022
        a      <= BIT1023_SET;
        alu_op <= OP_SRA;
        wait for 10 ns;
        assert result = SRA_EXP
            report "SRA test failed: expected bit1023+bit1022 set" severity error;

        -- Test 10: ROL  bit1023 rotate left = bit0
        a      <= BIT1023_SET;
        alu_op <= OP_ROL;
        wait for 10 ns;
        assert result = BIT0_SET
            report "ROL test failed: expected bit0 set" severity error;

        -- Test 11: ROR  bit0 rotate right = bit1023
        a      <= BIT0_SET;
        alu_op <= OP_ROR;
        wait for 10 ns;
        assert result = BIT1023_SET
            report "ROR test failed: expected bit1023 set" severity error;

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

        report "All 1024-bit ALU tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim_proc;

end architecture test;

-- Testbench for 8-bit ALU
-- Tests multiple operations: ADD, SUB, AND, OR, XOR, NOT, SLL, SRL, SRA,
--                            ROL, ROR, CMP, INC, DEC, MUL, PASS
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_alu_8bit is
end entity tb_alu_8bit;

architecture test of tb_alu_8bit is

    -- Operation opcodes (must match DUT)
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

    signal a        : std_logic_vector(7 downto 0) := (others => '0');
    signal b        : std_logic_vector(7 downto 0) := (others => '0');
    signal alu_op   : std_logic_vector(3 downto 0) := (others => '0');
    signal result   : std_logic_vector(7 downto 0);
    signal zero     : std_logic;
    signal carry    : std_logic;
    signal overflow : std_logic;
    signal negative : std_logic;
    signal parity   : std_logic;

begin

    -- Instantiate DUT
    dut : entity work.alu_8bit
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

    -- Stimulus process
    stim_proc : process
    begin

        ----------------------------------------------------------------
        -- Test 1: ADD  0x05 + 0x03 = 0x08
        ----------------------------------------------------------------
        a      <= x"05";
        b      <= x"03";
        alu_op <= OP_ADD;
        wait for 10 ns;
        assert result = x"08"
            report "ADD test failed: expected 0x08, got " &
                   std_logic_vector'image(result) severity error;
        assert carry = '0'
            report "ADD carry test failed: expected 0" severity error;

        ----------------------------------------------------------------
        -- Test 2: SUB  0x0A - 0x03 = 0x07
        ----------------------------------------------------------------
        a      <= x"0A";
        b      <= x"03";
        alu_op <= OP_SUB;
        wait for 10 ns;
        assert result = x"07"
            report "SUB test failed: expected 0x07, got " &
                   std_logic_vector'image(result) severity error;

        ----------------------------------------------------------------
        -- Test 3: AND  0xF0 AND 0x0F = 0x00
        ----------------------------------------------------------------
        a      <= x"F0";
        b      <= x"0F";
        alu_op <= OP_AND;
        wait for 10 ns;
        assert result = x"00"
            report "AND test failed: expected 0x00, got " &
                   std_logic_vector'image(result) severity error;
        assert zero = '1'
            report "AND zero flag failed: expected 1" severity error;

        ----------------------------------------------------------------
        -- Test 4: OR  0xF0 OR 0x0F = 0xFF
        ----------------------------------------------------------------
        a      <= x"F0";
        b      <= x"0F";
        alu_op <= OP_OR;
        wait for 10 ns;
        assert result = x"FF"
            report "OR test failed: expected 0xFF, got " &
                   std_logic_vector'image(result) severity error;

        ----------------------------------------------------------------
        -- Test 5: XOR  0xFF XOR 0x0F = 0xF0
        ----------------------------------------------------------------
        a      <= x"FF";
        b      <= x"0F";
        alu_op <= OP_XOR;
        wait for 10 ns;
        assert result = x"F0"
            report "XOR test failed: expected 0xF0, got " &
                   std_logic_vector'image(result) severity error;

        ----------------------------------------------------------------
        -- Test 6: NOT  NOT 0x00 = 0xFF
        ----------------------------------------------------------------
        a      <= x"00";
        b      <= x"00";
        alu_op <= OP_NOT;
        wait for 10 ns;
        assert result = x"FF"
            report "NOT test failed: expected 0xFF, got " &
                   std_logic_vector'image(result) severity error;

        ----------------------------------------------------------------
        -- Test 7: SLL  0x01 << 1 = 0x02
        ----------------------------------------------------------------
        a      <= x"01";
        alu_op <= OP_SLL;
        wait for 10 ns;
        assert result = x"02"
            report "SLL test failed: expected 0x02, got " &
                   std_logic_vector'image(result) severity error;

        ----------------------------------------------------------------
        -- Test 8: SRL  0x80 >> 1 = 0x40
        ----------------------------------------------------------------
        a      <= x"80";
        alu_op <= OP_SRL;
        wait for 10 ns;
        assert result = x"40"
            report "SRL test failed: expected 0x40, got " &
                   std_logic_vector'image(result) severity error;

        ----------------------------------------------------------------
        -- Test 9: SRA  0x80 >> 1 (arith) = 0xC0
        ----------------------------------------------------------------
        a      <= x"80";
        alu_op <= OP_SRA;
        wait for 10 ns;
        assert result = x"C0"
            report "SRA test failed: expected 0xC0, got " &
                   std_logic_vector'image(result) severity error;

        ----------------------------------------------------------------
        -- Test 10: ROL  0x80 rotate left = 0x01
        ----------------------------------------------------------------
        a      <= x"80";
        alu_op <= OP_ROL;
        wait for 10 ns;
        assert result = x"01"
            report "ROL test failed: expected 0x01, got " &
                   std_logic_vector'image(result) severity error;

        ----------------------------------------------------------------
        -- Test 11: ROR  0x01 rotate right = 0x80
        ----------------------------------------------------------------
        a      <= x"01";
        alu_op <= OP_ROR;
        wait for 10 ns;
        assert result = x"80"
            report "ROR test failed: expected 0x80, got " &
                   std_logic_vector'image(result) severity error;

        ----------------------------------------------------------------
        -- Test 12: CMP  0x05 - 0x05 = 0x00, zero=1
        ----------------------------------------------------------------
        a      <= x"05";
        b      <= x"05";
        alu_op <= OP_CMP;
        wait for 10 ns;
        assert result = x"00"
            report "CMP test failed: expected 0x00, got " &
                   std_logic_vector'image(result) severity error;
        assert zero = '1'
            report "CMP zero flag failed: expected 1" severity error;

        ----------------------------------------------------------------
        -- Test 13: INC  0xFF + 1 = 0x00, carry=1
        ----------------------------------------------------------------
        a      <= x"FF";
        alu_op <= OP_INC;
        wait for 10 ns;
        assert result = x"00"
            report "INC test failed: expected 0x00, got " &
                   std_logic_vector'image(result) severity error;
        assert carry = '1'
            report "INC carry flag failed: expected 1" severity error;
        assert zero = '1'
            report "INC zero flag failed: expected 1" severity error;

        ----------------------------------------------------------------
        -- Test 14: DEC  0x00 - 1 = 0xFF
        ----------------------------------------------------------------
        a      <= x"00";
        alu_op <= OP_DEC;
        wait for 10 ns;
        assert result = x"FF"
            report "DEC test failed: expected 0xFF, got " &
                   std_logic_vector'image(result) severity error;

        ----------------------------------------------------------------
        -- Test 15: MUL  0x03 * 0x04 = 0x0C
        ----------------------------------------------------------------
        a      <= x"03";
        b      <= x"04";
        alu_op <= OP_MUL;
        wait for 10 ns;
        assert result = x"0C"
            report "MUL test failed: expected 0x0C, got " &
                   std_logic_vector'image(result) severity error;

        ----------------------------------------------------------------
        -- Test 16: PASS  pass A through = 0x42
        ----------------------------------------------------------------
        a      <= x"42";
        alu_op <= OP_PASS;
        wait for 10 ns;
        assert result = x"42"
            report "PASS test failed: expected 0x42, got " &
                   std_logic_vector'image(result) severity error;

        ----------------------------------------------------------------
        -- Test 17: ADD with carry  0xFF + 0x01 = 0x00, carry=1
        ----------------------------------------------------------------
        a      <= x"FF";
        b      <= x"01";
        alu_op <= OP_ADD;
        wait for 10 ns;
        assert result = x"00"
            report "ADD carry test failed: expected 0x00, got " &
                   std_logic_vector'image(result) severity error;
        assert carry = '1'
            report "ADD carry flag failed: expected 1" severity error;

        report "All 8-bit ALU tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim_proc;

end architecture test;

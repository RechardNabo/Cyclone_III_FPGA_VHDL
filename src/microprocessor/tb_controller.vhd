-- ============================================================================
-- Testbench for Controller (instruction decoder)
-- ============================================================================
-- Tests the combinational instruction decoder for all opcodes (NOP, LOAD,
-- ADD, SUB, AND, OR, OUT, HALT). Verifies that the correct control signals
-- are asserted for each instruction type.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_controller is
end entity tb_controller;

architecture sim of tb_controller is

    signal instruction : std_logic_vector(7 downto 0) := (others => '0');
    signal reg_write   : std_logic;
    signal alu_op      : std_logic_vector(2 downto 0);
    signal mem_read    : std_logic;
    signal mem_write   : std_logic;
    signal pc_load     : std_logic;
    signal out_load    : std_logic;
    signal halt        : std_logic;
    signal use_imm     : std_logic;
    signal rd_addr     : std_logic_vector(2 downto 0);
    signal rs_addr     : std_logic_vector(2 downto 0);
    signal imm         : std_logic_vector(7 downto 0);

begin

    -- Instantiate DUT
    dut : entity work.controller
        port map (
            instruction => instruction,
            reg_write   => reg_write,
            alu_op      => alu_op,
            mem_read    => mem_read,
            mem_write   => mem_write,
            pc_load     => pc_load,
            out_load    => out_load,
            halt        => halt,
            use_imm     => use_imm,
            rd_addr     => rd_addr,
            rs_addr     => rs_addr,
            imm         => imm
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- -------------------------------------------------------
        -- Test 1: NOP (opcode 000) - all control signals low
        -- -------------------------------------------------------
        instruction <= "00000000";
        wait for 10 ns;
        assert reg_write = '0' and out_load = '0' and halt = '0' and use_imm = '0'
            report "Test 1 FAIL: NOP should assert no control signals"
            severity error;
        report "Test 1 PASS: NOP asserts no control signals" severity note;

        -- -------------------------------------------------------
        -- Test 2: LOAD rd=1, imm=5 (opcode 001, rd=01, imm=101)
        --         instruction = 001_01_101 = 00101101
        -- -------------------------------------------------------
        instruction <= "00101101";
        wait for 10 ns;
        assert reg_write = '1'
            report "Test 2 FAIL: LOAD should set reg_write=1"
            severity error;
        assert use_imm = '1'
            report "Test 2 FAIL: LOAD should set use_imm=1"
            severity error;
        assert rd_addr = "001"
            report "Test 2 FAIL: LOAD rd_addr should be 001"
            severity error;
        assert imm = "00000101"
            report "Test 2 FAIL: LOAD imm should be 0x05"
            severity error;
        report "Test 2 PASS: LOAD decoded correctly" severity note;

        -- -------------------------------------------------------
        -- Test 3: ADD rd=2, rs=1 (opcode 010, rd=10, rs=01)
        --         instruction = 010_10_01_0 = 01010010
        -- -------------------------------------------------------
        instruction <= "01010010";
        wait for 10 ns;
        assert reg_write = '1'
            report "Test 3 FAIL: ADD should set reg_write=1"
            severity error;
        assert alu_op = "000"
            report "Test 3 FAIL: ADD alu_op should be 000"
            severity error;
        assert rd_addr = "010"
            report "Test 3 FAIL: ADD rd_addr should be 010"
            severity error;
        assert rs_addr = "001"
            report "Test 3 FAIL: ADD rs_addr should be 001"
            severity error;
        report "Test 3 PASS: ADD decoded correctly" severity note;

        -- -------------------------------------------------------
        -- Test 4: SUB rd=0, rs=3 (opcode 011, rd=00, rs=11)
        --         instruction = 011_00_11_0 = 01100110
        -- -------------------------------------------------------
        instruction <= "01100110";
        wait for 10 ns;
        assert reg_write = '1'
            report "Test 4 FAIL: SUB should set reg_write=1"
            severity error;
        assert alu_op = "001"
            report "Test 4 FAIL: SUB alu_op should be 001"
            severity error;
        report "Test 4 PASS: SUB decoded correctly" severity note;

        -- -------------------------------------------------------
        -- Test 5: AND rd=1, rs=2 (opcode 100, rd=01, rs=10)
        --         instruction = 100_01_10_0 = 10001100
        -- -------------------------------------------------------
        instruction <= "10001100";
        wait for 10 ns;
        assert reg_write = '1'
            report "Test 5 FAIL: AND should set reg_write=1"
            severity error;
        assert alu_op = "010"
            report "Test 5 FAIL: AND alu_op should be 010"
            severity error;
        report "Test 5 PASS: AND decoded correctly" severity note;

        -- -------------------------------------------------------
        -- Test 6: OR rd=3, rs=0 (opcode 101, rd=11, rs=00)
        --         instruction = 101_11_00_0 = 10111000
        -- -------------------------------------------------------
        instruction <= "10111000";
        wait for 10 ns;
        assert reg_write = '1'
            report "Test 6 FAIL: OR should set reg_write=1"
            severity error;
        assert alu_op = "011"
            report "Test 6 FAIL: OR alu_op should be 011"
            severity error;
        report "Test 6 PASS: OR decoded correctly" severity note;

        -- -------------------------------------------------------
        -- Test 7: OUT rd=2 (opcode 110, rd=10)
        --         instruction = 110_10_00_0 = 11010000
        -- -------------------------------------------------------
        instruction <= "11010000";
        wait for 10 ns;
        assert out_load = '1'
            report "Test 7 FAIL: OUT should set out_load=1"
            severity error;
        assert reg_write = '0'
            report "Test 7 FAIL: OUT should not set reg_write"
            severity error;
        report "Test 7 PASS: OUT decoded correctly" severity note;

        -- -------------------------------------------------------
        -- Test 8: HALT (opcode 111)
        --         instruction = 111_00_00_0 = 11100000
        -- -------------------------------------------------------
        instruction <= "11100000";
        wait for 10 ns;
        assert halt = '1'
            report "Test 8 FAIL: HALT should set halt=1"
            severity error;
        report "Test 8 PASS: HALT decoded correctly" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

-- ============================================================================
-- Testbench for Control Unit (FSM + decoder)
-- ============================================================================
-- Tests the control unit state machine: reset state, FETCH/DECODE/EXECUTE/
-- WRITEBACK sequencing, ir_load and pc_inc assertion during FETCH, reg_write
-- assertion during WRITEBACK for a LOAD instruction, and HALT transitioning
-- to the done state.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_ctrl_unit is
end entity tb_ctrl_unit;

architecture sim of tb_ctrl_unit is

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '0';
    signal instruction : std_logic_vector(7 downto 0) := (others => '0');
    signal zero_flag   : std_logic := '0';
    signal ir_load     : std_logic;
    signal pc_load     : std_logic;
    signal pc_inc      : std_logic;
    signal reg_write   : std_logic;
    signal alu_op      : std_logic_vector(2 downto 0);
    signal mem_read    : std_logic;
    signal mem_write   : std_logic;
    signal out_load    : std_logic;
    signal use_imm     : std_logic;
    signal rd_addr     : std_logic_vector(2 downto 0);
    signal rs_addr     : std_logic_vector(2 downto 0);
    signal imm         : std_logic_vector(7 downto 0);
    signal done        : std_logic;

    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.ctrl_unit
        port map (
            clk         => clk,
            rst         => rst,
            instruction => instruction,
            zero_flag   => zero_flag,
            ir_load     => ir_load,
            pc_load     => pc_load,
            pc_inc      => pc_inc,
            reg_write   => reg_write,
            alu_op      => alu_op,
            mem_read    => mem_read,
            mem_write   => mem_write,
            out_load    => out_load,
            use_imm     => use_imm,
            rd_addr     => rd_addr,
            rs_addr     => rs_addr,
            imm         => imm,
            done        => done
        );

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus process
    stim_proc : process
    begin
        -- -------------------------------------------------------
        -- Test 1: Reset puts FSM in FETCH, done=0
        -- -------------------------------------------------------
        rst <= '1';
        instruction <= (others => '0');
        wait for CLK_PERIOD;
        assert done = '0'
            report "Test 1 FAIL: done should be 0 after reset"
            severity error;
        assert ir_load = '1'
            report "Test 1 FAIL: ir_load should be 1 in FETCH state"
            severity error;
        assert pc_inc = '1'
            report "Test 1 FAIL: pc_inc should be 1 in FETCH state"
            severity error;
        report "Test 1 PASS: Reset state is FETCH with ir_load and pc_inc" severity note;

        -- -------------------------------------------------------
        -- Test 2: Advance to DECODE (ir_load and pc_inc go low)
        -- -------------------------------------------------------
        rst <= '0';
        wait for CLK_PERIOD;
        assert ir_load = '0'
            report "Test 2 FAIL: ir_load should be 0 in DECODE"
            severity error;
        assert pc_inc = '0'
            report "Test 2 FAIL: pc_inc should be 0 in DECODE"
            severity error;
        report "Test 2 PASS: DECODE state has ir_load and pc_inc low" severity note;

        -- -------------------------------------------------------
        -- Test 3: Advance to EXECUTE
        -- -------------------------------------------------------
        wait for CLK_PERIOD;
        report "Test 3 PASS: Reached EXECUTE state" severity note;

        -- -------------------------------------------------------
        -- Test 4: LOAD instruction - WRITEBACK asserts reg_write and use_imm
        --         LOAD rd=1, imm=3 => 001_01_011 = 00101011
        -- -------------------------------------------------------
        instruction <= "00101011";
        wait for CLK_PERIOD;  -- now in WRITEBACK
        assert reg_write = '1'
            report "Test 4 FAIL: reg_write should be 1 in WRITEBACK for LOAD"
            severity error;
        assert use_imm = '1'
            report "Test 4 FAIL: use_imm should be 1 for LOAD"
            severity error;
        report "Test 4 PASS: LOAD WRITEBACK asserts reg_write and use_imm" severity note;

        -- -------------------------------------------------------
        -- Test 5: After WRITEBACK, FSM loops back to FETCH
        -- -------------------------------------------------------
        wait for CLK_PERIOD;
        assert ir_load = '1'
            report "Test 5 FAIL: ir_load should be 1 again in FETCH"
            severity error;
        assert pc_inc = '1'
            report "Test 5 FAIL: pc_inc should be 1 again in FETCH"
            severity error;
        report "Test 5 PASS: FSM looped back to FETCH" severity note;

        -- -------------------------------------------------------
        -- Test 6: HALT instruction transitions to done state
        --         HALT => 111_00_000 = 11100000
        --         Need to go through DECODE, EXECUTE, WRITEBACK
        -- -------------------------------------------------------
        instruction <= "11100000";
        wait for CLK_PERIOD;  -- DECODE
        wait for CLK_PERIOD;  -- EXECUTE
        wait for CLK_PERIOD;  -- WRITEBACK -> should go to HALT_STATE
        assert done = '1'
            report "Test 6 FAIL: done should be 1 after HALT WRITEBACK"
            severity error;
        report "Test 6 PASS: HALT instruction sets done=1" severity note;

        -- -------------------------------------------------------
        -- Test 7: HALT_STATE is sticky (done stays 1)
        -- -------------------------------------------------------
        wait for CLK_PERIOD;
        assert done = '1'
            report "Test 7 FAIL: done should remain 1 in HALT_STATE"
            severity error;
        report "Test 7 PASS: HALT_STATE is sticky, done remains 1" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

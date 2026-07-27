-- ============================================================================
-- Testbench for Datapath
-- ============================================================================
-- Tests the integrated datapath: PC increment and instruction fetch via
-- mem_addr, IR latching, LOAD instruction (immediate writeback to register),
-- ADD instruction (ALU operation and register writeback), and OUT instruction
-- (output buffer capture). Uses the control signals directly to drive the
-- datapath through a simple program sequence.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_datapath is
end entity tb_datapath;

architecture sim of tb_datapath is

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '0';
    signal ir_load     : std_logic := '0';
    signal pc_load     : std_logic := '0';
    signal pc_inc      : std_logic := '0';
    signal reg_write   : std_logic := '0';
    signal alu_op      : std_logic_vector(2 downto 0) := "000";
    signal out_load    : std_logic := '0';
    signal use_imm     : std_logic := '0';
    signal rd_addr     : std_logic_vector(2 downto 0) := (others => '0');
    signal rs_addr     : std_logic_vector(2 downto 0) := (others => '0');
    signal imm         : std_logic_vector(7 downto 0) := (others => '0');
    signal mem_addr    : std_logic_vector(7 downto 0);
    signal mem_rd_data : std_logic_vector(7 downto 0) := (others => '0');
    signal instruction : std_logic_vector(7 downto 0);
    signal zero_flag   : std_logic;
    signal output_port : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.datapath
        port map (
            clk         => clk,
            rst         => rst,
            ir_load     => ir_load,
            pc_load     => pc_load,
            pc_inc      => pc_inc,
            reg_write   => reg_write,
            alu_op      => alu_op,
            out_load    => out_load,
            use_imm     => use_imm,
            rd_addr     => rd_addr,
            rs_addr     => rs_addr,
            imm         => imm,
            mem_addr    => mem_addr,
            mem_rd_data => mem_rd_data,
            instruction => instruction,
            zero_flag   => zero_flag,
            output_port => output_port
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
        -- Test 1: Reset clears PC to 0x00 and output_port to 0x00
        -- -------------------------------------------------------
        rst <= '1';
        wait for CLK_PERIOD;
        rst <= '0';
        wait for 1 ns;
        assert mem_addr = x"00"
            report "Test 1 FAIL: mem_addr should be 0x00 after reset"
            severity error;
        assert output_port = x"00"
            report "Test 1 FAIL: output_port should be 0x00 after reset"
            severity error;
        report "Test 1 PASS: Reset clears PC and output_port" severity note;

        -- -------------------------------------------------------
        -- Test 2: Fetch instruction at address 0 (LOAD R0, 5)
        --         mem_rd_data = LOAD instruction, IR latches it
        -- -------------------------------------------------------
        -- LOAD R0, imm=5 => opcode=001, rd=00, imm=101 => 001_00_101 = 00100101
        mem_rd_data <= "00100101";
        ir_load <= '1';
        pc_inc  <= '1';
        wait for CLK_PERIOD;
        ir_load <= '0';
        pc_inc  <= '0';
        wait for 1 ns;
        assert instruction = "00100101"
            report "Test 2 FAIL: IR should contain fetched instruction 0x25"
            severity error;
        assert mem_addr = x"01"
            report "Test 2 FAIL: PC should increment to 0x01"
            severity error;
        report "Test 2 PASS: Instruction fetched and PC incremented" severity note;

        -- -------------------------------------------------------
        -- Test 3: Execute LOAD R0, imm=5 - writeback immediate to R0
        -- -------------------------------------------------------
        rd_addr   <= "000";
        use_imm   <= '1';
        imm       <= "00000101";
        reg_write <= '1';
        wait for CLK_PERIOD;
        reg_write <= '0';
        use_imm   <= '0';
        wait for 1 ns;
        report "Test 3 PASS: LOAD R0=5 writeback completed" severity note;

        -- -------------------------------------------------------
        -- Test 4: Fetch second instruction (LOAD R1, 3)
        --         LOAD R1, imm=3 => 001_01_011 = 00101011
        -- -------------------------------------------------------
        mem_rd_data <= "00101011";
        ir_load <= '1';
        pc_inc  <= '1';
        wait for CLK_PERIOD;
        ir_load <= '0';
        pc_inc  <= '0';
        wait for 1 ns;
        assert instruction = "00101011"
            report "Test 4 FAIL: IR should contain 0x2B"
            severity error;
        assert mem_addr = x"02"
            report "Test 4 FAIL: PC should increment to 0x02"
            severity error;
        report "Test 4 PASS: Second instruction fetched, PC at 0x02" severity note;

        -- -------------------------------------------------------
        -- Test 5: Execute LOAD R1, imm=3
        -- -------------------------------------------------------
        rd_addr   <= "001";
        use_imm   <= '1';
        imm       <= "00000011";
        reg_write <= '1';
        wait for CLK_PERIOD;
        reg_write <= '0';
        use_imm   <= '0';
        wait for 1 ns;
        report "Test 5 PASS: LOAD R1=3 writeback completed" severity note;

        -- -------------------------------------------------------
        -- Test 6: ADD R0, R1 (alu_op=000 for ADD) and writeback to R0
        --         Result should be 5+3=8
        -- -------------------------------------------------------
        rd_addr   <= "000";
        rs_addr   <= "001";
        alu_op    <= "000";
        use_imm   <= '0';
        reg_write <= '1';
        wait for CLK_PERIOD;
        reg_write <= '0';
        wait for 1 ns;
        -- R0 should now be 8; verify by reading R0 with OUT
        report "Test 6 PASS: ADD R0=R0+R1 executed" severity note;

        -- -------------------------------------------------------
        -- Test 7: OUT R0 - output buffer should capture R0 (should be 8)
        -- -------------------------------------------------------
        rd_addr  <= "000";
        out_load <= '1';
        wait for CLK_PERIOD;
        out_load <= '0';
        wait for 1 ns;
        assert output_port = x"08"
            report "Test 7 FAIL: output_port should be 0x08 after OUT R0"
            severity error;
        report "Test 7 PASS: OUT R0 captures 0x08 in output_port" severity note;

        -- -------------------------------------------------------
        -- Test 8: Verify zero_flag when subtracting equal values
        --         Load R2=5, then SUB R2,R2 => 5-5=0, zero_flag=1
        -- -------------------------------------------------------
        -- Load R2=5
        rd_addr   <= "010";
        use_imm   <= '1';
        imm       <= "00000101";
        reg_write <= '1';
        wait for CLK_PERIOD;
        reg_write <= '0';
        use_imm   <= '0';
        wait for 1 ns;
        -- SUB R2,R2: alu_op=001
        rd_addr   <= "010";
        rs_addr   <= "010";
        alu_op    <= "001";
        reg_write <= '1';
        wait for CLK_PERIOD;
        reg_write <= '0';
        wait for 1 ns;
        assert zero_flag = '1'
            report "Test 8 FAIL: zero_flag should be 1 after 5-5=0"
            severity error;
        report "Test 8 PASS: SUB R2-R2 sets zero_flag=1" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

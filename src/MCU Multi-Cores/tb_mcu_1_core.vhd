-- ============================================================================
-- Testbench for MCU_1_Core : Single-core 8-bit MCU
-- ============================================================================
-- Loads a small program into a memory model and verifies instruction
-- execution: LOAD, ADD, STORE, and HLT.  Checks reg_view (R0) and the
-- status register after the core halts.
--
-- Program:
--   0x00: LOAD  R0,[0x10]   ; R0 = mem[0x10] = 0x05
--   0x02: LOAD  R1,[0x11]   ; R1 = mem[0x11] = 0x03
--   0x04: ADD   R0,R1       ; R0 = 0x05 + 0x03 = 0x08
--   0x05: STORE R0,[0x20]   ; mem[0x20] = 0x08
--   0x07: HLT               ; halt core
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_mcu_1_core is
end entity tb_mcu_1_core;

architecture sim of tb_mcu_1_core is

    constant CLK_PERIOD : time := 20 ns;

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal addr_out : std_logic_vector(7 downto 0);
    signal data_in  : std_logic_vector(7 downto 0);
    signal data_out : std_logic_vector(7 downto 0);
    signal we       : std_logic;
    signal oe       : std_logic;
    signal status   : std_logic_vector(7 downto 0);
    signal irq      : std_logic := '0';
    signal irq_ack  : std_logic;
    signal halt     : std_logic := '0';
    signal reg_view : std_logic_vector(7 downto 0);

    -- Memory model: 256-byte array
    type mem_t is array(0 to 255) of std_logic_vector(7 downto 0);
    signal mem : mem_t := (others => (others => '0'));

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.MCU_1_Core
        port map (
            clk      => clk,
            reset    => reset,
            addr_out => addr_out,
            data_in  => data_in,
            data_out => data_out,
            we       => we,
            oe       => oe,
            status   => status,
            irq      => irq,
            irq_ack  => irq_ack,
            halt     => halt,
            reg_view => reg_view
        );

    -- ========================================================================
    -- Memory Model: combinational read, synchronous write
    -- ========================================================================
    data_in <= mem(to_integer(unsigned(addr_out)));

    mem_wr : process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                mem(to_integer(unsigned(addr_out))) <= data_out;
            end if;
        end if;
    end process mem_wr;

    -- ========================================================================
    -- Stimulus
    -- ========================================================================
    stim : process
    begin
        -- ------------------------------------------------------------------
        -- Load program into memory
        -- ------------------------------------------------------------------
        -- Address 0x00: LOAD R0, [0x10]  (opcode=0x6, rd=0, rs=0)
        mem(0) <= x"60";
        mem(1) <= x"10";
        -- Address 0x02: LOAD R1, [0x11]  (opcode=0x6, rd=1, rs=0)
        mem(2) <= x"64";
        mem(3) <= x"11";
        -- Address 0x04: ADD R0, R1       (opcode=0x1, rd=0, rs=1)
        mem(4) <= x"11";
        -- Address 0x05: STORE R0, [0x20] (opcode=0x7, rd=0, rs=0)
        mem(5) <= x"70";
        mem(6) <= x"20";
        -- Address 0x07: HLT              (opcode=0xB)
        mem(7) <= x"B0";

        -- Data values
        mem(16) <= x"05";  -- 0x10
        mem(17) <= x"03";  -- 0x11

        -- ------------------------------------------------------------------
        -- Reset
        -- ------------------------------------------------------------------
        reset <= '1';
        halt  <= '0';
        wait for CLK_PERIOD * 4;
        reset <= '0';
        wait until rising_edge(clk);

        -- ------------------------------------------------------------------
        -- Test 1: After reset, status should show running (bit 0 = 1)
        -- ------------------------------------------------------------------
        assert status(0) = '1'
            report "Test 1 FAIL: core not running after reset"
            severity error;
        assert status(1) = '0'
            report "Test 1 FAIL: core halted after reset"
            severity error;
        report "Test 1 PASS: core running after reset" severity note;

        -- ------------------------------------------------------------------
        -- Test 2: Wait for program to execute and core to halt
        --   LOAD (2 bytes, 3 cycles: fetch, decode, operand, load)
        --   LOAD (2 bytes, 3 cycles)
        --   ADD  (1 byte, 1 cycle)
        --   STORE(2 bytes, 2 cycles: fetch, decode, operand)
        --   HLT  (1 byte, 1 cycle)
        --   Total ~15-20 cycles; wait generously
        -- ------------------------------------------------------------------
        for i in 0 to 40 loop
            wait until rising_edge(clk);
            -- Check if halted
            if status(1) = '1' then
                exit;
            end if;
        end loop;

        -- Verify core is halted
        assert status(1) = '1'
            report "Test 2 FAIL: core did not halt after program execution"
            severity error;
        assert status(0) = '0'
            report "Test 2 FAIL: core still running after HLT"
            severity error;
        report "Test 2 PASS: core halted after HLT instruction" severity note;

        -- ------------------------------------------------------------------
        -- Test 3: Verify R0 = 0x05 + 0x03 = 0x08
        -- ------------------------------------------------------------------
        assert reg_view = x"08"
            report "Test 3 FAIL: R0 mismatch, expected 08 got " &
                   integer'image(to_integer(unsigned(reg_view)))
            severity error;
        report "Test 3 PASS: R0 = 0x08 after LOAD+LOAD+ADD" severity note;

        -- ------------------------------------------------------------------
        -- Test 4: Verify STORE wrote 0x08 to memory address 0x20
        -- ------------------------------------------------------------------
        wait until rising_edge(clk);
        assert mem(32) = x"08"
            report "Test 4 FAIL: mem[0x20] mismatch, expected 08 got " &
                   integer'image(to_integer(unsigned(mem(32))))
            severity error;
        report "Test 4 PASS: mem[0x20] = 0x08 after STORE" severity note;

        -- ------------------------------------------------------------------
        -- Test 5: Verify Zero flag is clear (0x08 != 0)
        -- ------------------------------------------------------------------
        assert status(4) = '0'
            report "Test 5 FAIL: Zero flag should be clear for result 0x08"
            severity error;
        report "Test 5 PASS: Zero flag clear for non-zero result" severity note;

        -- ------------------------------------------------------------------
        -- Test 6: Resume from halt by deasserting halt (already '0')
        --   and verify core resumes fetching
        -- ------------------------------------------------------------------
        -- Core should resume from S_HALT when halt='0'
        -- It should fetch from current PC (after HLT)
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        -- Core should be running again
        assert status(0) = '1'
            report "Test 6 FAIL: core not running after resume from halt"
            severity error;
        report "Test 6 PASS: core resumed from halt" severity note;

        -- Halt again to stop execution
        halt <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        halt <= '0';

        -- ------------------------------------------------------------------
        -- Done
        -- ------------------------------------------------------------------
        report "All MCU_1_Core tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim;

end architecture sim;

-- ================================================================================
-- MCU_1_Core : Single-core 8-bit MCU with instruction execution
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- This is a complete (educational) 8-bit MCU core that fetches and executes
-- instructions from external memory. It implements a simple 8-bit ISA with
-- 8 general-purpose registers, an ALU, status flags, and interrupt handling.
--
-- 8-BIT INSTRUCTION SET:
--   Format: [opcode(7:4) | operand(3:0)]
--   1-byte instructions (operand = rd(3:2) + rs(1:0)):
--     0x0: MOV  rd,rs  - Copy rs to rd
--     0x1: ADD  rd,rs  - rd = rd + rs (sets Z,C,N flags)
--     0x2: SUB  rd,rs  - rd = rd - rs (sets Z,C,N flags)
--     0x3: AND  rd,rs  - rd = rd AND rs (sets Z,N flags)
--     0x4: OR   rd,rs  - rd = rd OR  rs (sets Z,N flags)
--     0x5: XOR  rd,rs  - rd = rd XOR rs (sets Z,N flags)
--     0xB: HLT         - Halt core (stop execution)
--     0xC: NOP         - No operation
--   2-byte instructions (byte 1 = opcode+reg, byte 2 = address):
--     0x6: LOAD  rd,[addr] - Load from memory address into rd
--     0x7: STORE [addr],rd - Store rd to memory address
--     0x8: JMP  addr       - Unconditional jump to addr
--     0x9: JZ   addr       - Jump if Zero flag is set
--     0xA: JNZ  addr       - Jump if Zero flag is clear
--
-- REGISTER FILE: 8 x 8-bit registers (R0-R7), R0 is NOT special
--
-- STATUS FLAGS (stored in status register):
--   bit 0: Running (1=core is executing)
--   bit 1: Halted  (1=core is halted)
--   bit 2: Waiting (1=core waiting for bus/memory)
--   bit 3: IRQ pending
--   bit 4: Zero flag (Z) - last result was 0
--   bit 5: Carry flag (C) - last ADD overflowed / SUB no borrow
--   bit 6: Negative flag (N) - last result bit 7 was 1
--   bit 7: Reserved
--
-- INTERRUPT HANDLING:
--   When irq=1: save PC to saved_pc, jump to vector 0xFE, assert irq_ack
--   Handler returns by executing JMP to saved address
--
-- EXECUTION STATE MACHINE:
--   S_FETCH  -> S_DECODE -> (S_OPERAND -> S_LOAD) -> S_FETCH ...
--   S_HALT   : core stopped, waiting for halt=0
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity MCU_1_Core is
    port (
        clk      : in  std_logic;                     -- System clock
        reset    : in  std_logic;                     -- Active-high reset
        addr_out : out std_logic_vector(7 downto 0);  -- Memory address bus
        data_in  : in  std_logic_vector(7 downto 0);  -- Memory read data
        data_out : out std_logic_vector(7 downto 0);  -- Memory write data
        we       : out std_logic;                     -- Write enable
        oe       : out std_logic;                     -- Output enable (read)
        status   : out std_logic_vector(7 downto 0);  -- Status register
        irq      : in  std_logic;                     -- Interrupt request
        irq_ack  : out std_logic;                     -- Interrupt acknowledge
        halt     : in  std_logic;                     -- Halt core (stop execution)
        reg_view : out std_logic_vector(7 downto 0)   -- Debug: view R0 register
    );
end entity MCU_1_Core;

architecture rtl of MCU_1_Core is

    -- Opcode constants (upper 4 bits of instruction byte)
    constant OP_MOV   : std_logic_vector(3 downto 0) := "0000"; -- MOV rd,rs
    constant OP_ADD   : std_logic_vector(3 downto 0) := "0001"; -- ADD rd,rs
    constant OP_SUB   : std_logic_vector(3 downto 0) := "0010"; -- SUB rd,rs
    constant OP_AND   : std_logic_vector(3 downto 0) := "0011"; -- AND rd,rs
    constant OP_OR    : std_logic_vector(3 downto 0) := "0100"; -- OR  rd,rs
    constant OP_XOR   : std_logic_vector(3 downto 0) := "0101"; -- XOR rd,rs
    constant OP_LOAD  : std_logic_vector(3 downto 0) := "0110"; -- LOAD rd,[addr]
    constant OP_STORE : std_logic_vector(3 downto 0) := "0111"; -- STORE [addr],rd
    constant OP_JMP   : std_logic_vector(3 downto 0) := "1000"; -- JMP addr
    constant OP_JZ    : std_logic_vector(3 downto 0) := "1001"; -- JZ  addr
    constant OP_JNZ   : std_logic_vector(3 downto 0) := "1010"; -- JNZ addr
    constant OP_HLT   : std_logic_vector(3 downto 0) := "1011"; -- HLT
    constant OP_NOP   : std_logic_vector(3 downto 0) := "1100"; -- NOP

    constant IRQ_VECTOR : unsigned(7 downto 0) := x"FE"; -- Interrupt vector address

    -- State machine states
    type state_t is (S_FETCH, S_DECODE, S_OPERAND, S_LOAD, S_HALT);
    signal state : state_t := S_FETCH;

    -- Register file: 8 x 8-bit general purpose registers
    type regfile_t is array(0 to 7) of std_logic_vector(7 downto 0);
    signal regs : regfile_t := (others => (others => '0'));

    -- Program counter (8-bit, wraps at 256)
    signal pc : unsigned(7 downto 0) := (others => '0');

    -- Saved PC for interrupt return
    signal saved_pc : unsigned(7 downto 0) := (others => '0');

    -- Latched instruction fields (decoded in S_DECODE, used in later states)
    signal cur_opcode : std_logic_vector(3 downto 0) := (others => '0');
    signal cur_rd     : integer range 0 to 7 := 0;  -- Destination register index
    signal cur_rs     : integer range 0 to 7 := 0;  -- Source register index

    -- Status flags
    signal flag_z : std_logic := '0'; -- Zero flag
    signal flag_c : std_logic := '0'; -- Carry flag
    signal flag_n : std_logic := '0'; -- Negative flag
    signal running : std_logic := '1'; -- Core is running
    signal halted  : std_logic := '0'; -- Core is halted
    signal hlt_instr : std_logic := '0'; -- Halt was caused by HLT instruction

begin

    -- =========================================================================
    -- MAIN EXECUTION PROCESS (state machine)
    -- Fetches instructions from memory, decodes, and executes them.
    -- Memory interface: set addr_out + oe, next cycle data_in is valid.
    -- =========================================================================
    process(clk, reset)
        variable alu_a, alu_b : unsigned(7 downto 0); -- ALU operands
        variable alu_sum : unsigned(8 downto 0);      -- 9-bit sum for carry detection
        variable alu_result : std_logic_vector(7 downto 0); -- 8-bit ALU result
        variable opcode : std_logic_vector(3 downto 0);
        variable rd_idx, rs_idx : integer range 0 to 7;
    begin
        if reset = '1' then
            -- Active-high reset: clear all state
            state <= S_FETCH;
            pc <= (others => '0');
            regs <= (others => (others => '0'));
            flag_z <= '0'; flag_c <= '0'; flag_n <= '0';
            running <= '1'; halted <= '0';
            hlt_instr <= '0';
            we <= '0'; oe <= '0'; irq_ack <= '0';
            addr_out <= (others => '0');
            data_out <= (others => '0');

        elsif rising_edge(clk) then
            -- Default: no memory access, no interrupt ack
            we <= '0'; oe <= '0'; irq_ack <= '0';

            -- Check for halt input (highest priority)
            if halt = '1' and state /= S_HALT then
                state <= S_HALT;
                running <= '0'; halted <= '1';
                hlt_instr <= '0';  -- external halt, not instruction
            elsif halt = '1' and state = S_HALT then
                hlt_instr <= '0';  -- Clear HLT instruction flag on external halt
            elsif halt = '0' and state = S_HALT and hlt_instr = '0' then
                -- Resume from external halt only (not HLT instruction)
                state <= S_FETCH;
                running <= '1'; halted <= '0';
                addr_out <= std_logic_vector(pc);
                oe <= '1';
            end if;

            case state is

                -- =============================================================
                -- S_FETCH: Set up memory read for instruction at PC
                -- =============================================================
                when S_FETCH =>
                    addr_out <= std_logic_vector(pc);
                    oe <= '1';
                    state <= S_DECODE;

                -- =============================================================
                -- S_DECODE: data_in contains the instruction byte
                -- Decode opcode and execute 1-byte instructions or fetch operand
                -- =============================================================
                when S_DECODE =>
                    opcode := data_in(7 downto 4);
                    rd_idx := to_integer(unsigned(data_in(3 downto 2)));
                    rs_idx := to_integer(unsigned(data_in(1 downto 0)));
                    cur_opcode <= opcode;
                    cur_rd <= rd_idx;
                    cur_rs <= rs_idx;

                    case opcode is
                        -- -- 1-byte instructions: execute immediately --
                        when OP_MOV =>
                            regs(rd_idx) <= regs(rs_idx); -- rd = rs
                            -- Update flags
                            flag_z <= '1' when regs(rs_idx) = x"00" else '0';
                            flag_n <= regs(rs_idx)(7);
                            pc <= pc + 1;
                            addr_out <= std_logic_vector(pc + 1);
                            oe <= '1';
                            state <= S_DECODE; -- Fetch next instruction

                        when OP_ADD =>
                            alu_a := unsigned(regs(rd_idx));
                            alu_b := unsigned(regs(rs_idx));
                            alu_sum := ('0' & alu_a) + ('0' & alu_b); -- 9-bit for carry
                            alu_result := std_logic_vector(alu_sum(7 downto 0));
                            regs(rd_idx) <= alu_result;
                            flag_z <= '1' when alu_result = x"00" else '0';
                            flag_c <= alu_sum(8); -- Carry = bit 8 of sum
                            flag_n <= alu_result(7);
                            pc <= pc + 1;
                            addr_out <= std_logic_vector(pc + 1);
                            oe <= '1';
                            state <= S_DECODE;

                        when OP_SUB =>
                            alu_a := unsigned(regs(rd_idx));
                            alu_b := unsigned(regs(rs_idx));
                            alu_sum := ('0' & alu_a) - ('0' & alu_b); -- 9-bit for borrow
                            alu_result := std_logic_vector(alu_sum(7 downto 0));
                            regs(rd_idx) <= alu_result;
                            flag_z <= '1' when alu_result = x"00" else '0';
                            flag_c <= not alu_sum(8); -- Carry = no borrow (inverted)
                            flag_n <= alu_result(7);
                            pc <= pc + 1;
                            addr_out <= std_logic_vector(pc + 1);
                            oe <= '1';
                            state <= S_DECODE;

                        when OP_AND =>
                            alu_result := regs(rd_idx) and regs(rs_idx);
                            regs(rd_idx) <= alu_result;
                            flag_z <= '1' when alu_result = x"00" else '0';
                            flag_n <= alu_result(7);
                            pc <= pc + 1;
                            addr_out <= std_logic_vector(pc + 1);
                            oe <= '1';
                            state <= S_DECODE;

                        when OP_OR =>
                            alu_result := regs(rd_idx) or regs(rs_idx);
                            regs(rd_idx) <= alu_result;
                            flag_z <= '1' when alu_result = x"00" else '0';
                            flag_n <= alu_result(7);
                            pc <= pc + 1;
                            addr_out <= std_logic_vector(pc + 1);
                            oe <= '1';
                            state <= S_DECODE;

                        when OP_XOR =>
                            alu_result := regs(rd_idx) xor regs(rs_idx);
                            regs(rd_idx) <= alu_result;
                            flag_z <= '1' when alu_result = x"00" else '0';
                            flag_n <= alu_result(7);
                            pc <= pc + 1;
                            addr_out <= std_logic_vector(pc + 1);
                            oe <= '1';
                            state <= S_DECODE;

                        when OP_HLT =>
                            state <= S_HALT;
                            running <= '0'; halted <= '1';
                            hlt_instr <= '1';

                        when OP_NOP =>
                            pc <= pc + 1;
                            addr_out <= std_logic_vector(pc + 1);
                            oe <= '1';
                            state <= S_DECODE;

                        -- -- 2-byte instructions: fetch operand byte --
                        when others =>
                            addr_out <= std_logic_vector(pc + 1);
                            oe <= '1';
                            state <= S_OPERAND;
                    end case;

                -- =============================================================
                -- S_OPERAND: data_in contains the operand (address/immediate)
                -- Execute 2-byte instructions (JMP, JZ, JNZ, STORE) or
                -- set up memory read for LOAD
                -- =============================================================
                when S_OPERAND =>
                    case cur_opcode is
                        when OP_JMP =>
                            pc <= unsigned(data_in);     -- Jump to operand address
                            addr_out <= data_in;          -- Fetch from new address
                            oe <= '1';
                            state <= S_DECODE;

                        when OP_JZ =>
                            if flag_z = '1' then
                                pc <= unsigned(data_in); -- Taken: jump
                                addr_out <= data_in;
                            else
                                pc <= pc + 2;            -- Not taken: skip 2 bytes
                                addr_out <= std_logic_vector(pc + 2);
                            end if;
                            oe <= '1';
                            state <= S_DECODE;

                        when OP_JNZ =>
                            if flag_z = '0' then
                                pc <= unsigned(data_in); -- Taken: jump
                                addr_out <= data_in;
                            else
                                pc <= pc + 2;            -- Not taken: skip 2 bytes
                                addr_out <= std_logic_vector(pc + 2);
                            end if;
                            oe <= '1';
                            state <= S_DECODE;

                        when OP_LOAD =>
                            -- Set up memory read at operand address
                            addr_out <= data_in;
                            oe <= '1';
                            state <= S_LOAD;

                        when OP_STORE =>
                            -- Write register value to memory at operand address
                            addr_out <= data_in;
                            data_out <= regs(cur_rd);
                            we <= '1';
                            pc <= pc + 2;
                            state <= S_FETCH; -- Next: fetch instruction at PC+2

                        when others =>
                            pc <= pc + 2;
                            addr_out <= std_logic_vector(pc + 2);
                            oe <= '1';
                            state <= S_DECODE;
                    end case;

                -- =============================================================
                -- S_LOAD: data_in contains the byte loaded from memory
                -- Store it into the destination register
                -- =============================================================
                when S_LOAD =>
                    regs(cur_rd) <= data_in; -- Store loaded data to register
                    flag_z <= '1' when data_in = x"00" else '0';
                    flag_n <= data_in(7);
                    pc <= pc + 2;
                    addr_out <= std_logic_vector(pc + 2);
                    oe <= '1';
                    state <= S_DECODE;

                -- =============================================================
                -- S_HALT: Core is stopped, do nothing
                -- =============================================================
                when S_HALT =>
                    null; -- Stay halted until halt=0
            end case;

            -- =============================================================
            -- INTERRUPT HANDLING: checked at end of each instruction
            -- When irq=1, save PC and jump to interrupt vector
            -- =============================================================
            if irq = '1' and state = S_DECODE and halt = '0' then
                saved_pc <= pc; -- Save current PC for return
                pc <= IRQ_VECTOR; -- Jump to interrupt handler
                addr_out <= std_logic_vector(IRQ_VECTOR);
                oe <= '1';
                irq_ack <= '1'; -- Acknowledge interrupt
                state <= S_DECODE; -- Fetch from vector address
            end if;
        end if;
    end process;

    -- =========================================================================
    -- STATUS REGISTER OUTPUT
    -- Assemble status byte from individual flags and state signals
    -- =========================================================================
    status <= (
        0 => running,       -- bit 0: Running
        1 => halted,        -- bit 1: Halted
        2 => '0',           -- bit 2: Waiting (not used in single core)
        3 => irq,           -- bit 3: IRQ pending
        4 => flag_z,        -- bit 4: Zero flag
        5 => flag_c,        -- bit 5: Carry flag
        6 => flag_n,        -- bit 6: Negative flag
        7 => '0'            -- bit 7: Reserved
    );

    -- Debug output: show register R0
    reg_view <= regs(0);

end architecture rtl;

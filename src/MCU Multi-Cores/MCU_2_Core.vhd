-- ================================================================================
-- MCU_2_Core : Dual-core 8-bit MCU with shared bus arbiter
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- Two independent 8-bit cores share a single memory bus. A simple alternating
-- arbiter grants bus access to each core on alternate cycles.
--
-- 8-BIT INSTRUCTION SET (same as MCU_1_Core):
--   1-byte: MOV(0x0) ADD(0x1) SUB(0x2) AND(0x3) OR(0x4) XOR(0x5) HLT(0xB) NOP(0xC)
--   2-byte: LOAD(0x6) STORE(0x7) JMP(0x8) JZ(0x9) JNZ(0xA)
--   Format: [opcode(7:4) | rd(3:2) rs(1:0)] + optional [addr(7:0)]
--
-- STATUS BYTE per core:
--   bit0=running bit1=halted bit2=waiting bit3=irq bit4=Z bit5=C bit6=N bit7=0
--
-- BUS ARBITER: Alternating (toggle) - core0 on even cycles, core1 on odd
-- The non-active core stalls its state machine until it gets bus access.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity MCU_2_Core is
    port (
        clk      : in  std_logic;                     -- System clock
        reset    : in  std_logic;                     -- Active-high reset
        addr_out : out std_logic_vector(7 downto 0);  -- Shared memory address bus
        data_out : out std_logic_vector(7 downto 0);  -- Shared memory write data
        we       : out std_logic;                     -- Shared write enable
        core0_pc : out std_logic_vector(7 downto 0);  -- Core 0 program counter
        core1_pc : out std_logic_vector(7 downto 0);  -- Core 1 program counter
        data_in  : in  std_logic_vector(7 downto 0);  -- Shared read data
        oe       : out std_logic;                     -- Output enable (read)
        irq0     : in  std_logic;                     -- Core 0 interrupt request
        irq1     : in  std_logic;                     -- Core 1 interrupt request
        irq_ack  : out std_logic_vector(1 downto 0);  -- Per-core interrupt ack
        core0_status : out std_logic_vector(7 downto 0); -- Core 0 status
        core1_status : out std_logic_vector(7 downto 0); -- Core 1 status
        bus_grant : in std_logic                       -- External bus grant (1=allowed)
    );
end entity MCU_2_Core;

architecture rtl of MCU_2_Core is

    -- Opcode constants (upper 4 bits of instruction byte)
    constant OP_MOV   : std_logic_vector(3 downto 0) := "0000";
    constant OP_ADD   : std_logic_vector(3 downto 0) := "0001";
    constant OP_SUB   : std_logic_vector(3 downto 0) := "0010";
    constant OP_AND   : std_logic_vector(3 downto 0) := "0011";
    constant OP_OR    : std_logic_vector(3 downto 0) := "0100";
    constant OP_XOR   : std_logic_vector(3 downto 0) := "0101";
    constant OP_LOAD  : std_logic_vector(3 downto 0) := "0110";
    constant OP_STORE : std_logic_vector(3 downto 0) := "0111";
    constant OP_JMP   : std_logic_vector(3 downto 0) := "1000";
    constant OP_JZ    : std_logic_vector(3 downto 0) := "1001";
    constant OP_JNZ   : std_logic_vector(3 downto 0) := "1010";
    constant OP_HLT   : std_logic_vector(3 downto 0) := "1011";
    constant OP_NOP   : std_logic_vector(3 downto 0) := "1100";
    constant IRQ_VECTOR : unsigned(7 downto 0) := x"FE";

    -- State machine type
    type state_t is (S_FETCH, S_DECODE, S_OPERAND, S_LOAD, S_HALT);

    -- Type definitions for per-core arrays
    type regfile_t is array(0 to 7) of std_logic_vector(7 downto 0);
    type core_regfiles_t is array(0 to 1) of regfile_t;
    type pc_array_t is array(0 to 1) of unsigned(7 downto 0);
    type state_array_t is array(0 to 1) of state_t;
    type opcode_array_t is array(0 to 1) of std_logic_vector(3 downto 0);
    type idx_array_t is array(0 to 1) of integer range 0 to 7;

    -- Per-core state arrays (index 0 = core0, index 1 = core1)
    signal regs_arr      : core_regfiles_t := (others => (others => (others => '0')));
    signal pc_arr        : pc_array_t := (others => (others => '0'));
    signal state_arr     : state_array_t := (others => S_FETCH);
    signal opcode_arr    : opcode_array_t := (others => (others => '0'));
    signal rd_arr        : idx_array_t := (others => 0);
    signal rs_arr        : idx_array_t := (others => 0);
    signal saved_pc_arr  : pc_array_t := (others => (others => '0'));

    -- Per-core flags (bit 0 = core0, bit 1 = core1)
    signal flag_z_arr  : std_logic_vector(1 downto 0) := "00";
    signal flag_c_arr  : std_logic_vector(1 downto 0) := "00";
    signal flag_n_arr  : std_logic_vector(1 downto 0) := "00";
    signal running_arr : std_logic_vector(1 downto 0) := "11";
    signal halted_arr  : std_logic_vector(1 downto 0) := "00";

    -- Bus arbiter: alternating grant (0=core0, 1=core1)
    signal grant : std_logic := '0';

    -- Bus output signals (driven by the active core)
    signal active_addr : std_logic_vector(7 downto 0) := (others => '0');
    signal active_data : std_logic_vector(7 downto 0) := (others => '0');
    signal active_we   : std_logic := '0';
    signal active_oe   : std_logic := '0';

begin

    -- =========================================================================
    -- BUS ARBITER: Alternating grant (toggles each cycle when bus_grant=1)
    -- =========================================================================
    process(clk, reset)
    begin
        if reset = '1' then
            grant <= '0';
        elsif rising_edge(clk) then
            if bus_grant = '1' then
                grant <= not grant; -- Alternate between core0 and core1
            end if;
        end if;
    end process;

    -- =========================================================================
    -- CORE EXECUTION PROCESS: handles both cores
    -- Only the active core (selected by grant) advances its state machine.
    -- The inactive core stalls in its current state until it gets bus access.
    -- =========================================================================
    process(clk, reset)
        variable active : integer range 0 to 1;
        variable opcode : std_logic_vector(3 downto 0);
        variable rd_idx, rs_idx : integer range 0 to 7;
        variable alu_a, alu_b : unsigned(7 downto 0);
        variable alu_sum : unsigned(8 downto 0);
        variable alu_result : std_logic_vector(7 downto 0);
    begin
        if reset = '1' then
            -- Active-high reset: clear all state for both cores
            pc_arr <= (others => (others => '0'));
            state_arr <= (others => S_FETCH);
            regs_arr <= (others => (others => (others => '0')));
            flag_z_arr <= "00"; flag_c_arr <= "00"; flag_n_arr <= "00";
            running_arr <= "11"; halted_arr <= "00";
            active_we <= '0'; active_oe <= '0'; irq_ack <= "00";
            active_addr <= (others => '0'); active_data <= (others => '0');

        elsif rising_edge(clk) then
            -- Determine which core is active this cycle
            if grant = '0' then active := 0; else active := 1; end if;

            -- Default: no bus access, no interrupt ack
            active_we <= '0'; active_oe <= '0'; irq_ack <= "00";

            -- Only the active core can use the bus and advance its state
            if bus_grant = '1' then
                case state_arr(active) is

                    -- S_FETCH: Set up memory read for instruction at PC
                    when S_FETCH =>
                        active_addr <= std_logic_vector(pc_arr(active));
                        active_oe <= '1';
                        state_arr(active) <= S_DECODE;

                    -- S_DECODE: data_in has instruction, decode and execute
                    when S_DECODE =>
                        opcode := data_in(7 downto 4);
                        rd_idx := to_integer(unsigned(data_in(3 downto 2)));
                        rs_idx := to_integer(unsigned(data_in(1 downto 0)));
                        opcode_arr(active) <= opcode;
                        rd_arr(active) <= rd_idx;
                        rs_arr(active) <= rs_idx;

                        case opcode is
                            when OP_MOV => -- MOV rd, rs (1-byte)
                                regs_arr(active)(rd_idx) <= regs_arr(active)(rs_idx);
                                flag_z_arr(active) <= '1' when regs_arr(active)(rs_idx) = x"00" else '0';
                                flag_n_arr(active) <= regs_arr(active)(rs_idx)(7);
                                pc_arr(active) <= pc_arr(active) + 1;
                                active_addr <= std_logic_vector(pc_arr(active) + 1);
                                active_oe <= '1'; state_arr(active) <= S_DECODE;

                            when OP_ADD => -- ADD rd, rs (1-byte)
                                alu_a := unsigned(regs_arr(active)(rd_idx));
                                alu_b := unsigned(regs_arr(active)(rs_idx));
                                alu_sum := ('0' & alu_a) + ('0' & alu_b);
                                alu_result := std_logic_vector(alu_sum(7 downto 0));
                                regs_arr(active)(rd_idx) <= alu_result;
                                flag_z_arr(active) <= '1' when alu_result = x"00" else '0';
                                flag_c_arr(active) <= alu_sum(8);
                                flag_n_arr(active) <= alu_result(7);
                                pc_arr(active) <= pc_arr(active) + 1;
                                active_addr <= std_logic_vector(pc_arr(active) + 1);
                                active_oe <= '1'; state_arr(active) <= S_DECODE;

                            when OP_SUB => -- SUB rd, rs (1-byte)
                                alu_a := unsigned(regs_arr(active)(rd_idx));
                                alu_b := unsigned(regs_arr(active)(rs_idx));
                                alu_sum := ('0' & alu_a) - ('0' & alu_b);
                                alu_result := std_logic_vector(alu_sum(7 downto 0));
                                regs_arr(active)(rd_idx) <= alu_result;
                                flag_z_arr(active) <= '1' when alu_result = x"00" else '0';
                                flag_c_arr(active) <= not alu_sum(8);
                                flag_n_arr(active) <= alu_result(7);
                                pc_arr(active) <= pc_arr(active) + 1;
                                active_addr <= std_logic_vector(pc_arr(active) + 1);
                                active_oe <= '1'; state_arr(active) <= S_DECODE;

                            when OP_AND => -- AND rd, rs (1-byte)
                                alu_result := regs_arr(active)(rd_idx) and regs_arr(active)(rs_idx);
                                regs_arr(active)(rd_idx) <= alu_result;
                                flag_z_arr(active) <= '1' when alu_result = x"00" else '0';
                                flag_n_arr(active) <= alu_result(7);
                                pc_arr(active) <= pc_arr(active) + 1;
                                active_addr <= std_logic_vector(pc_arr(active) + 1);
                                active_oe <= '1'; state_arr(active) <= S_DECODE;

                            when OP_OR => -- OR rd, rs (1-byte)
                                alu_result := regs_arr(active)(rd_idx) or regs_arr(active)(rs_idx);
                                regs_arr(active)(rd_idx) <= alu_result;
                                flag_z_arr(active) <= '1' when alu_result = x"00" else '0';
                                flag_n_arr(active) <= alu_result(7);
                                pc_arr(active) <= pc_arr(active) + 1;
                                active_addr <= std_logic_vector(pc_arr(active) + 1);
                                active_oe <= '1'; state_arr(active) <= S_DECODE;

                            when OP_XOR => -- XOR rd, rs (1-byte)
                                alu_result := regs_arr(active)(rd_idx) xor regs_arr(active)(rs_idx);
                                regs_arr(active)(rd_idx) <= alu_result;
                                flag_z_arr(active) <= '1' when alu_result = x"00" else '0';
                                flag_n_arr(active) <= alu_result(7);
                                pc_arr(active) <= pc_arr(active) + 1;
                                active_addr <= std_logic_vector(pc_arr(active) + 1);
                                active_oe <= '1'; state_arr(active) <= S_DECODE;

                            when OP_HLT => -- HLT (1-byte): halt core
                                state_arr(active) <= S_HALT;
                                running_arr(active) <= '0'; halted_arr(active) <= '1';

                            when OP_NOP => -- NOP (1-byte)
                                pc_arr(active) <= pc_arr(active) + 1;
                                active_addr <= std_logic_vector(pc_arr(active) + 1);
                                active_oe <= '1'; state_arr(active) <= S_DECODE;

                            when others => -- 2-byte: fetch operand byte
                                active_addr <= std_logic_vector(pc_arr(active) + 1);
                                active_oe <= '1'; state_arr(active) <= S_OPERAND;
                        end case;

                    -- S_OPERAND: data_in has operand, execute 2-byte instructions
                    when S_OPERAND =>
                        case opcode_arr(active) is
                            when OP_JMP => -- JMP addr
                                pc_arr(active) <= unsigned(data_in);
                                active_addr <= data_in; active_oe <= '1';
                                state_arr(active) <= S_DECODE;
                            when OP_JZ => -- JZ addr (jump if zero flag set)
                                if flag_z_arr(active) = '1' then
                                    pc_arr(active) <= unsigned(data_in);
                                    active_addr <= data_in;
                                else
                                    pc_arr(active) <= pc_arr(active) + 2;
                                    active_addr <= std_logic_vector(pc_arr(active) + 2);
                                end if;
                                active_oe <= '1'; state_arr(active) <= S_DECODE;
                            when OP_JNZ => -- JNZ addr (jump if zero flag clear)
                                if flag_z_arr(active) = '0' then
                                    pc_arr(active) <= unsigned(data_in);
                                    active_addr <= data_in;
                                else
                                    pc_arr(active) <= pc_arr(active) + 2;
                                    active_addr <= std_logic_vector(pc_arr(active) + 2);
                                end if;
                                active_oe <= '1'; state_arr(active) <= S_DECODE;
                            when OP_LOAD => -- LOAD rd, [addr]: set up memory read
                                active_addr <= data_in; active_oe <= '1';
                                state_arr(active) <= S_LOAD;
                            when OP_STORE => -- STORE [addr], rd: write to memory
                                active_addr <= data_in;
                                active_data <= regs_arr(active)(rd_arr(active));
                                active_we <= '1';
                                pc_arr(active) <= pc_arr(active) + 2;
                                state_arr(active) <= S_FETCH;
                            when others =>
                                pc_arr(active) <= pc_arr(active) + 2;
                                active_addr <= std_logic_vector(pc_arr(active) + 2);
                                active_oe <= '1'; state_arr(active) <= S_DECODE;
                        end case;

                    -- S_LOAD: data_in has loaded byte, store to register
                    when S_LOAD =>
                        regs_arr(active)(rd_arr(active)) <= data_in;
                        flag_z_arr(active) <= '1' when data_in = x"00" else '0';
                        flag_n_arr(active) <= data_in(7);
                        pc_arr(active) <= pc_arr(active) + 2;
                        active_addr <= std_logic_vector(pc_arr(active) + 2);
                        active_oe <= '1'; state_arr(active) <= S_DECODE;

                    -- S_HALT: core stopped, do nothing
                    when S_HALT => null;
                end case;

                -- =============================================================
                -- INTERRUPT HANDLING for the active core
                -- =============================================================
                if (active = 0 and irq0 = '1') or (active = 1 and irq1 = '1') then
                    if state_arr(active) = S_DECODE then
                        saved_pc_arr(active) <= pc_arr(active);
                        pc_arr(active) <= IRQ_VECTOR;
                        active_addr <= std_logic_vector(IRQ_VECTOR);
                        active_oe <= '1';
                        irq_ack(active) <= '1';
                        state_arr(active) <= S_DECODE;
                    end if;
                end if;
            end if; -- bus_grant
        end if; -- rising_edge
    end process;

    -- =========================================================================
    -- BUS OUTPUT: route active core's signals to shared bus
    -- =========================================================================
    addr_out <= active_addr;
    data_out <= active_data;
    we       <= active_we;
    oe       <= active_oe;

    -- Per-core PC outputs (always visible for debugging)
    core0_pc <= std_logic_vector(pc_arr(0));
    core1_pc <= std_logic_vector(pc_arr(1));

    -- Per-core status bytes
    core0_status <= (
        0 => running_arr(0), 1 => halted_arr(0), 2 => not grant,
        3 => irq0, 4 => flag_z_arr(0), 5 => flag_c_arr(0),
        6 => flag_n_arr(0), 7 => '0'
    );
    core1_status <= (
        0 => running_arr(1), 1 => halted_arr(1), 2 => grant,
        3 => irq1, 4 => flag_z_arr(1), 5 => flag_c_arr(1),
        6 => flag_n_arr(1), 7 => '0'
    );

end architecture rtl;

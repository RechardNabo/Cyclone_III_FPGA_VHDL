-- ================================================================================
-- MCU_8_Core : Octa-core 8-bit MCU with priority bus arbiter
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- Eight independent 8-bit cores share a single memory bus. A priority
-- arbiter selects the highest-priority core that has an active bus request.
-- Core 0 has highest priority, core 7 has lowest.
--
-- 8-BIT INSTRUCTION SET (same as MCU_1_Core):
--   1-byte: MOV(0x0) ADD(0x1) SUB(0x2) AND(0x3) OR(0x4) XOR(0x5) HLT(0xB) NOP(0xC)
--   2-byte: LOAD(0x6) STORE(0x7) JMP(0x8) JZ(0x9) JNZ(0xA)
--   Format: [opcode(7:4) | rd(3:2) rs(1:0)] + optional [addr(7:0)]
--
-- STATUS BYTE per core (packed into 64-bit core_status):
--   bit0=running bit1=halted bit2=waiting bit3=irq bit4=Z bit5=C bit6=N bit7=0
--
-- BUS ARBITER: Priority encoded - lowest index with bus_req=1 wins
-- If no bus_req is set, default to core 0
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity MCU_8_Core is
    port (
        clk       : in  std_logic;                     -- System clock
        reset     : in  std_logic;                     -- Active-high reset
        bus_req   : in  std_logic_vector(7 downto 0);  -- Per-core bus requests
        addr_out  : out std_logic_vector(7 downto 0);  -- Shared memory address bus
        data_out  : out std_logic_vector(7 downto 0);  -- Shared memory write data
        we        : out std_logic;                     -- Shared write enable
        active    : out std_logic_vector(2 downto 0);  -- Active core index (0-7)
        grant_ack : out std_logic;                     -- Bus grant acknowledge
        data_in   : in  std_logic_vector(7 downto 0);  -- Shared read data
        oe        : out std_logic;                     -- Output enable (read)
        irq       : in  std_logic_vector(7 downto 0);  -- Per-core interrupt requests
        irq_ack   : out std_logic;                     -- Common interrupt ack
        core_status : out std_logic_vector(63 downto 0) -- 8 x 8-bit status bytes
    );
end entity MCU_8_Core;

architecture rtl of MCU_8_Core is

    -- Opcode constants
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

    type state_t is (S_FETCH, S_DECODE, S_OPERAND, S_LOAD, S_HALT);

    -- Type definitions for per-core arrays (8 cores)
    type regfile_t is array(0 to 7) of std_logic_vector(7 downto 0);
    type core_regfiles_t is array(0 to 7) of regfile_t;
    type pc_array_t is array(0 to 7) of unsigned(7 downto 0);
    type state_array_t is array(0 to 7) of state_t;
    type opcode_array_t is array(0 to 7) of std_logic_vector(3 downto 0);
    type idx_array_t is array(0 to 7) of integer range 0 to 7;
    type flag_array_t is array(0 to 7) of std_logic;

    -- Per-core state
    signal regs_arr   : core_regfiles_t := (others => (others => (others => '0')));
    signal pc_arr     : pc_array_t := (others => (others => '0'));
    signal state_arr  : state_array_t := (others => S_FETCH);
    signal opcode_arr : opcode_array_t := (others => (others => '0'));
    signal rd_arr     : idx_array_t := (others => 0);
    signal rs_arr     : idx_array_t := (others => 0);
    signal flag_z_arr : flag_array_t := (others => '0');
    signal flag_c_arr : flag_array_t := (others => '0');
    signal flag_n_arr : flag_array_t := (others => '0');
    signal running_arr: flag_array_t := (others => '1');
    signal halted_arr : flag_array_t := (others => '0');
    signal hlt_instr_arr : flag_array_t := (others => '0'); -- Halt caused by HLT instruction

    -- Priority arbiter result
    signal winner : integer range 0 to 7 := 0;
    signal found  : std_logic := '0';

    -- Bus output signals (from active core)
    signal active_addr : std_logic_vector(7 downto 0) := (others => '0');
    signal active_data : std_logic_vector(7 downto 0) := (others => '0');
    signal active_we   : std_logic := '0';
    signal active_oe   : std_logic := '0';
    signal irq_ack_reg : std_logic := '0';

begin

    -- =========================================================================
    -- PRIORITY ARBITER: lowest index with bus_req=1 wins (combinational)
    -- =========================================================================
    process(bus_req)
        variable v_winner : integer range 0 to 7;
        variable v_found  : std_logic;
    begin
        v_winner := 0;
        v_found  := '0';
        -- Scan from core 0 (highest priority) to core 7 (lowest)
        for i in 0 to 7 loop
            if bus_req(i) = '1' and v_found = '0' then
                v_winner := i;
                v_found  := '1';
            end if;
        end loop;
        -- If no request, default to core 0
        if v_found = '0' then
            v_winner := 0;
        end if;
        winner <= v_winner;
        found  <= v_found;
    end process;

    active    <= std_logic_vector(to_unsigned(winner, 3));
    grant_ack <= '1'; -- Always grant (defaults to core 0 if no request)

    -- =========================================================================
    -- CORE EXECUTION PROCESS: handles all 8 cores
    -- Only the winning core (selected by priority arbiter) advances.
    -- =========================================================================
    process(clk, reset)
        variable opcode : std_logic_vector(3 downto 0);
        variable rd_idx, rs_idx : integer range 0 to 7;
        variable alu_a, alu_b : unsigned(7 downto 0);
        variable alu_sum : unsigned(8 downto 0);
        variable alu_result : std_logic_vector(7 downto 0);
    begin
        if reset = '1' then
            -- Active-high reset: clear all 8 cores
            pc_arr <= (others => (others => '0'));
            state_arr <= (others => S_FETCH);
            regs_arr <= (others => (others => (others => '0')));
            flag_z_arr <= (others => '0'); flag_c_arr <= (others => '0');
            flag_n_arr <= (others => '0');
            running_arr <= (others => '1'); halted_arr <= (others => '0');
            hlt_instr_arr <= (others => '0');
            active_we <= '0'; active_oe <= '0'; irq_ack_reg <= '0';
            active_addr <= (others => '0'); active_data <= (others => '0');

        elsif rising_edge(clk) then
            -- Default: no bus access, no interrupt ack
            active_we <= '0'; active_oe <= '0'; irq_ack_reg <= '0';

            case state_arr(winner) is

                -- S_FETCH: Set up memory read for instruction at PC
                when S_FETCH =>
                    active_addr <= std_logic_vector(pc_arr(winner));
                    active_oe <= '1';
                    state_arr(winner) <= S_DECODE;

                -- S_DECODE: decode and execute 1-byte instructions
                when S_DECODE =>
                    opcode := data_in(7 downto 4);
                    rd_idx := to_integer(unsigned(data_in(3 downto 2)));
                    rs_idx := to_integer(unsigned(data_in(1 downto 0)));
                    opcode_arr(winner) <= opcode;
                    rd_arr(winner) <= rd_idx;
                    rs_arr(winner) <= rs_idx;

                    case opcode is
                        when OP_MOV =>
                            regs_arr(winner)(rd_idx) <= regs_arr(winner)(rs_idx);
                            flag_z_arr(winner) <= '1' when regs_arr(winner)(rs_idx) = x"00" else '0';
                            flag_n_arr(winner) <= regs_arr(winner)(rs_idx)(7);
                            pc_arr(winner) <= pc_arr(winner) + 1;
                            active_addr <= std_logic_vector(pc_arr(winner) + 1);
                            active_oe <= '1'; state_arr(winner) <= S_DECODE;

                        when OP_ADD =>
                            alu_a := unsigned(regs_arr(winner)(rd_idx));
                            alu_b := unsigned(regs_arr(winner)(rs_idx));
                            alu_sum := ('0' & alu_a) + ('0' & alu_b);
                            alu_result := std_logic_vector(alu_sum(7 downto 0));
                            regs_arr(winner)(rd_idx) <= alu_result;
                            flag_z_arr(winner) <= '1' when alu_result = x"00" else '0';
                            flag_c_arr(winner) <= alu_sum(8);
                            flag_n_arr(winner) <= alu_result(7);
                            pc_arr(winner) <= pc_arr(winner) + 1;
                            active_addr <= std_logic_vector(pc_arr(winner) + 1);
                            active_oe <= '1'; state_arr(winner) <= S_DECODE;

                        when OP_SUB =>
                            alu_a := unsigned(regs_arr(winner)(rd_idx));
                            alu_b := unsigned(regs_arr(winner)(rs_idx));
                            alu_sum := ('0' & alu_a) - ('0' & alu_b);
                            alu_result := std_logic_vector(alu_sum(7 downto 0));
                            regs_arr(winner)(rd_idx) <= alu_result;
                            flag_z_arr(winner) <= '1' when alu_result = x"00" else '0';
                            flag_c_arr(winner) <= not alu_sum(8);
                            flag_n_arr(winner) <= alu_result(7);
                            pc_arr(winner) <= pc_arr(winner) + 1;
                            active_addr <= std_logic_vector(pc_arr(winner) + 1);
                            active_oe <= '1'; state_arr(winner) <= S_DECODE;

                        when OP_AND =>
                            alu_result := regs_arr(winner)(rd_idx) and regs_arr(winner)(rs_idx);
                            regs_arr(winner)(rd_idx) <= alu_result;
                            flag_z_arr(winner) <= '1' when alu_result = x"00" else '0';
                            flag_n_arr(winner) <= alu_result(7);
                            pc_arr(winner) <= pc_arr(winner) + 1;
                            active_addr <= std_logic_vector(pc_arr(winner) + 1);
                            active_oe <= '1'; state_arr(winner) <= S_DECODE;

                        when OP_OR =>
                            alu_result := regs_arr(winner)(rd_idx) or regs_arr(winner)(rs_idx);
                            regs_arr(winner)(rd_idx) <= alu_result;
                            flag_z_arr(winner) <= '1' when alu_result = x"00" else '0';
                            flag_n_arr(winner) <= alu_result(7);
                            pc_arr(winner) <= pc_arr(winner) + 1;
                            active_addr <= std_logic_vector(pc_arr(winner) + 1);
                            active_oe <= '1'; state_arr(winner) <= S_DECODE;

                        when OP_XOR =>
                            alu_result := regs_arr(winner)(rd_idx) xor regs_arr(winner)(rs_idx);
                            regs_arr(winner)(rd_idx) <= alu_result;
                            flag_z_arr(winner) <= '1' when alu_result = x"00" else '0';
                            flag_n_arr(winner) <= alu_result(7);
                            pc_arr(winner) <= pc_arr(winner) + 1;
                            active_addr <= std_logic_vector(pc_arr(winner) + 1);
                            active_oe <= '1'; state_arr(winner) <= S_DECODE;

                        when OP_HLT =>
                            state_arr(winner) <= S_HALT;
                            running_arr(winner) <= '0'; halted_arr(winner) <= '1';
                            hlt_instr_arr(winner) <= '1';

                        when OP_NOP =>
                            pc_arr(winner) <= pc_arr(winner) + 1;
                            active_addr <= std_logic_vector(pc_arr(winner) + 1);
                            active_oe <= '1'; state_arr(winner) <= S_DECODE;

                        when others => -- 2-byte: fetch operand
                            active_addr <= std_logic_vector(pc_arr(winner) + 1);
                            active_oe <= '1'; state_arr(winner) <= S_OPERAND;
                    end case;

                -- S_OPERAND: execute 2-byte instructions
                when S_OPERAND =>
                    case opcode_arr(winner) is
                        when OP_JMP =>
                            pc_arr(winner) <= unsigned(data_in);
                            active_addr <= data_in; active_oe <= '1';
                            state_arr(winner) <= S_DECODE;
                        when OP_JZ =>
                            if flag_z_arr(winner) = '1' then
                                pc_arr(winner) <= unsigned(data_in);
                                active_addr <= data_in;
                            else
                                pc_arr(winner) <= pc_arr(winner) + 2;
                                active_addr <= std_logic_vector(pc_arr(winner) + 2);
                            end if;
                            active_oe <= '1'; state_arr(winner) <= S_DECODE;
                        when OP_JNZ =>
                            if flag_z_arr(winner) = '0' then
                                pc_arr(winner) <= unsigned(data_in);
                                active_addr <= data_in;
                            else
                                pc_arr(winner) <= pc_arr(winner) + 2;
                                active_addr <= std_logic_vector(pc_arr(winner) + 2);
                            end if;
                            active_oe <= '1'; state_arr(winner) <= S_DECODE;
                        when OP_LOAD =>
                            active_addr <= data_in; active_oe <= '1';
                            state_arr(winner) <= S_LOAD;
                        when OP_STORE =>
                            active_addr <= data_in;
                            active_data <= regs_arr(winner)(rd_arr(winner));
                            active_we <= '1';
                            pc_arr(winner) <= pc_arr(winner) + 2;
                            state_arr(winner) <= S_FETCH;
                        when others =>
                            pc_arr(winner) <= pc_arr(winner) + 2;
                            active_addr <= std_logic_vector(pc_arr(winner) + 2);
                            active_oe <= '1'; state_arr(winner) <= S_DECODE;
                    end case;

                -- S_LOAD: store loaded data to register
                when S_LOAD =>
                    regs_arr(winner)(rd_arr(winner)) <= data_in;
                    flag_z_arr(winner) <= '1' when data_in = x"00" else '0';
                    flag_n_arr(winner) <= data_in(7);
                    pc_arr(winner) <= pc_arr(winner) + 2;
                    active_addr <= std_logic_vector(pc_arr(winner) + 2);
                    active_oe <= '1'; state_arr(winner) <= S_DECODE;

                when S_HALT => null;
            end case;

            -- Interrupt handling for winning core
            if irq(winner) = '1' and state_arr(winner) = S_DECODE then
                pc_arr(winner) <= IRQ_VECTOR;
                active_addr <= std_logic_vector(IRQ_VECTOR);
                active_oe <= '1';
                irq_ack_reg <= '1';
                state_arr(winner) <= S_DECODE;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- BUS OUTPUT AND STATUS
    -- =========================================================================
    addr_out <= active_addr;
    data_out <= active_data;
    we       <= active_we;
    oe       <= active_oe;
    irq_ack  <= irq_ack_reg;

    -- Pack 8 x 8-bit status bytes into 64-bit output (VHDL-93 compatible)
    -- core_status(7:0)=core0, (15:8)=core1, ... (63:56)=core7
    process(winner, running_arr, halted_arr, irq, flag_z_arr, flag_c_arr, flag_n_arr)
        variable sb : std_logic_vector(7 downto 0);
    begin
        for i in 0 to 7 loop
            sb := (others => '0');
            sb(0) := running_arr(i);
            sb(1) := halted_arr(i);
            if winner /= i then sb(2) := '1'; end if; -- waiting if not active
            sb(3) := irq(i);
            sb(4) := flag_z_arr(i);
            sb(5) := flag_c_arr(i);
            sb(6) := flag_n_arr(i);
            core_status(i*8 + 7 downto i*8) <= sb;
        end loop;
    end process;

end architecture rtl;

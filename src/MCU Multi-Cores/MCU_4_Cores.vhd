-- ================================================================================
-- MCU_4_Cores : Quad-core 8-bit MCU with round-robin bus arbiter
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- Four independent 8-bit cores share a single memory bus. A round-robin
-- arbiter cycles through cores 0->1->2->3->0 giving each core a turn.
--
-- 8-BIT INSTRUCTION SET (same as MCU_1_Core):
--   1-byte: MOV(0x0) ADD(0x1) SUB(0x2) AND(0x3) OR(0x4) XOR(0x5) HLT(0xB) NOP(0xC)
--   2-byte: LOAD(0x6) STORE(0x7) JMP(0x8) JZ(0x9) JNZ(0xA)
--   Format: [opcode(7:4) | rd(3:2) rs(1:0)] + optional [addr(7:0)]
--
-- STATUS BYTE per core (packed into 32-bit core_status):
--   bit0=running bit1=halted bit2=waiting bit3=irq bit4=Z bit5=C bit6=N bit7=0
--
-- BUS ARBITER: Round-robin (0->1->2->3->0), one core per cycle
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity MCU_4_Cores is
    port (
        clk      : in  std_logic;                     -- System clock
        reset    : in  std_logic;                     -- Active-high reset
        addr_out : out std_logic_vector(7 downto 0);  -- Shared memory address bus
        data_out : out std_logic_vector(7 downto 0);  -- Shared memory write data
        we       : out std_logic;                     -- Shared write enable
        active   : out std_logic_vector(1 downto 0);  -- Active core index (0-3)
        data_in  : in  std_logic_vector(7 downto 0);  -- Shared read data
        oe       : out std_logic;                     -- Output enable (read)
        irq      : in  std_logic_vector(3 downto 0);  -- Per-core interrupt requests
        irq_ack  : out std_logic_vector(3 downto 0);  -- Per-core interrupt acks
        core_status : out std_logic_vector(31 downto 0) -- 4 x 8-bit status bytes
    );
end entity MCU_4_Cores;

architecture rtl of MCU_4_Cores is

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

    -- Type definitions for per-core arrays (4 cores)
    type regfile_t is array(0 to 7) of std_logic_vector(7 downto 0);
    type core_regfiles_t is array(0 to 3) of regfile_t;
    type pc_array_t is array(0 to 3) of unsigned(7 downto 0);
    type state_array_t is array(0 to 3) of state_t;
    type opcode_array_t is array(0 to 3) of std_logic_vector(3 downto 0);
    type idx_array_t is array(0 to 3) of integer range 0 to 7;
    type flag_array_t is array(0 to 3) of std_logic;

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

    -- Round-robin arbiter state
    signal turn : integer range 0 to 3 := 0;

    -- Bus output signals (from active core)
    signal active_addr : std_logic_vector(7 downto 0) := (others => '0');
    signal active_data : std_logic_vector(7 downto 0) := (others => '0');
    signal active_we   : std_logic := '0';
    signal active_oe   : std_logic := '0';
    signal irq_ack_reg : std_logic_vector(3 downto 0) := "0000";

begin

    -- =========================================================================
    -- ROUND-ROBIN ARBITER: cycles through cores 0->1->2->3->0
    -- =========================================================================
    process(clk, reset)
    begin
        if reset = '1' then
            turn <= 0;
        elsif rising_edge(clk) then
            if turn = 3 then turn <= 0;
            else turn <= turn + 1; end if;
        end if;
    end process;

    active <= std_logic_vector(to_unsigned(turn, 2));

    -- =========================================================================
    -- CORE EXECUTION PROCESS: handles all 4 cores
    -- Only the active core (selected by turn) advances its state machine.
    -- =========================================================================
    process(clk, reset)
        variable opcode : std_logic_vector(3 downto 0);
        variable rd_idx, rs_idx : integer range 0 to 7;
        variable alu_a, alu_b : unsigned(7 downto 0);
        variable alu_sum : unsigned(8 downto 0);
        variable alu_result : std_logic_vector(7 downto 0);
    begin
        if reset = '1' then
            pc_arr <= (others => (others => '0'));
            state_arr <= (others => S_FETCH);
            regs_arr <= (others => (others => (others => '0')));
            flag_z_arr <= (others => '0'); flag_c_arr <= (others => '0');
            flag_n_arr <= (others => '0');
            running_arr <= (others => '1'); halted_arr <= (others => '0');
            active_we <= '0'; active_oe <= '0'; irq_ack_reg <= "0000";
            active_addr <= (others => '0'); active_data <= (others => '0');

        elsif rising_edge(clk) then
            -- Default: no bus access, no interrupt ack
            active_we <= '0'; active_oe <= '0'; irq_ack_reg <= "0000";

            case state_arr(turn) is

                when S_FETCH =>
                    active_addr <= std_logic_vector(pc_arr(turn));
                    active_oe <= '1';
                    state_arr(turn) <= S_DECODE;

                when S_DECODE =>
                    opcode := data_in(7 downto 4);
                    rd_idx := to_integer(unsigned(data_in(3 downto 2)));
                    rs_idx := to_integer(unsigned(data_in(1 downto 0)));
                    opcode_arr(turn) <= opcode;
                    rd_arr(turn) <= rd_idx;
                    rs_arr(turn) <= rs_idx;

                    case opcode is
                        when OP_MOV =>
                            regs_arr(turn)(rd_idx) <= regs_arr(turn)(rs_idx);
                            flag_z_arr(turn) <= '1' when regs_arr(turn)(rs_idx) = x"00" else '0';
                            flag_n_arr(turn) <= regs_arr(turn)(rs_idx)(7);
                            pc_arr(turn) <= pc_arr(turn) + 1;
                            active_addr <= std_logic_vector(pc_arr(turn) + 1);
                            active_oe <= '1'; state_arr(turn) <= S_DECODE;

                        when OP_ADD =>
                            alu_a := unsigned(regs_arr(turn)(rd_idx));
                            alu_b := unsigned(regs_arr(turn)(rs_idx));
                            alu_sum := ('0' & alu_a) + ('0' & alu_b);
                            alu_result := std_logic_vector(alu_sum(7 downto 0));
                            regs_arr(turn)(rd_idx) <= alu_result;
                            flag_z_arr(turn) <= '1' when alu_result = x"00" else '0';
                            flag_c_arr(turn) <= alu_sum(8);
                            flag_n_arr(turn) <= alu_result(7);
                            pc_arr(turn) <= pc_arr(turn) + 1;
                            active_addr <= std_logic_vector(pc_arr(turn) + 1);
                            active_oe <= '1'; state_arr(turn) <= S_DECODE;

                        when OP_SUB =>
                            alu_a := unsigned(regs_arr(turn)(rd_idx));
                            alu_b := unsigned(regs_arr(turn)(rs_idx));
                            alu_sum := ('0' & alu_a) - ('0' & alu_b);
                            alu_result := std_logic_vector(alu_sum(7 downto 0));
                            regs_arr(turn)(rd_idx) <= alu_result;
                            flag_z_arr(turn) <= '1' when alu_result = x"00" else '0';
                            flag_c_arr(turn) <= not alu_sum(8);
                            flag_n_arr(turn) <= alu_result(7);
                            pc_arr(turn) <= pc_arr(turn) + 1;
                            active_addr <= std_logic_vector(pc_arr(turn) + 1);
                            active_oe <= '1'; state_arr(turn) <= S_DECODE;

                        when OP_AND =>
                            alu_result := regs_arr(turn)(rd_idx) and regs_arr(turn)(rs_idx);
                            regs_arr(turn)(rd_idx) <= alu_result;
                            flag_z_arr(turn) <= '1' when alu_result = x"00" else '0';
                            flag_n_arr(turn) <= alu_result(7);
                            pc_arr(turn) <= pc_arr(turn) + 1;
                            active_addr <= std_logic_vector(pc_arr(turn) + 1);
                            active_oe <= '1'; state_arr(turn) <= S_DECODE;

                        when OP_OR =>
                            alu_result := regs_arr(turn)(rd_idx) or regs_arr(turn)(rs_idx);
                            regs_arr(turn)(rd_idx) <= alu_result;
                            flag_z_arr(turn) <= '1' when alu_result = x"00" else '0';
                            flag_n_arr(turn) <= alu_result(7);
                            pc_arr(turn) <= pc_arr(turn) + 1;
                            active_addr <= std_logic_vector(pc_arr(turn) + 1);
                            active_oe <= '1'; state_arr(turn) <= S_DECODE;

                        when OP_XOR =>
                            alu_result := regs_arr(turn)(rd_idx) xor regs_arr(turn)(rs_idx);
                            regs_arr(turn)(rd_idx) <= alu_result;
                            flag_z_arr(turn) <= '1' when alu_result = x"00" else '0';
                            flag_n_arr(turn) <= alu_result(7);
                            pc_arr(turn) <= pc_arr(turn) + 1;
                            active_addr <= std_logic_vector(pc_arr(turn) + 1);
                            active_oe <= '1'; state_arr(turn) <= S_DECODE;

                        when OP_HLT =>
                            state_arr(turn) <= S_HALT;
                            running_arr(turn) <= '0'; halted_arr(turn) <= '1';

                        when OP_NOP =>
                            pc_arr(turn) <= pc_arr(turn) + 1;
                            active_addr <= std_logic_vector(pc_arr(turn) + 1);
                            active_oe <= '1'; state_arr(turn) <= S_DECODE;

                        when others => -- 2-byte: fetch operand
                            active_addr <= std_logic_vector(pc_arr(turn) + 1);
                            active_oe <= '1'; state_arr(turn) <= S_OPERAND;
                    end case;

                when S_OPERAND =>
                    case opcode_arr(turn) is
                        when OP_JMP =>
                            pc_arr(turn) <= unsigned(data_in);
                            active_addr <= data_in; active_oe <= '1';
                            state_arr(turn) <= S_DECODE;
                        when OP_JZ =>
                            if flag_z_arr(turn) = '1' then
                                pc_arr(turn) <= unsigned(data_in);
                                active_addr <= data_in;
                            else
                                pc_arr(turn) <= pc_arr(turn) + 2;
                                active_addr <= std_logic_vector(pc_arr(turn) + 2);
                            end if;
                            active_oe <= '1'; state_arr(turn) <= S_DECODE;
                        when OP_JNZ =>
                            if flag_z_arr(turn) = '0' then
                                pc_arr(turn) <= unsigned(data_in);
                                active_addr <= data_in;
                            else
                                pc_arr(turn) <= pc_arr(turn) + 2;
                                active_addr <= std_logic_vector(pc_arr(turn) + 2);
                            end if;
                            active_oe <= '1'; state_arr(turn) <= S_DECODE;
                        when OP_LOAD =>
                            active_addr <= data_in; active_oe <= '1';
                            state_arr(turn) <= S_LOAD;
                        when OP_STORE =>
                            active_addr <= data_in;
                            active_data <= regs_arr(turn)(rd_arr(turn));
                            active_we <= '1';
                            pc_arr(turn) <= pc_arr(turn) + 2;
                            state_arr(turn) <= S_FETCH;
                        when others =>
                            pc_arr(turn) <= pc_arr(turn) + 2;
                            active_addr <= std_logic_vector(pc_arr(turn) + 2);
                            active_oe <= '1'; state_arr(turn) <= S_DECODE;
                    end case;

                when S_LOAD =>
                    regs_arr(turn)(rd_arr(turn)) <= data_in;
                    flag_z_arr(turn) <= '1' when data_in = x"00" else '0';
                    flag_n_arr(turn) <= data_in(7);
                    pc_arr(turn) <= pc_arr(turn) + 2;
                    active_addr <= std_logic_vector(pc_arr(turn) + 2);
                    active_oe <= '1'; state_arr(turn) <= S_DECODE;

                when S_HALT => null;
            end case;

            -- Interrupt handling for active core
            if irq(turn) = '1' and state_arr(turn) = S_DECODE then
                pc_arr(turn) <= IRQ_VECTOR;
                active_addr <= std_logic_vector(IRQ_VECTOR);
                active_oe <= '1';
                irq_ack_reg(turn) <= '1';
                state_arr(turn) <= S_DECODE;
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

    -- Pack 4 x 8-bit status bytes into 32-bit output (VHDL-93 compatible)
    -- core_status(7:0)=core0, (15:8)=core1, (23:16)=core2, (31:24)=core3
    process(turn, running_arr, halted_arr, irq, flag_z_arr, flag_c_arr, flag_n_arr)
        variable sb : std_logic_vector(7 downto 0);
    begin
        for i in 0 to 3 loop
            sb := (others => '0');
            sb(0) := running_arr(i);
            sb(1) := halted_arr(i);
            if turn /= i then sb(2) := '1'; end if; -- waiting if not active
            sb(3) := irq(i);
            sb(4) := flag_z_arr(i);
            sb(5) := flag_c_arr(i);
            sb(6) := flag_n_arr(i);
            core_status(i*8 + 7 downto i*8) <= sb;
        end loop;
    end process;

end architecture rtl;

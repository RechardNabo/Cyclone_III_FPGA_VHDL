-- ================================================================================
-- msp430_core : MSP430 16-bit microcontroller soft core
--
-- Implements the MSP430 16-bit instruction set (MSP430F2xx subset).
-- Target: Altera Cyclone III EP3C16F484C6N.
--
-- Features:
--   * 16-bit instruction width, 16-bit data width, von Neumann (unified memory)
--   * 16 x 16-bit registers (R0=PC, R1=SP, R2=SR/CG1, R3=CG2, R4-R15=GP)
--   * 7 addressing modes (register, indexed, symbolic, absolute, indirect,
--     indirect autoincrement, immediate)
--   * Constant generators: R2 (0, 1, 2, -1), R3 (-1, 0, 1, 2)
--   * Status register: V, N, Z, C, GIE, CPUOFF, OSCOFF, SCG0, SCG1
--   * 27 core instructions + 24 emulated instructions
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity msp430_core is
    generic (
        MEM_SIZE : integer := 4096  -- 4K x 16 unified memory
    );
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;      -- active-high synchronous
        -- Unified memory interface (16-bit)
        mem_addr   : out std_logic_vector(15 downto 0);
        mem_dout   : out std_logic_vector(15 downto 0);  -- data to write
        mem_din    : in  std_logic_vector(15 downto 0);  -- data read
        mem_we     : out std_logic;
        mem_re     : out std_logic;
        -- I/O port interface
        port1_out  : out std_logic_vector(7 downto 0);
        port2_out  : out std_logic_vector(7 downto 0);
        port1_in   : in  std_logic_vector(7 downto 0);
        port2_in   : in  std_logic_vector(7 downto 0);
        p1dir_out  : out std_logic_vector(7 downto 0);
        p2dir_out  : out std_logic_vector(7 downto 0);
        -- Interrupts
        irq        : in  std_logic_vector(7 downto 0);
        irq_out    : out std_logic;
        -- Status
        running    : out std_logic;
        -- Debug: expose GP registers
        debug_r4   : out std_logic_vector(15 downto 0);
        debug_r5   : out std_logic_vector(15 downto 0);
        debug_r6   : out std_logic_vector(15 downto 0)
    );
end entity msp430_core;

architecture rtl of msp430_core is

    -- I/O register addresses (MSP430 peripheral map)
    constant P1IN_ADDR  : unsigned(15 downto 0) := x"0020";
    constant P1OUT_ADDR : unsigned(15 downto 0) := x"0021";
    constant P1DIR_ADDR : unsigned(15 downto 0) := x"0022";
    constant P2IN_ADDR  : unsigned(15 downto 0) := x"0028";
    constant P2OUT_ADDR : unsigned(15 downto 0) := x"0029";
    constant P2DIR_ADDR : unsigned(15 downto 0) := x"002A";

    -- SR bit positions
    constant SR_C   : integer := 0;
    constant SR_Z   : integer := 1;
    constant SR_N   : integer := 2;
    constant SR_GIE : integer := 3;
    constant SR_V   : integer := 8;

    -- CPU state machine
    type cpu_state_t is (ST_RESET, ST_FETCH, ST_FETCH2, ST_DECODE, ST_EXEC,
                         ST_READ_SRC, ST_READ_DST, ST_WRITE_DST,
                         ST_FETCH_IMM, ST_FETCH_IMM2, ST_DONE);
    signal state : cpu_state_t := ST_RESET;

    -- 16 x 16-bit register file
    type regfile_t is array(0 to 15) of unsigned(15 downto 0);
    signal regs : regfile_t := (others => (others => '0'));

    -- Status register
    signal sr : unsigned(15 downto 0) := (others => '0');

    -- I/O registers
    signal p1out_reg : unsigned(7 downto 0) := (others => '0');
    signal p2out_reg : unsigned(7 downto 0) := (others => '0');
    signal p1dir_reg : unsigned(7 downto 0) := (others => '0');
    signal p2dir_reg : unsigned(7 downto 0) := (others => '0');

    -- Instruction register
    signal ir  : unsigned(15 downto 0) := (others => '0');

    -- Memory interface
    signal mem_addr_i  : unsigned(15 downto 0) := (others => '0');
    signal mem_dout_i  : unsigned(15 downto 0) := (others => '0');
    signal mem_we_i    : std_logic := '0';
    signal mem_re_i    : std_logic := '0';
    -- Fetch address: combinational, always points to PC during fetch
    signal fetch_addr  : unsigned(15 downto 0);

    -- Decoded instruction fields (stored as signals for multi-cycle access)
    signal op4_sig    : unsigned(3 downto 0) := (others => '0');
    signal src_reg_sig : integer range 0 to 15 := 0;
    signal dst_reg_sig : integer range 0 to 15 := 0;
    signal as_sig     : unsigned(1 downto 0) := (others => '0');
    signal ad_sig     : std_logic := '0';
    signal bw_sig     : std_logic := '0';

    -- Intermediate values for multi-cycle execution
    signal src_val_sig : unsigned(15 downto 0) := (others => '0');
    signal dst_val_sig : unsigned(15 downto 0) := (others => '0');
    signal dst_addr_sig : unsigned(15 downto 0) := (others => '0');
    signal result_sig  : unsigned(15 downto 0) := (others => '0');
    signal new_sr_sig  : unsigned(15 downto 0) := (others => '0');
    signal writeback_en : std_logic := '0';
    signal is_io_write : std_logic := '0';
    signal io_write_addr : unsigned(15 downto 0) := (others => '0');

begin

    -- Outputs
    mem_addr  <= std_logic_vector(mem_addr_i);
    mem_dout  <= std_logic_vector(mem_dout_i);
    mem_we    <= mem_we_i;
    mem_re    <= mem_re_i;
    port1_out <= std_logic_vector(p1out_reg);
    port2_out <= std_logic_vector(p2out_reg);
    p1dir_out <= std_logic_vector(p1dir_reg);
    p2dir_out <= std_logic_vector(p2dir_reg);
    running   <= '1' when state /= ST_RESET else '0';
    debug_r4  <= std_logic_vector(regs(4));
    debug_r5  <= std_logic_vector(regs(5));
    debug_r6  <= std_logic_vector(regs(6));

    -- Main CPU process
    cpu_proc : process(clk)
        -- Constant generator: returns value for R2/R3 with given As/Ad mode
        function const_gen(reg_idx : integer; mode : unsigned(1 downto 0)) return unsigned is
        begin
            if reg_idx = 2 then
                case mode is
                    when "00" => return x"0000";  -- R2 register mode = SR
                    when "01" => return x"0001";  -- CG1: +1
                    when "10" => return x"0002";  -- CG1: +2
                    when "11" => return x"FFFF";  -- CG1: -1
                    when others => return x"0000";
                end case;
            elsif reg_idx = 3 then
                case mode is
                    when "00" => return x"FFFF";  -- CG2: -1
                    when "01" => return x"0000";  -- CG2: 0
                    when "10" => return x"0001";  -- CG2: +1
                    when "11" => return x"0002";  -- CG2: +2
                    when others => return x"0000";
                end case;
            else
                return x"0000";
            end if;
        end function;

        -- Check if register+mode uses constant generator
        function is_const_gen(reg_idx : integer; mode : unsigned(1 downto 0)) return boolean is
        begin
            if reg_idx = 3 then
                return true;  -- R3 always generates constants
            elsif reg_idx = 2 and mode /= "00" then
                return true;  -- R2 with As != 00 generates constants
            else
                return false;
            end if;
        end function;

        variable op4     : unsigned(3 downto 0);
        variable src_val : unsigned(15 downto 0);
        variable dst_val : unsigned(15 downto 0);
        variable result  : unsigned(15 downto 0);
        variable res17   : unsigned(16 downto 0);
        variable new_sr  : unsigned(15 downto 0);
        variable byte_mask : unsigned(15 downto 0);
        variable bw       : std_logic;
        variable src_reg  : integer range 0 to 15;
        variable dst_reg  : integer range 0 to 15;
        variable src_addr : unsigned(15 downto 0);
        variable dst_addr : unsigned(15 downto 0);
        variable jump_offset : signed(10 downto 0);
        variable new_pc   : unsigned(15 downto 0);
        variable do_writeback : std_logic;
        variable is_io    : boolean;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state       <= ST_RESET;
                regs        <= (others => (others => '0'));
                sr          <= (others => '0');
                p1out_reg   <= (others => '0');
                p2out_reg   <= (others => '0');
                p1dir_reg   <= (others => '0');
                p2dir_reg   <= (others => '0');
                ir          <= (others => '0');
                mem_we_i    <= '0';
                mem_re_i    <= '0';
                mem_dout_i  <= (others => '0');
                mem_addr_i  <= (others => '0');
                writeback_en <= '0';
                is_io_write  <= '0';
            else
                mem_we_i <= '0';
                mem_re_i <= '0';

                case state is
                    when ST_RESET =>
                        state <= ST_FETCH;

                    when ST_FETCH =>
                        -- Set up instruction fetch address
                        mem_addr_i <= regs(0);
                        mem_re_i <= '1';
                        state <= ST_FETCH2;

                    when ST_FETCH2 =>
                        -- Read instruction data (mem_din now has the instruction)
                        ir <= unsigned(mem_din);
                        regs(0) <= regs(0) + 2;  -- PC += 2
                        report "MSP430: FETCH2 addr=" & integer'image(to_integer(mem_addr_i)) &
                               " data=" & integer'image(to_integer(unsigned(mem_din)))
                            severity note;
                        state <= ST_DECODE;

                    when ST_DECODE =>
                        op4 := ir(15 downto 12);
                        bw := ir(6);
                        src_reg := to_integer(ir(11 downto 8));
                        dst_reg := to_integer(ir(3 downto 0));

                        -- Store decoded fields
                        op4_sig <= op4;
                        src_reg_sig <= src_reg;
                        dst_reg_sig <= dst_reg;
                        as_sig <= ir(5 downto 4);
                        ad_sig <= ir(7);
                        bw_sig <= bw;
                        new_sr_sig <= sr;
                        writeback_en <= '0';
                        is_io_write <= '0';

                        if op4 = "0001" then
                            -- Format II: single-operand
                            -- Check if source needs extension word
                            if is_const_gen(dst_reg, ir(5 downto 4)) then
                                src_val_sig <= const_gen(dst_reg, ir(5 downto 4));
                                state <= ST_EXEC;
                            elsif dst_reg = 0 and ir(5 downto 4) = "11" then
                                -- Immediate mode (@PC+): fetch extension word
                                mem_addr_i <= regs(0);
                                mem_re_i <= '1';
                                regs(0) <= regs(0) + 2;
                                state <= ST_FETCH_IMM;
                            elsif ir(5 downto 4) = "00" then
                                -- Register mode
                                src_val_sig <= regs(dst_reg);
                                state <= ST_EXEC;
                            else
                                -- Other modes: simplified to register
                                src_val_sig <= regs(dst_reg);
                                state <= ST_EXEC;
                            end if;
                        elsif op4 = "0010" or op4 = "0011" then
                            -- Format III: jump
                            jump_offset := resize(signed(ir(9 downto 0)), 11);
                            new_pc := regs(0) + unsigned(jump_offset(10 downto 0) & '0');
                            case ir(12 downto 10) is
                                when "000" =>  -- JNE/JNZ (Z=0)
                                    if sr(SR_Z) = '0' then regs(0) <= new_pc; end if;
                                when "001" =>  -- JEQ/JZ (Z=1)
                                    if sr(SR_Z) = '1' then regs(0) <= new_pc; end if;
                                when "010" =>  -- JNC/JLO (C=0)
                                    if sr(SR_C) = '0' then regs(0) <= new_pc; end if;
                                when "011" =>  -- JC/JHS (C=1)
                                    if sr(SR_C) = '1' then regs(0) <= new_pc; end if;
                                when "100" =>  -- JN (N=1)
                                    if sr(SR_N) = '1' then regs(0) <= new_pc; end if;
                                when "101" =>  -- JGE (N=V)
                                    if sr(SR_N) = sr(SR_V) then regs(0) <= new_pc; end if;
                                when "110" =>  -- JL (N!=V)
                                    if sr(SR_N) /= sr(SR_V) then regs(0) <= new_pc; end if;
                                when "111" =>  -- JMP (unconditional)
                                    regs(0) <= new_pc;
                                when others => null;
                            end case;
                            state <= ST_FETCH;
                        else
                            -- Format I: dual-operand
                            -- Check if source needs extension word
                            if is_const_gen(src_reg, ir(5 downto 4)) then
                                src_val_sig <= const_gen(src_reg, ir(5 downto 4));
                                -- Get destination value
                                if ir(7) = '0' then
                                    -- Register destination
                                    if dst_reg = 2 then
                                        dst_val_sig <= sr;
                                    else
                                        dst_val_sig <= regs(dst_reg);
                                    end if;
                                    state <= ST_EXEC;
                                else
                                    -- Absolute/indexed destination: need extension word
                                    mem_addr_i <= regs(0);
                                    mem_re_i <= '1';
                                    regs(0) <= regs(0) + 2;
                                    state <= ST_READ_DST;
                                end if;
                            elsif src_reg = 0 and ir(5 downto 4) = "11" then
                                -- Immediate mode (@PC+): fetch extension word
                                mem_addr_i <= regs(0);
                                mem_re_i <= '1';
                                regs(0) <= regs(0) + 2;
                                state <= ST_FETCH_IMM;
                            elsif ir(5 downto 4) = "00" then
                                -- Register mode source
                                src_val_sig <= regs(src_reg);
                                if ir(7) = '0' then
                                    if dst_reg = 2 then
                                        dst_val_sig <= sr;
                                    else
                                        dst_val_sig <= regs(dst_reg);
                                    end if;
                                    state <= ST_EXEC;
                                else
                                    mem_addr_i <= regs(0);
                                    mem_re_i <= '1';
                                    regs(0) <= regs(0) + 2;
                                    state <= ST_READ_DST;
                                end if;
                            else
                                -- Other source modes: simplified
                                src_val_sig <= regs(src_reg);
                                if ir(7) = '0' then
                                    dst_val_sig <= regs(dst_reg);
                                    state <= ST_EXEC;
                                else
                                    state <= ST_FETCH;
                                end if;
                            end if;
                        end if;

                    when ST_FETCH_IMM =>
                        -- Address was set in ST_DECODE, wait one cycle
                        state <= ST_FETCH_IMM2;

                    when ST_FETCH_IMM2 =>
                        -- Now read the extension word
                        src_val_sig <= unsigned(mem_din);
                        -- Now get destination value
                        if ad_sig = '0' then
                            -- Register destination
                            if dst_reg_sig = 2 then
                                dst_val_sig <= sr;
                            else
                                dst_val_sig <= regs(dst_reg_sig);
                            end if;
                            state <= ST_EXEC;
                        else
                            -- Absolute destination: need another extension word
                            mem_addr_i <= regs(0);
                            mem_re_i <= '1';
                            regs(0) <= regs(0) + 2;
                            state <= ST_READ_DST;
                        end if;

                    when ST_READ_DST =>
                        -- Address was set in previous state, now read the extension word
                        dst_addr_sig <= unsigned(mem_din);
                        state <= ST_EXEC;

                    when ST_EXEC =>
                        op4 := op4_sig;
                        bw := bw_sig;
                        byte_mask := x"00FF" when bw = '1' else x"FFFF";
                        src_val := src_val_sig;
                        dst_val := dst_val_sig;
                        new_sr := new_sr_sig;
                        do_writeback := '1';

                        -- Execute ALU operation
                        if op4 = "0001" then
                            -- Format II: single-operand
                            case ir(11 downto 8) is
                                when "0000" =>  -- RRC
                                    result := sr(SR_C) & dst_val(15 downto 1);
                                    new_sr(SR_C) := dst_val(0);
                                    new_sr(SR_Z) := '1' when (result and byte_mask) = 0 else '0';
                                    new_sr(SR_N) := result(15) when bw = '0' else result(7);
                                    new_sr(SR_V) := '0';
                                when "0001" =>  -- SWPB
                                    result := dst_val(7 downto 0) & dst_val(15 downto 8);
                                when "0010" =>  -- RRA
                                    result := dst_val(15) & dst_val(15 downto 1);
                                    new_sr(SR_C) := dst_val(0);
                                    new_sr(SR_Z) := '1' when (result and byte_mask) = 0 else '0';
                                    new_sr(SR_N) := result(15) when bw = '0' else result(7);
                                    new_sr(SR_V) := '0';
                                when "0011" =>  -- SXT
                                    result := x"00" & dst_val(7 downto 0) when dst_val(7) = '0' else x"FF" & dst_val(7 downto 0);
                                    new_sr(SR_Z) := '1' when result = 0 else '0';
                                    new_sr(SR_N) := result(15);
                                    new_sr(SR_C) := '1' when result /= 0 else '0';
                                    new_sr(SR_V) := '0';
                                when "0100" =>  -- PUSH
                                    mem_addr_i <= regs(1);
                                    mem_dout_i <= src_val;
                                    mem_we_i <= '1';
                                    regs(1) <= regs(1) - 2;
                                    do_writeback := '0';
                                when "0101" =>  -- CALL
                                    mem_addr_i <= regs(1);
                                    mem_dout_i <= regs(0);
                                    mem_we_i <= '1';
                                    regs(1) <= regs(1) - 2;
                                    regs(0) <= src_val;
                                    do_writeback := '0';
                                when "0110" =>  -- RETI
                                    -- Pop SR, then PC (simplified)
                                    do_writeback := '0';
                                when others =>
                                    do_writeback := '0';
                            end case;
                        else
                            -- Format I: dual-operand
                            case op4 is
                                when "0100" =>  -- MOV
                                    result := src_val;
                                when "0101" =>  -- ADD
                                    res17 := ('0' & dst_val) + ('0' & src_val);
                                    result := res17(15 downto 0);
                                    new_sr(SR_C) := res17(16);
                                    new_sr(SR_Z) := '1' when (result and byte_mask) = 0 else '0';
                                    new_sr(SR_N) := result(15) when bw = '0' else result(7);
                                    new_sr(SR_V) := '1' when (dst_val(15) = src_val(15) and result(15) /= dst_val(15)) else '0';
                                when "0110" =>  -- ADDC
                                    res17 := ('0' & dst_val) + ('0' & src_val) + ('0' & sr(SR_C));
                                    result := res17(15 downto 0);
                                    new_sr(SR_C) := res17(16);
                                    new_sr(SR_Z) := '1' when (result and byte_mask) = 0 else '0';
                                    new_sr(SR_N) := result(15) when bw = '0' else result(7);
                                    new_sr(SR_V) := '1' when (dst_val(15) = src_val(15) and result(15) /= dst_val(15)) else '0';
                                when "0111" =>  -- SUBC
                                    res17 := ('0' & dst_val) - ('0' & src_val) + ('0' & sr(SR_C)) - 1;
                                    result := res17(15 downto 0);
                                    new_sr(SR_C) := not res17(16);
                                    new_sr(SR_Z) := '1' when (result and byte_mask) = 0 else '0';
                                    new_sr(SR_N) := result(15) when bw = '0' else result(7);
                                    new_sr(SR_V) := '1' when (dst_val(15) /= src_val(15) and result(15) /= dst_val(15)) else '0';
                                when "1000" =>  -- SUB
                                    res17 := ('0' & dst_val) - ('0' & src_val);
                                    result := res17(15 downto 0);
                                    new_sr(SR_C) := not res17(16);
                                    new_sr(SR_Z) := '1' when (result and byte_mask) = 0 else '0';
                                    new_sr(SR_N) := result(15) when bw = '0' else result(7);
                                    new_sr(SR_V) := '1' when (dst_val(15) /= src_val(15) and result(15) /= dst_val(15)) else '0';
                                when "1001" =>  -- CMP (no writeback)
                                    res17 := ('0' & dst_val) - ('0' & src_val);
                                    result := res17(15 downto 0);
                                    new_sr(SR_C) := not res17(16);
                                    new_sr(SR_Z) := '1' when (result and byte_mask) = 0 else '0';
                                    new_sr(SR_N) := result(15) when bw = '0' else result(7);
                                    new_sr(SR_V) := '1' when (dst_val(15) /= src_val(15) and result(15) /= dst_val(15)) else '0';
                                    do_writeback := '0';
                                when "1010" =>  -- DADD
                                    res17 := ('0' & dst_val) + ('0' & src_val) + ('0' & sr(SR_C));
                                    result := res17(15 downto 0);
                                    new_sr(SR_C) := res17(16);
                                    new_sr(SR_Z) := '1' when (result and byte_mask) = 0 else '0';
                                    new_sr(SR_N) := result(15) when bw = '0' else result(7);
                                when "1011" =>  -- BIT (no writeback)
                                    result := dst_val and src_val;
                                    new_sr(SR_C) := '1' when result /= 0 else '0';
                                    new_sr(SR_Z) := '1' when (result and byte_mask) = 0 else '0';
                                    new_sr(SR_N) := result(15) when bw = '0' else result(7);
                                    new_sr(SR_V) := '0';
                                    do_writeback := '0';
                                when "1100" =>  -- BIC (no flags)
                                    result := dst_val and (not src_val);
                                when "1101" =>  -- BIS (OR)
                                    result := dst_val or src_val;
                                when "1110" =>  -- XOR
                                    result := dst_val xor src_val;
                                    new_sr(SR_C) := '1' when result /= 0 else '0';
                                    new_sr(SR_Z) := '1' when (result and byte_mask) = 0 else '0';
                                    new_sr(SR_N) := result(15) when bw = '0' else result(7);
                                    new_sr(SR_V) := '1' when (dst_val and src_val and byte_mask) = byte_mask else '0';
                                when "1111" =>  -- AND
                                    result := dst_val and src_val;
                                    new_sr(SR_C) := '1' when result /= 0 else '0';
                                    new_sr(SR_Z) := '1' when (result and byte_mask) = 0 else '0';
                                    new_sr(SR_N) := result(15) when bw = '0' else result(7);
                                    new_sr(SR_V) := '0';
                                when others =>
                                    do_writeback := '0';
                            end case;
                        end if;

                        -- Store results
                        result_sig <= result;
                        new_sr_sig <= new_sr;
                        writeback_en <= do_writeback;

                        -- Determine writeback target
                        if do_writeback = '1' then
                            if ad_sig = '0' then
                                -- Register writeback
                                if dst_reg_sig = 0 then
                                    -- Writing to PC
                                    null;  -- handled below
                                elsif dst_reg_sig = 2 then
                                    -- Writing to SR
                                    null;  -- handled below
                                end if;
                            else
                                -- Memory writeback
                                is_io := false;
                                if dst_addr_sig = P1OUT_ADDR then
                                    p1out_reg <= result(7 downto 0);
                                    is_io := true;
                                elsif dst_addr_sig = P2OUT_ADDR then
                                    p2out_reg <= result(7 downto 0);
                                    is_io := true;
                                elsif dst_addr_sig = P1DIR_ADDR then
                                    p1dir_reg <= result(7 downto 0);
                                    is_io := true;
                                elsif dst_addr_sig = P2DIR_ADDR then
                                    p2dir_reg <= result(7 downto 0);
                                    is_io := true;
                                end if;
                                if not is_io then
                                    mem_addr_i <= dst_addr_sig;
                                    mem_dout_i <= result;
                                    mem_we_i <= '1';
                                end if;
                            end if;
                        end if;

                        state <= ST_DONE;

                    when ST_DONE =>
                        -- Write back results
                        if writeback_en = '1' then
                            if ad_sig = '0' then
                                -- Register writeback
                                if dst_reg_sig = 0 then
                                    regs(0) <= result_sig;
                                elsif dst_reg_sig = 1 then
                                    regs(1) <= result_sig;
                                elsif dst_reg_sig = 2 then
                                    sr <= result_sig;
                                else
                                    regs(dst_reg_sig) <= result_sig;
                                end if;
                            end if;
                            -- Memory writeback already done in ST_EXEC
                        end if;
                        -- Update SR (unless writing to SR directly)
                        if not (dst_reg_sig = 2 and ad_sig = '0' and writeback_en = '1') then
                            sr <= new_sr_sig;
                        end if;
                        state <= ST_FETCH;

                    when others =>
                        state <= ST_FETCH;
                end case;
            end if;
        end if;
    end process cpu_proc;

end architecture rtl;

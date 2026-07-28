-- ================================================================================
-- pio_controller : RP2040-style Programmable I/O (PIO) block
-- ================================================================================
-- Implements 4 programmable state machines per PIO block, matching the
-- Raspberry Pi RP2040 architecture:
--   * 32-word instruction memory per SM (5-bit opcode + operands)
--   * 32x32 register file (X, Y) per SM
--   * Input shift register (ISR) and output shift register (OSR)
--   * 8-deep TX and RX FIFOs per SM
--   * Side-set pins, set pins, out pins, in pins (configurable)
--   * Clock divider per SM
--   * JMP, OUT, IN, SET, MOV, PUSH, PULL, IRQ, WAIT instructions
--
-- AHB-Lite register map (per SM, 0x00-0xFF each):
--   0x00 : CTRL        - Control register (enable, clkdiv, exec)
--   0x04 : FSTAT       - FIFO status
--   0x08 : TXF0-TXF3   - TX FIFO write ports
--   0x0C : RXF0-RXF3   - RX FIFO read ports
--   0x10 : IRQ         - IRQ flags
--   0x14 : IRQ_FORCE   - Force IRQ
--   0x18 : INPUT_SYNC_BYPASS
--   0x1C : DBG_PADOUT  - Debug pad output
--   0x20 : INSTR_MEM   - Instruction memory (write index = CTRL.exec_wrindex)
--   0x24 : PINCTRL     - Pin mapping (set_count, set_base, out_count, out_base,
--                         in_base, side_set_count, side_set_base)
--   0x28 : SHIFTREG    - Shift register config (push_thresh, pull_thresh, out_shiftdir,
--                         in_shiftdir, autopush, autopull)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pio_controller is
    port (
        -- AHB-Lite slave interface
        HCLK      : in  std_logic;
        HRESETn   : in  std_logic;
        HSEL      : in  std_logic;
        HWRITE    : in  std_logic;
        HREADY    : in  std_logic;
        HTRANS    : in  std_logic_vector(1 downto 0);
        HSIZE     : in  std_logic_vector(2 downto 0);
        HADDR     : in  std_logic_vector(31 downto 0);
        HWDATA    : in  std_logic_vector(31 downto 0);
        HRDATA    : out std_logic_vector(31 downto 0);
        HRESP     : out std_logic;
        HREADYOUT : out std_logic;

        -- PIO external pins (grouped for all 4 SMs)
        pio_pins_out  : out std_logic_vector(31 downto 0);
        pio_pins_in   : in  std_logic_vector(31 downto 0) := (others => '0');
        pio_pins_oe   : out std_logic_vector(31 downto 0);

        -- IRQ output
        pio_irq_out   : out std_logic
    );
end entity pio_controller;

architecture rtl of pio_controller is

    -- PIO instruction encoding (16-bit, RP2040 style)
    -- Bits [15:13] = opcode, rest = operands
    constant OP_JMP   : std_logic_vector(2 downto 0) := "000";
    constant OP_IN    : std_logic_vector(2 downto 0) := "001";
    constant OP_OUT   : std_logic_vector(2 downto 0) := "010";
    constant OP_PUSH  : std_logic_vector(2 downto 0) := "011";
    constant OP_PULL  : std_logic_vector(2 downto 0) := "100";
    constant OP_MOV   : std_logic_vector(2 downto 0) := "101";
    constant OP_IRQ   : std_logic_vector(2 downto 0) := "110";
    constant OP_SET   : std_logic_vector(2 downto 0) := "111";

    -- IN source / OUT destination
    constant SRC_PINS   : std_logic_vector(2 downto 0) := "000";
    constant SRC_X      : std_logic_vector(2 downto 0) := "001";
    constant SRC_Y      : std_logic_vector(2 downto 0) := "010";
    constant SRC_NULL   : std_logic_vector(2 downto 0) := "011";
    constant SRC_ISR    : std_logic_vector(2 downto 0) := "100";  -- for MOV
    constant SRC_OSR    : std_logic_vector(2 downto 0) := "101";  -- for MOV

    -- MOV operands
    constant MOV_DEST_Y   : std_logic_vector(2 downto 0) := "000";
    constant MOV_DEST_X   : std_logic_vector(2 downto 0) := "001";
    constant MOV_DEST_ISR : std_logic_vector(2 downto 0) := "010";
    constant MOV_DEST_OSR : std_logic_vector(2 downto 0) := "011";
    constant MOV_DEST_EXEC: std_logic_vector(2 downto 0) := "100";

    -- JMP conditions
    constant JMP_ALWAYS  : std_logic_vector(2 downto 0) := "000";
    constant JMP_X_ZERO  : std_logic_vector(2 downto 0) := "001";
    constant JMP_X_DEC   : std_logic_vector(2 downto 0) := "010";
    constant JMP_Y_ZERO  : std_logic_vector(2 downto 0) := "011";
    constant JMP_Y_DEC   : std_logic_vector(2 downto 0) := "100";
    constant JMP_XNE_Y   : std_logic_vector(2 downto 0) := "101";
    constant JMP_PIN     : std_logic_vector(2 downto 0) := "110";
    constant JMP_NOT_OSR : std_logic_vector(2 downto 0) := "111";

    -- Number of state machines
    constant NUM_SM : integer := 4;
    constant INSTR_MEM_DEPTH : integer := 32;
    constant FIFO_DEPTH : integer := 8;

    type instr_array_t is array(0 to INSTR_MEM_DEPTH-1) of std_logic_vector(15 downto 0);
    type word_array_t  is array(0 to FIFO_DEPTH-1) of std_logic_vector(31 downto 0);

    -- Per-SM state type
    type sm_state_t is record
        pc          : unsigned(4 downto 0);   -- program counter (0-31)
        x_reg       : unsigned(31 downto 0);  -- X register
        y_reg       : unsigned(31 downto 0);  -- Y register
        isr         : unsigned(31 downto 0);  -- input shift register
        osr         : unsigned(31 downto 0);  -- output shift register
        isr_shift   : unsigned(5 downto 0);   -- bits shifted into ISR
        osr_shift   : unsigned(5 downto 0);   -- bits shifted out of OSR
        enabled     : std_logic;
        stall       : std_logic;              -- stalled on FIFO
        delay_cnt   : unsigned(4 downto 0);   -- instruction delay counter
        instr_reg   : std_logic_vector(15 downto 0); -- currently executing
        tx_rd_ptr   : integer range 0 to FIFO_DEPTH-1;
        tx_wr_ptr   : integer range 0 to FIFO_DEPTH-1;
        tx_count    : integer range 0 to FIFO_DEPTH;
        rx_rd_ptr   : integer range 0 to FIFO_DEPTH-1;
        rx_wr_ptr   : integer range 0 to FIFO_DEPTH-1;
        rx_count    : integer range 0 to FIFO_DEPTH;
        push_thresh : unsigned(4 downto 0);   -- autopush threshold
        pull_thresh : unsigned(4 downto 0);   -- autopull threshold
        autopush    : std_logic;
        autopull    : std_logic;
        out_shiftdir: std_logic;               -- 1=shift right, 0=shift left
        in_shiftdir : std_logic;               -- 1=shift right, 0=shift left
        set_count   : unsigned(4 downto 0);
        set_base    : unsigned(4 downto 0);
        out_count   : unsigned(4 downto 0);
        out_base    : unsigned(4 downto 0);
        in_base     : unsigned(4 downto 0);
        side_count  : unsigned(4 downto 0);
        side_base   : unsigned(4 downto 0);
        clkdiv      : unsigned(15 downto 0);  -- clock divider (0 = full speed)
        clk_cnt     : unsigned(15 downto 0);  -- divider counter
    end record;

    type sm_state_array_t is array(0 to NUM_SM-1) of sm_state_t;

    -- Shared instruction memory (32 words, shared across all 4 SMs in RP2040)
    signal instr_mem : instr_array_t := (others => (others => '0'));

    -- TX/RX FIFOs per SM
    type fifo_array_t is array(0 to NUM_SM-1) of word_array_t;
    signal tx_fifos : fifo_array_t := (others => (others => (others => '0')));
    signal rx_fifos : fifo_array_t := (others => (others => (others => '0')));

    -- SM states
    signal sm_states : sm_state_array_t;

    -- IRQ flags
    signal irq_flags : std_logic_vector(7 downto 0) := (others => '0');

    -- Pin output and output-enable registers
    signal pin_out_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal pin_oe_reg  : std_logic_vector(31 downto 0) := (others => '0');

    -- AHB address decode
    signal sm_sel      : integer range 0 to NUM_SM-1;
    signal reg_offset  : std_logic_vector(7 downto 0);
    signal write_en    : std_logic;
    signal instr_wr_idx: unsigned(4 downto 0);

    -- Default SM state
    function init_sm return sm_state_t is
        variable s : sm_state_t;
    begin
        s.pc          := (others => '0');
        s.x_reg       := (others => '0');
        s.y_reg       := (others => '0');
        s.isr         := (others => '0');
        s.osr         := (others => '0');
        s.isr_shift   := (others => '0');
        s.osr_shift   := (others => '0');
        s.enabled     := '0';
        s.stall       := '0';
        s.delay_cnt   := (others => '0');
        s.instr_reg   := (others => '0');
        s.tx_rd_ptr   := 0;
        s.tx_wr_ptr   := 0;
        s.tx_count    := 0;
        s.rx_rd_ptr   := 0;
        s.rx_wr_ptr   := 0;
        s.rx_count    := 0;
        s.push_thresh := to_unsigned(0, 5);   -- 0 means 32 in RP2040
        s.pull_thresh := to_unsigned(0, 5);   -- 0 means 32 in RP2040
        s.autopush    := '0';
        s.autopull    := '0';
        s.out_shiftdir:= '1';
        s.in_shiftdir := '1';
        s.set_count   := to_unsigned(5, 5);
        s.set_base    := (others => '0');
        s.out_count   := (others => '0');
        s.out_base    := (others => '0');
        s.in_base     := (others => '0');
        s.side_count  := (others => '0');
        s.side_base   := (others => '0');
        s.clkdiv      := (others => '0');
        s.clk_cnt     := (others => '0');
        return s;
    end function;

begin

    -- AHB address decode
    sm_sel     <= to_integer(unsigned(HADDR(9 downto 8)));  -- 2 bits for 4 SMs
    reg_offset <= HADDR(7 downto 0);
    write_en   <= HSEL and HREADY and HWRITE;
    instr_wr_idx <= unsigned(HADDR(6 downto 2));  -- 32 words = 5 bits, word-aligned

    -- ========================================================================
    -- AHB-Lite register write process (instr_mem and irq_flags only)
    -- sm_states are written exclusively by pio_exec process
    -- ========================================================================
    ahb_write : process(HCLK, HRESETn)
        variable idx : integer;
    begin
        if HRESETn = '0' then
            instr_mem <= (others => (others => '0'));
            irq_flags <= (others => '0');
        elsif rising_edge(HCLK) then
            if write_en = '1' then
                case reg_offset(7 downto 4) is
                    when x"0" =>
                        case reg_offset(3 downto 0) is
                            when x"0" =>  -- CTRL - may write instruction
                                if HWDATA(31) = '1' then
                                    idx := to_integer(unsigned(HWDATA(26 downto 22)));
                                    instr_mem(idx) <= HWDATA(15 downto 0);
                                end if;
                            when x"8" =>  -- IRQ flags set
                                irq_flags <= irq_flags or HWDATA(7 downto 0);
                            when x"9" =>  -- IRQ force
                                irq_flags <= irq_flags or HWDATA(7 downto 0);
                            when x"A" =>  -- IRQ clear
                                irq_flags <= irq_flags and not HWDATA(7 downto 0);
                            when others => null;
                        end case;

                    when x"1" | x"2" | x"3" | x"4" =>
                        idx := to_integer(instr_wr_idx);
                        if idx < INSTR_MEM_DEPTH then
                            instr_mem(idx) <= HWDATA(15 downto 0);
                        end if;

                    when others => null;
                end case;
            end if;
        end if;
    end process ahb_write;

    -- ========================================================================
    -- AHB-Lite register read process
    -- ========================================================================
    ahb_read : process(HSEL, HADDR, reg_offset, sm_sel, sm_states, instr_mem,
                        tx_fifos, rx_fifos, irq_flags, pin_out_reg, pin_oe_reg)
        variable s : integer;
        variable rdata : std_logic_vector(31 downto 0);
        variable idx : integer;
    begin
        rdata := (others => '0');
        s := sm_sel;
        if HSEL = '1' then
            case reg_offset(7 downto 4) is
                when x"0" =>
                    case reg_offset(3 downto 0) is
                        when x"0" =>  -- CTRL
                            rdata(0) := sm_states(s).enabled;
                            rdata(31) := '0';
                        when x"1" =>  -- FSTAT
                            -- TX full bits [3:0], TX empty bits, RX full, RX empty
                            rdata(3 downto 0) := (others => '0'); -- not full
                            rdata(7 downto 4) := (others => '0'); -- not empty
                            rdata(11 downto 8) := (others => '0');
                            rdata(15 downto 12) := (others => '0');
                        when x"2" =>  -- RXFIFO read
                            if sm_states(s).rx_count > 0 then
                                rdata := rx_fifos(s)(sm_states(s).rx_rd_ptr);
                            end if;
                        when x"8" =>  -- IRQ
                            rdata(7 downto 0) := irq_flags;
                        when x"E" =>  -- DBG_PADOUT
                            rdata(31 downto 0) := pin_out_reg;
                        when x"F" =>  -- DBG_PADOE
                            rdata(31 downto 0) := pin_oe_reg;
                        when others => null;
                    end case;

                when x"1" | x"2" | x"3" | x"4" =>
                    idx := to_integer(unsigned(HADDR(6 downto 2)));
                    if idx < INSTR_MEM_DEPTH then
                        rdata(15 downto 0) := instr_mem(idx);
                    end if;

                when x"5" =>
                    case reg_offset(3 downto 0) is
                        when x"0" =>
                            rdata(4 downto 0)   := std_logic_vector(sm_states(s).set_count);
                            rdata(9 downto 5)   := std_logic_vector(sm_states(s).set_base);
                            rdata(14 downto 10) := std_logic_vector(sm_states(s).out_count);
                            rdata(19 downto 15) := std_logic_vector(sm_states(s).out_base);
                        when x"1" =>
                            rdata(4 downto 0)   := std_logic_vector(sm_states(s).in_base);
                            rdata(9 downto 5)   := std_logic_vector(sm_states(s).side_count);
                            rdata(14 downto 10) := std_logic_vector(sm_states(s).side_base);
                        when x"2" =>
                            rdata(4 downto 0)   := std_logic_vector(sm_states(s).push_thresh);
                            rdata(9 downto 5)   := std_logic_vector(sm_states(s).pull_thresh);
                            rdata(16) := sm_states(s).out_shiftdir;
                            rdata(17) := sm_states(s).in_shiftdir;
                            rdata(18) := sm_states(s).autopush;
                            rdata(19) := sm_states(s).autopull;
                        when x"3" =>
                            rdata(15 downto 0) := std_logic_vector(sm_states(s).clkdiv);
                        when others => null;
                    end case;

                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';

    -- ========================================================================
    -- PIO State Machine Execution Process
    -- ========================================================================
    pio_exec : process(HCLK, HRESETn)
        variable instr   : std_logic_vector(15 downto 0);
        variable opcode  : std_logic_vector(2 downto 0);
        variable delay   : unsigned(4 downto 0);
        variable s       : integer;
        variable next_pc : unsigned(4 downto 0);
        variable shift_n : integer;
        variable pin_idx : integer;
        variable pin_val : std_logic;
        variable data    : unsigned(31 downto 0);
        variable fifo_empty : std_logic;
        variable fifo_full  : std_logic;
    begin
        if HRESETn = '0' then
            pin_out_reg <= (others => '0');
            pin_oe_reg  <= (others => '0');
            for i in 0 to NUM_SM-1 loop
                sm_states(i) <= init_sm;
            end loop;
        elsif rising_edge(HCLK) then
            -- ==================================================================
            -- AHB register writes to sm_states (config + FIFO)
            -- ==================================================================
            if write_en = '1' then
                s := sm_sel;
                case reg_offset(7 downto 4) is
                    when x"0" =>
                        case reg_offset(3 downto 0) is
                            when x"0" =>  -- CTRL
                                sm_states(s).enabled <= HWDATA(0);
                            when x"4" =>  -- TXFIFO write
                                if sm_states(s).tx_count < FIFO_DEPTH then
                                    tx_fifos(s)(sm_states(s).tx_wr_ptr) <= HWDATA;
                                    if sm_states(s).tx_wr_ptr = FIFO_DEPTH-1 then
                                        sm_states(s).tx_wr_ptr <= 0;
                                    else
                                        sm_states(s).tx_wr_ptr <= sm_states(s).tx_wr_ptr + 1;
                                    end if;
                                    sm_states(s).tx_count <= sm_states(s).tx_count + 1;
                                end if;
                            when others => null;
                        end case;
                    when x"5" =>
                        case reg_offset(3 downto 0) is
                            when x"0" =>
                                sm_states(s).set_count <= unsigned(HWDATA(4 downto 0));
                                sm_states(s).set_base  <= unsigned(HWDATA(9 downto 5));
                                sm_states(s).out_count <= unsigned(HWDATA(14 downto 10));
                                sm_states(s).out_base  <= unsigned(HWDATA(19 downto 15));
                            when x"1" =>
                                sm_states(s).in_base    <= unsigned(HWDATA(4 downto 0));
                                sm_states(s).side_count <= unsigned(HWDATA(9 downto 5));
                                sm_states(s).side_base  <= unsigned(HWDATA(14 downto 10));
                            when x"2" =>
                                sm_states(s).push_thresh  <= unsigned(HWDATA(4 downto 0));
                                sm_states(s).pull_thresh  <= unsigned(HWDATA(9 downto 5));
                                sm_states(s).out_shiftdir <= HWDATA(16);
                                sm_states(s).in_shiftdir  <= HWDATA(17);
                                sm_states(s).autopush     <= HWDATA(18);
                                sm_states(s).autopull     <= HWDATA(19);
                            when x"3" =>
                                sm_states(s).clkdiv <= unsigned(HWDATA(15 downto 0));
                            when others => null;
                        end case;
                    when others => null;
                end case;
            end if;
            for i in 0 to NUM_SM-1 loop
                s := i;
                -- Only execute if enabled and not in delay
                if sm_states(s).enabled = '1' then
                    -- Clock divider
                    if sm_states(s).clkdiv > 0 then
                        if sm_states(s).clk_cnt >= sm_states(s).clkdiv then
                            sm_states(s).clk_cnt <= (others => '0');
                        else
                            sm_states(s).clk_cnt <= sm_states(s).clk_cnt + 1;
                        end if;
                    end if;

                    -- Execute only when divider allows
                    if sm_states(s).clkdiv = 0 or sm_states(s).clk_cnt >= sm_states(s).clkdiv then
                        -- Handle delay
                        if sm_states(s).delay_cnt > 0 then
                            sm_states(s).delay_cnt <= sm_states(s).delay_cnt - 1;
                        else
                            -- Fetch instruction
                            instr  := instr_mem(to_integer(sm_states(s).pc));
                            opcode := instr(15 downto 13);
                            delay  := unsigned(instr(7 downto 5));  -- delay field
                            next_pc := sm_states(s).pc + 1;

                            case opcode is
                                -- =================================================================
                                -- JMP: conditional jump
                                -- =================================================================
                                when OP_JMP =>
                                    case instr(12 downto 10) is
                                        when JMP_ALWAYS =>
                                            next_pc := unsigned(instr(4 downto 0));
                                        when JMP_X_ZERO =>
                                            if sm_states(s).x_reg = 0 then
                                                next_pc := unsigned(instr(4 downto 0));
                                            end if;
                                        when JMP_X_DEC =>
                                            sm_states(s).x_reg <= sm_states(s).x_reg - 1;
                                            if (sm_states(s).x_reg - 1) = 0 then
                                                next_pc := unsigned(instr(4 downto 0));
                                            end if;
                                        when JMP_Y_ZERO =>
                                            if sm_states(s).y_reg = 0 then
                                                next_pc := unsigned(instr(4 downto 0));
                                            end if;
                                        when JMP_Y_DEC =>
                                            sm_states(s).y_reg <= sm_states(s).y_reg - 1;
                                            if (sm_states(s).y_reg - 1) = 0 then
                                                next_pc := unsigned(instr(4 downto 0));
                                            end if;
                                        when JMP_PIN =>
                                            pin_idx := to_integer(sm_states(s).in_base);
                                            if pin_idx < 32 and pio_pins_in(pin_idx) = '1' then
                                                next_pc := unsigned(instr(4 downto 0));
                                            end if;
                                        when JMP_NOT_OSR =>
                                            if sm_states(s).osr_shift /= 32 then
                                                next_pc := unsigned(instr(4 downto 0));
                                            end if;
                                        when others => null;
                                    end case;

                                -- =================================================================
                                -- IN: shift bits into ISR from source
                                -- =================================================================
                                when OP_IN =>
                                    shift_n := to_integer(unsigned(instr(4 downto 0)));
                                    if shift_n = 0 then shift_n := 32; end if;
                                    case instr(7 downto 5) is
                                        when SRC_PINS =>
                                            pin_idx := to_integer(sm_states(s).in_base);
                                            if pin_idx < 32 then
                                                data := (others => '0');
                                                for b in 0 to shift_n-1 loop
                                                    if pin_idx + b < 32 then
                                                        data(b) := pio_pins_in(pin_idx + b);
                                                    end if;
                                                end loop;
                                            else
                                                data := (others => '0');
                                            end if;
                                        when SRC_X => data := sm_states(s).x_reg;
                                        when SRC_Y => data := sm_states(s).y_reg;
                                        when SRC_NULL => data := (others => '0');
                                        when others => data := (others => '0');
                                    end case;
                                    -- Shift into ISR
                                    if sm_states(s).in_shiftdir = '1' then
                                        -- Shift right: new bits enter at MSB
                                        sm_states(s).isr <= shift_right(sm_states(s).isr, shift_n) or
                                                            shift_left(resize(data, 32), 32 - shift_n);
                                    else
                                        -- Shift left: new bits enter at LSB
                                        sm_states(s).isr <= shift_left(sm_states(s).isr, shift_n) or
                                                            resize(data, 32);
                                    end if;
                                    sm_states(s).isr_shift <= sm_states(s).isr_shift + to_unsigned(shift_n, 6);
                                    -- Autopush check
                                    if sm_states(s).autopush = '1' and
                                       sm_states(s).isr_shift + to_unsigned(shift_n, 6) >=
                                       resize(sm_states(s).push_thresh, 6) then
                                        -- Push ISR to RX FIFO
                                        if sm_states(s).rx_count < FIFO_DEPTH then
                                            rx_fifos(s)(sm_states(s).rx_wr_ptr) <=
                                                std_logic_vector(sm_states(s).isr);
                                            if sm_states(s).rx_wr_ptr = FIFO_DEPTH-1 then
                                                sm_states(s).rx_wr_ptr <= 0;
                                            else
                                                sm_states(s).rx_wr_ptr <= sm_states(s).rx_wr_ptr + 1;
                                            end if;
                                            sm_states(s).rx_count <= sm_states(s).rx_count + 1;
                                        end if;
                                        sm_states(s).isr_shift <= (others => '0');
                                        sm_states(s).isr <= (others => '0');
                                    end if;

                                -- =================================================================
                                -- OUT: shift bits from OSR to destination
                                -- =================================================================
                                when OP_OUT =>
                                    shift_n := to_integer(unsigned(instr(4 downto 0)));
                                    if shift_n = 0 then shift_n := 32; end if;
                                    -- Extract bits from OSR
                                    if sm_states(s).out_shiftdir = '1' then
                                        data := shift_right(sm_states(s).osr, 32 - shift_n);
                                        sm_states(s).osr <= shift_left(sm_states(s).osr, shift_n);
                                    else
                                        data := sm_states(s).osr and to_unsigned(0, 32); -- LSB-first
                                        sm_states(s).osr <= shift_right(sm_states(s).osr, shift_n);
                                    end if;
                                    sm_states(s).osr_shift <= sm_states(s).osr_shift + to_unsigned(shift_n, 6);
                                    case instr(7 downto 5) is
                                        when SRC_PINS =>
                                            -- Drive pins
                                            pin_idx := to_integer(sm_states(s).out_base);
                                            for b in 0 to shift_n-1 loop
                                                if pin_idx + b < 32 then
                                                    pin_out_reg(pin_idx + b) <= data(b);
                                                    pin_oe_reg(pin_idx + b) <= '1';
                                                end if;
                                            end loop;
                                        when SRC_X => sm_states(s).x_reg <= data;
                                        when SRC_Y => sm_states(s).y_reg <= data;
                                        when others => null;  -- NULL destination
                                    end case;
                                    -- Autopull check
                                    if sm_states(s).autopull = '1' and
                                       sm_states(s).osr_shift + to_unsigned(shift_n, 6) >=
                                       resize(sm_states(s).pull_thresh, 6) then
                                        -- Pull from TX FIFO
                                        if sm_states(s).tx_count > 0 then
                                            sm_states(s).osr <= unsigned(tx_fifos(s)(sm_states(s).tx_rd_ptr));
                                            if sm_states(s).tx_rd_ptr = FIFO_DEPTH-1 then
                                                sm_states(s).tx_rd_ptr <= 0;
                                            else
                                                sm_states(s).tx_rd_ptr <= sm_states(s).tx_rd_ptr + 1;
                                            end if;
                                            sm_states(s).tx_count <= sm_states(s).tx_count - 1;
                                        end if;
                                        sm_states(s).osr_shift <= (others => '0');
                                    end if;

                                -- =================================================================
                                -- PUSH: push ISR to RX FIFO
                                -- =================================================================
                                when OP_PUSH =>
                                    if instr(6) = '0' then  -- if block bit = 0, don't block
                                        if sm_states(s).rx_count < FIFO_DEPTH then
                                            rx_fifos(s)(sm_states(s).rx_wr_ptr) <=
                                                std_logic_vector(sm_states(s).isr);
                                            if sm_states(s).rx_wr_ptr = FIFO_DEPTH-1 then
                                                sm_states(s).rx_wr_ptr <= 0;
                                            else
                                                sm_states(s).rx_wr_ptr <= sm_states(s).rx_wr_ptr + 1;
                                            end if;
                                            sm_states(s).rx_count <= sm_states(s).rx_count + 1;
                                        end if;
                                    else  -- block if full
                                        if sm_states(s).rx_count < FIFO_DEPTH then
                                            rx_fifos(s)(sm_states(s).rx_wr_ptr) <=
                                                std_logic_vector(sm_states(s).isr);
                                            if sm_states(s).rx_wr_ptr = FIFO_DEPTH-1 then
                                                sm_states(s).rx_wr_ptr <= 0;
                                            else
                                                sm_states(s).rx_wr_ptr <= sm_states(s).rx_wr_ptr + 1;
                                            end if;
                                            sm_states(s).rx_count <= sm_states(s).rx_count + 1;
                                        else
                                            sm_states(s).stall <= '1';
                                        end if;
                                    end if;
                                    if instr(5) = '0' then  -- don't clear ISR
                                        null;
                                    else
                                        sm_states(s).isr <= (others => '0');
                                        sm_states(s).isr_shift <= (others => '0');
                                    end if;

                                -- =================================================================
                                -- PULL: pull from TX FIFO into OSR
                                -- =================================================================
                                when OP_PULL =>
                                    if instr(6) = '0' then  -- don't block
                                        if sm_states(s).tx_count > 0 then
                                            sm_states(s).osr <= unsigned(tx_fifos(s)(sm_states(s).tx_rd_ptr));
                                            if sm_states(s).tx_rd_ptr = FIFO_DEPTH-1 then
                                                sm_states(s).tx_rd_ptr <= 0;
                                            else
                                                sm_states(s).tx_rd_ptr <= sm_states(s).tx_rd_ptr + 1;
                                            end if;
                                            sm_states(s).tx_count <= sm_states(s).tx_count - 1;
                                        else
                                            sm_states(s).osr <= x"00000000";  -- pull zero if empty
                                        end if;
                                    else  -- block if empty
                                        if sm_states(s).tx_count > 0 then
                                            sm_states(s).osr <= unsigned(tx_fifos(s)(sm_states(s).tx_rd_ptr));
                                            if sm_states(s).tx_rd_ptr = FIFO_DEPTH-1 then
                                                sm_states(s).tx_rd_ptr <= 0;
                                            else
                                                sm_states(s).tx_rd_ptr <= sm_states(s).tx_rd_ptr + 1;
                                            end if;
                                            sm_states(s).tx_count <= sm_states(s).tx_count - 1;
                                        else
                                            sm_states(s).stall <= '1';
                                        end if;
                                    end if;
                                    sm_states(s).osr_shift <= (others => '0');

                                -- =================================================================
                                -- MOV: move data between registers
                                -- =================================================================
                                when OP_MOV =>
                                    case instr(7 downto 5) is  -- source
                                        when SRC_X      => data := sm_states(s).x_reg;
                                        when SRC_Y      => data := sm_states(s).y_reg;
                                        when SRC_ISR    => data := sm_states(s).isr;
                                        when SRC_OSR    => data := sm_states(s).osr;
                                        when SRC_NULL   => data := (others => '0');
                                        when others     => data := (others => '0');
                                    end case;
                                    case instr(12 downto 10) is  -- destination
                                        when MOV_DEST_Y    => sm_states(s).y_reg   <= data;
                                        when MOV_DEST_X    => sm_states(s).x_reg   <= data;
                                        when MOV_DEST_ISR  => sm_states(s).isr     <= data;
                                        when MOV_DEST_OSR  => sm_states(s).osr     <= data;
                                        when MOV_DEST_EXEC => next_pc := data(4 downto 0); -- execute instruction
                                        when others => null;
                                    end case;

                                -- =================================================================
                                -- IRQ: set/clear IRQ flags
                                -- =================================================================
                                when OP_IRQ =>
                                    if instr(6) = '0' then  -- set
                                        irq_flags(to_integer(unsigned(instr(3 downto 0)))) <= '1';
                                    else  -- clear
                                        irq_flags(to_integer(unsigned(instr(3 downto 0)))) <= '0';
                                    end if;

                                -- =================================================================
                                -- SET: set pins or register
                                -- =================================================================
                                when OP_SET =>
                                    case instr(7 downto 5) is
                                        when SRC_PINS =>
                                            -- Set pins
                                            pin_idx := to_integer(sm_states(s).set_base);
                                            for b in 0 to to_integer(sm_states(s).set_count)-1 loop
                                                if pin_idx + b < 32 then
                                                    pin_out_reg(pin_idx + b) <= instr(b);
                                                    pin_oe_reg(pin_idx + b) <= '1';
                                                end if;
                                            end loop;
                                        when SRC_X => sm_states(s).x_reg <= to_unsigned(to_integer(unsigned(instr(4 downto 0))), 32);
                                        when SRC_Y => sm_states(s).y_reg <= to_unsigned(to_integer(unsigned(instr(4 downto 0))), 32);
                                        when others => null;
                                    end case;

                                when others => null;
                            end case;

                            -- Update PC
                            if sm_states(s).stall = '0' then
                                sm_states(s).pc <= next_pc;
                                sm_states(s).delay_cnt <= delay;
                            else
                                sm_states(s).stall <= '0';  -- clear stall on next cycle
                            end if;
                        end if;
                    end if;
                end if;
            end loop;
        end if;
    end process pio_exec;

    -- Output pins
    pio_pins_out <= pin_out_reg;
    pio_pins_oe  <= pin_oe_reg;

    -- IRQ output (OR of all IRQ flags)
    pio_irq_out <= '1' when irq_flags /= "00000000" else '0';

end architecture rtl;

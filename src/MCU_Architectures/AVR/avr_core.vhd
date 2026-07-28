-- ================================================================================
-- avr_core : AVR ATmega-style 8-bit microcontroller soft core
--
-- Implements the AVR 8-bit instruction set (ATmega328P subset).
-- Target: Altera Cyclone III EP3C16F484C6N.
--
-- Features:
--   * 16-bit instruction width, 8-bit data width, Harvard architecture
--   * 32 x 8-bit general purpose registers (R0-R31)
--   * X (R27:R26), Y (R29:R28), Z (R31:R30) pointer pairs
--   * 16-bit Program Counter, 16-bit Stack Pointer
--   * SREG flags: I, T, H, S, V, N, Z, C
--   * I/O space (64 registers) + extended I/O + SRAM
--   * Most instructions execute in 1 cycle (skip/branch taken: 2 cycles)
--
-- Register file:
--   R0-R31 general purpose, R16-R31 for immediate, R26-R31 for pointers
--
-- SREG bits: [7]I [6]T [5]H [4]S [3]V [2]N [1]Z [0]C
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity avr_core is
    generic (
        PROGRAM_SIZE : integer := 4096;  -- 4K x 16 program memory words
        DATA_SIZE    : integer := 2048   -- 2K x 8 SRAM
    );
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;      -- active-high synchronous
        -- Program memory interface
        pmem_addr  : out std_logic_vector(15 downto 0);  -- PC (word address)
        pmem_data  : in  std_logic_vector(15 downto 0);  -- instruction word
        -- Data memory interface (SRAM + I/O)
        dmem_addr  : out std_logic_vector(15 downto 0);
        dmem_dout  : out std_logic_vector(7 downto 0);  -- data to write
        dmem_din   : in  std_logic_vector(7 downto 0);  -- data read
        dmem_we    : out std_logic;
        dmem_re    : out std_logic;
        -- I/O port interface (for PORTB/PORTC/PORTD)
        portb_out  : out std_logic_vector(7 downto 0);
        portc_out  : out std_logic_vector(7 downto 0);
        portd_out  : out std_logic_vector(7 downto 0);
        portb_in   : in  std_logic_vector(7 downto 0);
        portc_in   : in  std_logic_vector(7 downto 0);
        portd_in   : in  std_logic_vector(7 downto 0);
        ddrb_out   : out std_logic_vector(7 downto 0);
        ddrc_out   : out std_logic_vector(7 downto 0);
        ddrd_out   : out std_logic_vector(7 downto 0);
        -- Interrupts
        int0       : in  std_logic;
        int1       : in  std_logic;
        irq_out    : out std_logic;
        -- Status
        running    : out std_logic
    );
end entity avr_core;

architecture rtl of avr_core is

    -- I/O register addresses (I/O space 0x00-0x3F, data space 0x20-0x5F)
    constant IO_PINB  : integer := 16#03#;
    constant IO_DDRB  : integer := 16#04#;
    constant IO_PORTB : integer := 16#05#;
    constant IO_PINC  : integer := 16#06#;
    constant IO_DDRC  : integer := 16#07#;
    constant IO_PORTC : integer := 16#08#;
    constant IO_PIND  : integer := 16#09#;
    constant IO_DDRD  : integer := 16#0A#;
    constant IO_PORTD : integer := 16#0B#;
    constant IO_SREG  : integer := 16#3F#;
    constant IO_SPL   : integer := 16#3D#;
    constant IO_SPH   : integer := 16#3E#;

    -- SREG bit positions
    constant SREG_C : integer := 0;
    constant SREG_Z : integer := 1;
    constant SREG_N : integer := 2;
    constant SREG_V : integer := 3;
    constant SREG_S : integer := 4;
    constant SREG_H : integer := 5;
    constant SREG_T : integer := 6;
    constant SREG_I : integer := 7;

    -- CPU state machine
    type cpu_state_t is (ST_RESET, ST_FETCH, ST_EXEC, ST_SKIP, ST_FETCH2);
    signal state : cpu_state_t := ST_RESET;

    -- Program counter (16-bit, byte address / 2 = word address)
    signal pc        : unsigned(15 downto 0) := (others => '0');

    -- 32 x 8-bit register file
    type regfile_t is array(0 to 31) of unsigned(7 downto 0);
    signal regs      : regfile_t := (others => (others => '0'));

    -- Status register
    signal sreg      : unsigned(7 downto 0) := (others => '0');

    -- Stack pointer (16-bit)
    signal sp        : unsigned(15 downto 0) := x"0FFF";

    -- I/O registers
    signal portb_lat : unsigned(7 downto 0) := (others => '0');
    signal portc_lat : unsigned(7 downto 0) := (others => '0');
    signal portd_lat : unsigned(7 downto 0) := (others => '0');
    signal ddrb_reg   : unsigned(7 downto 0) := (others => '0');
    signal ddrc_reg   : unsigned(7 downto 0) := (others => '0');
    signal ddrd_reg   : unsigned(7 downto 0) := (others => '0');

    -- Instruction register
    signal ir        : unsigned(15 downto 0) := (others => '0');
    signal ir2       : unsigned(15 downto 0) := (others => '0');  -- second word for 2-word instrs
    signal is_2word  : std_logic := '0';

    -- dmem interface
    signal dmem_addr_i : unsigned(15 downto 0) := (others => '0');
    signal dmem_dout_i : unsigned(7 downto 0) := (others => '0');
    signal dmem_we_i   : std_logic := '0';
    signal dmem_re_i   : std_logic := '0';

    signal irq_p : std_logic := '0';

begin

    -- Outputs
    pmem_addr <= std_logic_vector(pc);
    portb_out <= std_logic_vector(portb_lat);
    portc_out <= std_logic_vector(portc_lat);
    portd_out <= std_logic_vector(portd_lat);
    ddrb_out  <= std_logic_vector(ddrb_reg);
    ddrc_out  <= std_logic_vector(ddrc_reg);
    ddrd_out  <= std_logic_vector(ddrd_reg);
    irq_out   <= irq_p;
    running   <= '1' when state /= ST_RESET else '0';

    dmem_addr <= std_logic_vector(dmem_addr_i);
    dmem_dout <= std_logic_vector(dmem_dout_i);
    dmem_we   <= dmem_we_i;
    dmem_re   <= dmem_re_i;

    -- Main CPU process
    cpu_proc : process(clk)
        variable op4    : unsigned(3 downto 0);  -- bits 15:12
        variable rd_idx : integer range 0 to 31;
        variable rr_idx : integer range 0 to 31;
        variable rd_val : unsigned(7 downto 0);
        variable rr_val : unsigned(7 downto 0);
        variable res8   : unsigned(7 downto 0);
        variable res9   : unsigned(8 downto 0);
        variable res16  : unsigned(15 downto 0);
        variable k8     : unsigned(7 downto 0);
        variable k6     : unsigned(5 downto 0);
        variable k4     : unsigned(3 downto 0);
        variable s_bit  : integer range 0 to 7;
        variable b_bit  : integer range 0 to 7;
        variable io_addr : integer range 0 to 63;
        variable new_sreg : unsigned(7 downto 0);
        variable new_pc   : unsigned(15 downto 0);
        variable skip     : std_logic;
        variable x_ptr   : unsigned(15 downto 0);
        variable y_ptr   : unsigned(15 downto 0);
        variable z_ptr   : unsigned(15 downto 0);
        variable offset  : signed(12 downto 0);
        variable addr16  : unsigned(15 downto 0);
        variable is_io   : boolean;
        variable io_val  : unsigned(7 downto 0);
        variable ret_addr : unsigned(15 downto 0);
        variable next_state : cpu_state_t;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state       <= ST_RESET;
                pc          <= (others => '0');
                sreg        <= (others => '0');
                sp          <= x"0FFF";
                portb_lat   <= (others => '0');
                portc_lat   <= (others => '0');
                portd_lat   <= (others => '0');
                ddrb_reg    <= (others => '0');
                ddrc_reg    <= (others => '0');
                ddrd_reg    <= (others => '0');
                ir          <= (others => '0');
                ir2         <= (others => '0');
                is_2word    <= '0';
                dmem_we_i   <= '0';
                dmem_re_i   <= '0';
                dmem_dout_i <= (others => '0');
                regs        <= (others => (others => '0'));
            else
                dmem_we_i <= '0';
                dmem_re_i <= '0';

                case state is
                    when ST_RESET =>
                        state <= ST_FETCH;
                        pc    <= (others => '0');

                    when ST_FETCH =>
                        ir    <= unsigned(pmem_data);
                        state <= ST_EXEC;

                    when ST_EXEC =>
                        op4 := ir(15 downto 12);
                        -- Extract register indices
                        -- For most R-type: d = ir(8:4), r = ir(9)&ir(3:0)
                        rd_idx := to_integer(ir(8 downto 4));
                        rr_idx := to_integer(ir(9) & ir(3 downto 0));
                        rd_val := regs(rd_idx);
                        rr_val := regs(rr_idx);
                        k8 := ir(11 downto 8) & ir(3 downto 0);  -- for immediate: K in [11:8]&[3:0]
                        k6 := ir(5 downto 0);
                        k4 := ir(3 downto 0);
                        s_bit := to_integer(ir(2 downto 0));  -- for BRBS/BRBC (status bit in [2:0])
                        b_bit := to_integer(ir(6 downto 3));  -- for BLD/BST/SBRC/SBRS
                        io_addr := to_integer(ir(8 downto 3));  -- for IN/OUT/CBI/SBI/SBIC/SBIS

                        new_sreg := sreg;
                        new_pc := pc + 1;
                        skip := '0';
                        next_state := ST_FETCH;

                        -- Helper: read I/O register
                        -- I/O space 0x00-0x3F maps to data space 0x20-0x5F
                        -- SREG at I/O 0x3F, SP at I/O 0x3D/0x3E
                        is_io := false;
                        io_val := (others => '0');
                        case io_addr is
                            when IO_PINB =>
                                for i in 0 to 7 loop
                                    if ddrb_reg(i) = '0' then
                                        io_val(i) := portb_in(i);
                                    else
                                        io_val(i) := portb_lat(i);
                                    end if;
                                end loop;
                                is_io := true;
                            when IO_PINC =>
                                for i in 0 to 7 loop
                                    if ddrc_reg(i) = '0' then
                                        io_val(i) := portc_in(i);
                                    else
                                        io_val(i) := portc_lat(i);
                                    end if;
                                end loop;
                                is_io := true;
                            when IO_PIND =>
                                for i in 0 to 7 loop
                                    if ddrd_reg(i) = '0' then
                                        io_val(i) := portd_in(i);
                                    else
                                        io_val(i) := portd_lat(i);
                                    end if;
                                end loop;
                                is_io := true;
                            when IO_PORTB => io_val := portb_lat; is_io := true;
                            when IO_PORTC => io_val := portc_lat; is_io := true;
                            when IO_PORTD => io_val := portd_lat; is_io := true;
                            when IO_DDRB  => io_val := ddrb_reg;  is_io := true;
                            when IO_DDRC  => io_val := ddrc_reg;  is_io := true;
                            when IO_DDRD  => io_val := ddrd_reg;  is_io := true;
                            when IO_SREG  => io_val := sreg;       is_io := true;
                            when IO_SPL   => io_val := sp(7 downto 0);   is_io := true;
                            when IO_SPH   => io_val := sp(15 downto 8);  is_io := true;
                            when others => null;
                        end case;

                        -- Decode and execute
                        case op4 is

                            -- 0000: NOP / MOVW / LDS / POP / ADD / CPC / SBC
                            when "0000" =>
                                if ir(15 downto 10) = "000000" and ir(9 downto 0) = "0000000000" then
                                    null;  -- NOP
                                elsif ir(15 downto 8) = "00000001" then
                                    -- MOVW Rd, Rr: copy register pair
                                    regs(to_integer(ir(7 downto 4)) * 2)     <= regs(to_integer(ir(3 downto 0)) * 2);
                                    regs(to_integer(ir(7 downto 4)) * 2 + 1) <= regs(to_integer(ir(3 downto 0)) * 2 + 1);
                                elsif ir(15 downto 9) = "1001000" and ir(3 downto 0) = "0000" then
                                    -- LDS Rd, k (2-word): load from data space
                                    is_2word <= '1';
                                    next_state := ST_FETCH2;
                                elsif ir(15 downto 9) = "1001000" and ir(3 downto 0) = "1111" then
                                    -- POP Rd
                                    dmem_addr_i <= sp + 1;
                                    dmem_re_i <= '1';
                                    sp <= sp + 1;
                                    regs(rd_idx) <= unsigned(dmem_din);
                                else
                                    -- Register-register instructions: ir(11:10) selects
                                    case ir(11 downto 10) is
                                        when "10" =>
                                            -- SBC Rd, Rr (subtract with carry)
                                            res9 := ('0' & rd_val) - ('0' & rr_val) - ('0' & sreg(SREG_C));
                                            res8 := res9(7 downto 0);
                                            new_sreg(SREG_C) := '1' when rd_val < (rr_val + sreg(SREG_C)) else '0';
                                            if res8 /= 0 then new_sreg(SREG_Z) := '0'; end if;
                                            new_sreg(SREG_N) := res8(7);
                                            new_sreg(SREG_V) := '1' when (rd_val(7) = '0' and rr_val(7) = '1' and res8(7) = '1') or
                                                                (rd_val(7) = '1' and rr_val(7) = '0' and res8(7) = '0') else '0';
                                            new_sreg(SREG_H) := '1' when (rd_val(3 downto 0) < (rr_val(3 downto 0) + sreg(SREG_C))) else '0';
                                            new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                            regs(rd_idx) <= res8;
                                        when "01" =>
                                            -- CPC Rd, Rr (compare with carry)
                                            res9 := ('0' & rd_val) - ('0' & rr_val) - ('0' & sreg(SREG_C));
                                            res8 := res9(7 downto 0);
                                            new_sreg(SREG_C) := '1' when rd_val < (rr_val + sreg(SREG_C)) else '0';
                                            if res8 /= 0 then new_sreg(SREG_Z) := '0'; end if;
                                            new_sreg(SREG_N) := res8(7);
                                            new_sreg(SREG_V) := '1' when (rd_val(7) = '0' and rr_val(7) = '1' and res8(7) = '1') or
                                                                (rd_val(7) = '1' and rr_val(7) = '0' and res8(7) = '0') else '0';
                                            new_sreg(SREG_H) := '1' when (rd_val(3 downto 0) < (rr_val(3 downto 0) + sreg(SREG_C))) else '0';
                                            new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                        when "11" =>
                                            -- ADD Rd, Rr
                                            res9 := ('0' & rd_val) + ('0' & rr_val);
                                            res8 := res9(7 downto 0);
                                            new_sreg(SREG_C) := res9(8);
                                            new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                            new_sreg(SREG_N) := res8(7);
                                            new_sreg(SREG_V) := '1' when (rd_val(7) = rr_val(7) and res8(7) /= rd_val(7)) else '0';
                                            new_sreg(SREG_H) := '1' when (rd_val(3 downto 0) + rr_val(3 downto 0)) > 15 else '0';
                                            new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                            regs(rd_idx) <= res8;
                                        when others => null;
                                    end case;
                                end if;

                            -- 0001: CPSE / CP / ADC / MOVW(alt)
                            when "0001" =>
                                case ir(11 downto 10) is
                                    when "00" =>
                                        -- CPSE Rd, Rr (skip if equal)
                                        if rd_val = rr_val then
                                            skip := '1';
                                        end if;
                                    when "01" =>
                                        -- CP Rd, Rr (compare, subtract for flags)
                                        res9 := ('0' & rd_val) - ('0' & rr_val);
                                        res8 := res9(7 downto 0);
                                        new_sreg(SREG_C) := '1' when rd_val < rr_val else '0';
                                        new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                        new_sreg(SREG_N) := res8(7);
                                        new_sreg(SREG_V) := '1' when (rd_val(7) = '0' and rr_val(7) = '1' and res8(7) = '1') or
                                                            (rd_val(7) = '1' and rr_val(7) = '0' and res8(7) = '0') else '0';
                                        new_sreg(SREG_H) := '1' when (rd_val(3 downto 0) < rr_val(3 downto 0)) else '0';
                                        new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                    when "11" =>
                                        -- ADC Rd, Rr (add with carry)
                                        res9 := ('0' & rd_val) + ('0' & rr_val) + ('0' & sreg(SREG_C));
                                        res8 := res9(7 downto 0);
                                        new_sreg(SREG_C) := res9(8);
                                        new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                        new_sreg(SREG_N) := res8(7);
                                        new_sreg(SREG_V) := '1' when (rd_val(7) = rr_val(7) and res8(7) /= rd_val(7)) else '0';
                                        new_sreg(SREG_H) := '1' when (rd_val(3 downto 0) + rr_val(3 downto 0) + sreg(SREG_C)) > 15 else '0';
                                        new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                        regs(rd_idx) <= res8;
                                    when others => null;
                                end case;

                            -- 0010: AND / EOR / OR / MOV
                            when "0010" =>
                                case ir(11 downto 10) is
                                    when "00" =>
                                        -- AND Rd, Rr
                                        res8 := rd_val and rr_val;
                                        new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                        new_sreg(SREG_N) := res8(7);
                                        new_sreg(SREG_V) := '0';
                                        new_sreg(SREG_S) := new_sreg(SREG_N);
                                        regs(rd_idx) <= res8;
                                    when "01" =>
                                        -- EOR Rd, Rr
                                        res8 := rd_val xor rr_val;
                                        new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                        new_sreg(SREG_N) := res8(7);
                                        new_sreg(SREG_V) := '0';
                                        new_sreg(SREG_S) := new_sreg(SREG_N);
                                        regs(rd_idx) <= res8;
                                    when "10" =>
                                        -- OR Rd, Rr
                                        res8 := rd_val or rr_val;
                                        new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                        new_sreg(SREG_N) := res8(7);
                                        new_sreg(SREG_V) := '0';
                                        new_sreg(SREG_S) := new_sreg(SREG_N);
                                        regs(rd_idx) <= res8;
                                    when "11" =>
                                        -- MOV Rd, Rr
                                        regs(rd_idx) <= rr_val;
                                    when others => null;
                                end case;

                            -- 0011: CPI / SBCI / SUBI
                            when "0011" =>
                                -- d = 16 + ir(7:4), K = ir(11:8)&ir(3:0)
                                rd_idx := 16 + to_integer(ir(7 downto 4));
                                rd_val := regs(rd_idx);
                                k8 := ir(11 downto 8) & ir(3 downto 0);
                                case ir(11 downto 10) is
                                    when "00" =>
                                        -- CPI Rd, K (compare immediate)
                                        res9 := ('0' & rd_val) - ('0' & k8);
                                        res8 := res9(7 downto 0);
                                        new_sreg(SREG_C) := '1' when rd_val < k8 else '0';
                                        new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                        new_sreg(SREG_N) := res8(7);
                                        new_sreg(SREG_V) := '1' when (rd_val(7) = '0' and k8(7) = '1' and res8(7) = '1') or
                                                            (rd_val(7) = '1' and k8(7) = '0' and res8(7) = '0') else '0';
                                        new_sreg(SREG_H) := '1' when (rd_val(3 downto 0) < k8(3 downto 0)) else '0';
                                        new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                    when others => null;
                                end case;

                            -- 0100: SBCI / SUBI / ORI / ANDI
                            when "0100" =>
                                rd_idx := 16 + to_integer(ir(7 downto 4));
                                rd_val := regs(rd_idx);
                                k8 := ir(11 downto 8) & ir(3 downto 0);
                                case ir(11 downto 10) is
                                    when "00" =>
                                        -- SBCI Rd, K
                                        res9 := ('0' & rd_val) - ('0' & k8) - ('0' & sreg(SREG_C));
                                        res8 := res9(7 downto 0);
                                        new_sreg(SREG_C) := '1' when rd_val < (k8 + sreg(SREG_C)) else '0';
                                        if res8 /= 0 then new_sreg(SREG_Z) := '0'; end if;
                                        new_sreg(SREG_N) := res8(7);
                                        new_sreg(SREG_V) := '1' when (rd_val(7) = '0' and k8(7) = '1' and res8(7) = '1') or
                                                            (rd_val(7) = '1' and k8(7) = '0' and res8(7) = '0') else '0';
                                        new_sreg(SREG_H) := '1' when (rd_val(3 downto 0) < (k8(3 downto 0) + sreg(SREG_C))) else '0';
                                        new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                        regs(rd_idx) <= res8;
                                    when others => null;
                                end case;

                            -- 0101: SUBI
                            when "0101" =>
                                rd_idx := 16 + to_integer(ir(7 downto 4));
                                rd_val := regs(rd_idx);
                                k8 := ir(11 downto 8) & ir(3 downto 0);
                                -- SUBI Rd, K
                                res9 := ('0' & rd_val) - ('0' & k8);
                                res8 := res9(7 downto 0);
                                new_sreg(SREG_C) := '1' when rd_val < k8 else '0';
                                new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                new_sreg(SREG_N) := res8(7);
                                new_sreg(SREG_V) := '1' when (rd_val(7) = '0' and k8(7) = '1' and res8(7) = '1') or
                                                    (rd_val(7) = '1' and k8(7) = '0' and res8(7) = '0') else '0';
                                new_sreg(SREG_H) := '1' when (rd_val(3 downto 0) < k8(3 downto 0)) else '0';
                                new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                regs(rd_idx) <= res8;

                            -- 0110: ORI
                            when "0110" =>
                                rd_idx := 16 + to_integer(ir(7 downto 4));
                                rd_val := regs(rd_idx);
                                k8 := ir(11 downto 8) & ir(3 downto 0);
                                -- ORI Rd, K
                                res8 := rd_val or k8;
                                new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                new_sreg(SREG_N) := res8(7);
                                new_sreg(SREG_V) := '0';
                                new_sreg(SREG_S) := new_sreg(SREG_N);
                                regs(rd_idx) <= res8;

                            -- 0111: ANDI
                            when "0111" =>
                                rd_idx := 16 + to_integer(ir(7 downto 4));
                                rd_val := regs(rd_idx);
                                k8 := ir(11 downto 8) & ir(3 downto 0);
                                -- ANDI Rd, K
                                res8 := rd_val and k8;
                                new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                new_sreg(SREG_N) := res8(7);
                                new_sreg(SREG_V) := '0';
                                new_sreg(SREG_S) := new_sreg(SREG_N);
                                regs(rd_idx) <= res8;

                            -- 1000: LD/ST with Y/Z, LDD/STD
                            when "1000" =>
                                -- Various load/store with displacement
                                -- 10q0 qqrd dddd 0qqq for LDD Y+q / LDD Z+q
                                -- Simplified: handle LD/ST with X/Y/Z
                                null;

                            -- 1001: Various (LDS/STS/LD/ST/LPM/IN/OUT/PUSH/POP/etc)
                            when "1001" =>
                                if ir(15 downto 9) = "1001000" and ir(3 downto 0) = "0001" then
                                    -- LD Rd, Z+ (post-increment)
                                    z_ptr := regs(31) & regs(30);
                                    dmem_addr_i <= z_ptr;
                                    dmem_re_i <= '1';
                                    regs(30) <= regs(30) + 1;
                                    if regs(30) = x"FF" then
                                        regs(31) <= regs(31) + 1;
                                    end if;
                                    regs(rd_idx) <= unsigned(dmem_din);
                                elsif ir(15 downto 9) = "1001001" and ir(3 downto 0) = "0001" then
                                    -- ST Z+, Rr (post-increment store)
                                    z_ptr := regs(31) & regs(30);
                                    dmem_addr_i <= z_ptr;
                                    dmem_dout_i <= rr_val;
                                    dmem_we_i <= '1';
                                    regs(30) <= regs(30) + 1;
                                    if regs(30) = x"FF" then
                                        regs(31) <= regs(31) + 1;
                                    end if;
                                elsif ir(15 downto 9) = "1001001" and ir(3 downto 0) = "0000" then
                                    -- STS k, Rr (2-word): store to data space
                                    next_state := ST_FETCH2;
                                elsif ir(15 downto 9) = "1001000" and ir(3 downto 0) = "1111" then
                                    -- POP Rd (already handled in 0000 case, but duplicate)
                                    null;
                                elsif ir(15 downto 9) = "1001010" and ir(8) = '0' and ir(3 downto 0) = "0000" then
                                    -- COM Rd
                                    res8 := not rd_val;
                                    new_sreg(SREG_C) := '1';
                                    new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                    new_sreg(SREG_N) := res8(7);
                                    new_sreg(SREG_V) := '0';
                                    new_sreg(SREG_S) := new_sreg(SREG_N);
                                    regs(rd_idx) <= res8;
                                elsif ir(15 downto 9) = "1001010" and ir(8) = '0' and ir(3 downto 0) = "0011" then
                                    -- INC Rd
                                    res8 := rd_val + 1;
                                    new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                    new_sreg(SREG_N) := res8(7);
                                    new_sreg(SREG_V) := '1' when rd_val = x"7F" else '0';
                                    new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                    regs(rd_idx) <= res8;
                                elsif ir(15 downto 9) = "1001010" and ir(8) = '1' and ir(3 downto 0) = "1010" then
                                    -- DEC Rd
                                    res8 := rd_val - 1;
                                    new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                    new_sreg(SREG_N) := res8(7);
                                    new_sreg(SREG_V) := '1' when rd_val = x"80" else '0';
                                    new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                    regs(rd_idx) <= res8;
                                elsif ir(15 downto 9) = "1001010" and ir(8) = '1' and ir(3 downto 0) = "0101" then
                                    -- CLR Rd (alias for EOR Rd,Rd)
                                    regs(rd_idx) <= (others => '0');
                                    new_sreg(SREG_Z) := '1';
                                    new_sreg(SREG_N) := '0';
                                    new_sreg(SREG_V) := '0';
                                    new_sreg(SREG_S) := '0';
                                elsif ir(15 downto 9) = "1001010" and ir(8) = '0' and ir(3 downto 0) = "0110" then
                                    -- LSR Rd (logical shift right)
                                    res8 := '0' & rd_val(7 downto 1);
                                    new_sreg(SREG_C) := rd_val(0);
                                    new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                    new_sreg(SREG_N) := '0';
                                    new_sreg(SREG_V) := new_sreg(SREG_N) xor new_sreg(SREG_C);
                                    new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                    regs(rd_idx) <= res8;
                                elsif ir(15 downto 9) = "1001010" and ir(8) = '0' and ir(3 downto 0) = "0111" then
                                    -- ROR Rd (rotate right through carry)
                                    res8 := sreg(SREG_C) & rd_val(7 downto 1);
                                    new_sreg(SREG_C) := rd_val(0);
                                    new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                    new_sreg(SREG_N) := res8(7);
                                    new_sreg(SREG_V) := new_sreg(SREG_N) xor new_sreg(SREG_C);
                                    new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                    regs(rd_idx) <= res8;
                                elsif ir(15 downto 9) = "1001010" and ir(8) = '0' and ir(3 downto 0) = "0101" then
                                    -- ASR Rd (arithmetic shift right)
                                    res8 := rd_val(7) & rd_val(7 downto 1);
                                    new_sreg(SREG_C) := rd_val(0);
                                    new_sreg(SREG_Z) := '1' when res8 = 0 else '0';
                                    new_sreg(SREG_N) := res8(7);
                                    new_sreg(SREG_V) := new_sreg(SREG_N) xor new_sreg(SREG_C);
                                    new_sreg(SREG_S) := new_sreg(SREG_N) xor new_sreg(SREG_V);
                                    regs(rd_idx) <= res8;
                                elsif ir(15 downto 9) = "1001010" and ir(8) = '0' and ir(3 downto 0) = "0010" then
                                    -- SWAP Rd (swap nibbles)
                                    res8 := rd_val(3 downto 0) & rd_val(7 downto 4);
                                    regs(rd_idx) <= res8;
                                elsif ir(15 downto 8) = "10010100" and ir(7 downto 0) = "00001000" then
                                    -- RET
                                    dmem_addr_i <= sp;
                                    dmem_re_i <= '1';
                                    new_pc(7 downto 0) := unsigned(dmem_din);
                                    dmem_addr_i <= sp + 1;
                                    new_pc(15 downto 8) := unsigned(dmem_din);
                                    sp <= sp + 2;
                                elsif ir(15 downto 8) = "10010100" and ir(7 downto 0) = "00001001" then
                                    -- ICALL (call to Z)
                                    z_ptr := regs(31) & regs(30);
                                    -- Push PC
                                    ret_addr := pc + 1;
                                    dmem_addr_i <= sp;
                                    dmem_dout_i <= ret_addr(7 downto 0);
                                    dmem_we_i <= '1';
                                    dmem_addr_i <= sp - 1;
                                    dmem_dout_i <= ret_addr(15 downto 8);
                                    dmem_we_i <= '1';
                                    sp <= sp - 2;
                                    new_pc := z_ptr;
                                elsif ir(15 downto 8) = "10010100" and ir(7 downto 0) = "00001101" then
                                    -- IJMP (jump to Z)
                                    z_ptr := regs(31) & regs(30);
                                    new_pc := z_ptr;
                                elsif ir(15 downto 8) = "10010100" and ir(7 downto 0) = "00011000" then
                                    -- SLEEP
                                    null;
                                elsif ir(15 downto 8) = "10010100" and ir(7 downto 0) = "1001000" then
                                    -- LPM Rd, Z (load program memory)
                                    -- Z is byte address; high bit selects page
                                    z_ptr := regs(31) & regs(30);
                                    -- Read from program memory (byte access)
                                    if z_ptr(0) = '0' then
                                        regs(rd_idx) <= unsigned(pmem_data(7 downto 0));
                                    else
                                        regs(rd_idx) <= unsigned(pmem_data(15 downto 8));
                                    end if;
                                elsif ir(15 downto 8) = "10010100" and ir(7 downto 0) = "00000100" then
                                    -- LPM Rd, Z+ (load program memory with post-increment)
                                    z_ptr := regs(31) & regs(30);
                                    if z_ptr(0) = '0' then
                                        regs(rd_idx) <= unsigned(pmem_data(7 downto 0));
                                    else
                                        regs(rd_idx) <= unsigned(pmem_data(15 downto 8));
                                    end if;
                                    regs(30) <= regs(30) + 1;
                                    if regs(30) = x"FF" then
                                        regs(31) <= regs(31) + 1;
                                    end if;
                                elsif ir(15 downto 9) = "1001001" and ir(3 downto 0) = "1111" then
                                    -- PUSH Rr
                                    dmem_addr_i <= sp;
                                    dmem_dout_i <= rr_val;
                                    dmem_we_i <= '1';
                                    sp <= sp - 1;
                                elsif ir(15 downto 9) = "1001000" and ir(3 downto 0) = "0101" then
                                    -- LPM Rd, Z+ (alt encoding)
                                    z_ptr := regs(31) & regs(30);
                                    if z_ptr(0) = '0' then
                                        regs(rd_idx) <= unsigned(pmem_data(7 downto 0));
                                    else
                                        regs(rd_idx) <= unsigned(pmem_data(15 downto 8));
                                    end if;
                                    regs(30) <= regs(30) + 1;
                                    if regs(30) = x"FF" then
                                        regs(31) <= regs(31) + 1;
                                    end if;
                                end if;

                            -- 1010-1011: LDS/STS/LD/ST with X/Y/Z (various)
                            when "1010" | "1011" =>
                                -- IN/OUT instructions
                                if ir(15 downto 11) = "10110" then
                                    -- IN Rd, P (P = ir(10:8)&ir(2:0), Rd = ir(7:3))
                                    rd_idx := to_integer(ir(7 downto 3));
                                    io_addr := to_integer(ir(10 downto 8) & ir(2 downto 0));
                                    if is_io then
                                        regs(rd_idx) <= io_val;
                                    else
                                        -- Read from I/O space via dmem (0x20 + io_addr)
                                        dmem_addr_i <= to_unsigned(16#20# + io_addr, 16);
                                        dmem_re_i <= '1';
                                        regs(rd_idx) <= unsigned(dmem_din);
                                    end if;
                                elsif ir(15 downto 11) = "10111" then
                                    -- OUT P, Rr (P = ir(10:8)&ir(2:0), Rr = ir(7:3))
                                    rr_idx := to_integer(ir(7 downto 3));
                                    rr_val := regs(rr_idx);
                                    io_addr := to_integer(ir(10 downto 8) & ir(2 downto 0));
                                    case io_addr is
                                        when IO_PORTB => portb_lat <= rr_val;
                                        when IO_PORTC => portc_lat <= rr_val;
                                        when IO_PORTD => portd_lat <= rr_val;
                                        when IO_DDRB  => ddrb_reg  <= rr_val;
                                        when IO_DDRC  => ddrc_reg  <= rr_val;
                                        when IO_DDRD  => ddrd_reg  <= rr_val;
                                        when IO_SREG  => new_sreg := rr_val;
                                        when IO_SPL   => sp(7 downto 0) <= rr_val;
                                        when IO_SPH   => sp(15 downto 8) <= rr_val;
                                        when others =>
                                            -- Write to I/O space via dmem
                                            dmem_addr_i <= to_unsigned(16#20# + io_addr, 16);
                                            dmem_dout_i <= rr_val;
                                            dmem_we_i <= '1';
                                    end case;
                                end if;

                            -- 1100: RJMP
                            when "1100" =>
                                -- RJMP k (k = signed 12-bit, in words)
                                offset := resize(signed(ir(11 downto 0)), 13);
                                new_pc := pc + 1 + unsigned(offset);

                            -- 1101: RCALL
                            when "1101" =>
                                -- RCALL k (relative call)
                                offset := resize(signed(ir(11 downto 0)), 13);
                                -- Push return address (PC+1 as byte address)
                                ret_addr := pc + 1;
                                dmem_addr_i <= sp;
                                dmem_dout_i <= ret_addr(7 downto 0);
                                dmem_we_i <= '1';
                                dmem_addr_i <= sp - 1;
                                dmem_dout_i <= ret_addr(15 downto 8);
                                dmem_we_i <= '1';
                                sp <= sp - 2;
                                new_pc := pc + 1 + unsigned(offset);

                            -- 1110: LDI
                            when "1110" =>
                                -- LDI Rd, K (d = 16 + ir(7:4), K = ir(11:8)&ir(3:0))
                                rd_idx := 16 + to_integer(ir(7 downto 4));
                                k8 := ir(11 downto 8) & ir(3 downto 0);
                                regs(rd_idx) <= k8;

                            -- 1111: BRBS/BRBC/BLD/BST/SBRC/SBRS
                            when "1111" =>
                                case ir(11 downto 10) is
                                    when "00" =>
                                        -- BRBS s, k (branch if status bit set)
                                        -- k = signed 7-bit offset (ir(9 downto 3))
                                        offset := resize(signed(ir(9 downto 3)), 13);
                                        if sreg(s_bit) = '1' then
                                            new_pc := pc + 1 + unsigned(offset);
                                            skip := '1';  -- mark as taken branch
                                        end if;
                                    when "01" =>
                                        -- BRBC s, k (branch if status bit clear)
                                        offset := resize(signed(ir(9 downto 3)), 13);
                                        if sreg(s_bit) = '0' then
                                            new_pc := pc + 1 + unsigned(offset);
                                            skip := '1';
                                        end if;
                                    when "10" =>
                                        -- BLD Rd, b (load T into bit b of Rd)
                                        res8 := rd_val;
                                        res8(b_bit) := sreg(SREG_T);
                                        regs(rd_idx) <= res8;
                                    when "11" =>
                                        -- BST Rd, b (store bit b of Rd into T)
                                        new_sreg(SREG_T) := rd_val(b_bit);
                                    when others => null;
                                end case;

                            when others =>
                                null;
                        end case;

                        -- Update SREG
                        sreg <= new_sreg;

                        -- State transition
                        if skip = '1' then
                            pc <= new_pc;
                            state <= ST_FETCH;
                        else
                            pc <= new_pc;
                            state <= next_state;
                        end if;

                    when ST_FETCH2 =>
                        -- Fetch second word of 2-word instruction
                        ir2 <= unsigned(pmem_data);
                        -- Execute 2-word instruction (LDS/STS/JMP/CALL)
                        if ir(15 downto 9) = "1001000" and ir(3 downto 0) = "0000" then
                            -- LDS Rd, k: load from address in ir2
                            dmem_addr_i <= unsigned(pmem_data);
                            dmem_re_i <= '1';
                            regs(to_integer(ir(8 downto 4))) <= unsigned(dmem_din);
                        elsif ir(15 downto 9) = "1001001" and ir(3 downto 0) = "0000" then
                            -- STS k, Rr: store to address in ir2
                            dmem_addr_i <= unsigned(pmem_data);
                            dmem_dout_i <= regs(to_integer(ir(8 downto 4)));
                            dmem_we_i <= '1';
                        elsif ir(15 downto 8) = "10010100" and ir(7 downto 0) = "00001100" then
                            -- JMP k (k = 16-bit in ir2, extended PC)
                            new_pc := unsigned(pmem_data);
                            pc <= new_pc;
                        elsif ir(15 downto 8) = "10010100" and ir(7 downto 0) = "00001110" then
                            -- CALL k (push PC, jump to k)
                            ret_addr := pc + 2;
                            dmem_addr_i <= sp;
                            dmem_dout_i <= ret_addr(7 downto 0);
                            dmem_we_i <= '1';
                            dmem_addr_i <= sp - 1;
                            dmem_dout_i <= ret_addr(15 downto 8);
                            dmem_we_i <= '1';
                            sp <= sp - 2;
                            new_pc := unsigned(pmem_data);
                            pc <= new_pc;
                        end if;
                        is_2word <= '0';
                        pc <= pc + 2;
                        state <= ST_FETCH;

                    when ST_SKIP =>
                        state <= ST_FETCH;

                    when others =>
                        state <= ST_FETCH;
                end case;
            end if;
        end if;
    end process cpu_proc;

end architecture rtl;

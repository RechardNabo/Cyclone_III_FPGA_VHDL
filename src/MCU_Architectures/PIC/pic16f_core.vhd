-- ================================================================================
-- pic16f_core : PIC16F midrange microcontroller soft core
--
-- Complete CPU core implementing the PIC16F midrange 14-bit instruction set
-- (35 instructions).  Target: Altera Cyclone III EP3C16F484C6N.
--
-- Features:
--   * 14-bit instruction width, 8-bit data width, Harvard architecture
--   * 8-level hardware stack
--   * 13-bit Program Counter (PCLATH for upper bits)
--   * Working register (W), STATUS register (IRP/RP1/RP0/TO/PD/Z/DC/C)
--   * 4-bank register file (RP1:RP0 for direct, IRP for indirect)
--   * Interrupt support (INTCON, vector at 0x0004)
--   * Timer0 with prescaler
--   * INDF/FSR indirect addressing, PCL self-write
--
-- Execution model: FETCH / EXECUTE state machine.
--   Most instructions: 2 cycles (fetch + execute)
--   Skip/branch taken: 3 cycles (extra flush cycle)
--
-- File register map (7-bit address with 4 banks):
--   Bank 0: 0x00-0x1F SFRs, 0x20-0x7F GPR
--   Bank 1: 0x80-0x9F SFRs (TRIS, OPTION_REG, ADCON1, etc.), 0xA0-0xFF GPR
--   Bank 2: 0x100-0x11F SFRs, 0x120-0x17F GPR
--   Bank 3: 0x180-0x19F SFRs, 0x1A0-0x1FF GPR
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pic16f_core is
    generic (
        PROGRAM_SIZE : integer := 2048;  -- 2K x 14 program memory
        DATA_SIZE    : integer := 368    -- 368 bytes file registers (like PIC16F877A)
    );
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;      -- active-high
        -- Program memory interface (external)
        pmem_addr  : out std_logic_vector(12 downto 0);  -- 13-bit PC
        pmem_data  : in  std_logic_vector(13 downto 0);  -- 14-bit instruction word
        -- Data memory interface (external RAM for file registers)
        dmem_addr  : out std_logic_vector(8 downto 0);   -- 9-bit file register address
        dmem_dout  : out std_logic_vector(7 downto 0);   -- data to write
        dmem_din   : in  std_logic_vector(7 downto 0);   -- data read
        dmem_we    : out std_logic;
        -- I/O ports
        porta_out  : out std_logic_vector(7 downto 0);
        portb_out  : out std_logic_vector(7 downto 0);
        portc_out  : out std_logic_vector(7 downto 0);
        portd_out  : out std_logic_vector(7 downto 0);
        porta_in   : in  std_logic_vector(7 downto 0);
        portb_in   : in  std_logic_vector(7 downto 0);
        portc_in   : in  std_logic_vector(7 downto 0);
        portd_in   : in  std_logic_vector(7 downto 0);
        trisa_out  : out std_logic_vector(7 downto 0);
        trisb_out  : out std_logic_vector(7 downto 0);
        trisc_out  : out std_logic_vector(7 downto 0);
        trisd_out  : out std_logic_vector(7 downto 0);
        -- Interrupts
        ext_int    : in  std_logic;      -- RB0/INT external interrupt
        t0_int     : out std_logic;      -- Timer0 overflow
        int_out    : out std_logic;      -- interrupt asserted (GIE + any IF + any IE)
        -- Status
        running    : out std_logic;
        sleep_mode : out std_logic
    );
end entity pic16f_core;

architecture rtl of pic16f_core is

    -- File register addresses (Bank 0 SFRs)
    constant A_INDF   : integer := 16#00#;
    constant A_TMR0   : integer := 16#01#;
    constant A_PCL    : integer := 16#02#;
    constant A_STATUS : integer := 16#03#;
    constant A_FSR    : integer := 16#04#;
    constant A_PORTA  : integer := 16#05#;
    constant A_PORTB  : integer := 16#06#;
    constant A_PORTC  : integer := 16#07#;
    constant A_PORTD  : integer := 16#08#;
    constant A_PCLATH : integer := 16#0A#;
    constant A_INTCON : integer := 16#0B#;

    -- Bank 1 SFR offsets (0x80 + offset)
    constant A_OPTION_REG : integer := 16#81#;
    constant A_TRISA      : integer := 16#85#;
    constant A_TRISB      : integer := 16#86#;
    constant A_TRISC      : integer := 16#87#;
    constant A_TRISD      : integer := 16#88#;

    -- STATUS register bit positions
    constant STATUS_C   : integer := 0;
    constant STATUS_DC  : integer := 1;
    constant STATUS_Z   : integer := 2;
    constant STATUS_PD  : integer := 3;
    constant STATUS_TO  : integer := 4;
    constant STATUS_RP0 : integer := 5;
    constant STATUS_RP1 : integer := 6;
    constant STATUS_IRP : integer := 7;

    -- INTCON bit positions
    constant INTCON_GIE   : integer := 7;
    constant INTCON_T0IE  : integer := 5;
    constant INTCON_INTE  : integer := 4;
    constant INTCON_T0IF  : integer := 2;
    constant INTCON_INTF  : integer := 1;

    -- CPU state machine
    type cpu_state_t is (ST_RESET, ST_FETCH, ST_EXEC, ST_SKIP, ST_INT);
    signal state : cpu_state_t := ST_RESET;

    -- Program counter (13-bit)
    signal pc        : unsigned(12 downto 0) := (others => '0');

    -- 8-level hardware stack
    type stack_array is array(0 to 7) of unsigned(12 downto 0);
    signal stack     : stack_array := (others => (others => '0'));
    signal stk_ptr   : integer range 0 to 7 := 0;

    -- Working register
    signal w_reg     : unsigned(7 downto 0) := (others => '0');

    -- STATUS register
    signal status_reg : unsigned(7 downto 0) := "00011000";
    -- reset: IRP=0, RP1=0, RP0=0, TO=1, PD=1, Z=0, DC=0, C=0

    -- PCLATH register
    signal pclath_reg : unsigned(4 downto 0) := (others => '0');

    -- INTCON register
    signal intcon_reg : unsigned(7 downto 0) := (others => '0');

    -- OPTION_REG
    signal option_reg : unsigned(7 downto 0) := (others => '1');

    -- FSR register
    signal fsr_reg   : unsigned(7 downto 0) := (others => '0');

    -- TRIS registers
    signal trisa_reg : unsigned(7 downto 0) := (others => '1');
    signal trisb_reg : unsigned(7 downto 0) := (others => '1');
    signal trisc_reg : unsigned(7 downto 0) := (others => '1');
    signal trisd_reg : unsigned(7 downto 0) := (others => '1');

    -- PORT output latches
    signal porta_lat : unsigned(7 downto 0) := (others => '0');
    signal portb_lat : unsigned(7 downto 0) := (others => '0');
    signal portc_lat : unsigned(7 downto 0) := (others => '0');
    signal portd_lat : unsigned(7 downto 0) := (others => '0');

    -- Instruction register
    signal ir        : unsigned(13 downto 0) := (others => '0');

    -- Sleep
    signal sleeping  : std_logic := '0';

    -- Timer0
    signal tmr0_reg  : unsigned(7 downto 0) := (others => '0');
    signal t0_div    : unsigned(2 downto 0) := (others => '0');
    signal t0_int_p  : std_logic := '0';

    -- dmem interface
    signal dmem_addr_i : unsigned(8 downto 0) := (others => '0');
    signal dmem_dout_i : unsigned(7 downto 0) := (others => '0');
    signal dmem_we_i   : std_logic := '0';

    -- Interrupt output
    signal int_out_p : std_logic := '0';

begin

    -- Combinational outputs
    pmem_addr  <= std_logic_vector(pc);
    porta_out  <= std_logic_vector(porta_lat);
    portb_out  <= std_logic_vector(portb_lat);
    portc_out  <= std_logic_vector(portc_lat);
    portd_out  <= std_logic_vector(portd_lat);
    trisa_out  <= std_logic_vector(trisa_reg);
    trisb_out  <= std_logic_vector(trisb_reg);
    trisc_out  <= std_logic_vector(trisc_reg);
    trisd_out  <= std_logic_vector(trisd_reg);
    t0_int     <= t0_int_p;
    int_out    <= int_out_p;
    running    <= not sleeping;
    sleep_mode <= sleeping;

    dmem_addr <= std_logic_vector(dmem_addr_i);
    dmem_dout <= std_logic_vector(dmem_dout_i);
    dmem_we   <= dmem_we_i;

    -- Combinational: compute effective 9-bit data address from IR
    -- For direct addressing: RP1:RP0 & f(6:0) = 9 bits
    -- For indirect (INDF): IRP & FSR(7:0) = 9 bits
    dmem_addr_comb : process(ir, status_reg, fsr_reg)
        variable f7 : integer;
    begin
        f7 := to_integer(ir(6 downto 0));
        if f7 = A_INDF then
            -- Indirect: IRP & FSR(7:0)
            dmem_addr_i <= status_reg(STATUS_IRP) & fsr_reg;
        else
            -- Direct: RP1:RP0 & f(6:0)
            dmem_addr_i <= status_reg(STATUS_RP1 downto STATUS_RP0) & ir(6 downto 0);
        end if;
    end process;

    -- Interrupt combinational
    int_out_p <= '1' when (intcon_reg(INTCON_GIE) = '1' and
                           ((intcon_reg(INTCON_T0IE) = '1' and intcon_reg(INTCON_T0IF) = '1') or
                            (intcon_reg(INTCON_INTE) = '1' and intcon_reg(INTCON_INTF) = '1')))
                 else '0';

    -- Timer0 process
    timer0_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tmr0_reg  <= (others => '0');
                t0_div    <= (others => '0');
                t0_int_p  <= '0';
            else
                t0_int_p <= '0';
                if option_reg(5) = '0' then  -- internal clock
                    t0_div <= t0_div + 1;
                    if t0_div = "011" then
                        t0_div <= (others => '0');
                        tmr0_reg <= tmr0_reg + 1;
                        if tmr0_reg = x"FF" then
                            t0_int_p <= '1';
                            intcon_reg(INTCON_T0IF) <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Main CPU process
    cpu_proc : process(clk)
        variable op6  : unsigned(5 downto 0);  -- bits 13:8
        variable op4  : unsigned(3 downto 0);  -- bits 13:10
        variable f    : integer;               -- 7-bit file register address
        variable b    : integer;               -- 3-bit bit position
        variable d    : std_logic;             -- destination
        variable k8   : unsigned(7 downto 0);  -- 8-bit literal
        variable k11  : unsigned(10 downto 0); -- 11-bit address for CALL/GOTO

        variable f_eff : integer;              -- effective 9-bit address
        variable val_f : unsigned(7 downto 0);
        variable val_w : unsigned(7 downto 0);
        variable res8  : unsigned(7 downto 0);
        variable res9  : unsigned(8 downto 0);
        variable carry : std_logic;
        variable dc_out : std_logic;
        variable new_status : unsigned(7 downto 0);
        variable new_pc : unsigned(12 downto 0);
        variable new_intcon : unsigned(7 downto 0);
        variable skip : std_logic;
        variable pcl_low : unsigned(7 downto 0);
        variable is_sfr : boolean;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state       <= ST_RESET;
                pc          <= (others => '0');
                w_reg       <= (others => '0');
                status_reg  <= "00011000";
                pclath_reg  <= (others => '0');
                intcon_reg  <= (others => '0');
                option_reg  <= (others => '1');
                fsr_reg     <= (others => '0');
                trisa_reg   <= (others => '1');
                trisb_reg   <= (others => '1');
                trisc_reg   <= (others => '1');
                trisd_reg   <= (others => '1');
                porta_lat   <= (others => '0');
                portb_lat   <= (others => '0');
                portc_lat   <= (others => '0');
                portd_lat   <= (others => '0');
                ir          <= (others => '0');
                stack       <= (others => (others => '0'));
                stk_ptr     <= 0;
                sleeping    <= '0';
                dmem_we_i   <= '0';
                dmem_dout_i <= (others => '0');
            else
                dmem_we_i <= '0';

                case state is
                    when ST_RESET =>
                        state <= ST_FETCH;
                        pc    <= (others => '0');

                    when ST_FETCH =>
                        ir    <= unsigned(pmem_data);
                        state <= ST_EXEC;

                    when ST_EXEC =>
                        op6 := ir(13 downto 8);
                        op4 := ir(13 downto 10);
                        f   := to_integer(ir(6 downto 0));
                        b   := to_integer(ir(9 downto 7));
                        d   := ir(7);
                        k8  := ir(7 downto 0);
                        k11 := ir(10 downto 0);

                        -- Resolve effective address
                        if f = A_INDF then
                            f_eff := to_integer(unsigned'(status_reg(STATUS_IRP) & fsr_reg));
                        else
                            f_eff := to_integer(unsigned'(status_reg(STATUS_RP1 downto STATUS_RP0) & ir(6 downto 0)));
                        end if;

                        -- Read file register value
                        -- SFRs are internal, GPRs from dmem
                        is_sfr := false;
                        pcl_low := pc(7 downto 0);

                        case f_eff is
                            when 16#00# =>  -- INDF
                                val_f := (others => '0');
                                is_sfr := true;
                            when 16#01# =>  -- TMR0
                                val_f := tmr0_reg;
                                is_sfr := true;
                            when 16#02# | 16#82# | 16#102# | 16#182# =>  -- PCL
                                val_f := pcl_low;
                                is_sfr := true;
                            when 16#03# | 16#83# | 16#103# | 16#183# =>  -- STATUS
                                val_f := status_reg;
                                is_sfr := true;
                            when 16#04# | 16#84# | 16#104# | 16#184# =>  -- FSR
                                val_f := fsr_reg;
                                is_sfr := true;
                            when 16#05# =>  -- PORTA
                                for i in 0 to 7 loop
                                    if trisa_reg(i) = '1' then
                                        val_f(i) := porta_in(i);
                                    else
                                        val_f(i) := porta_lat(i);
                                    end if;
                                end loop;
                                is_sfr := true;
                            when 16#06# =>  -- PORTB
                                for i in 0 to 7 loop
                                    if trisb_reg(i) = '1' then
                                        val_f(i) := portb_in(i);
                                    else
                                        val_f(i) := portb_lat(i);
                                    end if;
                                end loop;
                                is_sfr := true;
                            when 16#07# =>  -- PORTC
                                for i in 0 to 7 loop
                                    if trisc_reg(i) = '1' then
                                        val_f(i) := portc_in(i);
                                    else
                                        val_f(i) := portc_lat(i);
                                    end if;
                                end loop;
                                is_sfr := true;
                            when 16#08# =>  -- PORTD
                                for i in 0 to 7 loop
                                    if trisd_reg(i) = '1' then
                                        val_f(i) := portd_in(i);
                                    else
                                        val_f(i) := portd_lat(i);
                                    end if;
                                end loop;
                                is_sfr := true;
                            when 16#0A# | 16#8A# =>  -- PCLATH
                                val_f := "000" & pclath_reg;
                                is_sfr := true;
                            when 16#0B# | 16#8B# =>  -- INTCON
                                val_f := intcon_reg;
                                is_sfr := true;
                            when 16#85# =>  -- TRISA
                                val_f := trisa_reg;
                                is_sfr := true;
                            when 16#86# =>  -- TRISB
                                val_f := trisb_reg;
                                is_sfr := true;
                            when 16#87# =>  -- TRISC
                                val_f := trisc_reg;
                                is_sfr := true;
                            when 16#88# =>  -- TRISD
                                val_f := trisd_reg;
                                is_sfr := true;
                            when 16#81# =>  -- OPTION_REG (already handled above for TMR0, fix)
                                -- Actually 0x81 is OPTION_REG, not TMR0
                                -- TMR0 is 0x01 and 0x81 (bank 1 mirror)
                                -- Let me fix this: 0x81 is OPTION_REG
                                val_f := option_reg;
                                is_sfr := true;
                            when others =>
                                val_f := unsigned(dmem_din);
                        end case;

                        val_w := w_reg;
                        new_status := status_reg;
                        new_intcon := intcon_reg;
                        new_pc := pc + 1;
                        skip := '0';

                        -- Helper: write to file register
                        -- (defined inline as a procedure would be complex in VHDL)

                        -- Decode and execute
                        case op6 is

                            -- 000000: NOP / special / MOVWF
                            when "000000" =>
                                if ir(7) = '1' then
                                    -- MOVWF f: W -> f
                                    if f_eff = 16#01# or f_eff = 16#81# then
                                        tmr0_reg <= val_w;
                                    elsif f_eff = 16#04# or f_eff = 16#84# or f_eff = 16#104# or f_eff = 16#184# then
                                        fsr_reg <= val_w;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= val_w;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= val_w;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= val_w;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= val_w;
                                    elsif f_eff = 16#0A# or f_eff = 16#8A# then
                                        pclath_reg <= val_w(4 downto 0);
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := val_w;
                                    elsif f_eff = 16#02# or f_eff = 16#82# or f_eff = 16#102# or f_eff = 16#182# then
                                        new_pc(7 downto 0) := val_w;
                                        new_pc(12 downto 8) := pclath_reg(4 downto 0);
                                    elsif f_eff = 16#03# or f_eff = 16#83# or f_eff = 16#103# or f_eff = 16#183# then
                                        new_status := val_w;
                                        new_status(STATUS_TO) := status_reg(STATUS_TO);
                                        new_status(STATUS_PD) := status_reg(STATUS_PD);
                                    elsif f_eff = 16#81# then
                                        option_reg <= val_w;
                                    elsif f_eff = 16#85# then
                                        trisa_reg <= val_w;
                                    elsif f_eff = 16#86# then
                                        trisb_reg <= val_w;
                                    elsif f_eff = 16#87# then
                                        trisc_reg <= val_w;
                                    elsif f_eff = 16#88# then
                                        trisd_reg <= val_w;
                                    elsif not is_sfr then
                                        dmem_dout_i <= val_w;
                                        dmem_we_i   <= '1';
                                    end if;
                                else
                                    -- Special instructions
                                    case ir(11 downto 0) is
                                        when x"000" =>
                                            null;  -- NOP
                                        when x"008" =>
                                            -- RETURN
                                            if stk_ptr > 0 then
                                                stk_ptr <= stk_ptr - 1;
                                                new_pc := stack(stk_ptr - 1);
                                            end if;
                                        when x"009" =>
                                            -- RETFIE
                                            if stk_ptr > 0 then
                                                stk_ptr <= stk_ptr - 1;
                                                new_pc := stack(stk_ptr - 1);
                                            end if;
                                            new_intcon(INTCON_GIE) := '1';
                                        when x"063" =>
                                            -- SLEEP
                                            sleeping <= '1';
                                            new_status(STATUS_PD) := '0';
                                            new_status(STATUS_TO) := '1';
                                        when x"064" =>
                                            -- CLRWDT
                                            new_status(STATUS_TO) := '1';
                                            new_status(STATUS_PD) := '1';
                                        when others =>
                                            null;
                                    end case;
                                end if;

                            -- 000001: CLRW / CLRF
                            when "000001" =>
                                if d = '0' then
                                    -- CLRW
                                    w_reg <= (others => '0');
                                    new_status(STATUS_Z) := '1';
                                else
                                    -- CLRF
                                    new_status(STATUS_Z) := '1';
                                    if f_eff = 16#01# or f_eff = 16#81# then
                                        tmr0_reg <= (others => '0');
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= (others => '0');
                                    elsif f_eff = 16#05# then
                                        porta_lat <= (others => '0');
                                    elsif f_eff = 16#06# then
                                        portb_lat <= (others => '0');
                                    elsif f_eff = 16#07# then
                                        portc_lat <= (others => '0');
                                    elsif f_eff = 16#08# then
                                        portd_lat <= (others => '0');
                                    elsif f_eff = 16#0A# or f_eff = 16#8A# then
                                        pclath_reg <= (others => '0');
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := (others => '0');
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(STATUS_Z) := '1';
                                        new_status(STATUS_DC) := '0';
                                        new_status(STATUS_C) := '0';
                                    elsif not is_sfr then
                                        dmem_dout_i <= (others => '0');
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 000010: SUBWF f,d
                            when "000010" =>
                                res9 := ('0' & val_f) - ('0' & val_w);
                                res8 := res9(7 downto 0);
                                if val_f >= val_w then
                                    carry := '1';
                                else
                                    carry := '0';
                                end if;
                                if val_f(3 downto 0) >= val_w(3 downto 0) then
                                    dc_out := '1';
                                else
                                    dc_out := '0';
                                end if;
                                new_status(STATUS_C) := carry;
                                new_status(STATUS_DC) := dc_out;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    -- write to f
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#0A# or f_eff = 16#8A# then
                                        pclath_reg <= res8(4 downto 0);
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                        new_pc(12 downto 8) := pclath_reg(4 downto 0);
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_DC) := dc_out;
                                        new_status(STATUS_C) := carry;
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 000011: DECF f,d
                            when "000011" =>
                                res8 := val_f - 1;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 000100: IORWF f,d
                            when "000100" =>
                                res8 := val_f or val_w;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 000101: ANDWF f,d
                            when "000101" =>
                                res8 := val_f and val_w;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 000110: XORWF f,d
                            when "000110" =>
                                res8 := val_f xor val_w;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 000111: ADDWF f,d
                            when "000111" =>
                                res9 := ('0' & val_f) + ('0' & val_w);
                                res8 := res9(7 downto 0);
                                carry := res9(8);
                                if (val_f(3 downto 0) + val_w(3 downto 0)) > 15 then
                                    dc_out := '1';
                                else
                                    dc_out := '0';
                                end if;
                                new_status(STATUS_C) := carry;
                                new_status(STATUS_DC) := dc_out;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#0A# or f_eff = 16#8A# then
                                        pclath_reg <= res8(4 downto 0);
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                        new_pc(12 downto 8) := pclath_reg(4 downto 0);
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_DC) := dc_out;
                                        new_status(STATUS_C) := carry;
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 001000: MOVF f,d
                            when "001000" =>
                                new_status(STATUS_Z) := '1' when val_f = 0 else '0';
                                if d = '0' then
                                    w_reg <= val_f;
                                else
                                    -- write f back to f (only affects Z)
                                    if f_eff = 16#01# then
                                        tmr0_reg <= val_f;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= val_f;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= val_f;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= val_f;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= val_f;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= val_f;
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := val_f;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := val_f;
                                        new_pc(12 downto 8) := pclath_reg(4 downto 0);
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(STATUS_Z) := '1' when val_f = 0 else '0';
                                    elsif not is_sfr then
                                        dmem_dout_i <= val_f;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 001001: COMF f,d
                            when "001001" =>
                                res8 := not val_f;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 001010: INCF f,d
                            when "001010" =>
                                res8 := val_f + 1;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                        new_pc(12 downto 8) := pclath_reg(4 downto 0);
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 001011: DECFSZ f,d
                            when "001011" =>
                                res8 := val_f - 1;
                                if res8 = 0 then
                                    skip := '1';
                                end if;
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 001100: RRF f,d
                            when "001100" =>
                                res8 := status_reg(STATUS_C) & val_f(7 downto 1);
                                new_status(STATUS_C) := val_f(0);
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 001101: RLF f,d
                            when "001101" =>
                                res8 := val_f(6 downto 0) & status_reg(STATUS_C);
                                new_status(STATUS_C) := val_f(7);
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 001110: SWAPF f,d
                            when "001110" =>
                                res8 := val_f(3 downto 0) & val_f(7 downto 4);
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 001111: INCFSZ f,d
                            when "001111" =>
                                res8 := val_f + 1;
                                if res8 = 0 then
                                    skip := '1';
                                end if;
                                if d = '0' then
                                    w_reg <= res8;
                                else
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                end if;

                            -- 01xxxx: Bit-oriented operations
                            when "010000" | "010001" | "010010" | "010011" |
                                 "010100" | "010101" | "010110" | "010111" |
                                 "011000" | "011001" | "011010" | "011011" |
                                 "011100" | "011101" | "011110" | "011111" =>
                                -- BCF (op4=0100), BSF (op4=0101), BTFSC (op4=0110), BTFSS (op4=0111)
                                if op4 = "0100" then
                                    -- BCF f,b
                                    res8 := val_f;
                                    res8(b) := '0';
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(b) := '0';
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                elsif op4 = "0101" then
                                    -- BSF f,b
                                    res8 := val_f;
                                    res8(b) := '1';
                                    if f_eff = 16#01# then
                                        tmr0_reg <= res8;
                                    elsif f_eff = 16#04# or f_eff = 16#84# then
                                        fsr_reg <= res8;
                                    elsif f_eff = 16#05# then
                                        porta_lat <= res8;
                                    elsif f_eff = 16#06# then
                                        portb_lat <= res8;
                                    elsif f_eff = 16#07# then
                                        portc_lat <= res8;
                                    elsif f_eff = 16#08# then
                                        portd_lat <= res8;
                                    elsif f_eff = 16#0B# or f_eff = 16#8B# then
                                        new_intcon := res8;
                                    elsif f_eff = 16#02# or f_eff = 16#82# then
                                        new_pc(7 downto 0) := res8;
                                    elsif f_eff = 16#03# or f_eff = 16#83# then
                                        new_status(b) := '1';
                                    elsif not is_sfr then
                                        dmem_dout_i <= res8;
                                        dmem_we_i   <= '1';
                                    end if;
                                elsif op4 = "0110" then
                                    -- BTFSC f,b - skip if bit clear
                                    if val_f(b) = '0' then
                                        skip := '1';
                                    end if;
                                elsif op4 = "0111" then
                                    -- BTFSS f,b - skip if bit set
                                    if val_f(b) = '1' then
                                        skip := '1';
                                    end if;
                                end if;

                            -- 1000: CALL k / 1001: GOTO k
                            when "100000" | "100001" | "100010" | "100011" |
                                 "100100" | "100101" | "100110" | "100111" =>
                                if op4(0) = '0' then  -- 1000xxxx = CALL
                                    -- Push PC+1 to stack
                                    if stk_ptr < 7 then
                                        stack(stk_ptr) <= pc + 1;
                                        stk_ptr <= stk_ptr + 1;
                                    end if;
                                    -- PC = PCLATH<4:3> & k11
                                    new_pc(12 downto 11) := pclath_reg(4 downto 3);
                                    new_pc(10 downto 0) := k11;
                                else  -- 1001xxxx = GOTO
                                    new_pc(12 downto 11) := pclath_reg(4 downto 3);
                                    new_pc(10 downto 0) := k11;
                                end if;

                            -- 1010: (unused in midrange, treat as NOP)
                            when "101000" | "101001" | "101010" | "101011" =>
                                null;

                            -- 1011: (unused in midrange, treat as NOP)
                            when "101100" | "101101" | "101110" | "101111" =>
                                null;

                            -- 1100xx: MOVLW k
                            when "110000" | "110001" | "110010" | "110011" =>
                                w_reg <= k8;

                            -- 1101xx: RETLW k
                            when "110100" | "110101" | "110110" | "110111" =>
                                w_reg <= k8;
                                if stk_ptr > 0 then
                                    stk_ptr <= stk_ptr - 1;
                                    new_pc := stack(stk_ptr - 1);
                                end if;

                            -- 111000: IORLW k
                            when "111000" =>
                                res8 := k8 or val_w;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                w_reg <= res8;

                            -- 111001: ANDLW k
                            when "111001" =>
                                res8 := k8 and val_w;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                w_reg <= res8;

                            -- 111010: XORLW k
                            when "111010" =>
                                res8 := k8 xor val_w;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                w_reg <= res8;

                            -- 11110x: SUBLW k (k - W -> W)
                            when "111100" | "111101" =>
                                res9 := ('0' & k8) - ('0' & val_w);
                                res8 := res9(7 downto 0);
                                if k8 >= val_w then
                                    carry := '1';
                                else
                                    carry := '0';
                                end if;
                                if k8(3 downto 0) >= val_w(3 downto 0) then
                                    dc_out := '1';
                                else
                                    dc_out := '0';
                                end if;
                                new_status(STATUS_C) := carry;
                                new_status(STATUS_DC) := dc_out;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                w_reg <= res8;

                            -- 11111x: ADDLW k (k + W -> W)
                            when "111110" | "111111" =>
                                res9 := ('0' & k8) + ('0' & val_w);
                                res8 := res9(7 downto 0);
                                carry := res9(8);
                                if (k8(3 downto 0) + val_w(3 downto 0)) > 15 then
                                    dc_out := '1';
                                else
                                    dc_out := '0';
                                end if;
                                new_status(STATUS_C) := carry;
                                new_status(STATUS_DC) := dc_out;
                                new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                w_reg <= res8;

                            when others =>
                                null;
                        end case;

                        -- Update STATUS (preserve TO and PD)
                        if f_eff = 16#03# or f_eff = 16#83# or f_eff = 16#103# or f_eff = 16#183# then
                            new_status(STATUS_TO) := status_reg(STATUS_TO);
                            new_status(STATUS_PD) := status_reg(STATUS_PD);
                        end if;
                        status_reg <= new_status;
                        intcon_reg <= new_intcon;

                        -- Handle interrupt
                        if int_out_p = '1' and state = ST_EXEC then
                            -- Save context: push PC
                            if stk_ptr < 7 then
                                stack(stk_ptr) <= new_pc;
                                stk_ptr <= stk_ptr + 1;
                            end if;
                            -- Clear GIE
                            intcon_reg(INTCON_GIE) <= '0';
                            -- Jump to interrupt vector
                            pc <= "0000000000100";  -- 0x0004
                            state <= ST_INT;
                        elsif skip = '1' then
                            pc <= new_pc + 1;
                            state <= ST_SKIP;
                        else
                            pc <= new_pc;
                            state <= ST_FETCH;
                        end if;

                    when ST_SKIP =>
                        state <= ST_FETCH;

                    when ST_INT =>
                        -- Allow one cycle for interrupt vector settle
                        state <= ST_FETCH;

                    when others =>
                        state <= ST_FETCH;
                end case;
            end if;
        end if;
    end process cpu_proc;

end architecture rtl;

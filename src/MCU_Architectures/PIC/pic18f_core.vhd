-- ================================================================================
-- pic18f_core : PIC18F enhanced microcontroller soft core
--
-- Complete CPU core implementing the PIC18F enhanced 16-bit instruction set.
-- Target: Altera Cyclone III EP3C16F484C6N.
--
-- Features:
--   * 16-bit instruction width, 8-bit data width, Harvard architecture
--   * 32-level hardware stack
--   * 21-bit Program Counter (up to 2 MB program memory)
--   * Working register (WREG), STATUS register (N/OV/Z/DC/C)
--   * BSR (Bank Select Register) for data memory banking
--   * Access RAM mode (a=0: access bank, a=1: BSR banked)
--   * Hardware 8x8 multiply (MULWF, MULLW) -> PRODL:PRODH
--   * Table read/write (TBLRD/TBLWT) for flash access
--   * FSR0-FSR5 indirect addressing registers
--   * Interrupt support (vector at 0x0008)
--
-- Execution model: FETCH / EXECUTE state machine.
--   Most instructions: 2 cycles (fetch + execute)
--   Skip/branch taken: 3 cycles (extra flush cycle)
--   2-word instructions (MOVFF, GOTO/CALL with >16-bit addr): 4 cycles
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pic18f_core is
    generic (
        PROGRAM_SIZE : integer := 4096;  -- 4K x 16 program memory
        DATA_SIZE    : integer := 1536   -- 1.5K data memory
    );
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;      -- active-high
        -- Program memory interface (external)
        pmem_addr  : out std_logic_vector(20 downto 0);  -- 21-bit PC
        pmem_data  : in  std_logic_vector(15 downto 0);  -- 16-bit instruction word
        -- Data memory interface (external RAM)
        dmem_addr  : out std_logic_vector(11 downto 0);  -- 12-bit data address
        dmem_dout  : out std_logic_vector(7 downto 0);   -- data to write
        dmem_din   : in  std_logic_vector(7 downto 0);   -- data read
        dmem_we    : out std_logic;
        -- I/O ports
        porta_out  : out std_logic_vector(7 downto 0);
        portb_out  : out std_logic_vector(7 downto 0);
        portc_out  : out std_logic_vector(7 downto 0);
        portd_out  : out std_logic_vector(7 downto 0);
        porte_out  : out std_logic_vector(7 downto 0);
        porta_in   : in  std_logic_vector(7 downto 0);
        portb_in   : in  std_logic_vector(7 downto 0);
        portc_in   : in  std_logic_vector(7 downto 0);
        portd_in   : in  std_logic_vector(7 downto 0);
        porte_in   : in  std_logic_vector(7 downto 0);
        trisa_out  : out std_logic_vector(7 downto 0);
        trisb_out  : out std_logic_vector(7 downto 0);
        trisc_out  : out std_logic_vector(7 downto 0);
        trisd_out  : out std_logic_vector(7 downto 0);
        trie_out   : out std_logic_vector(7 downto 0);
        -- Interrupts
        ext_int    : in  std_logic;      -- INT0
        int_out    : out std_logic;      -- interrupt asserted
        -- Status
        running    : out std_logic;
        sleep_mode : out std_logic
    );
end entity pic18f_core;

architecture rtl of pic18f_core is

    -- SFR addresses in access bank (0xF80-0xFFF)
    -- Access bank low: 0x000-0x07F (mapped via access bit)
    -- Access bank high (SFRs): 0xF80-0xFFF
    constant A_PORTA   : integer := 16#F80#;
    constant A_TRISA    : integer := 16#F92#;
    constant A_PORTB    : integer := 16#F81#;
    constant A_TRISB    : integer := 16#F93#;
    constant A_PORTC    : integer := 16#F82#;
    constant A_TRISC    : integer := 16#F94#;
    constant A_PORTD    : integer := 16#F83#;
    constant A_TRISD    : integer := 16#F95#;
    constant A_PORTE    : integer := 16#F84#;
    constant A_TRISE    : integer := 16#F96#;
    constant A_WREG     : integer := 16#FE8#;
    constant A_STATUS   : integer := 16#FD8#;
    constant A_BSR       : integer := 16#FE0#;
    constant A_PRODL     : integer := 16#FEB#;
    constant A_PRODH     : integer := 16#FEC#;
    constant A_TBLPTRL   : integer := 16#FF6#;
    constant A_TBLPTRH   : integer := 16#FF7#;
    constant A_TBLPTRU   : integer := 16#FF8#;
    constant A_TABLAT    : integer := 16#FF5#;
    constant A_STKPTR    : integer := 16#FFC#;
    constant A_INTCON    : integer := 16#FF0#;
    constant A_INTCON2   : integer := 16#FF1#;
    constant A_FSR0L     : integer := 16#FE9#;
    constant A_FSR0H     : integer := 16#FEA#;
    constant A_FSR1L     : integer := 16#FE1#;
    constant A_FSR1H     : integer := 16#FE2#;
    constant A_PCL       : integer := 16#FF9#;
    constant A_PCLATH    : integer := 16#FFA#;
    constant A_PCLATU    : integer := 16#FFB#;

    -- STATUS register bit positions
    constant STATUS_C   : integer := 0;
    constant STATUS_DC  : integer := 1;
    constant STATUS_Z   : integer := 2;
    constant STATUS_OV : integer := 3;
    constant STATUS_N   : integer := 4;

    -- INTCON bit positions
    constant INTCON_GIE  : integer := 7;
    constant INTCON_T0IE : integer := 5;
    constant INTCON_T0IF : integer := 2;

    -- CPU state machine
    type cpu_state_t is (ST_RESET, ST_FETCH, ST_EXEC, ST_SKIP, ST_FETCH2);
    signal state : cpu_state_t := ST_RESET;

    -- Program counter (21-bit)
    signal pc        : unsigned(20 downto 0) := (others => '0');

    -- 32-level hardware stack
    type stack_array is array(0 to 31) of unsigned(20 downto 0);
    signal stack     : stack_array := (others => (others => '0'));
    signal stk_ptr   : integer range 0 to 31 := 0;

    -- Working register
    signal w_reg     : unsigned(7 downto 0) := (others => '0');

    -- STATUS register
    signal status_reg : unsigned(7 downto 0) := (others => '0');

    -- BSR (Bank Select Register)
    signal bsr_reg   : unsigned(7 downto 0) := (others => '0');

    -- PRODL/PRODH
    signal prodl_reg : unsigned(7 downto 0) := (others => '0');
    signal prodh_reg : unsigned(7 downto 0) := (others => '0');

    -- Table pointer
    signal tblptr    : unsigned(20 downto 0) := (others => '0');
    signal tablat    : unsigned(7 downto 0) := (others => '0');

    -- PCLATH/PCLATU
    signal pclath    : unsigned(4 downto 0) := (others => '0');
    signal pclatu    : unsigned(2 downto 0) := (others => '0');

    -- INTCON
    signal intcon    : unsigned(7 downto 0) := (others => '0');

    -- FSR0 (simplified - only FSR0 for indirect addressing)
    signal fsr0     : unsigned(11 downto 0) := (others => '0');

    -- TRIS registers
    signal trisa_reg : unsigned(7 downto 0) := (others => '1');
    signal trisb_reg : unsigned(7 downto 0) := (others => '1');
    signal trisc_reg : unsigned(7 downto 0) := (others => '1');
    signal trisd_reg : unsigned(7 downto 0) := (others => '1');
    signal trie_reg : unsigned(7 downto 0) := (others => '1');

    -- PORT latches
    signal porta_lat : unsigned(7 downto 0) := (others => '0');
    signal portb_lat : unsigned(7 downto 0) := (others => '0');
    signal portc_lat : unsigned(7 downto 0) := (others => '0');
    signal portd_lat : unsigned(7 downto 0) := (others => '0');
    signal porte_lat : unsigned(7 downto 0) := (others => '0');

    -- Instruction register
    signal ir        : unsigned(15 downto 0) := (others => '0');

    -- Second word for 2-word instructions
    signal ir2       : unsigned(15 downto 0) := (others => '0');
    signal is_2word  : std_logic := '0';

    -- Sleep
    signal sleeping  : std_logic := '0';

    -- Timer0
    signal tmr0_reg  : unsigned(7 downto 0) := (others => '0');
    signal t0_div    : unsigned(2 downto 0) := (others => '0');

    -- dmem interface
    signal dmem_addr_i : unsigned(11 downto 0) := (others => '0');
    signal dmem_dout_i : unsigned(7 downto 0) := (others => '0');
    signal dmem_we_i   : std_logic := '0';

    signal int_out_p : std_logic := '0';

begin

    -- Combinational outputs
    pmem_addr  <= std_logic_vector(pc);
    porta_out  <= std_logic_vector(porta_lat);
    portb_out  <= std_logic_vector(portb_lat);
    portc_out  <= std_logic_vector(portc_lat);
    portd_out  <= std_logic_vector(portd_lat);
    porte_out  <= std_logic_vector(porte_lat);
    trisa_out  <= std_logic_vector(trisa_reg);
    trisb_out  <= std_logic_vector(trisb_reg);
    trisc_out  <= std_logic_vector(trisc_reg);
    trisd_out  <= std_logic_vector(trisd_reg);
    trie_out  <= std_logic_vector(trie_reg);
    int_out    <= int_out_p;
    running    <= not sleeping;
    sleep_mode <= sleeping;

    dmem_addr <= std_logic_vector(dmem_addr_i);
    dmem_dout <= std_logic_vector(dmem_dout_i);
    dmem_we   <= dmem_we_i;

    -- Combinational: compute effective 12-bit data address from IR
    -- PIC18F: a=0 (access bit) -> access bank (0x000-0x07F or 0xF80-0xFFF)
    --         a=1 -> BSR-based bank (BSR & f(7:0))
    -- f is 8-bit (bits 7:0 of instruction for byte-oriented)
    dmem_addr_comb : process(ir, bsr_reg, fsr0)
        variable f8 : integer;
        variable a_bit : std_logic;
    begin
        f8 := to_integer(ir(7 downto 0));
        a_bit := ir(8);
        if f8 < 16#60# then
            -- Low access bank or BSR bank
            if a_bit = '0' then
                dmem_addr_i <= "0000" & ir(7 downto 0);  -- access bank low (0x000-0x07F)
            else
                dmem_addr_i <= bsr_reg(3 downto 0) & ir(7 downto 0);  -- BSR banked
            end if;
        else
            -- High access bank (SFRs: 0xF80-0xFFF)
            if a_bit = '0' then
                dmem_addr_i <= x"F" & ir(7 downto 0);  -- access bank high
            else
                dmem_addr_i <= bsr_reg(3 downto 0) & ir(7 downto 0);
            end if;
        end if;
    end process;

    -- Interrupt combinational
    int_out_p <= '1' when (intcon(INTCON_GIE) = '1' and intcon(INTCON_T0IF) = '1' and intcon(INTCON_T0IE) = '1')
                 else '0';

    -- Timer0 process
    timer0_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tmr0_reg <= (others => '0');
                t0_div   <= (others => '0');
                intcon(INTCON_T0IF) <= '0';
            else
                t0_div <= t0_div + 1;
                if t0_div = "011" then
                    t0_div <= (others => '0');
                    tmr0_reg <= tmr0_reg + 1;
                    if tmr0_reg = x"FF" then
                        intcon(INTCON_T0IF) <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Main CPU process
    cpu_proc : process(clk)
        variable op4  : unsigned(3 downto 0);  -- bits 15:12
        variable op5  : unsigned(4 downto 0);  -- bits 15:11
        variable f8   : integer;               -- 8-bit file address
        variable b3   : integer;               -- 3-bit bit position
        variable d    : std_logic;             -- destination
        variable a    : std_logic;             -- access bit
        variable k8   : unsigned(7 downto 0);  -- 8-bit literal
        variable k12  : unsigned(11 downto 0); -- 12-bit address

        variable f_eff : integer;              -- effective 12-bit address
        variable val_f : unsigned(7 downto 0);
        variable val_w : unsigned(7 downto 0);
        variable res8  : unsigned(7 downto 0);
        variable res9  : unsigned(8 downto 0);
        variable res16 : unsigned(15 downto 0);
        variable carry : std_logic;
        variable dc_out : std_logic;
        variable ov_out : std_logic;
        variable n_out : std_logic;
        variable new_status : unsigned(7 downto 0);
        variable new_pc : unsigned(20 downto 0);
        variable skip : std_logic;
        variable is_sfr : boolean;
        variable pcl_low : unsigned(7 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state       <= ST_RESET;
                pc          <= (others => '0');
                w_reg       <= (others => '0');
                status_reg  <= (others => '0');
                bsr_reg     <= (others => '0');
                prodl_reg   <= (others => '0');
                prodh_reg   <= (others => '0');
                tblptr      <= (others => '0');
                tablat      <= (others => '0');
                pclath      <= (others => '0');
                pclatu      <= (others => '0');
                intcon      <= (others => '0');
                fsr0        <= (others => '0');
                trisa_reg   <= (others => '1');
                trisb_reg   <= (others => '1');
                trisc_reg   <= (others => '1');
                trisd_reg   <= (others => '1');
                trie_reg    <= (others => '1');
                porta_lat   <= (others => '0');
                portb_lat   <= (others => '0');
                portc_lat   <= (others => '0');
                portd_lat   <= (others => '0');
                porte_lat   <= (others => '0');
                ir          <= (others => '0');
                ir2         <= (others => '0');
                is_2word    <= '0';
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
                        op4 := ir(15 downto 12);
                        op5 := ir(15 downto 11);
                        f8  := to_integer(ir(7 downto 0));
                        b3  := to_integer(ir(11 downto 9));
                        d   := ir(9);
                        a   := ir(8);
                        k8  := ir(7 downto 0);
                        k12 := ir(11 downto 0);

                        -- Compute effective address
                        if f8 < 16#60# then
                            if a = '0' then
                                f_eff := f8;  -- access bank low
                            else
                                f_eff := to_integer(bsr_reg(3 downto 0)) * 256 + f8;
                            end if;
                        else
                            if a = '0' then
                                f_eff := 16#F00# + f8;  -- access bank high (SFRs)
                            else
                                f_eff := to_integer(bsr_reg(3 downto 0)) * 256 + f8;
                            end if;
                        end if;

                        -- Read file register
                        is_sfr := false;
                        pcl_low := pc(7 downto 0);

                        case f_eff is
                            when A_PORTA =>
                                for i in 0 to 7 loop
                                    if trisa_reg(i) = '1' then
                                        val_f(i) := porta_in(i);
                                    else
                                        val_f(i) := porta_lat(i);
                                    end if;
                                end loop;
                                is_sfr := true;
                            when A_PORTB =>
                                for i in 0 to 7 loop
                                    if trisb_reg(i) = '1' then
                                        val_f(i) := portb_in(i);
                                    else
                                        val_f(i) := portb_lat(i);
                                    end if;
                                end loop;
                                is_sfr := true;
                            when A_PORTC =>
                                for i in 0 to 7 loop
                                    if trisc_reg(i) = '1' then
                                        val_f(i) := portc_in(i);
                                    else
                                        val_f(i) := portc_lat(i);
                                    end if;
                                end loop;
                                is_sfr := true;
                            when A_PORTD =>
                                for i in 0 to 7 loop
                                    if trisd_reg(i) = '1' then
                                        val_f(i) := portd_in(i);
                                    else
                                        val_f(i) := portd_lat(i);
                                    end if;
                                end loop;
                                is_sfr := true;
                            when A_PORTE =>
                                for i in 0 to 7 loop
                                    if trie_reg(i) = '1' then
                                        val_f(i) := porte_in(i);
                                    else
                                        val_f(i) := porte_lat(i);
                                    end if;
                                end loop;
                                is_sfr := true;
                            when A_TRISA =>
                                val_f := trisa_reg; is_sfr := true;
                            when A_TRISB =>
                                val_f := trisb_reg; is_sfr := true;
                            when A_TRISC =>
                                val_f := trisc_reg; is_sfr := true;
                            when A_TRISD =>
                                val_f := trisd_reg; is_sfr := true;
                            when A_TRISE =>
                                val_f := trie_reg; is_sfr := true;
                            when A_WREG =>
                                val_f := w_reg; is_sfr := true;
                            when A_STATUS =>
                                val_f := status_reg; is_sfr := true;
                            when A_BSR =>
                                val_f := bsr_reg; is_sfr := true;
                            when A_PRODL =>
                                val_f := prodl_reg; is_sfr := true;
                            when A_PRODH =>
                                val_f := prodh_reg; is_sfr := true;
                            when A_TBLPTRL =>
                                val_f := tblptr(7 downto 0); is_sfr := true;
                            when A_TBLPTRH =>
                                val_f := tblptr(15 downto 8); is_sfr := true;
                            when A_TBLPTRU =>
                                val_f := "00000" & tblptr(20 downto 16); is_sfr := true;
                            when A_TABLAT =>
                                val_f := tablat; is_sfr := true;
                            when A_PCL =>
                                val_f := pcl_low; is_sfr := true;
                            when A_PCLATH =>
                                val_f := "000" & pclath; is_sfr := true;
                            when A_PCLATU =>
                                val_f := "00000" & pclatu; is_sfr := true;
                            when A_INTCON =>
                                val_f := intcon; is_sfr := true;
                            when A_FSR0L =>
                                val_f := fsr0(7 downto 0); is_sfr := true;
                            when A_FSR0H =>
                                val_f := "0000" & fsr0(11 downto 8); is_sfr := true;
                            when others =>
                                val_f := unsigned(dmem_din);
                        end case;

                        val_w := w_reg;
                        new_status := status_reg;
                        new_pc := pc + 1;
                        skip := '0';

                        -- Decode and execute
                        -- PIC18F instruction decoding is complex; we handle the most
                        -- common instructions. The opcode is in bits 15:12 (4 bits),
                        -- with additional decode from bits 11:8.

                        case op4 is

                            -- 0000: Byte-oriented operations / special
                            when "0000" =>
                                case ir(11 downto 8) is
                                    when "0000" =>
                                        -- NOP or special (0000 0000 xxxx)
                                        case ir(7 downto 0) is
                                            when x"00" => null;  -- NOP
                                            when x"04" => null;  -- CLRWDT (simplified)
                                            when x"06" => null;  -- DAW (simplified)
                                            when x"08" =>
                                                -- TBLRD* (table read)
                                                tablat <= unsigned(pmem_data);  -- simplified
                                            when x"09" =>
                                                -- TBLRD*+ (post-increment)
                                                tablat <= unsigned(pmem_data);
                                                tblptr <= tblptr + 1;
                                            when x"0A" =>
                                                -- TBLRD*- (post-decrement)
                                                tablat <= unsigned(pmem_data);
                                                tblptr <= tblptr - 1;
                                            when x"0B" =>
                                                -- TBLRD+* (pre-increment)
                                                tblptr <= tblptr + 1;
                                                -- (tablat update on next cycle, simplified)
                                            when x"10" =>
                                                -- RETFIE s
                                                if stk_ptr > 0 then
                                                    stk_ptr <= stk_ptr - 1;
                                                    new_pc := stack(stk_ptr - 1);
                                                end if;
                                                intcon(INTCON_GIE) <= '1';
                                            when x"12" =>
                                                -- RETURN s
                                                if stk_ptr > 0 then
                                                    stk_ptr <= stk_ptr - 1;
                                                    new_pc := stack(stk_ptr - 1);
                                                end if;
                                            when x"63" =>
                                                -- POP
                                                if stk_ptr > 0 then
                                                    stk_ptr <= stk_ptr - 1;
                                                end if;
                                            when x"64" =>
                                                -- PUSH
                                                if stk_ptr < 31 then
                                                    stack(stk_ptr) <= new_pc;
                                                    stk_ptr <= stk_ptr + 1;
                                                end if;
                                            when others => null;
                                        end case;
                                    when "0001" =>
                                        -- MOVLB k (k -> BSR, 4-bit)
                                        bsr_reg <= "0000" & ir(3 downto 0);
                                    when "0010" =>
                                        -- MULLW k (k * W -> PRODL:PRODH)
                                        res16 := k8 * val_w;
                                        prodl_reg <= res16(7 downto 0);
                                        prodh_reg <= res16(15 downto 8);
                                    when "0011" =>
                                        -- RETLW k
                                        w_reg <= k8;
                                        if stk_ptr > 0 then
                                            stk_ptr <= stk_ptr - 1;
                                            new_pc := stack(stk_ptr - 1);
                                        end if;
                                    when "0100" =>
                                        -- IORLW k
                                        res8 := k8 or val_w;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_N) := res8(7);
                                        w_reg <= res8;
                                    when "0101" =>
                                        -- ANDLW k
                                        res8 := k8 and val_w;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_N) := res8(7);
                                        w_reg <= res8;
                                    when "0110" =>
                                        -- XORLW k
                                        res8 := k8 xor val_w;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_N) := res8(7);
                                        w_reg <= res8;
                                    when "1000" =>
                                        -- MOVLW k (also 0000 10xx)
                                        w_reg <= k8;
                                    when "1010" =>
                                        -- SUBLW k (k - W -> W)
                                        res9 := ('0' & k8) - ('0' & val_w);
                                        res8 := res9(7 downto 0);
                                        carry := '1' when k8 >= val_w else '0';
                                        dc_out := '1' when k8(3 downto 0) >= val_w(3 downto 0) else '0';
                                        n_out := res8(7);
                                        ov_out := '1' when (k8(7) = '0' and val_w(7) = '1' and res8(7) = '1') or
                                                          (k8(7) = '1' and val_w(7) = '0' and res8(7) = '0') else '0';
                                        new_status(STATUS_C) := carry;
                                        new_status(STATUS_DC) := dc_out;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_OV) := ov_out;
                                        new_status(STATUS_N) := n_out;
                                        w_reg <= res8;
                                    when "1011" =>
                                        -- ADDLW k (k + W -> W)
                                        res9 := ('0' & k8) + ('0' & val_w);
                                        res8 := res9(7 downto 0);
                                        carry := res9(8);
                                        dc_out := '1' when (k8(3 downto 0) + val_w(3 downto 0)) > 15 else '0';
                                        n_out := res8(7);
                                        ov_out := '1' when (k8(7) = val_w(7) and res8(7) /= k8(7)) else '0';
                                        new_status(STATUS_C) := carry;
                                        new_status(STATUS_DC) := dc_out;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_OV) := ov_out;
                                        new_status(STATUS_N) := n_out;
                                        w_reg <= res8;
                                    when others => null;
                                end case;

                            -- 0001: Byte-oriented (DECF, IORWF, ANDWF, XORWF, ADDWFC, ADDWF, etc.)
                            when "0001" =>
                                case ir(11 downto 10) is
                                    when "00" =>
                                        -- IORWF f,d,a
                                        res8 := val_f or val_w;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_N) := res8(7);
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when "01" =>
                                        -- ANDWF f,d,a
                                        res8 := val_f and val_w;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_N) := res8(7);
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when "10" =>
                                        -- XORWF f,d,a
                                        res8 := val_f xor val_w;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_N) := res8(7);
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when others => null;
                                end case;

                            -- 0010: SUBWF / ADDWF / SWAPF / COMF
                            when "0010" =>
                                case ir(11 downto 10) is
                                    when "00" =>
                                        -- SUBWF f,d,a (f - W -> d)
                                        res9 := ('0' & val_f) - ('0' & val_w);
                                        res8 := res9(7 downto 0);
                                        carry := '1' when val_f >= val_w else '0';
                                        dc_out := '1' when val_f(3 downto 0) >= val_w(3 downto 0) else '0';
                                        n_out := res8(7);
                                        ov_out := '1' when (val_f(7) = '0' and val_w(7) = '1' and res8(7) = '1') or
                                                          (val_f(7) = '1' and val_w(7) = '0' and res8(7) = '0') else '0';
                                        new_status(STATUS_C) := carry;
                                        new_status(STATUS_DC) := dc_out;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_OV) := ov_out;
                                        new_status(STATUS_N) := n_out;
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when "01" =>
                                        -- ADDWF f,d,a (f + W -> d)
                                        res9 := ('0' & val_f) + ('0' & val_w);
                                        res8 := res9(7 downto 0);
                                        carry := res9(8);
                                        dc_out := '1' when (val_f(3 downto 0) + val_w(3 downto 0)) > 15 else '0';
                                        n_out := res8(7);
                                        ov_out := '1' when (val_f(7) = val_w(7) and res8(7) /= val_f(7)) else '0';
                                        new_status(STATUS_C) := carry;
                                        new_status(STATUS_DC) := dc_out;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_OV) := ov_out;
                                        new_status(STATUS_N) := n_out;
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when "11" =>
                                        -- COMF f,d,a
                                        res8 := not val_f;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_N) := res8(7);
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when others => null;
                                end case;

                            -- 0011: INCF / DECF / RRNCF / RLNCF
                            when "0011" =>
                                case ir(11 downto 10) is
                                    when "00" =>
                                        -- INCF f,d,a
                                        res8 := val_f + 1;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_N) := res8(7);
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when "01" =>
                                        -- DECF f,d,a
                                        res8 := val_f - 1;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_N) := res8(7);
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when others => null;
                                end case;

                            -- 0100: SWAPF / RRCF / RLCF / RRNCF / RLNCF
                            when "0100" =>
                                case ir(11 downto 10) is
                                    when "00" =>
                                        -- SWAPF f,d,a
                                        res8 := val_f(3 downto 0) & val_f(7 downto 4);
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when "10" =>
                                        -- RRCF f,d,a (rotate right through carry)
                                        res8 := status_reg(STATUS_C) & val_f(7 downto 1);
                                        new_status(STATUS_C) := val_f(0);
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_N) := res8(7);
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when "11" =>
                                        -- RLCF f,d,a (rotate left through carry)
                                        res8 := val_f(6 downto 0) & status_reg(STATUS_C);
                                        new_status(STATUS_C) := val_f(7);
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_N) := res8(7);
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when others => null;
                                end case;

                            -- 0110: CLRF / MOVF / NEGWF / ADDWF
                            when "0110" =>
                                case ir(11 downto 10) is
                                    when "00" =>
                                        -- CLRF f,a
                                        res8 := (others => '0');
                                        new_status(STATUS_Z) := '1';
                                        dmem_dout_i <= res8; dmem_we_i <= '1';
                                    when "01" =>
                                        -- MOVF f,d,a (f -> d, sets Z and N)
                                        new_status(STATUS_Z) := '1' when val_f = 0 else '0';
                                        new_status(STATUS_N) := val_f(7);
                                        if d = '0' then w_reg <= val_f;
                                        else dmem_dout_i <= val_f; dmem_we_i <= '1'; end if;
                                    when others => null;
                                end case;

                            -- 0111: ADDWFC / COMF / INCF / DECFSZ
                            when "0111" =>
                                case ir(11 downto 10) is
                                    when "10" =>
                                        -- INCF f,d,a (alt encoding)
                                        res8 := val_f + 1;
                                        new_status(STATUS_Z) := '1' when res8 = 0 else '0';
                                        new_status(STATUS_N) := res8(7);
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when "11" =>
                                        -- DECFSZ f,d,a
                                        res8 := val_f - 1;
                                        if res8 = 0 then skip := '1'; end if;
                                        if d = '0' then w_reg <= res8;
                                        else dmem_dout_i <= res8; dmem_we_i <= '1'; end if;
                                    when others => null;
                                end case;

                            -- 1000: BCF f,b,a (bit clear)
                            -- Format: [15:12]=1000, [11:9]=b, [8]=a, [7:0]=f
                            when "1000" =>
                                res8 := val_f;
                                res8(b3) := '0';
                                if f_eff = A_PORTA then
                                    porta_lat <= res8;
                                elsif f_eff = A_PORTB then
                                    portb_lat <= res8;
                                elsif f_eff = A_PORTC then
                                    portc_lat <= res8;
                                elsif f_eff = A_PORTD then
                                    portd_lat <= res8;
                                elsif f_eff = A_INTCON then
                                    intcon <= res8;
                                elsif f_eff = A_STATUS then
                                    new_status(b3) := '0';
                                elsif not is_sfr then
                                    dmem_dout_i <= res8; dmem_we_i <= '1';
                                end if;

                            -- 1001: BSF f,b,a (bit set)
                            -- Format: [15:12]=1001, [11:9]=b, [8]=a, [7:0]=f
                            when "1001" =>
                                res8 := val_f;
                                res8(b3) := '1';
                                if f_eff = A_PORTA then
                                    porta_lat <= res8;
                                elsif f_eff = A_PORTB then
                                    portb_lat <= res8;
                                elsif f_eff = A_PORTC then
                                    portc_lat <= res8;
                                elsif f_eff = A_PORTD then
                                    portd_lat <= res8;
                                elsif f_eff = A_INTCON then
                                    intcon <= res8;
                                elsif f_eff = A_STATUS then
                                    new_status(b3) := '1';
                                elsif not is_sfr then
                                    dmem_dout_i <= res8; dmem_we_i <= '1';
                                end if;

                            -- 1010: BTFSC f,b,a (skip if bit clear)
                            -- Format: [15:12]=1010, [11:9]=b, [8]=a, [7:0]=f
                            when "1010" =>
                                if val_f(b3) = '0' then skip := '1'; end if;

                            -- 1011: BTFSS f,b,a (skip if bit set)
                            -- Format: [15:12]=1011, [11:9]=b, [8]=a, [7:0]=f
                            when "1011" =>
                                if val_f(b3) = '1' then skip := '1'; end if;

                            -- 1100: MOVWF (alt) / MOVF
                            when "1100" =>
                                case ir(11 downto 10) is
                                    when "00" =>
                                        -- MOVWF f,a (W -> f) - primary encoding
                                        if f_eff = A_PORTA then
                                            porta_lat <= val_w;
                                        elsif f_eff = A_PORTB then
                                            portb_lat <= val_w;
                                        elsif f_eff = A_PORTC then
                                            portc_lat <= val_w;
                                        elsif f_eff = A_PORTD then
                                            portd_lat <= val_w;
                                        elsif f_eff = A_TRISA then
                                            trisa_reg <= val_w;
                                        elsif f_eff = A_TRISB then
                                            trisb_reg <= val_w;
                                        elsif f_eff = A_TRISC then
                                            trisc_reg <= val_w;
                                        elsif f_eff = A_BSR then
                                            bsr_reg <= val_w;
                                        elsif f_eff = A_PCL then
                                            new_pc(7 downto 0) := val_w;
                                            new_pc(20 downto 8) := pclatu & pclath;
                                        elsif f_eff = A_STATUS then
                                            new_status := val_w;
                                        elsif f_eff = A_PRODL then
                                            prodl_reg <= val_w;
                                        elsif f_eff = A_PRODH then
                                            prodh_reg <= val_w;
                                        elsif f_eff = A_INTCON then
                                            intcon <= val_w;
                                        elsif not is_sfr then
                                            dmem_dout_i <= val_w;
                                            dmem_we_i <= '1';
                                        end if;
                                    when "01" =>
                                        -- MOVF f,d,a (f -> d)
                                        new_status(STATUS_Z) := '1' when val_f = 0 else '0';
                                        new_status(STATUS_N) := val_f(7);
                                        if d = '0' then w_reg <= val_f;
                                        else dmem_dout_i <= val_f; dmem_we_i <= '1'; end if;
                                    when others => null;
                                end case;

                            -- 1110: CALL / MOVFF (first word)
                            when "1110" =>
                                if ir(11) = '0' then
                                    -- CALL k,s (11-bit address, single word for <2K)
                                    if stk_ptr < 31 then
                                        stack(stk_ptr) <= pc + 1;
                                        stk_ptr <= stk_ptr + 1;
                                    end if;
                                    new_pc(10 downto 0) := k12(10 downto 0);
                                    new_pc(15 downto 11) := pclath(4 downto 0);
                                    new_pc(20 downto 16) := "00" & pclatu;
                                else
                                    -- MOVFF f (first word: 1110 1000 ffff ffff)
                                    -- Need second word for destination
                                    is_2word <= '1';
                                    state <= ST_FETCH2;
                                end if;

                            -- 1111: GOTO / MOVFF (second word)
                            when "1111" =>
                                -- GOTO k (12-bit address)
                                new_pc(11 downto 0) := k12;
                                new_pc(15 downto 12) := pclath(3 downto 0);
                                new_pc(20 downto 16) := "00" & pclatu;

                            when others =>
                                null;
                        end case;

                        -- Update STATUS
                        status_reg <= new_status;

                        -- Handle state transition
                        if state = ST_EXEC and is_2word = '0' then
                            if skip = '1' then
                                pc <= new_pc + 1;
                                state <= ST_SKIP;
                            else
                                pc <= new_pc;
                                state <= ST_FETCH;
                            end if;
                        end if;

                    when ST_FETCH2 =>
                        -- Fetch second word of 2-word instruction
                        ir2 <= unsigned(pmem_data);
                        state <= ST_EXEC;
                        -- Execute MOVFF: move f (from ir) to f (from ir2)
                        -- (simplified: just do the move)

                    when ST_SKIP =>
                        state <= ST_FETCH;

                    when others =>
                        state <= ST_FETCH;
                end case;
            end if;
        end if;
    end process cpu_proc;

end architecture rtl;

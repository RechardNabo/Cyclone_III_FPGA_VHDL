-- ================================================================================
-- avr_core_testbench : Testbench for AVR ATmega soft core
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity avr_core_tb is
end entity avr_core_tb;

architecture sim of avr_core_tb is

    constant CLK_PERIOD : time := 20 ns;

    signal clk        : std_logic := '0';
    signal reset      : std_logic := '1';
    signal pmem_addr  : std_logic_vector(15 downto 0);
    signal pmem_data  : std_logic_vector(15 downto 0);
    signal dmem_addr  : std_logic_vector(15 downto 0);
    signal dmem_dout  : std_logic_vector(7 downto 0);
    signal dmem_din   : std_logic_vector(7 downto 0);
    signal dmem_we    : std_logic;
    signal dmem_re    : std_logic;
    signal portb_out  : std_logic_vector(7 downto 0);
    signal portc_out  : std_logic_vector(7 downto 0);
    signal portd_out  : std_logic_vector(7 downto 0);
    signal portb_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal portc_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal portd_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal ddrb_out   : std_logic_vector(7 downto 0);
    signal ddrc_out   : std_logic_vector(7 downto 0);
    signal ddrd_out   : std_logic_vector(7 downto 0);
    signal int0       : std_logic := '0';
    signal int1       : std_logic := '0';
    signal irq_out    : std_logic;
    signal running    : std_logic;

    -- Program memory: 4K x 16
    type pmem_array is array(0 to 4095) of std_logic_vector(15 downto 0);
    signal pmem : pmem_array := (others => (others => '0'));

    -- Data memory: 4K x 8
    type dmem_array is array(0 to 4095) of std_logic_vector(7 downto 0);
    signal dmem : dmem_array := (others => (others => '0'));

    signal sim_done : boolean := false;

begin

    dut : entity work.avr_core
        generic map (
            PROGRAM_SIZE => 4096,
            DATA_SIZE    => 2048
        )
        port map (
            clk        => clk,
            reset      => reset,
            pmem_addr  => pmem_addr,
            pmem_data  => pmem_data,
            dmem_addr  => dmem_addr,
            dmem_dout  => dmem_dout,
            dmem_din   => dmem_din,
            dmem_we    => dmem_we,
            dmem_re    => dmem_re,
            portb_out  => portb_out,
            portc_out  => portc_out,
            portd_out  => portd_out,
            portb_in   => portb_in,
            portc_in   => portc_in,
            portd_in   => portd_in,
            ddrb_out   => ddrb_out,
            ddrc_out   => ddrc_out,
            ddrd_out   => ddrd_out,
            int0       => int0,
            int1       => int1,
            irq_out    => irq_out,
            running    => running
        );

    clk_proc : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Program memory: PC is word address
    pmem_data <= pmem(to_integer(unsigned(pmem_addr(11 downto 0))));

    -- Data memory
    dmem_proc : process(clk)
    begin
        if rising_edge(clk) then
            if dmem_we = '1' then
                dmem(to_integer(unsigned(dmem_addr))) <= dmem_dout;
            end if;
        end if;
    end process;

    dmem_din <= dmem(to_integer(unsigned(dmem_addr)));

    stim_proc : process
        -- AVR instruction encoders (16-bit)
        -- Register-register: [15:10]=opcode, [9]=r high, [8:4]=d, [3:0]=r low
        -- Immediate: [15:12]=opcode, [11:8]=K high, [8:4]=d, [3:0]=K low

        function ldi(d : integer; k : integer) return std_logic_vector is
            variable k8 : std_logic_vector(7 downto 0);
        begin
            k8 := std_logic_vector(to_unsigned(k, 8));
            return "1110" & k8(7 downto 4) & std_logic_vector(to_unsigned(d - 16, 4)) & k8(3 downto 0);
        end function;

        function mov(d : integer; r : integer) return std_logic_vector is
            variable r5 : std_logic_vector(4 downto 0);
        begin
            r5 := std_logic_vector(to_unsigned(r, 5));
            return "001011" & r5(4) & std_logic_vector(to_unsigned(d, 5)) & r5(3 downto 0);
        end function;

        function add(d : integer; r : integer) return std_logic_vector is
            variable r5 : std_logic_vector(4 downto 0);
        begin
            r5 := std_logic_vector(to_unsigned(r, 5));
            return "000011" & r5(4) & std_logic_vector(to_unsigned(d, 5)) & r5(3 downto 0);
        end function;

        function sub(d : integer; r : integer) return std_logic_vector is
            variable r5 : std_logic_vector(4 downto 0);
        begin
            r5 := std_logic_vector(to_unsigned(r, 5));
            return "000110" & r5(4) & std_logic_vector(to_unsigned(d, 5)) & r5(3 downto 0);
        end function;

        function andi(d : integer; k : integer) return std_logic_vector is
            variable k8 : std_logic_vector(7 downto 0);
        begin
            k8 := std_logic_vector(to_unsigned(k, 8));
            return "0111" & k8(7 downto 4) & std_logic_vector(to_unsigned(d - 16, 4)) & k8(3 downto 0);
        end function;

        function ori(d : integer; k : integer) return std_logic_vector is
            variable k8 : std_logic_vector(7 downto 0);
        begin
            k8 := std_logic_vector(to_unsigned(k, 8));
            return "0110" & k8(7 downto 4) & std_logic_vector(to_unsigned(d - 16, 4)) & k8(3 downto 0);
        end function;

        function subi(d : integer; k : integer) return std_logic_vector is
            variable k8 : std_logic_vector(7 downto 0);
        begin
            k8 := std_logic_vector(to_unsigned(k, 8));
            return "0101" & k8(7 downto 4) & std_logic_vector(to_unsigned(d - 16, 4)) & k8(3 downto 0);
        end function;

        function cpi(d : integer; k : integer) return std_logic_vector is
            variable k8 : std_logic_vector(7 downto 0);
        begin
            k8 := std_logic_vector(to_unsigned(k, 8));
            return "0011" & k8(7 downto 4) & std_logic_vector(to_unsigned(d - 16, 4)) & k8(3 downto 0);
        end function;

        function out_instr(p : integer; r : integer) return std_logic_vector is
            variable p6 : std_logic_vector(5 downto 0);
        begin
            p6 := std_logic_vector(to_unsigned(p, 6));
            return "10111" & p6(5 downto 3) & std_logic_vector(to_unsigned(r, 5)) & p6(2 downto 0);
        end function;

        function in_instr(d : integer; p : integer) return std_logic_vector is
            variable p6 : std_logic_vector(5 downto 0);
        begin
            p6 := std_logic_vector(to_unsigned(p, 6));
            return "10110" & p6(5 downto 3) & std_logic_vector(to_unsigned(d, 5)) & p6(2 downto 0);
        end function;

        function rjmp(k : integer) return std_logic_vector is
        begin
            -- RJMP k: 1100 kkkk kkkk kkkk (12-bit signed)
            return "1100" & std_logic_vector(to_unsigned(k, 12));
        end function;

        function rcall(k : integer) return std_logic_vector is
        begin
            -- RCALL k: 1101 kkkk kkkk kkkk (12-bit signed)
            return "1101" & std_logic_vector(to_unsigned(k, 12));
        end function;

        function ret return std_logic_vector is
        begin
            return "1001010100001000";
        end function;

        function nop return std_logic_vector is
        begin
            return x"0000";
        end function;

        function brne(k : integer) return std_logic_vector is
            variable k7 : std_logic_vector(6 downto 0);
        begin
            -- BRNE: BRBC 1, k (Z=0)
            -- 1111 01kk kkkk ksss (k=7-bit signed, s=001 for Z)
            k7 := std_logic_vector(to_signed(k, 7));
            return "111101" & k7 & "001";
        end function;

        function breq(k : integer) return std_logic_vector is
            variable k7 : std_logic_vector(6 downto 0);
        begin
            -- BREQ: BRBS 1, k (Z=1)
            -- 1111 00kk kkkk ksss (k=7-bit signed, s=001 for Z)
            k7 := std_logic_vector(to_signed(k, 7));
            return "111100" & k7 & "001";
        end function;

        function sts(addr : integer; r : integer) return std_logic_vector is
        begin
            -- STS k, Rr: 1001 001r rrrr 0000 + k (2-word)
            return "1001001" & std_logic_vector(to_unsigned(r, 5)) & "0000";
        end function;

        function lds(d : integer; addr : integer) return std_logic_vector is
        begin
            -- LDS Rd, k: 1001 000d dddd 0000 + k (2-word)
            return "1001000" & std_logic_vector(to_unsigned(d, 5)) & "0000";
        end function;

        function st_z(r : integer) return std_logic_vector is
        begin
            -- ST Z, Rr: 1001 001r rrrr 0000 (actually ST Z+)
            -- ST Z+: 1001 001r rrrr 0001
            return "1001001" & std_logic_vector(to_unsigned(r, 5)) & "0001";
        end function;

        function ld_z(d : integer) return std_logic_vector is
        begin
            -- LD Rd, Z+: 1001 000d dddd 0001
            return "1001000" & std_logic_vector(to_unsigned(d, 5)) & "0001";
        end function;

        -- I/O addresses
        constant IO_DDRB  : integer := 16#04#;
        constant IO_PORTB : integer := 16#05#;
        constant IO_SREG : integer := 16#3F#;

        variable reg16 : std_logic_vector(7 downto 0);
        variable reg17 : std_logic_vector(7 downto 0);
        variable reg18 : std_logic_vector(7 downto 0);
        variable reg19 : std_logic_vector(7 downto 0);
        variable sram_100 : std_logic_vector(7 downto 0);
    begin
        -- ====================================================================
        -- Test program (linear, no branches):
        --   0: LDI R16, 0x05     ; R16 = 0x05
        --   1: LDI R17, 0x03     ; R17 = 0x03
        --   2: ADD R16, R17      ; R16 = 0x05 + 0x03 = 0x08
        --   3: LDI R18, 0x08     ; R18 = 0x08
        --   4: OUT DDRB, R18     ; DDRB = 0x08 (bit 3 output)
        --   5: LDI R17, 0xAA     ; R17 = 0xAA
        --   6: OUT PORTB, R17    ; PORTB = 0xAA
        --   7: STS 0x100, R16    ; SRAM[0x100] = R16 = 0x08
        --   9: RJMP 0            ; done: infinite loop (self-loop)
        -- ====================================================================

        pmem(0)  <= ldi(16, 16#05#);
        pmem(1)  <= ldi(17, 16#03#);
        pmem(2)  <= add(16, 17);
        pmem(3)  <= ldi(18, 16#08#);
        pmem(4)  <= out_instr(IO_DDRB, 18);
        pmem(5)  <= ldi(17, 16#AA#);
        pmem(6)  <= out_instr(IO_PORTB, 17);
        pmem(7)  <= sts(16#100#, 16);  -- 2-word: pmem(7)=opcode, pmem(8)=addr
        pmem(8)  <= std_logic_vector(to_unsigned(16#100#, 16));
        pmem(9)  <= rjmp(0);            -- done: infinite loop (self-loop)

        -- Reset
        reset <= '1';
        wait for CLK_PERIOD * 4;
        reset <= '0';

        -- Wait for program to complete
        wait for CLK_PERIOD * 200;

        -- Read results
        reg16 := std_logic_vector(to_unsigned(0, 8));  -- placeholder
        reg17 := std_logic_vector(to_unsigned(0, 8));
        reg18 := std_logic_vector(to_unsigned(0, 8));
        reg19 := std_logic_vector(to_unsigned(0, 8));
        sram_100 := dmem(16#100#);

        -- Verify PORTB output
        assert portb_out = x"AA"
            report "FAIL: PORTB = 0x" & to_hstring(portb_out) & ", expected 0xAA"
            severity error;

        assert ddrb_out = x"08"
            report "FAIL: DDRB = 0x" & to_hstring(ddrb_out) & ", expected 0x08"
            severity error;

        assert sram_100 = x"08"
            report "FAIL: SRAM[0x100] = 0x" & to_hstring(sram_100) & ", expected 0x08"
            severity error;

        report "AVR Testbench complete" severity note;

        sim_done <= true;
        wait;
    end process;

end architecture sim;

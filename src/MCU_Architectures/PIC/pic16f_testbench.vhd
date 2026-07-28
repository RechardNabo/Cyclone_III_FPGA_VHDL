-- ================================================================================
-- pic16f_testbench : Testbench for PIC16F midrange soft core
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pic16f_tb is
end entity pic16f_tb;

architecture sim of pic16f_tb is

    constant CLK_PERIOD : time := 20 ns;

    signal clk        : std_logic := '0';
    signal reset      : std_logic := '1';
    signal pmem_addr  : std_logic_vector(12 downto 0);
    signal pmem_data  : std_logic_vector(13 downto 0);
    signal dmem_addr  : std_logic_vector(8 downto 0);
    signal dmem_dout  : std_logic_vector(7 downto 0);
    signal dmem_din   : std_logic_vector(7 downto 0);
    signal dmem_we    : std_logic;
    signal porta_out  : std_logic_vector(7 downto 0);
    signal portb_out  : std_logic_vector(7 downto 0);
    signal portc_out  : std_logic_vector(7 downto 0);
    signal portd_out  : std_logic_vector(7 downto 0);
    signal porta_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal portb_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal portc_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal portd_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal trisa_out  : std_logic_vector(7 downto 0);
    signal trisb_out  : std_logic_vector(7 downto 0);
    signal trisc_out  : std_logic_vector(7 downto 0);
    signal trisd_out  : std_logic_vector(7 downto 0);
    signal ext_int    : std_logic := '0';
    signal t0_int     : std_logic;
    signal int_out    : std_logic;
    signal running    : std_logic;
    signal sleep_mode : std_logic;

    -- Program memory: 2K x 14
    type pmem_array is array(0 to 2047) of std_logic_vector(13 downto 0);
    signal pmem : pmem_array := (others => (others => '0'));

    -- Data memory: 512 x 8
    type dmem_array is array(0 to 511) of std_logic_vector(7 downto 0);
    signal dmem : dmem_array := (others => (others => '0'));

    signal sim_done : boolean := false;

begin

    dut : entity work.pic16f_core
        generic map (
            PROGRAM_SIZE => 2048,
            DATA_SIZE    => 368
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
            porta_out  => porta_out,
            portb_out  => portb_out,
            portc_out  => portc_out,
            portd_out  => portd_out,
            porta_in   => porta_in,
            portb_in   => portb_in,
            portc_in   => portc_in,
            portd_in   => portd_in,
            trisa_out  => trisa_out,
            trisb_out  => trisb_out,
            trisc_out  => trisc_out,
            trisd_out  => trisd_out,
            ext_int    => ext_int,
            t0_int     => t0_int,
            int_out    => int_out,
            running    => running,
            sleep_mode => sleep_mode
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

    pmem_data <= pmem(to_integer(unsigned(pmem_addr)));

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
        -- PIC16F instruction encoders (14-bit)
        -- Byte-oriented: [13:8]=opcode, [7]=d, [6:0]=f
        -- Bit-oriented:  [13:10]=opcode, [9:7]=b, [6:0]=f
        -- Literal:       [13:10]=opcode, [7:0]=k (CALL/GOTO use [10:0]=k)

        function movlw(k : integer) return std_logic_vector is
        begin
            return "110000" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function retlw(k : integer) return std_logic_vector is
        begin
            return "110100" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function movwf(f : integer) return std_logic_vector is
        begin
            return "0000001" & std_logic_vector(to_unsigned(f, 7));
        end function;

        function clrw return std_logic_vector is
        begin
            return "00000100000000";
        end function;

        function clrf(f : integer) return std_logic_vector is
        begin
            return "0000011" & std_logic_vector(to_unsigned(f, 7));
        end function;

        function subwf(f : integer; d : integer) return std_logic_vector is
        begin
            return "000010" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function addwf(f : integer; d : integer) return std_logic_vector is
        begin
            return "000111" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function movf(f : integer; d : integer) return std_logic_vector is
        begin
            return "001000" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function incf(f : integer; d : integer) return std_logic_vector is
        begin
            return "001010" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function decf(f : integer; d : integer) return std_logic_vector is
        begin
            return "000011" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function andwf(f : integer; d : integer) return std_logic_vector is
        begin
            return "000101" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function iorwf(f : integer; d : integer) return std_logic_vector is
        begin
            return "000100" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function xorwf(f : integer; d : integer) return std_logic_vector is
        begin
            return "000110" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function comf(f : integer; d : integer) return std_logic_vector is
        begin
            return "001001" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function rrf(f : integer; d : integer) return std_logic_vector is
        begin
            return "001100" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function rlf(f : integer; d : integer) return std_logic_vector is
        begin
            return "001101" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function swapf(f : integer; d : integer) return std_logic_vector is
        begin
            return "001110" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function decfsz(f : integer; d : integer) return std_logic_vector is
        begin
            return "001011" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function incfsz(f : integer; d : integer) return std_logic_vector is
        begin
            return "001111" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function bcf(f : integer; b : integer) return std_logic_vector is
        begin
            return "0100" & std_logic_vector(to_unsigned(b, 3)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function bsf(f : integer; b : integer) return std_logic_vector is
        begin
            return "0101" & std_logic_vector(to_unsigned(b, 3)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function btfsc(f : integer; b : integer) return std_logic_vector is
        begin
            return "0110" & std_logic_vector(to_unsigned(b, 3)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function btfss(f : integer; b : integer) return std_logic_vector is
        begin
            return "0111" & std_logic_vector(to_unsigned(b, 3)) & std_logic_vector(to_unsigned(f, 7));
        end function;

        function call_addr(k : integer) return std_logic_vector is
        begin
            return "1000" & std_logic_vector(to_unsigned(k, 10));
        end function;

        function goto_addr(k : integer) return std_logic_vector is
        begin
            return "1001" & std_logic_vector(to_unsigned(k, 10));
        end function;

        function iorlw(k : integer) return std_logic_vector is
        begin
            return "111000" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function andlw(k : integer) return std_logic_vector is
        begin
            return "111001" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function xorlw(k : integer) return std_logic_vector is
        begin
            return "111100" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function sublw(k : integer) return std_logic_vector is
        begin
            return "111110" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function addlw(k : integer) return std_logic_vector is
        begin
            return "111111" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function return_instr return std_logic_vector is
        begin
            return "0000000001000";
        end function;

        function nop return std_logic_vector is
        begin
            return "00000000000000";
        end function;

        -- Register addresses
        constant STATUS_ADDR : integer := 16#03#;
        constant Z_BIT       : integer := 2;
        constant RP0_BIT     : integer := 5;
        constant PORTA_ADDR  : integer := 16#05#;
        constant TRISA_ADDR  : integer := 16#05#;  -- in bank 1, same f, different bank

        variable reg20 : std_logic_vector(7 downto 0);
        variable reg21 : std_logic_vector(7 downto 0);
    begin
        -- ====================================================================
        -- Test program:
        --   0: MOVLW 0x05        ; W = 0x05
        --   1: MOVWF 0x20        ; reg[0x20] = 0x05
        --   2: MOVLW 0x03        ; W = 0x03
        --   3: ADDWF 0x20, 1     ; reg[0x20] = 0x05 + 0x03 = 0x08
        --   4: MOVLW 0x08        ; W = 0x08
        --   5: SUBWF 0x20, 0     ; W = reg[0x20] - W = 0x08 - 0x08 = 0x00, Z=1
        --   6: BTFSS STATUS, Z   ; skip if Z=1 (Z is set, so skip next)
        --   7: GOTO fail         ; should be skipped
        --   8: CALL sub          ; call subroutine at address 16
        --   9: MOVWF 0x21        ; reg[0x21] = W (should be 0x55 from RETLW)
        --  10: BSF STATUS, RP0   ; switch to bank 1
        --  11: MOVLW 0x00        ; W = 0x00 (all outputs)
        --  12: MOVWF 0x05        ; TRISA = 0x00 (bank 1, f=5 -> TRISA)
        --  13: BCF STATUS, RP0   ; switch back to bank 0
        --  14: MOVLW 0xAA        ; W = 0xAA
        --  15: MOVWF 0x05        ; PORTA = 0xAA
        --  16: (sub) RETLW 0x55  ; W = 0x55, return to addr 9
        --  17: (fail) MOVLW 0xFF ; error indicator
        --  18: (done) GOTO done  ; infinite loop
        -- ====================================================================

        pmem(0)  <= movlw(16#05#);
        pmem(1)  <= movwf(16#20#);
        pmem(2)  <= movlw(16#03#);
        pmem(3)  <= addwf(16#20#, 1);
        pmem(4)  <= movlw(16#08#);
        pmem(5)  <= subwf(16#20#, 0);
        pmem(6)  <= btfss(STATUS_ADDR, Z_BIT);
        pmem(7)  <= goto_addr(17);   -- fail
        pmem(8)  <= call_addr(16);   -- sub
        pmem(9)  <= movwf(16#21#);
        pmem(10) <= bsf(STATUS_ADDR, RP0_BIT);  -- bank 1
        pmem(11) <= movlw(16#00#);
        pmem(12) <= movwf(16#05#);   -- TRISA in bank 1
        pmem(13) <= bcf(STATUS_ADDR, RP0_BIT);  -- bank 0
        pmem(14) <= movlw(16#AA#);
        pmem(15) <= movwf(16#05#);   -- PORTA in bank 0
        pmem(16) <= retlw(16#55#);   -- subroutine
        pmem(17) <= movlw(16#FF#);   -- fail
        pmem(18) <= goto_addr(18);   -- done: infinite loop

        -- Reset
        reset <= '1';
        wait for CLK_PERIOD * 4;
        reset <= '0';

        -- Wait for program to complete
        wait for CLK_PERIOD * 200;

        -- Read results
        reg20 := dmem(16#20#);
        reg21 := dmem(16#21#);

        -- Verify
        assert reg20 = x"08"
            report "FAIL: reg[0x20] = 0x" & to_hstring(reg20) & ", expected 0x08"
            severity error;

        assert reg21 = x"55"
            report "FAIL: reg[0x21] = 0x" & to_hstring(reg21) & ", expected 0x55"
            severity error;

        assert porta_out = x"AA"
            report "FAIL: PORTA = 0x" & to_hstring(porta_out) & ", expected 0xAA"
            severity error;

        report "PIC16F Testbench complete" severity failure;

        sim_done <= true;
        wait;
    end process;

end architecture sim;

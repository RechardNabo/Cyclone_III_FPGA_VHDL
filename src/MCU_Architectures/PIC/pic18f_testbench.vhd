-- ================================================================================
-- pic18f_testbench : Testbench for PIC18F enhanced soft core
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pic18f_tb is
end entity pic18f_tb;

architecture sim of pic18f_tb is

    constant CLK_PERIOD : time := 20 ns;

    signal clk        : std_logic := '0';
    signal reset      : std_logic := '1';
    signal pmem_addr  : std_logic_vector(20 downto 0);
    signal pmem_data  : std_logic_vector(15 downto 0);
    signal dmem_addr  : std_logic_vector(11 downto 0);
    signal dmem_dout  : std_logic_vector(7 downto 0);
    signal dmem_din   : std_logic_vector(7 downto 0);
    signal dmem_we    : std_logic;
    signal porta_out  : std_logic_vector(7 downto 0);
    signal portb_out  : std_logic_vector(7 downto 0);
    signal portc_out  : std_logic_vector(7 downto 0);
    signal portd_out  : std_logic_vector(7 downto 0);
    signal porte_out  : std_logic_vector(7 downto 0);
    signal porta_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal portb_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal portc_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal portd_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal porte_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal trisa_out  : std_logic_vector(7 downto 0);
    signal trisb_out  : std_logic_vector(7 downto 0);
    signal trisc_out  : std_logic_vector(7 downto 0);
    signal trisd_out  : std_logic_vector(7 downto 0);
    signal trie_out   : std_logic_vector(7 downto 0);
    signal ext_int    : std_logic := '0';
    signal int_out    : std_logic;
    signal running    : std_logic;
    signal sleep_mode : std_logic;

    -- Program memory: 4K x 16
    type pmem_array is array(0 to 4095) of std_logic_vector(15 downto 0);
    signal pmem : pmem_array := (others => (others => '0'));

    -- Data memory: 4K x 8
    type dmem_array is array(0 to 4095) of std_logic_vector(7 downto 0);
    signal dmem : dmem_array := (others => (others => '0'));

    signal sim_done : boolean := false;

begin

    dut : entity work.pic18f_core
        generic map (
            PROGRAM_SIZE => 4096,
            DATA_SIZE    => 1536
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
            porte_out  => porte_out,
            porta_in   => porta_in,
            portb_in   => portb_in,
            portc_in   => portc_in,
            portd_in   => portd_in,
            porte_in   => porte_in,
            trisa_out  => trisa_out,
            trisb_out  => trisb_out,
            trisc_out  => trisc_out,
            trisd_out  => trisd_out,
            trie_out   => trie_out,
            ext_int    => ext_int,
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

    pmem_data <= pmem(to_integer(unsigned(pmem_addr(11 downto 0))));

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
        -- PIC18F instruction encoders (16-bit)
        -- Byte-oriented: [15:12]=opcode, [11:10]=sub, [9]=d, [8]=a, [7:0]=f
        -- Literal: [15:8]=opcode, [7:0]=k

        function movlw(k : integer) return std_logic_vector is
        begin
            return "00001000" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function retlw(k : integer) return std_logic_vector is
        begin
            return "00000011" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function movwf(f : integer; a : integer) return std_logic_vector is
        begin
            return "1100000" & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function movf(f : integer; d : integer; a : integer) return std_logic_vector is
        begin
            return "110001" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function addwf(f : integer; d : integer; a : integer) return std_logic_vector is
        begin
            return "001001" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function subwf(f : integer; d : integer; a : integer) return std_logic_vector is
        begin
            return "001000" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function andwf(f : integer; d : integer; a : integer) return std_logic_vector is
        begin
            return "000101" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function iorwf(f : integer; d : integer; a : integer) return std_logic_vector is
        begin
            return "000100" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function xorwf(f : integer; d : integer; a : integer) return std_logic_vector is
        begin
            return "000110" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function incf(f : integer; d : integer; a : integer) return std_logic_vector is
        begin
            return "001100" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function decf(f : integer; d : integer; a : integer) return std_logic_vector is
        begin
            return "001101" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function comf(f : integer; d : integer; a : integer) return std_logic_vector is
        begin
            return "001011" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function clrf(f : integer; a : integer) return std_logic_vector is
        begin
            return "0110000" & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function bcf(f : integer; b : integer; a : integer) return std_logic_vector is
        begin
            return "1000" & std_logic_vector(to_unsigned(b, 3)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function bsf(f : integer; b : integer; a : integer) return std_logic_vector is
        begin
            return "1001" & std_logic_vector(to_unsigned(b, 3)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function btfsc(f : integer; b : integer; a : integer) return std_logic_vector is
        begin
            return "1010" & std_logic_vector(to_unsigned(b, 3)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function btfss(f : integer; b : integer; a : integer) return std_logic_vector is
        begin
            return "1011" & std_logic_vector(to_unsigned(b, 3)) & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function call_addr(k : integer) return std_logic_vector is
        begin
            return "1110" & "0" & std_logic_vector(to_unsigned(k, 11));
        end function;

        function goto_addr(k : integer) return std_logic_vector is
        begin
            return "1111" & std_logic_vector(to_unsigned(k, 12));
        end function;

        function return_instr return std_logic_vector is
        begin
            return "0000000000010010";
        end function;

        function mullw(k : integer) return std_logic_vector is
        begin
            return "00000010" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function mulwf(f : integer; a : integer) return std_logic_vector is
        begin
            return "0000001" & std_logic_vector(to_unsigned(a, 1)) & std_logic_vector(to_unsigned(f, 8));
        end function;

        function movlb(k : integer) return std_logic_vector is
        begin
            return "00000001" & "0000" & std_logic_vector(to_unsigned(k, 4));
        end function;

        function nop return std_logic_vector is
        begin
            return x"0000";
        end function;

        -- SFR addresses (access bank high, 0xF80+)
        constant STATUS_ADDR : integer := 16#FD8# - 16#F00#;  -- offset in access high = 0xD8
        constant Z_BIT       : integer := 2;
        constant PORTA_OFF   : integer := 16#80#;  -- 0xF80 - 0xF00 = 0x80
        constant TRISA_OFF   : integer := 16#92#;  -- 0xF92 - 0xF00 = 0x92

        variable reg20 : std_logic_vector(7 downto 0);
        variable reg21 : std_logic_vector(7 downto 0);
        variable reg22 : std_logic_vector(7 downto 0);
        variable reg23 : std_logic_vector(7 downto 0);
    begin
        -- ====================================================================
        -- Test program:
        --   0: MOVLW 0x07        ; W = 0x07
        --   1: MOVWF 0x20, 0     ; reg[0x20] = 0x07 (access bank)
        --   2: MOVLW 0x03        ; W = 0x03
        --   3: ADDWF 0x20, 0, 0  ; W = reg[0x20] + W = 0x07 + 0x03 = 0x0A
        --   4: MOVWF 0x21, 0     ; reg[0x21] = 0x0A
        --   5: MOVLW 0x0A        ; W = 0x0A
        --   6: SUBWF 0x21, 0, 0  ; W = reg[0x21] - W = 0x0A - 0x0A = 0x00, Z=1
        --   7: BTFSS STATUS, Z, 0 ; skip if Z=1
        --   8: GOTO fail         ; should be skipped
        --   9: MOVLW 0x06        ; W = 0x06
        --  10: MULLW 0x07        ; PRODL:PRODH = 6*7 = 42 = 0x2A
        --  11: MOVF PRODL, 0, 0  ; W = PRODL = 0x2A (PRODL at 0xEB in access high)
        --  12: MOVWF 0x22, 0     ; reg[0x22] = 0x2A
        --  13: CALL sub          ; call subroutine at 20
        --  14: MOVWF 0x23, 0     ; reg[0x23] = W (should be 0xBB from RETLW)
        --  15: MOVLW 0x00        ; W = 0x00
        --  16: MOVWF TRISA, 0    ; TRISA = 0x00 (all outputs, TRISA at 0x92 in access high)
        --  17: MOVLW 0x55        ; W = 0x55
        --  18: MOVWF PORTA, 0    ; PORTA = 0x55 (PORTA at 0x80 in access high)
        --  19: GOTO done
        --  20: (sub) RETLW 0xBB ; W = 0xBB, return
        --  21: (fail) MOVLW 0xFF
        --  22: (done) GOTO done  ; infinite loop
        -- ====================================================================

        pmem(0)  <= movlw(16#07#);
        pmem(1)  <= movwf(16#20#, 0);  -- access bank
        pmem(2)  <= movlw(16#03#);
        pmem(3)  <= addwf(16#20#, 0, 0);  -- W = reg[0x20] + W
        pmem(4)  <= movwf(16#21#, 0);
        pmem(5)  <= movlw(16#0A#);
        pmem(6)  <= subwf(16#21#, 0, 0);  -- W = reg[0x21] - W
        pmem(7)  <= btfss(STATUS_ADDR, Z_BIT, 0);
        pmem(8)  <= goto_addr(21);  -- fail
        pmem(9)  <= movlw(16#06#);
        pmem(10) <= mullw(16#07#);  -- PRODL:PRODH = 42
        pmem(11) <= movf(16#EB#, 0, 0);  -- W = PRODL (0xEB in access high)
        pmem(12) <= movwf(16#22#, 0);
        pmem(13) <= call_addr(20);  -- sub
        pmem(14) <= movwf(16#23#, 0);
        pmem(15) <= movlw(16#00#);
        pmem(16) <= movwf(16#92#, 0);  -- TRISA (0x92 in access high, a=0)
        pmem(17) <= movlw(16#55#);
        pmem(18) <= movwf(16#80#, 0);  -- PORTA (0x80 in access high, a=0)
        pmem(19) <= goto_addr(22);  -- done
        pmem(20) <= retlw(16#BB#);  -- subroutine
        pmem(21) <= movlw(16#FF#);  -- fail
        pmem(22) <= goto_addr(22);  -- done: infinite loop

        -- Reset
        reset <= '1';
        wait for CLK_PERIOD * 4;
        reset <= '0';

        -- Wait for program to complete
        wait for CLK_PERIOD * 300;

        -- Read results
        reg20 := dmem(16#20#);
        reg21 := dmem(16#21#);
        reg22 := dmem(16#22#);
        reg23 := dmem(16#23#);

        -- Verify
        assert reg20 = x"07"
            report "FAIL: reg[0x20] = 0x" & to_hstring(reg20) & ", expected 0x07"
            severity error;

        assert reg21 = x"0A"
            report "FAIL: reg[0x21] = 0x" & to_hstring(reg21) & ", expected 0x0A"
            severity error;

        assert reg22 = x"2A"
            report "FAIL: reg[0x22] = 0x" & to_hstring(reg22) & ", expected 0x2A"
            severity error;

        assert reg23 = x"BB"
            report "FAIL: reg[0x23] = 0x" & to_hstring(reg23) & ", expected 0xBB"
            severity error;

        assert porta_out = x"55"
            report "FAIL: PORTA = 0x" & to_hstring(porta_out) & ", expected 0x55"
            severity error;

        report "PIC18F Testbench complete" severity failure;

        sim_done <= true;
        wait;
    end process;

end architecture sim;

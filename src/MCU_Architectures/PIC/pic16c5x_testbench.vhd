-- ================================================================================
-- pic16c5x_testbench : Testbench for PIC16C5x soft core
--
-- Loads a small test program into program memory and verifies execution.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pic16c5x_tb is
end entity pic16c5x_tb;

architecture sim of pic16c5x_tb is

    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal clk        : std_logic := '0';
    signal reset      : std_logic := '1';
    signal pmem_addr  : std_logic_vector(10 downto 0);
    signal pmem_data  : std_logic_vector(11 downto 0);
    signal dmem_addr  : std_logic_vector(6 downto 0);
    signal dmem_dout  : std_logic_vector(7 downto 0);
    signal dmem_din   : std_logic_vector(7 downto 0);
    signal dmem_we    : std_logic;
    signal porta_out  : std_logic_vector(7 downto 0);
    signal portb_out  : std_logic_vector(7 downto 0);
    signal portc_out  : std_logic_vector(7 downto 0);
    signal porta_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal portb_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal portc_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal trisa_out  : std_logic_vector(7 downto 0);
    signal trisb_out  : std_logic_vector(7 downto 0);
    signal trisc_out  : std_logic_vector(7 downto 0);
    signal t0cki      : std_logic := '0';
    signal t0_int     : std_logic;
    signal wdt_reset  : std_logic;
    signal running    : std_logic;
    signal sleep_mode : std_logic;

    -- Program memory: 1K x 12
    type pmem_array is array(0 to 1023) of std_logic_vector(11 downto 0);
    signal pmem : pmem_array := (others => (others => '0'));

    -- Data memory: 128 x 8 (file registers 0x08-0x7F)
    type dmem_array is array(0 to 127) of std_logic_vector(7 downto 0);
    signal dmem : dmem_array := (others => (others => '0'));

    signal sim_done : boolean := false;

begin

    -- DUT
    dut : entity work.pic16c5x_core
        generic map (
            PROGRAM_SIZE => 1024,
            DATA_SIZE    => 80
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
            porta_in   => porta_in,
            portb_in   => portb_in,
            portc_in   => portc_in,
            trisa_out  => trisa_out,
            trisb_out  => trisb_out,
            trisc_out  => trisc_out,
            t0cki      => t0cki,
            t0_int     => t0_int,
            wdt_reset  => wdt_reset,
            running    => running,
            sleep_mode => sleep_mode
        );

    -- Clock
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

    -- Program memory read (combinational)
    pmem_data <= pmem(to_integer(unsigned(pmem_addr)));

    -- Data memory: read/write
    dmem_proc : process(clk)
    begin
        if rising_edge(clk) then
            if dmem_we = '1' then
                dmem(to_integer(unsigned(dmem_addr))) <= dmem_dout;
            end if;
        end if;
    end process;

    -- Data memory read (combinational, with 1-cycle latency handled by core)
    dmem_din <= dmem(to_integer(unsigned(dmem_addr)));

    -- Test program loader and stimulus
    stim_proc : process
        -- Helper to build 12-bit instruction words
        -- Byte-oriented: [11:6]=opcode, [5]=d, [4:0]=f
        -- Bit-oriented:  [11:9]=opcode, [8:5]=unused, [7:5]=b, [4:0]=f
        -- Literal:       [11:8]=opcode, [7:0]=k
        -- CALL/GOTO:     [11:9]=100/101, [8:0]=k

        -- PIC16C5x instruction encoders
        function movlw(k : integer) return std_logic_vector is
        begin
            return "1010" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function retlw(k : integer) return std_logic_vector is
        begin
            return "1100" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function movwf(f : integer) return std_logic_vector is
        begin
            return "0000001" & std_logic_vector(to_unsigned(f, 5));
        end function;

        function clrw return std_logic_vector is
        begin
            return "000001000000";
        end function;

        function clrf(f : integer) return std_logic_vector is
        begin
            return "0000011" & std_logic_vector(to_unsigned(f, 5));
        end function;

        function subwf(f : integer; d : integer) return std_logic_vector is
        begin
            return "000010" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function addwf(f : integer; d : integer) return std_logic_vector is
        begin
            return "000111" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function movf(f : integer; d : integer) return std_logic_vector is
        begin
            return "001000" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function incf(f : integer; d : integer) return std_logic_vector is
        begin
            return "001010" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function decf(f : integer; d : integer) return std_logic_vector is
        begin
            return "000011" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function andwf(f : integer; d : integer) return std_logic_vector is
        begin
            return "000101" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function iorwf(f : integer; d : integer) return std_logic_vector is
        begin
            return "000100" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function xorwf(f : integer; d : integer) return std_logic_vector is
        begin
            return "000110" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function comf(f : integer; d : integer) return std_logic_vector is
        begin
            return "001001" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function rrf(f : integer; d : integer) return std_logic_vector is
        begin
            return "001100" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function rlf(f : integer; d : integer) return std_logic_vector is
        begin
            return "001101" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function swapf(f : integer; d : integer) return std_logic_vector is
        begin
            return "001110" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function decfsz(f : integer; d : integer) return std_logic_vector is
        begin
            return "001011" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function incfsz(f : integer; d : integer) return std_logic_vector is
        begin
            return "001111" & std_logic_vector(to_unsigned(d, 1)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function bcf(f : integer; b : integer) return std_logic_vector is
        begin
            return "0100" & std_logic_vector(to_unsigned(b, 3)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function bsf(f : integer; b : integer) return std_logic_vector is
        begin
            return "0101" & std_logic_vector(to_unsigned(b, 3)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function btfsc(f : integer; b : integer) return std_logic_vector is
        begin
            return "0110" & std_logic_vector(to_unsigned(b, 3)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function btfss(f : integer; b : integer) return std_logic_vector is
        begin
            return "0111" & std_logic_vector(to_unsigned(b, 3)) & std_logic_vector(to_unsigned(f, 5));
        end function;

        function call_addr(k : integer) return std_logic_vector is
        begin
            return "1000" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function goto_addr(k : integer) return std_logic_vector is
        begin
            return "1001" & std_logic_vector(to_unsigned(k, 8));
        end function;

        function nop return std_logic_vector is
        begin
            return "000000000000";
        end function;

        function tris(f : integer) return std_logic_vector is
        begin
            return "0000000001" & std_logic_vector(to_unsigned(f, 1));
        end function;

        -- STATUS register address
        constant STATUS_ADDR : integer := 16#03#;
        constant Z_BIT : integer := 2;

        variable reg10 : std_logic_vector(7 downto 0);
        variable reg11 : std_logic_vector(7 downto 0);
    begin
        -- ====================================================================
        -- Test program:
        --   0: MOVLW 0x05        ; W = 0x05
        --   1: MOVWF 0x10        ; reg[0x10] = 0x05
        --   2: MOVLW 0x03        ; W = 0x03
        --   3: ADDWF 0x10, 1     ; reg[0x10] = 0x05 + 0x03 = 0x08
        --   4: MOVLW 0x08        ; W = 0x08
        --   5: SUBWF 0x10, 0     ; W = reg[0x10] - W = 0x08 - 0x08 = 0x00, Z=1
        --   6: BTFSC STATUS, Z   ; skip if Z=1 (Z is set, so skip next)
        --   7: GOTO fail         ; should be skipped
        --   8: MOVLW 0x42        ; W = 0x42
        --   9: CALL sub          ; call subroutine at address 16
        --  10: MOVWF 0x11        ; reg[0x11] = W (should be 0xAA from RETLW)
        --  11: MOVLW 0x0F        ; W = 0x0F
        --  12: TRIS PORTA        ; TRISA = 0x0F (set PORTA as output for lower nibble)
        --  13: MOVLW 0xAA        ; W = 0xAA
        --  14: MOVWF 0x05        ; PORTA = 0xAA
        --  15: GOTO done
        --  16: (sub) RETLW 0xAA  ; W = 0xAA, return to addr 10
        --  17: (fail) MOVLW 0xFF ; error indicator
        --  18: (done) GOTO done  ; infinite loop
        -- ====================================================================

        pmem(0)  <= movlw(16#05#);
        pmem(1)  <= movwf(16#10#);
        pmem(2)  <= movlw(16#03#);
        pmem(3)  <= addwf(16#10#, 1);
        pmem(4)  <= movlw(16#08#);
        pmem(5)  <= subwf(16#10#, 0);
        pmem(6)  <= btfss(STATUS_ADDR, Z_BIT);
        pmem(7)  <= goto_addr(17);  -- fail label at 17
        pmem(8)  <= movlw(16#42#);
        pmem(9)  <= call_addr(16);  -- sub at 16
        pmem(10) <= movwf(16#11#);
        pmem(11) <= movlw(16#0F#);
        pmem(12) <= "000000000101";  -- TRIS 5 (PORTA)
        pmem(13) <= movlw(16#AA#);
        pmem(14) <= movwf(16#05#);   -- PORTA
        pmem(15) <= goto_addr(18);   -- done at 18
        pmem(16) <= retlw(16#AA#);   -- subroutine
        pmem(17) <= movlw(16#FF#);   -- fail
        pmem(18) <= goto_addr(18);   -- done: infinite loop

        -- Reset for a few cycles
        reset <= '1';
        wait for CLK_PERIOD * 4;
        reset <= '0';

        -- Wait for the program to reach the done loop
        -- Each instruction takes 2-3 cycles. ~19 instructions = ~50 cycles
        wait for CLK_PERIOD * 200;

        -- Read back results from data memory
        reg10 := dmem(to_integer(unsigned'(x"10")));
        reg11 := dmem(to_integer(unsigned'(x"11")));

        -- Verify results
        assert reg10 = x"08"
            report "FAIL: reg[0x10] = 0x" & to_hstring(reg10) & ", expected 0x08"
            severity error;

        assert reg11 = x"AA"
            report "FAIL: reg[0x11] = 0x" & to_hstring(reg11) & ", expected 0xAA"
            severity error;

        assert porta_out = x"AA"
            report "FAIL: PORTA = 0x" & to_hstring(porta_out) & ", expected 0xAA"
            severity error;

        -- Check that we didn't hit the fail path (W should not be 0xFF)
        -- (We can't directly read W, but if we hit fail, reg10/reg11 would be wrong)

        report "PIC16C5x Testbench complete" severity failure;

        sim_done <= true;
        wait;
    end process;

end architecture sim;

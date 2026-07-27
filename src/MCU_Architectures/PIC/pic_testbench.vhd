-- ================================================================================
-- pic_testbench : Testbench for pic_interface (PIC16F877A-style peripheral model)
-- VHDL-93 compliant.  10 ns clock, active-high reset.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pic_tb is
end entity pic_tb;

architecture sim of pic_tb is

    component pic_interface is
        port (
            clk, reset  : in  std_logic;
            addr        : in  std_logic_vector(8 downto 0);
            din         : in  std_logic_vector(7 downto 0);
            dout        : out std_logic_vector(7 downto 0);
            we, re      : in  std_logic;
            porta_out   : out std_logic_vector(7 downto 0);
            trisa_out   : out std_logic_vector(7 downto 0);
            porta_in    : in  std_logic_vector(7 downto 0);
            portb_out   : out std_logic_vector(7 downto 0);
            trisb_out   : out std_logic_vector(7 downto 0);
            portb_in    : in  std_logic_vector(7 downto 0);
            portc_out   : out std_logic_vector(7 downto 0);
            trisc_out   : out std_logic_vector(7 downto 0);
            portc_in    : in  std_logic_vector(7 downto 0);
            portd_out   : out std_logic_vector(7 downto 0);
            trisd_out   : out std_logic_vector(7 downto 0);
            portd_in    : in  std_logic_vector(7 downto 0);
            t0_int, t1_int, t2_int : out std_logic;
            adc_in      : in  std_logic_vector(9 downto 0);
            adc_int     : out std_logic;
            usart_txd   : out std_logic;
            usart_rxd   : in  std_logic;
            usart_tx_int, usart_rx_int : out std_logic;
            ext_int     : in  std_logic;
            ext_int_out : out std_logic;
            gie_out     : out std_logic
        );
    end component;

    -- Clock and reset
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '1';
    signal test_done : boolean := false;

    -- Bus signals
    signal addr : std_logic_vector(8 downto 0) := (others => '0');
    signal din  : std_logic_vector(7 downto 0) := (others => '0');
    signal dout : std_logic_vector(7 downto 0);
    signal we   : std_logic := '0';
    signal re   : std_logic := '0';

    -- Port A
    signal porta_out : std_logic_vector(7 downto 0);
    signal trisa_out : std_logic_vector(7 downto 0);
    signal porta_in  : std_logic_vector(7 downto 0) := (others => '0');

    -- Port B
    signal portb_out : std_logic_vector(7 downto 0);
    signal trisb_out : std_logic_vector(7 downto 0);
    signal portb_in  : std_logic_vector(7 downto 0) := (others => '0');

    -- Port C
    signal portc_out : std_logic_vector(7 downto 0);
    signal trisc_out : std_logic_vector(7 downto 0);
    signal portc_in  : std_logic_vector(7 downto 0) := (others => '0');

    -- Port D
    signal portd_out : std_logic_vector(7 downto 0);
    signal trisd_out : std_logic_vector(7 downto 0);
    signal portd_in  : std_logic_vector(7 downto 0) := (others => '0');

    -- Timer interrupts
    signal t0_int : std_logic;
    signal t1_int : std_logic;
    signal t2_int : std_logic;

    -- ADC
    signal adc_in  : std_logic_vector(9 downto 0) := (others => '0');
    signal adc_int : std_logic;

    -- USART
    signal usart_txd    : std_logic;
    signal usart_rxd    : std_logic := '1';
    signal usart_tx_int : std_logic;
    signal usart_rx_int : std_logic;

    -- External interrupt
    signal ext_int     : std_logic := '0';
    signal ext_int_out : std_logic;
    signal gie_out     : std_logic;

    -- Register address constants (9-bit: [bank1,bank0, file_addr(7 bits)])
    -- Bank 0
    constant A_PORTA  : std_logic_vector(8 downto 0) := "000000101"; -- 0x05
    constant A_PORTB  : std_logic_vector(8 downto 0) := "000000110"; -- 0x06
    constant A_PORTC  : std_logic_vector(8 downto 0) := "000000111"; -- 0x07
    constant A_PORTD  : std_logic_vector(8 downto 0) := "000001000"; -- 0x08
    constant A_INTCON : std_logic_vector(8 downto 0) := "000001011"; -- 0x0B
    constant A_PIR1   : std_logic_vector(8 downto 0) := "000001100"; -- 0x0C
    -- Bank 1
    constant A_TRISA  : std_logic_vector(8 downto 0) := "010000101"; -- 0x85
    constant A_TRISB  : std_logic_vector(8 downto 0) := "010000110"; -- 0x86
    constant A_TRISC  : std_logic_vector(8 downto 0) := "010000111"; -- 0x87
    constant A_TRISD  : std_logic_vector(8 downto 0) := "010001000"; -- 0x88
    constant A_OPTION : std_logic_vector(8 downto 0) := "010000001"; -- 0x81

begin

    -- ==================================================================
    -- DUT instantiation
    -- ==================================================================
    dut : pic_interface
        port map (
            clk => clk, reset => reset,
            addr => addr, din => din, dout => dout,
            we => we, re => re,
            porta_out => porta_out, trisa_out => trisa_out, porta_in => porta_in,
            portb_out => portb_out, trisb_out => trisb_out, portb_in => portb_in,
            portc_out => portc_out, trisc_out => trisc_out, portc_in => portc_in,
            portd_out => portd_out, trisd_out => trisd_out, portd_in => portd_in,
            t0_int => t0_int, t1_int => t1_int, t2_int => t2_int,
            adc_in => adc_in, adc_int => adc_int,
            usart_txd => usart_txd, usart_rxd => usart_rxd,
            usart_tx_int => usart_tx_int, usart_rx_int => usart_rx_int,
            ext_int => ext_int, ext_int_out => ext_int_out,
            gie_out => gie_out
        );

    -- ==================================================================
    -- Clock generation: 10 ns period
    -- ==================================================================
    clk_proc : process
    begin
        while not test_done loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
        wait;
    end process;

    -- ==================================================================
    -- Stimulus process
    -- ==================================================================
    stim_proc : process
        -- Register write helper (synchronous, one clock)
        procedure reg_write(a : in std_logic_vector(8 downto 0);
                            d : in std_logic_vector(7 downto 0)) is
        begin
            wait until rising_edge(clk);
            we   <= '1';
            addr <= a;
            din  <= d;
            wait until rising_edge(clk);
            we   <= '0';
            addr <= (others => '0');
            din  <= (others => '0');
        end procedure;

        -- Register read helper (combinational, sample mid-cycle)
        procedure reg_read(a : in std_logic_vector(8 downto 0);
                           d : out std_logic_vector(7 downto 0)) is
        begin
            re   <= '1';
            addr <= a;
            wait for 2 ns;
            d := dout;
            re   <= '0';
            addr <= (others => '0');
            wait for 2 ns;
        end procedure;

        variable rdata : std_logic_vector(7 downto 0);
    begin
        -- ----------------------------------------------------------------
        -- Reset (active-high)
        -- ----------------------------------------------------------------
        reset <= '1';
        wait for 20 ns;
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);

        -- After reset, TRIS defaults to input (0xFF)
        assert trisa_out = x"FF"
            report "PIC TB: TRISA not 0xFF after reset"
            severity error;
        assert trisb_out = x"FF"
            report "PIC TB: TRISB not 0xFF after reset"
            severity error;

        -- ----------------------------------------------------------------
        -- Register WRITE transactions (at least 3)
        -- ----------------------------------------------------------------

        -- Write 1: TRISB = 0x00 (all outputs) -- Bank 1
        reg_write(A_TRISB, x"00");
        assert trisb_out = x"00"
            report "PIC TB: TRISB output mismatch after write 1"
            severity error;

        -- Write 2: TRISC = 0x0F -- Bank 1
        reg_write(A_TRISC, x"0F");
        assert trisc_out = x"0F"
            report "PIC TB: TRISC output mismatch after write 2"
            severity error;

        -- Write 3: TRISD = 0xF0 -- Bank 1
        reg_write(A_TRISD, x"F0");
        assert trisd_out = x"F0"
            report "PIC TB: TRISD output mismatch after write 3"
            severity error;

        -- Write 4: INTCON = 0xB0 (GIE=1, T0IE=1, INTE=1)
        -- bit7=GIE, bit5=T0IE, bit4=INTE
        reg_write(A_INTCON, x"B0");
        assert gie_out = '1'
            report "PIC TB: gie_out not asserted after INTCON write"
            severity error;

        -- Write 5: OPTION_REG = 0x40 (INTEDG=1, rising edge) -- Bank 1
        reg_write(A_OPTION, x"40");

        -- ----------------------------------------------------------------
        -- Register READ transactions (at least 3) and check data
        -- ----------------------------------------------------------------

        -- Read 1: TRISB should be 0x00
        reg_read(A_TRISB, rdata);
        assert rdata = x"00"
            report "PIC TB: Read TRISB expected 0x00"
            severity error;

        -- Read 2: TRISC should be 0x0F
        reg_read(A_TRISC, rdata);
        assert rdata = x"0F"
            report "PIC TB: Read TRISC expected 0x0F"
            severity error;

        -- Read 3: TRISD should be 0xF0
        reg_read(A_TRISD, rdata);
        assert rdata = x"F0"
            report "PIC TB: Read TRISD expected 0xF0"
            severity error;

        -- Read 4: INTCON should be 0xB0
        reg_read(A_INTCON, rdata);
        assert rdata = x"B0"
            report "PIC TB: Read INTCON expected 0xB0"
            severity error;

        -- ----------------------------------------------------------------
        -- GPIO input stimulation and output checking
        -- ----------------------------------------------------------------
        -- Drive portb_in and read PORTB (reads physical pins)
        portb_in <= x"3C";
        wait for 10 ns;
        reg_read(A_PORTB, rdata);
        assert rdata = x"3C"
            report "PIC TB: Read PORTB expected 0x3C"
            severity error;

        -- Change portb_in and re-read
        portb_in <= x"81";
        wait for 10 ns;
        reg_read(A_PORTB, rdata);
        assert rdata = x"81"
            report "PIC TB: Read PORTB expected 0x81"
            severity error;

        -- Drive portc_in and read PORTC
        portc_in <= x"55";
        wait for 10 ns;
        reg_read(A_PORTC, rdata);
        assert rdata = x"55"
            report "PIC TB: Read PORTC expected 0x55"
            severity error;

        -- ----------------------------------------------------------------
        -- Interrupt input stimulation and output checking
        -- ----------------------------------------------------------------
        -- External interrupt (RB0/INT): rising edge (INTEDG=1)
        -- INTCON has INTE (bit4) enabled and GIE (bit7) enabled
        ext_int <= '0';
        wait for 20 ns;
        wait until rising_edge(clk);
        ext_int <= '1';
        wait for 20 ns;
        wait until rising_edge(clk);

        -- Check ext_int_out (INTF AND INTE AND GIE)
        assert ext_int_out = '1'
            report "PIC TB: ext_int_out not asserted after rising edge"
            severity error;

        -- Read INTCON to verify INTF (bit1) is set
        reg_read(A_INTCON, rdata);
        assert rdata(1) = '1'
            report "PIC TB: INTCON INTF bit not set after external interrupt"
            severity error;

        -- Clear INTF by writing 0 to bit1
        reg_write(A_INTCON, x"B0");
        wait for 10 ns;
        assert ext_int_out = '0'
            report "PIC TB: ext_int_out not cleared after INTF clear"
            severity error;

        -- ----------------------------------------------------------------
        -- Done
        -- ----------------------------------------------------------------
        wait for 50 ns;
        test_done <= true;
        assert false report "Testbench complete" severity failure;
        wait;
    end process;

end architecture sim;

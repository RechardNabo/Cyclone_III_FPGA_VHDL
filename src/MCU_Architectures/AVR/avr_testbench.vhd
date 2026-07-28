-- ================================================================================
-- avr_testbench : Testbench for avr_interface (AVR ATmega328P-style I/O model)
-- VHDL-93 compliant.  10 ns clock, active-high reset.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity avr_tb is
end entity avr_tb;

architecture sim of avr_tb is

    -- Device under test
    component avr_interface is
        port (
            clk, reset   : in  std_logic;
            iore, iowe   : in  std_logic;
            ioaddr       : in  std_logic_vector(6 downto 0);
            iodata_in    : in  std_logic_vector(7 downto 0);
            iodata_out   : out std_logic_vector(7 downto 0);
            portb_out    : out std_logic_vector(7 downto 0);
            ddrb_out     : out std_logic_vector(7 downto 0);
            pinb_in      : in  std_logic_vector(7 downto 0);
            portc_out    : out std_logic_vector(7 downto 0);
            ddrc_out     : out std_logic_vector(7 downto 0);
            pinc_in      : in  std_logic_vector(7 downto 0);
            portd_out    : out std_logic_vector(7 downto 0);
            ddrd_out     : out std_logic_vector(7 downto 0);
            pind_in      : in  std_logic_vector(7 downto 0);
            t0_overflow_int : out std_logic;
            t0_compare_int  : out std_logic;
            t0_waveform     : out std_logic;
            usart_txd       : out std_logic;
            usart_rxd       : in  std_logic;
            usart_udre_int  : out std_logic;
            usart_rxc_int   : out std_logic;
            usart_txc_int   : out std_logic;
            spi_sclk    : out std_logic;
            spi_mosi    : out std_logic;
            spi_miso    : in  std_logic;
            spi_ss_n    : out std_logic_vector(2 downto 0);
            spi_int     : out std_logic;
            adc_input   : in  std_logic_vector(9 downto 0);
            adc_int     : out std_logic;
            int0, int1  : in  std_logic;
            int0_int    : out std_logic;
            int1_int    : out std_logic;
            global_int  : out std_logic;
            -- I2C interface
            i2c_sda : inout std_logic;
            i2c_scl : inout std_logic;
            i2c_int : out std_logic;
            -- UART interface
            uart_txd : out std_logic;
            uart_rxd : in  std_logic;
            uart_int : out std_logic;
            -- I2S interface (audio)
            i2s_sck   : out std_logic;
            i2s_ws    : out std_logic;
            i2s_sd_tx : out std_logic;
            i2s_sd_rx : in  std_logic;
            i2s_int   : out std_logic
        );
    end component;

    -- Clock and reset
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '1';

    -- I/O bus
    signal iore    : std_logic := '0';
    signal iowe    : std_logic := '0';
    signal ioaddr  : std_logic_vector(6 downto 0) := (others => '0');
    signal iodata_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal iodata_out : std_logic_vector(7 downto 0);

    -- GPIO
    signal portb_out : std_logic_vector(7 downto 0);
    signal ddrb_out  : std_logic_vector(7 downto 0);
    signal pinb_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal portc_out : std_logic_vector(7 downto 0);
    signal ddrc_out  : std_logic_vector(7 downto 0);
    signal pinc_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal portd_out : std_logic_vector(7 downto 0);
    signal ddrd_out  : std_logic_vector(7 downto 0);
    signal pind_in   : std_logic_vector(7 downto 0) := (others => '0');

    -- Timer0
    signal t0_overflow_int : std_logic;
    signal t0_compare_int  : std_logic;
    signal t0_waveform     : std_logic;

    -- USART0
    signal usart_txd      : std_logic;
    signal usart_rxd      : std_logic := '1';
    signal usart_udre_int : std_logic;
    signal usart_rxc_int  : std_logic;
    signal usart_txc_int  : std_logic;

    -- SPI
    signal spi_sclk : std_logic;
    signal spi_mosi : std_logic;
    signal spi_miso : std_logic := '0';
    signal spi_ss_n : std_logic_vector(2 downto 0);
    signal spi_int  : std_logic;

    -- ADC
    signal adc_input : std_logic_vector(9 downto 0) := (others => '0');
    signal adc_int   : std_logic;

    -- External interrupts
    signal int0     : std_logic := '0';
    signal int1     : std_logic := '0';
    signal int0_int : std_logic;
    signal int1_int : std_logic;
    signal global_int : std_logic;

    -- I2C
    signal i2c_sda : std_logic := 'Z';
    signal i2c_scl : std_logic := 'Z';
    signal i2c_int : std_logic;

    -- UART (new separate UART interface)
    signal uart_txd : std_logic;
    signal uart_rxd : std_logic := '1';
    signal uart_int : std_logic;

    -- I2S (audio)
    signal i2s_sck   : std_logic;
    signal i2s_ws    : std_logic;
    signal i2s_sd_tx : std_logic;
    signal i2s_sd_rx : std_logic := '0';
    signal i2s_int   : std_logic;

    -- Register address constants (must match DUT)
    constant A_PINB   : std_logic_vector(6 downto 0) := "0000011"; -- 0x03
    constant A_DDRB   : std_logic_vector(6 downto 0) := "0000100"; -- 0x04
    constant A_PORTB  : std_logic_vector(6 downto 0) := "0000101"; -- 0x05
    constant A_PIND   : std_logic_vector(6 downto 0) := "0001001"; -- 0x09
    constant A_DDRD   : std_logic_vector(6 downto 0) := "0001010"; -- 0x0A
    constant A_PORTD  : std_logic_vector(6 downto 0) := "0001011"; -- 0x0B
    constant A_SREG   : std_logic_vector(6 downto 0) := "0011110"; -- 0x1E
    constant A_EICRA  : std_logic_vector(6 downto 0) := "1000101"; -- 0x45
    constant A_EIMSK  : std_logic_vector(6 downto 0) := "1000110"; -- 0x46
    constant A_EIFR   : std_logic_vector(6 downto 0) := "1000111"; -- 0x47

    -- Test done flag
    signal test_done : boolean := false;

begin

    -- ==================================================================
    -- DUT instantiation
    -- ==================================================================
    dut : avr_interface
        port map (
            clk => clk, reset => reset,
            iore => iore, iowe => iowe,
            ioaddr => ioaddr,
            iodata_in => iodata_in, iodata_out => iodata_out,
            portb_out => portb_out, ddrb_out => ddrb_out, pinb_in => pinb_in,
            portc_out => portc_out, ddrc_out => ddrc_out, pinc_in => pinc_in,
            portd_out => portd_out, ddrd_out => ddrd_out, pind_in => pind_in,
            t0_overflow_int => t0_overflow_int,
            t0_compare_int  => t0_compare_int,
            t0_waveform     => t0_waveform,
            usart_txd => usart_txd, usart_rxd => usart_rxd,
            usart_udre_int => usart_udre_int,
            usart_rxc_int  => usart_rxc_int,
            usart_txc_int  => usart_txc_int,
            spi_sclk => spi_sclk, spi_mosi => spi_mosi, spi_miso => spi_miso,
            spi_ss_n => spi_ss_n, spi_int => spi_int,
            adc_input => adc_input, adc_int => adc_int,
            int0 => int0, int1 => int1,
            int0_int => int0_int, int1_int => int1_int,
            global_int => global_int,
            -- I2C interface
            i2c_sda => i2c_sda, i2c_scl => i2c_scl, i2c_int => i2c_int,
            -- UART interface
            uart_txd => uart_txd, uart_rxd => uart_rxd, uart_int => uart_int,
            -- I2S interface
            i2s_sck => i2s_sck, i2s_ws => i2s_ws,
            i2s_sd_tx => i2s_sd_tx, i2s_sd_rx => i2s_sd_rx, i2s_int => i2s_int
        );

    -- ==================================================================
    -- Clock generation: 10 ns period (5 ns high, 5 ns low)
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
        -- Helper: perform a single register write (synchronous, one clock)
        procedure reg_write(addr : in std_logic_vector(6 downto 0);
                            data : in std_logic_vector(7 downto 0)) is
        begin
            wait until rising_edge(clk);
            iowe    <= '1';
            ioaddr  <= addr;
            iodata_in <= data;
            wait until rising_edge(clk);
            iowe    <= '0';
            ioaddr  <= (others => '0');
            iodata_in <= (others => '0');
        end procedure;

        -- Helper: perform a single register read (combinational, sample mid-cycle)
        procedure reg_read(addr : in std_logic_vector(6 downto 0);
                           data : out std_logic_vector(7 downto 0)) is
        begin
            iore   <= '1';
            ioaddr <= addr;
            wait for 2 ns;  -- allow combinational logic to settle
            data := iodata_out;
            iore   <= '0';
            ioaddr <= (others => '0');
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

        -- ----------------------------------------------------------------
        -- Register WRITE transactions (at least 3)
        -- ----------------------------------------------------------------

        -- Write 1: DDRB = 0xFF (all outputs)
        reg_write(A_DDRB, x"FF");
        assert ddrb_out = x"FF"
            report "AVR TB: DDRB output mismatch after write 1"
            severity error;

        -- Write 2: PORTB = 0xA5
        reg_write(A_PORTB, x"A5");
        assert portb_out = x"A5"
            report "AVR TB: PORTB output mismatch after write 2"
            severity error;

        -- Write 3: DDRD = 0x0F, PORTD = 0xF0
        reg_write(A_DDRD, x"0F");
        assert ddrd_out = x"0F"
            report "AVR TB: DDRD output mismatch after write 3"
            severity error;

        reg_write(A_PORTD, x"F0");
        assert portd_out = x"F0"
            report "AVR TB: PORTD output mismatch after write 3b"
            severity error;

        -- Write 4: SREG = 0x80 (enable global interrupt, bit 7)
        reg_write(A_SREG, x"80");
        assert global_int = '1'
            report "AVR TB: global_int not asserted after SREG write"
            severity error;

        -- ----------------------------------------------------------------
        -- Register READ transactions (at least 3) and check data
        -- ----------------------------------------------------------------

        -- Read 1: DDRB should be 0xFF
        reg_read(A_DDRB, rdata);
        assert rdata = x"FF"
            report "AVR TB: Read DDRB expected 0xFF, got " &
                   std_logic'image(rdata(7)) & std_logic'image(rdata(0))
            severity error;

        -- Read 2: PORTB should be 0xA5
        reg_read(A_PORTB, rdata);
        assert rdata = x"A5"
            report "AVR TB: Read PORTB expected 0xA5"
            severity error;

        -- Read 3: DDRD should be 0x0F
        reg_read(A_DDRD, rdata);
        assert rdata = x"0F"
            report "AVR TB: Read DDRD expected 0x0F"
            severity error;

        -- ----------------------------------------------------------------
        -- GPIO input stimulation and output checking
        -- ----------------------------------------------------------------
        -- Drive pinb_in and read PINB
        pinb_in <= x"3C";
        wait for 10 ns;
        reg_read(A_PINB, rdata);
        assert rdata = x"3C"
            report "AVR TB: Read PINB expected 0x3C"
            severity error;

        -- Change pinb_in and re-read
        pinb_in <= x"81";
        wait for 10 ns;
        reg_read(A_PINB, rdata);
        assert rdata = x"81"
            report "AVR TB: Read PINB expected 0x81"
            severity error;

        -- Check GPIO outputs reflect written values
        assert portb_out = x"A5"
            report "AVR TB: portb_out not 0xA5"
            severity error;
        assert portd_out = x"F0"
            report "AVR TB: portd_out not 0xF0"
            severity error;

        -- ----------------------------------------------------------------
        -- Interrupt input stimulation and output checking
        -- ----------------------------------------------------------------
        -- Configure EICRA: int0 rising edge (bits 1:0 = "11"), int1 rising (3:2="11")
        reg_write(A_EICRA, x"0F");
        -- Enable INT0 and INT1 in EIMSK (bit0=INT0, bit1=INT1)
        reg_write(A_EIMSK, x"03");

        -- Stimulate INT0 with rising edge
        int0 <= '0';
        wait for 20 ns;
        wait until rising_edge(clk);
        int0 <= '1';
        wait for 20 ns;
        wait until rising_edge(clk);
        -- int0_int should be asserted (EIFR bit0 AND EIMSK bit0 AND SREG I)
        assert int0_int = '1'
            report "AVR TB: int0_int not asserted after INT0 rising edge"
            severity error;

        -- Stimulate INT1 with rising edge
        int1 <= '0';
        wait for 20 ns;
        wait until rising_edge(clk);
        int1 <= '1';
        wait for 20 ns;
        wait until rising_edge(clk);
        assert int1_int = '1'
            report "AVR TB: int1_int not asserted after INT1 rising edge"
            severity error;

        -- ----------------------------------------------------------------
        -- Done
        -- ----------------------------------------------------------------
        wait for 50 ns;
        test_done <= true;
        report "Testbench complete" severity note;
        wait;
    end process;

end architecture sim;

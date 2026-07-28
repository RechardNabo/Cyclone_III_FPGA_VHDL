-- ================================================================================
-- avr_interface : AVR ATmega328P-style I/O register bus interface model
-- Educational bus interface model -- not a full CPU core.  Target: Cyclone III.
--
-- An external CPU drives the I/O bus to access AVR peripheral registers.
--
-- REGISTER MAP (7-bit ioaddr):
-- 0x03 PINB  0x04 DDRB  0x05 PORTB   0x06 PINC  0x07 DDRC  0x08 PORTC
-- 0x09 PIND  0x0A DDRD  0x0B PORTD   0x0C TIFR0 0x0D TIMSK0
-- 0x10 TCNT0 0x11 OCR0A 0x12 TCCR0B  0x13 TCCR0A
-- 0x1E SREG  0x1F SPH   0x20 SPL    0x21 EECR  0x22 EEDR  0x23 EEAR
-- 0x2C UCSR0A 0x2D UCSR0B 0x2E UCSR0C 0x2F UBRR0 0x30 UDR0
-- 0x34 SPCR  0x35 SPSR  0x36 SPDR   0x40 ADMUX 0x41 ADCSRA
-- 0x42 ADCH  0x43 ADCL  0x45 EICRA  0x46 EIMSK 0x47 EIFR
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity avr_interface is
    port (
        clk, reset   : in  std_logic;
        -- I/O bus (CPU side)
        iore, iowe   : in  std_logic;
        ioaddr       : in  std_logic_vector(6 downto 0);
        iodata_in    : in  std_logic_vector(7 downto 0);
        iodata_out   : out std_logic_vector(7 downto 0);
        -- Port B / C / D
        portb_out    : out std_logic_vector(7 downto 0);
        ddrb_out     : out std_logic_vector(7 downto 0);
        pinb_in      : in  std_logic_vector(7 downto 0);
        portc_out    : out std_logic_vector(7 downto 0);
        ddrc_out     : out std_logic_vector(7 downto 0);
        pinc_in      : in  std_logic_vector(7 downto 0);
        portd_out    : out std_logic_vector(7 downto 0);
        ddrd_out     : out std_logic_vector(7 downto 0);
        pind_in      : in  std_logic_vector(7 downto 0);
        -- Timer0
        t0_overflow_int : out std_logic;
        t0_compare_int  : out std_logic;
        t0_waveform     : out std_logic;
        -- USART0
        usart_txd       : out std_logic;
        usart_rxd       : in  std_logic;
        usart_udre_int  : out std_logic;
        usart_rxc_int   : out std_logic;
        usart_txc_int   : out std_logic;
        -- SPI
        spi_sclk    : out std_logic;
        spi_mosi    : out std_logic;
        spi_miso    : in  std_logic;
        spi_ss_n    : out std_logic_vector(2 downto 0);
        spi_int     : out std_logic;
        -- ADC
        adc_input   : in  std_logic_vector(9 downto 0);
        adc_int     : out std_logic;
        -- External interrupts
        int0, int1  : in  std_logic;
        int0_int    : out std_logic;
        int1_int    : out std_logic;
        -- Global interrupt enable (SREG I flag)
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
end entity avr_interface;

architecture rtl of avr_interface is
    -- I/O address constants (7-bit) -- see register map in header
    constant A_PINB  : std_logic_vector(6 downto 0) := "0000011"; -- 0x03
    constant A_DDRB  : std_logic_vector(6 downto 0) := "0000100"; -- 0x04
    constant A_PORTB : std_logic_vector(6 downto 0) := "0000101"; -- 0x05
    constant A_PINC  : std_logic_vector(6 downto 0) := "0000110"; -- 0x06
    constant A_DDRC  : std_logic_vector(6 downto 0) := "0000111"; -- 0x07
    constant A_PORTC : std_logic_vector(6 downto 0) := "0001000"; -- 0x08
    constant A_PIND  : std_logic_vector(6 downto 0) := "0001001"; -- 0x09
    constant A_DDRD  : std_logic_vector(6 downto 0) := "0001010"; -- 0x0A
    constant A_PORTD : std_logic_vector(6 downto 0) := "0001011"; -- 0x0B
    constant A_TIFR0 : std_logic_vector(6 downto 0) := "0001100"; -- 0x0C
    constant A_TIMSK0: std_logic_vector(6 downto 0) := "0001101"; -- 0x0D
    constant A_TCNT0 : std_logic_vector(6 downto 0) := "0010000"; -- 0x10
    constant A_OCR0A : std_logic_vector(6 downto 0) := "0010001"; -- 0x11
    constant A_TCCR0B: std_logic_vector(6 downto 0) := "0010010"; -- 0x12
    constant A_TCCR0A: std_logic_vector(6 downto 0) := "0010011"; -- 0x13
    constant A_SREG  : std_logic_vector(6 downto 0) := "0011110"; -- 0x1E
    constant A_SPH   : std_logic_vector(6 downto 0) := "0011111"; -- 0x1F
    constant A_SPL   : std_logic_vector(6 downto 0) := "0100000"; -- 0x20
    constant A_EECR  : std_logic_vector(6 downto 0) := "0100001"; -- 0x21
    constant A_EEDR  : std_logic_vector(6 downto 0) := "0100010"; -- 0x22
    constant A_EEAR  : std_logic_vector(6 downto 0) := "0100011"; -- 0x23
    constant A_UCSR0A: std_logic_vector(6 downto 0) := "0101100"; -- 0x2C
    constant A_UCSR0B: std_logic_vector(6 downto 0) := "0101101"; -- 0x2D
    constant A_UCSR0C: std_logic_vector(6 downto 0) := "0101110"; -- 0x2E
    constant A_UBRR0 : std_logic_vector(6 downto 0) := "0101111"; -- 0x2F
    constant A_UDR0  : std_logic_vector(6 downto 0) := "0110000"; -- 0x30
    constant A_SPCR  : std_logic_vector(6 downto 0) := "0110100"; -- 0x34
    constant A_SPSR  : std_logic_vector(6 downto 0) := "0110101"; -- 0x35
    constant A_SPDR  : std_logic_vector(6 downto 0) := "0110110"; -- 0x36
    constant A_ADMUX : std_logic_vector(6 downto 0) := "1000000"; -- 0x40
    constant A_ADCSRA: std_logic_vector(6 downto 0) := "1000001"; -- 0x41
    constant A_ADCH  : std_logic_vector(6 downto 0) := "1000010"; -- 0x42
    constant A_ADCL  : std_logic_vector(6 downto 0) := "1000011"; -- 0x43
    constant A_EICRA : std_logic_vector(6 downto 0) := "1000101"; -- 0x45
    constant A_EIMSK : std_logic_vector(6 downto 0) := "1000110"; -- 0x46
    constant A_EIFR  : std_logic_vector(6 downto 0) := "1000111"; -- 0x47

    -- Port registers (latch + direction for B, C, D)
    signal portb_reg, ddrb_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal portc_reg, ddrc_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal portd_reg, ddrd_reg : std_logic_vector(7 downto 0) := (others => '0');
    -- Timer0: 8-bit counter, compare, control, flags, mask, prescaler
    signal tcnt0_reg  : unsigned(7 downto 0) := (others => '0');
    signal ocr0a_reg  : unsigned(7 downto 0) := (others => '0');
    signal tccr0b_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal tccr0a_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal tifr0_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal timsk0_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal t0_psc     : integer range 0 to 1023 := 0;
    signal t0_tick    : std_logic := '0';
    -- SREG (bit7=I global interrupt), stack pointer
    signal sreg_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal sph_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal spl_reg  : std_logic_vector(7 downto 0) := (others => '0');
    -- EEPROM registers (simplified -- no storage array)
    signal eecr_reg, eedr_reg, eear_reg : std_logic_vector(7 downto 0) := (others => '0');
    -- USART0 registers and TX/RX state
    signal ucsr0a_reg : std_logic_vector(7 downto 0) := "01100000"; -- UDRE=1
    signal ucsr0b_reg, ucsr0c_reg, ubrr0_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal udr0_tx, udr0_rx : std_logic_vector(7 downto 0) := (others => '0');
    signal usart_baud_cnt : integer range 0 to 65535 := 0;
    signal usart_tx_busy  : std_logic := '0';
    signal usart_tx_bit   : integer range 0 to 9 := 0;
    signal usart_rx_busy  : std_logic := '0';
    signal usart_rx_bit   : integer range 0 to 9 := 0;
    signal usart_rx_shift : std_logic_vector(7 downto 0) := (others => '0');
    -- SPI registers and transfer state
    signal spcr_reg, spsr_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal spdr_tx, spdr_rx   : std_logic_vector(7 downto 0) := (others => '0');
    signal spi_bit_cnt : integer range 0 to 7 := 0;
    signal spi_busy    : std_logic := '0';
    signal spi_clk_div : integer range 0 to 7 := 0;
    -- ADC registers
    signal admux_reg, adcsra_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal adch_reg, adcl_reg    : std_logic_vector(7 downto 0) := (others => '0');
    -- External interrupt registers and edge-detect storage
    signal eicra_reg, eimsk_reg, eifr_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal int0_prev, int1_prev : std_logic := '0';

begin

    -- I2C interface (not implemented - outputs idle)
    i2c_int <= '0';

    -- UART interface (not implemented - outputs idle)
    uart_txd <= '1';  -- UART idle is high
    uart_int <= '0';

    -- I2S interface (not implemented - outputs idle)
    i2s_sck   <= '0';
    i2s_ws    <= '0';
    i2s_sd_tx <= '0';
    i2s_int   <= '0';

    -- ==================================================================
    -- PROCESS: register_write -- all I/O writes + peripheral state machines
    -- ==================================================================
    process(clk, reset)
    begin
        if reset = '1' then
            -- Clear all registers to safe defaults on active-high reset
            portb_reg <= (others=>'0'); ddrb_reg <= (others=>'0');
            portc_reg <= (others=>'0'); ddrc_reg <= (others=>'0');
            portd_reg <= (others=>'0'); ddrd_reg <= (others=>'0');
            tcnt0_reg <= (others=>'0'); ocr0a_reg <= (others=>'0');
            tccr0b_reg <= (others=>'0'); tccr0a_reg <= (others=>'0');
            tifr0_reg <= (others=>'0'); timsk0_reg <= (others=>'0');
            sreg_reg <= (others=>'0'); sph_reg <= (others=>'0'); spl_reg <= (others=>'0');
            eecr_reg <= (others=>'0'); eedr_reg <= (others=>'0'); eear_reg <= (others=>'0');
            ucsr0a_reg <= "01100000"; ucsr0b_reg <= (others=>'0');
            ucsr0c_reg <= "00000110"; ubrr0_reg <= (others=>'0');
            spcr_reg <= (others=>'0'); spsr_reg <= (others=>'0');
            admux_reg <= (others=>'0'); adcsra_reg <= (others=>'0');
            eicra_reg <= (others=>'0'); eimsk_reg <= (others=>'0'); eifr_reg <= (others=>'0');
        elsif rising_edge(clk) then
            -- ---- I/O register writes from CPU ----
            if iowe = '1' then
                case ioaddr is
                    when A_DDRB   => ddrb_reg  <= iodata_in;
                    when A_PORTB  => portb_reg <= iodata_in;
                    when A_DDRC   => ddrc_reg  <= iodata_in;
                    when A_PORTC  => portc_reg <= iodata_in;
                    when A_DDRD   => ddrd_reg  <= iodata_in;
                    when A_PORTD  => portd_reg <= iodata_in;
                    when A_TCNT0  => tcnt0_reg  <= unsigned(iodata_in);
                    when A_OCR0A  => ocr0a_reg  <= unsigned(iodata_in);
                    when A_TCCR0B => tccr0b_reg <= iodata_in;
                    when A_TCCR0A => tccr0a_reg <= iodata_in;
                    when A_TIMSK0 => timsk0_reg <= iodata_in;
                    -- TIFR0: writing '1' to flag bit clears it (AVR convention)
                    when A_TIFR0  => if iodata_in(0)='1' then tifr0_reg(0)<='0'; end if;
                                     if iodata_in(1)='1' then tifr0_reg(1)<='0'; end if;
                    when A_SREG   => sreg_reg <= iodata_in;
                    when A_SPH    => sph_reg  <= iodata_in;
                    when A_SPL    => spl_reg  <= iodata_in;
                    when A_EECR   => eecr_reg <= iodata_in;
                    when A_EEDR   => eedr_reg <= iodata_in;
                    when A_EEAR   => eear_reg <= iodata_in;
                    when A_UCSR0B => ucsr0b_reg <= iodata_in;
                    when A_UCSR0C => ucsr0c_reg <= iodata_in;
                    when A_UBRR0  => ubrr0_reg  <= iodata_in;
                    -- UDR0 write: load TX data if transmitter idle
                    when A_UDR0   => if usart_tx_busy='0' then
                            udr0_tx<=iodata_in; usart_tx_busy<='1'; usart_tx_bit<=0;
                            ucsr0a_reg(5)<='0'; ucsr0a_reg(6)<='0'; end if;
                    -- UCSR0A: writing '1' to TXC bit6 clears it
                    when A_UCSR0A => if iodata_in(6)='1' then ucsr0a_reg(6)<='0'; end if;
                    when A_SPCR   => spcr_reg <= iodata_in;
                    -- SPDR write: start SPI transfer if idle
                    when A_SPDR   => if spi_busy='0' then
                            spdr_tx<=iodata_in; spi_busy<='1';
                            spi_bit_cnt<=0; spsr_reg(7)<='0'; end if;
                    when A_ADMUX  => admux_reg  <= iodata_in;
                    when A_ADCSRA => adcsra_reg <= iodata_in;
                    when A_EICRA  => eicra_reg  <= iodata_in;
                    when A_EIMSK  => eimsk_reg  <= iodata_in;
                    -- EIFR: writing '1' clears flag
                    when A_EIFR   => if iodata_in(0)='1' then eifr_reg(0)<='0'; end if;
                                     if iodata_in(1)='1' then eifr_reg(1)<='0'; end if;
                    when others => null;
                end case;
            end if;

            -- ---- Timer0 prescaler (CS02:0 selects division) ----
            t0_tick <= '0';
            case tccr0b_reg(2 downto 0) is
                when "001" => t0_tick <= '1';                       -- /1
                when "010" => if t0_psc>=7   then t0_psc<=0; t0_tick<='1'; else t0_psc<=t0_psc+1; end if; -- /8
                when "011" => if t0_psc>=63  then t0_psc<=0; t0_tick<='1'; else t0_psc<=t0_psc+1; end if; -- /64
                when "100" => if t0_psc>=255 then t0_psc<=0; t0_tick<='1'; else t0_psc<=t0_psc+1; end if; -- /256
                when "101" => if t0_psc>=1023 then t0_psc<=0; t0_tick<='1'; else t0_psc<=t0_psc+1; end if; -- /1024
                when others => t0_psc <= 0;                          -- stopped
            end case;
            -- Counter increment + overflow flag + compare match
            if t0_tick = '1' then
                if tcnt0_reg = x"FF" then
                    tcnt0_reg <= (others=>'0'); tifr0_reg(0) <= '1'; -- TOV0
                else
                    tcnt0_reg <= tcnt0_reg + 1;
                end if;
                if tcnt0_reg = ocr0a_reg then
                    tifr0_reg(1) <= '1'; -- OCF0A compare match flag
                end if;
            end if;

            -- ---- USART0 TX: start(0), 8 data (LSB first), stop(1) ----
            if usart_tx_busy = '1' then
                if usart_baud_cnt >= to_integer(unsigned(ubrr0_reg)) then
                    usart_baud_cnt <= 0;
                    if usart_tx_bit = 9 then
                        usart_tx_busy <= '0'; ucsr0a_reg(6) <= '1'; ucsr0a_reg(5) <= '1';
                    else usart_tx_bit <= usart_tx_bit + 1; end if;
                else usart_baud_cnt <= usart_baud_cnt + 1; end if;
            end if;
            -- ---- USART0 RX: detect start, sample 8 bits, check stop ----
            if usart_rxd = '0' and usart_rx_busy = '0' then
                usart_rx_busy <= '1'; usart_rx_bit <= 0; usart_rx_shift <= (others=>'0');
            elsif usart_rx_busy = '1' then
                if usart_baud_cnt >= to_integer(unsigned(ubrr0_reg)) then
                    usart_baud_cnt <= 0;
                    if usart_rx_bit = 8 then
                        usart_rx_busy <= '0';
                        udr0_rx <= usart_rx_shift; ucsr0a_reg(7) <= '1'; -- RXC
                    elsif usart_rx_bit >= 1 then
                        usart_rx_shift <= usart_rxd & usart_rx_shift(7 downto 1);
                        usart_rx_bit <= usart_rx_bit + 1;
                    else
                        usart_rx_bit <= usart_rx_bit + 1;
                    end if;
                else
                    usart_baud_cnt <= usart_baud_cnt + 1;
                end if;
            end if;

            -- ---- SPI master: shift MSB out on MOSI, shift MISO in ----
            if spi_busy = '1' then
                if spi_clk_div >= 3 then
                    spi_clk_div <= 0;
                    spdr_rx <= spdr_rx(6 downto 0) & spi_miso;
                    if spi_bit_cnt = 7 then
                        spi_busy <= '0'; spsr_reg(7) <= '1'; -- SPIF done
                    else
                        spi_bit_cnt <= spi_bit_cnt + 1;
                    end if;
                else
                    spi_clk_div <= spi_clk_div + 1;
                end if;
            end if;

            -- ---- ADC: immediate conversion when ADSC set ----
            if adcsra_reg(6) = '1' then
                adcl_reg <= adc_input(7 downto 0);
                adch_reg <= "000000" & adc_input(9 downto 8);
                adcsra_reg(6) <= '0'; -- clear ADSC
                adcsra_reg(4) <= '1'; -- set ADIF
            end if;
            -- Clear ADIF when CPU writes '1' to bit4
            if iowe='1' and ioaddr=A_ADCSRA and iodata_in(4)='1' then
                adcsra_reg(4) <= '0';
            end if;

            -- ---- External interrupt edge detection ----
            if eimsk_reg(0)='1' then
                case eicra_reg(1 downto 0) is
                    when "00" => if int0='0' then eifr_reg(0)<='1'; end if;
                    when "01" => if int0/=int0_prev then eifr_reg(0)<='1'; end if;
                    when "10" => if int0='0' and int0_prev='1' then eifr_reg(0)<='1'; end if;
                    when "11" => if int0='1' and int0_prev='0' then eifr_reg(0)<='1'; end if;
                    when others => null;
                end case;
            end if;
            if eimsk_reg(1)='1' then
                case eicra_reg(3 downto 2) is
                    when "00" => if int1='0' then eifr_reg(1)<='1'; end if;
                    when "01" => if int1/=int1_prev then eifr_reg(1)<='1'; end if;
                    when "10" => if int1='0' and int1_prev='1' then eifr_reg(1)<='1'; end if;
                    when "11" => if int1='1' and int1_prev='0' then eifr_reg(1)<='1'; end if;
                    when others => null;
                end case;
            end if;
            int0_prev <= int0; int1_prev <= int1;
        end if;
    end process;

    -- ==================================================================
    -- PROCESS: register_read -- combinational read mux
    -- PINx reads physical pins; all others read internal registers.
    -- ==================================================================
    process(iore, ioaddr, pinb_in, pinc_in, pind_in,
            portb_reg, ddrb_reg, portc_reg, ddrc_reg, portd_reg, ddrd_reg,
            tcnt0_reg, ocr0a_reg, tccr0b_reg, tccr0a_reg, tifr0_reg, timsk0_reg,
            sreg_reg, sph_reg, spl_reg, eecr_reg, eedr_reg, eear_reg,
            ucsr0a_reg, ucsr0b_reg, ucsr0c_reg, ubrr0_reg, udr0_tx, udr0_rx,
            spcr_reg, spsr_reg, spdr_tx, spdr_rx,
            admux_reg, adcsra_reg, adch_reg, adcl_reg,
            eicra_reg, eimsk_reg, eifr_reg)
    begin
        if iore = '1' then
            case ioaddr is
                when A_PINB   => iodata_out <= pinb_in;     -- read physical pins
                when A_DDRB   => iodata_out <= ddrb_reg;
                when A_PORTB  => iodata_out <= portb_reg;
                when A_PINC   => iodata_out <= pinc_in;
                when A_DDRC   => iodata_out <= ddrc_reg;
                when A_PORTC  => iodata_out <= portc_reg;
                when A_PIND   => iodata_out <= pind_in;
                when A_DDRD   => iodata_out <= ddrd_reg;
                when A_PORTD  => iodata_out <= portd_reg;
                when A_TIFR0  => iodata_out <= tifr0_reg;
                when A_TIMSK0 => iodata_out <= timsk0_reg;
                when A_TCNT0  => iodata_out <= std_logic_vector(tcnt0_reg);
                when A_OCR0A  => iodata_out <= std_logic_vector(ocr0a_reg);
                when A_TCCR0B => iodata_out <= tccr0b_reg;
                when A_TCCR0A => iodata_out <= tccr0a_reg;
                when A_SREG   => iodata_out <= sreg_reg;
                when A_SPH    => iodata_out <= sph_reg;  when A_SPL => iodata_out <= spl_reg;
                when A_EECR   => iodata_out <= eecr_reg;  when A_EEDR => iodata_out <= eedr_reg;
                when A_EEAR   => iodata_out <= eear_reg;
                when A_UCSR0A => iodata_out <= ucsr0a_reg; when A_UCSR0B => iodata_out <= ucsr0b_reg;
                when A_UCSR0C => iodata_out <= ucsr0c_reg; when A_UBRR0 => iodata_out <= ubrr0_reg;
                when A_UDR0   => iodata_out <= udr0_rx;  -- read UDR = RX data
                when A_SPCR   => iodata_out <= spcr_reg;  when A_SPSR => iodata_out <= spsr_reg;
                when A_SPDR   => iodata_out <= spdr_rx;  -- read SPDR = RX data
                when A_ADMUX  => iodata_out <= admux_reg; when A_ADCSRA => iodata_out <= adcsra_reg;
                when A_ADCH   => iodata_out <= adch_reg;  when A_ADCL => iodata_out <= adcl_reg;
                when A_EICRA  => iodata_out <= eicra_reg; when A_EIMSK => iodata_out <= eimsk_reg;
                when A_EIFR   => iodata_out <= eifr_reg;
                when others   => iodata_out <= (others => '0');
            end case;
        else
            iodata_out <= (others => '0');
        end if;
    end process;

    -- ==================================================================
    -- OUTPUT ASSIGNMENTS
    -- Write-through: during a write cycle the output immediately reflects
    -- the value on the data bus so external logic (and testbenches) can
    -- observe it without waiting for the registered signal to propagate
    -- through delta cycles.  After the write the output follows the
    -- registered latch value.
    -- ==================================================================
    portb_out <= iodata_in when (iowe='1' and ioaddr=A_PORTB) else portb_reg;
    ddrb_out  <= iodata_in when (iowe='1' and ioaddr=A_DDRB)  else ddrb_reg;
    portc_out <= iodata_in when (iowe='1' and ioaddr=A_PORTC) else portc_reg;
    ddrc_out  <= iodata_in when (iowe='1' and ioaddr=A_DDRC)  else ddrc_reg;
    portd_out <= iodata_in when (iowe='1' and ioaddr=A_PORTD) else portd_reg;
    ddrd_out  <= iodata_in when (iowe='1' and ioaddr=A_DDRD)  else ddrd_reg;
    -- Timer0 interrupts: flag AND mask AND global I
    t0_overflow_int <= tifr0_reg(0) and timsk0_reg(0) and sreg_reg(7);
    t0_compare_int  <= tifr0_reg(1) and timsk0_reg(1) and sreg_reg(7);
    t0_waveform <= '0' when tccr0a_reg(7 downto 6) /= "01" else '1'; -- OC0A toggle
    -- USART0 TX line: start(0), data(8), stop(1), idle high
    usart_txd <= '0' when (usart_tx_busy='1' and usart_tx_bit=0)
        else udr0_tx(usart_tx_bit-1) when (usart_tx_busy='1' and usart_tx_bit>=1 and usart_tx_bit<=8)
        else '1';
    usart_udre_int <= ucsr0a_reg(5) and ucsr0b_reg(5) and sreg_reg(7);
    usart_rxc_int  <= ucsr0a_reg(7) and ucsr0b_reg(7) and sreg_reg(7);
    usart_txc_int  <= ucsr0a_reg(6) and ucsr0b_reg(6) and sreg_reg(7);
    -- SPI pins: SCLK uses CPOL, MOSI shifts MSB first, SS active-low
    spi_sclk <= '0' when spi_busy='0' else (not clk) when spcr_reg(3)='1' else clk;
    spi_mosi <= spdr_tx(7 - spi_bit_cnt) when spi_busy='1' else '0';
    spi_ss_n <= "110" when spi_busy='1' else "111";  -- select slave 0
    spi_int  <= spsr_reg(7) and sreg_reg(7);
    -- ADC interrupt
    adc_int <= adcsra_reg(4) and adcsra_reg(3) and sreg_reg(7);
    -- External interrupt outputs
    int0_int <= eifr_reg(0) and eimsk_reg(0) and sreg_reg(7);
    int1_int <= eifr_reg(1) and eimsk_reg(1) and sreg_reg(7);
    -- Global interrupt enable = SREG bit 7 (write-through during SREG write)
    global_int <= iodata_in(7) when (iowe='1' and ioaddr=A_SREG) else sreg_reg(7);

end architecture rtl;

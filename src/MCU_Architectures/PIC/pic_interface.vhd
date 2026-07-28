-- ================================================================================
-- pic_interface : PIC16F877A-style peripheral interface model
-- Educational bus interface model -- not a full PIC CPU core.  Target: Cyclone III.
--
-- Models PIC16 peripherals: 4 ports (A-D) with TRIS registers, Timer0/1/2,
-- 10-bit ADC with channel select, USART, INTCON, OPTION_REG, and bank switching.
--
-- REGISTER MAP (9-bit addr: 7-bit file addr + 2 bank bits [RP1:RP0]):
-- Bank 0 (RP1:RP0=00): 0x05 PORTA  0x06 PORTB  0x07 PORTC  0x08 PORTD
--   0x01 TMR0   0x0B INTCON  0x81 OPTION_REG  0x0C PIR1  0x0D PIR2
--   0x0E TMR1L  0x0F TMR1H  0x10 T1CON  0x11 TMR2  0x12 PR2  0x13 T2CON
--   0x1F ADRESH 0x20 ADRESL 0x1E ADCON0 0x9F ADCON1
--   0x18 RCSTA  0x19 TXSTA  0x1A SPBRG 0x1C TXREG 0x1A RCREG
-- Bank 1 (RP1:RP0=01): 0x85 TRISA  0x86 TRISB  0x87 TRISC  0x88 TRISD
--   0x81 OPTION_REG  0x8B INTCON  0x9F ADCON1
-- Bank 2/3: not fully implemented (simplified)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pic_interface is
    port (
        clk, reset  : in  std_logic;
        -- 9-bit address: 7-bit file register + 2 bank-select bits
        addr        : in  std_logic_vector(8 downto 0);
        din         : in  std_logic_vector(7 downto 0);
        dout        : out std_logic_vector(7 downto 0);
        we, re      : in  std_logic;
        -- Port A (8-bit GPIO with TRIS)
        porta_out   : out std_logic_vector(7 downto 0);
        trisa_out   : out std_logic_vector(7 downto 0);
        porta_in    : in  std_logic_vector(7 downto 0);
        -- Port B
        portb_out   : out std_logic_vector(7 downto 0);
        trisb_out   : out std_logic_vector(7 downto 0);
        portb_in    : in  std_logic_vector(7 downto 0);
        -- Port C
        portc_out   : out std_logic_vector(7 downto 0);
        trisc_out   : out std_logic_vector(7 downto 0);
        portc_in    : in  std_logic_vector(7 downto 0);
        -- Port D
        portd_out   : out std_logic_vector(7 downto 0);
        trisd_out   : out std_logic_vector(7 downto 0);
        portd_in    : in  std_logic_vector(7 downto 0);
        -- Timer interrupts
        t0_int, t1_int, t2_int : out std_logic;
        -- ADC
        adc_in      : in  std_logic_vector(9 downto 0);  -- 10-bit ADC
        adc_int     : out std_logic;
        -- USART
        usart_txd   : out std_logic;
        usart_rxd   : in  std_logic;
        usart_tx_int, usart_rx_int : out std_logic;
        -- External interrupt (RB0/INT)
        ext_int     : in  std_logic;
        ext_int_out : out std_logic;
        -- Global interrupt enable
        gie_out     : out std_logic;

        -- I2C interface
        i2c_sda : inout std_logic;
        i2c_scl : inout std_logic;
        i2c_int : out std_logic;

        -- SPI interface
        spi_sclk : out std_logic;
        spi_mosi : out std_logic;
        spi_miso : in  std_logic;
        spi_int  : out std_logic;

        -- UART interface
        uart_txd : out std_logic;
        uart_rxd : in  std_logic;
        uart_int : out std_logic;

        -- I2S interface (audio)
        i2s_sck   : out std_logic;
        i2s_ws    : out std_logic;
        i2s_sd_tx : out std_logic;
        i2s_sd_rx : in  std_logic;
        i2s_int   : out std_logic;

        -- Watchdog Timer (WDT)
        wdt_int   : out std_logic;
        wdt_reset : out std_logic;

        -- Real-Time Clock (RTC)
        rtc_int   : out std_logic;

        -- DAC (2-channel, 12-bit = 24 bits)
        dac_out   : out std_logic_vector(23 downto 0)
    );
end entity pic_interface;

architecture rtl of pic_interface is
    -- 9-bit address constants: [bank1,bank0, file_addr(7 bits)]
    -- Bank 0
    constant A_PORTA  : std_logic_vector(8 downto 0) := "000000101"; -- 0x05
    constant A_PORTB  : std_logic_vector(8 downto 0) := "000000110"; -- 0x06
    constant A_PORTC  : std_logic_vector(8 downto 0) := "000000111"; -- 0x07
    constant A_PORTD  : std_logic_vector(8 downto 0) := "000001000"; -- 0x08
    constant A_TMR0   : std_logic_vector(8 downto 0) := "000000001"; -- 0x01
    constant A_INTCON : std_logic_vector(8 downto 0) := "000001011"; -- 0x0B
    constant A_PIR1   : std_logic_vector(8 downto 0) := "000001100"; -- 0x0C
    constant A_TMR1L  : std_logic_vector(8 downto 0) := "000001110"; -- 0x0E
    constant A_TMR1H  : std_logic_vector(8 downto 0) := "000001111"; -- 0x0F
    constant A_T1CON  : std_logic_vector(8 downto 0) := "000010000"; -- 0x10
    constant A_TMR2   : std_logic_vector(8 downto 0) := "000010001"; -- 0x11
    constant A_PR2    : std_logic_vector(8 downto 0) := "000010010"; -- 0x12
    constant A_T2CON  : std_logic_vector(8 downto 0) := "000010011"; -- 0x13
    constant A_ADRESH : std_logic_vector(8 downto 0) := "000011111"; -- 0x1F
    constant A_ADRESL : std_logic_vector(8 downto 0) := "000100000"; -- 0x20
    constant A_ADCON0 : std_logic_vector(8 downto 0) := "000011110"; -- 0x1E
    constant A_RCSTA  : std_logic_vector(8 downto 0) := "000011000"; -- 0x18
    constant A_TXSTA  : std_logic_vector(8 downto 0) := "000011001"; -- 0x19
    constant A_SPBRG  : std_logic_vector(8 downto 0) := "000011010"; -- 0x1A
    constant A_TXREG  : std_logic_vector(8 downto 0) := "000011100"; -- 0x1C
    constant A_RCREG  : std_logic_vector(8 downto 0) := "000011010"; -- 0x1A shared
    -- Bank 1
    constant A_TRISA  : std_logic_vector(8 downto 0) := "010000101"; -- 0x85
    constant A_TRISB  : std_logic_vector(8 downto 0) := "010000110"; -- 0x86
    constant A_TRISC  : std_logic_vector(8 downto 0) := "010000111"; -- 0x87
    constant A_TRISD  : std_logic_vector(8 downto 0) := "010001000"; -- 0x88
    constant A_OPTION : std_logic_vector(8 downto 0) := "010000001"; -- 0x81
    constant A_ADCON1 : std_logic_vector(8 downto 0) := "010011111"; -- 0x9F

    -- Port registers (latch + TRIS direction for A, B, C, D)
    signal porta_reg, trisa_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal portb_reg, trisb_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal portc_reg, trisc_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal portd_reg, trisd_reg : std_logic_vector(7 downto 0) := (others => '0');
    -- Timer0: 8-bit counter, prescaler
    signal tmr0_reg  : unsigned(7 downto 0) := (others => '0');
    signal t0_psc    : integer range 0 to 255 := 0;
    -- Timer1: 16-bit counter, prescaler
    signal tmr1l_reg, tmr1h_reg : unsigned(7 downto 0) := (others => '0');
    signal t1con_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal t1_psc    : integer range 0 to 7 := 0;
    -- Timer2: 8-bit counter, period register, postscaler
    signal tmr2_reg, pr2_reg : unsigned(7 downto 0) := (others => '0');
    signal t2con_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal t2_psc    : integer range 0 to 15 := 0;
    signal t2_postsc : integer range 0 to 15 := 0;
    -- INTCON: GIE(7),T0IE(5),INTE(4),RBIE(3),T0IF(2),INTF(1),RBIF(0)
    signal intcon_reg : std_logic_vector(7 downto 0) := (others => '0');
    -- PIR1: bit4=TXIF, bit5=RCIF (simplified)
    signal pir1_reg   : std_logic_vector(7 downto 0) := (others => '0');
    -- OPTION_REG: bit7=RBPU,bit6=INTEDG,bit5=T0CS,bit3=PSA,bit2:0=PS
    signal option_reg : std_logic_vector(7 downto 0) := (others => '1');
    -- ADC registers
    signal adcon0_reg, adcon1_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal adresh_reg, adresl_reg : std_logic_vector(7 downto 0) := (others => '0');
    -- USART registers + state
    signal txsta_reg, rcsta_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal spbrg_reg, txreg_reg, rcreg_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal usart_tx_busy, usart_rx_busy : std_logic := '0';
    signal usart_tx_bit, usart_rx_bit : integer range 0 to 9 := 0;
    signal usart_baud_cnt : integer range 0 to 65535 := 0;
    signal usart_rx_shift : std_logic_vector(7 downto 0) := (others => '0');
    -- External interrupt edge detection
    signal ext_int_prev : std_logic := '0';

    -- ========================================================================
    -- WDT controller AHB bridge signals
    -- ========================================================================
    signal wdt_sel       : std_logic;
    signal wdt_hsel      : std_logic;
    signal wdt_hwrite    : std_logic;
    signal wdt_hready    : std_logic;
    signal wdt_htrans    : std_logic_vector(1 downto 0);
    signal wdt_hsize     : std_logic_vector(2 downto 0);
    signal wdt_haddr     : std_logic_vector(31 downto 0);
    signal wdt_hwdata    : std_logic_vector(31 downto 0);
    signal wdt_hrdata    : std_logic_vector(31 downto 0);
    signal wdt_hresp     : std_logic;
    signal wdt_hreadyout : std_logic;

    -- ========================================================================
    -- RTC controller AHB bridge signals
    -- ========================================================================
    signal rtc_sel       : std_logic;
    signal rtc_hsel      : std_logic;
    signal rtc_hwrite    : std_logic;
    signal rtc_hready    : std_logic;
    signal rtc_htrans    : std_logic_vector(1 downto 0);
    signal rtc_hsize     : std_logic_vector(2 downto 0);
    signal rtc_haddr     : std_logic_vector(31 downto 0);
    signal rtc_hwdata    : std_logic_vector(31 downto 0);
    signal rtc_hrdata    : std_logic_vector(31 downto 0);
    signal rtc_hresp     : std_logic;
    signal rtc_hreadyout : std_logic;

    -- ========================================================================
    -- DAC controller AHB bridge signals
    -- ========================================================================
    signal dac_sel       : std_logic;
    signal dac_hsel      : std_logic;
    signal dac_hwrite    : std_logic;
    signal dac_hready    : std_logic;
    signal dac_htrans    : std_logic_vector(1 downto 0);
    signal dac_hsize     : std_logic_vector(2 downto 0);
    signal dac_haddr     : std_logic_vector(31 downto 0);
    signal dac_hwdata    : std_logic_vector(31 downto 0);
    signal dac_hrdata    : std_logic_vector(31 downto 0);
    signal dac_hresp     : std_logic;
    signal dac_hreadyout : std_logic;

    -- ========================================================================
    -- Component declarations for WDT, RTC, and DAC controllers
    -- ========================================================================
    component wdt_controller is
        port (
            HCLK      : in  std_logic;
            HRESETn   : in  std_logic;
            HSEL      : in  std_logic;
            HWRITE    : in  std_logic;
            HREADY    : in  std_logic;
            HTRANS    : in  std_logic_vector(1 downto 0);
            HADDR     : in  std_logic_vector(31 downto 0);
            HWDATA    : in  std_logic_vector(31 downto 0);
            HRDATA    : out std_logic_vector(31 downto 0);
            HRESP     : out std_logic;
            HREADYOUT : out std_logic;
            wdt_int   : out std_logic;
            wdt_reset : out std_logic
        );
    end component;

    component rtc_controller is
        port (
            HCLK      : in  std_logic;
            HRESETn   : in  std_logic;
            HSEL      : in  std_logic;
            HWRITE    : in  std_logic;
            HREADY    : in  std_logic;
            HTRANS    : in  std_logic_vector(1 downto 0);
            HADDR     : in  std_logic_vector(31 downto 0);
            HWDATA    : in  std_logic_vector(31 downto 0);
            HRDATA    : out std_logic_vector(31 downto 0);
            HRESP     : out std_logic;
            HREADYOUT : out std_logic;
            rtc_int   : out std_logic
        );
    end component;

    component dac_controller is
        port (
            HCLK      : in  std_logic;
            HRESETn   : in  std_logic;
            HSEL      : in  std_logic;
            HWRITE    : in  std_logic;
            HREADY    : in  std_logic;
            HTRANS    : in  std_logic_vector(1 downto 0);
            HADDR     : in  std_logic_vector(31 downto 0);
            HWDATA    : in  std_logic_vector(31 downto 0);
            HRDATA    : out std_logic_vector(31 downto 0);
            HRESP     : out std_logic;
            HREADYOUT : out std_logic;
            dac_out   : out std_logic_vector(23 downto 0)
        );
    end component;

begin

    -- I2C interface (not implemented - outputs idle)
    i2c_int <= '0';

    -- SPI interface (not implemented - outputs idle)
    spi_sclk <= '0';
    spi_mosi <= '0';
    spi_int  <= '0';

    -- UART interface (not implemented - outputs idle)
    uart_txd <= '1';  -- UART idle is high
    uart_int <= '0';

    -- I2S interface (not implemented - outputs idle)
    i2s_sck   <= '0';
    i2s_ws    <= '0';
    i2s_sd_tx <= '0';
    i2s_int   <= '0';

    -- ==================================================================
    -- PROCESS: register_write -- all register writes + peripheral state machines
    -- ==================================================================
    process(clk, reset)
    begin
        if reset = '1' then
            -- Active-high reset: clear all registers, TRIS defaults to input (1)
            porta_reg<=(others=>'0'); trisa_reg<=(others=>'1');
            portb_reg<=(others=>'0'); trisb_reg<=(others=>'1');
            portc_reg<=(others=>'0'); trisc_reg<=(others=>'1');
            portd_reg<=(others=>'0'); trisd_reg<=(others=>'1');
            tmr0_reg<=(others=>'0'); tmr1l_reg<=(others=>'0'); tmr1h_reg<=(others=>'0');
            tmr2_reg<=(others=>'0'); pr2_reg<=(others=>'0');
            t1con_reg<=(others=>'0'); t2con_reg<=(others=>'0');
            intcon_reg<=(others=>'0'); pir1_reg<=(others=>'0'); option_reg<=(others=>'1');
            adcon0_reg<=(others=>'0'); adcon1_reg<=(others=>'0');
            adresh_reg<=(others=>'0'); adresl_reg<=(others=>'0');
            txsta_reg<=(others=>'0'); rcsta_reg<=(others=>'0'); spbrg_reg<=(others=>'0');
            txreg_reg<=(others=>'0'); rcreg_reg<=(others=>'0'); usart_tx_busy<='0'; usart_rx_busy<='0';
        elsif rising_edge(clk) then
            -- ---- CPU register writes ----
            if we = '1' then
                case addr is
                    -- Port latches (bank 0)
                    when A_PORTA  => porta_reg <= din;
                    when A_PORTB  => portb_reg <= din;
                    when A_PORTC  => portc_reg <= din;
                    when A_PORTD  => portd_reg <= din;
                    -- TRIS direction registers (bank 1)
                    when A_TRISA  => trisa_reg <= din;
                    when A_TRISB  => trisb_reg <= din;
                    when A_TRISC  => trisc_reg <= din;
                    when A_TRISD  => trisd_reg <= din;
                    -- Timer registers
                    when A_TMR0   => tmr0_reg <= unsigned(din);
                    when A_TMR1L  => tmr1l_reg <= unsigned(din);
                    when A_TMR1H  => tmr1h_reg <= unsigned(din);
                    when A_T1CON  => t1con_reg <= din;
                    when A_TMR2   => tmr2_reg <= unsigned(din);
                    when A_PR2    => pr2_reg <= unsigned(din);
                    when A_T2CON  => t2con_reg <= din;
                    -- Control / status registers
                    when A_INTCON => intcon_reg <= din;
                    when A_OPTION => option_reg <= din;
                    when A_PIR1   =>
                        -- Writing '1' to PIR1 flags clears them (PIC convention)
                        if din(4)='1' then pir1_reg(4)<='0'; end if; -- TXIF
                        if din(5)='1' then pir1_reg(5)<='0'; end if; -- RCIF
                    -- ADC registers
                    when A_ADCON0 => adcon0_reg <= din;
                    when A_ADCON1 => adcon1_reg <= din;
                    -- USART registers
                    when A_TXSTA  => txsta_reg <= din;
                    when A_RCSTA  => rcsta_reg <= din;
                    when A_SPBRG  => spbrg_reg <= din;
                    -- TXREG write: load TX data if transmitter idle
                    when A_TXREG  =>
                        if usart_tx_busy = '0' then
                            txreg_reg <= din; usart_tx_busy <= '1';
                            usart_tx_bit <= 0; pir1_reg(4) <= '0'; -- clear TXIF
                        end if;
                    when others => null;
                end case;
            end if;

            -- ---- Timer0: 8-bit with prescaler, overflow sets T0IF ----
            -- OPTION_REG bit5=T0CS (0=internal clock), bit3=PSA (0=prescaler to T0)
            -- Prescaler: bits2:0 => /2,/4,/8,/16,/32,/64,/128,/256
            -- Simplified: prescaler value = 2^(PS+1), compare t0_psc to threshold
            if option_reg(5) = '0' then  -- internal clock source
                -- Compute prescaler threshold from OPTION_REG bits2:0
                -- PS=000->1, 001->1, 010->3, 011->7, 100->15, 101->31, 110->63, 111->127
                if (option_reg(2 downto 0)="000" and t0_psc>=0) or
                   (option_reg(2 downto 0)="001" and t0_psc>=1) or
                   (option_reg(2 downto 0)="010" and t0_psc>=3) or
                   (option_reg(2 downto 0)="011" and t0_psc>=7) or
                   (option_reg(2 downto 0)="100" and t0_psc>=15) or
                   (option_reg(2 downto 0)="101" and t0_psc>=31) or
                   (option_reg(2 downto 0)="110" and t0_psc>=63) or
                   (option_reg(2 downto 0)="111" and t0_psc>=127) then
                    t0_psc <= 0;
                    if tmr0_reg = x"FF" then
                        tmr0_reg <= (others => '0');
                        intcon_reg(2) <= '1';  -- set T0IF
                    else
                        tmr0_reg <= tmr0_reg + 1;
                    end if;
                else
                    t0_psc <= t0_psc + 1;
                end if;
            end if;

            -- ---- Timer1: 16-bit with prescaler, overflow sets TMR1IF ----
            -- T1CON bit0=TMR1ON, bits5:4=T1CKPS (00=/1,01=/2,10=/4,11=/8)
            if t1con_reg(0) = '1' then
                -- Prescaler threshold: 00->0, 01->1, 10->3, 11->7
                if (t1con_reg(5 downto 4)="00" and t1_psc>=0) or
                   (t1con_reg(5 downto 4)="01" and t1_psc>=1) or
                   (t1con_reg(5 downto 4)="10" and t1_psc>=3) or
                   (t1con_reg(5 downto 4)="11" and t1_psc>=7) then
                    t1_psc <= 0;
                    if tmr1l_reg = x"FF" then
                        if tmr1h_reg = x"FF" then
                            tmr1l_reg<=(others=>'0'); tmr1h_reg<=(others=>'0');
                            pir1_reg(0) <= '1';  -- TMR1IF
                        else
                            tmr1l_reg <= (others => '0');
                            tmr1h_reg <= tmr1h_reg + 1;
                        end if;
                    else
                        tmr1l_reg <= tmr1l_reg + 1;
                    end if;
                else
                    t1_psc <= t1_psc + 1;
                end if;
            end if;

            -- ---- Timer2: 8-bit with PR2 period, postscaler, match sets TMR2IF ----
            -- T2CON bit2=TMR2ON, bits1:0=T2CKPS (00=/1,01=/4,1x=/16)
            -- bits6:3=TOUTPS (postscaler 1-16)
            if t2con_reg(2) = '1' then
                -- Prescaler: 00->0, 01->3, 1x->15
                if (t2con_reg(1 downto 0)="00" and t2_psc>=0) or
                   (t2con_reg(1 downto 0)="01" and t2_psc>=3) or
                   (t2con_reg(1)='1' and t2_psc>=15) then
                    t2_psc <= 0;
                    if tmr2_reg = pr2_reg then
                        tmr2_reg <= (others => '0');
                        -- Postscaler: when count reached, set TMR2IF
                        if t2_postsc >= to_integer(unsigned(t2con_reg(6 downto 3))) then
                            t2_postsc <= 0;
                            pir1_reg(1) <= '1';  -- TMR2IF
                        else
                            t2_postsc <= t2_postsc + 1;
                        end if;
                    else
                        tmr2_reg <= tmr2_reg + 1;
                    end if;
                else
                    t2_psc <= t2_psc + 1;
                end if;
            end if;

            -- ---- ADC: GO/DONE bit in ADCON0 bit2 starts conversion ----
            if adcon0_reg(2) = '1' then  -- GO/DONE
                -- Store 10-bit result (left-justified by default)
                adresh_reg <= adc_in(9 downto 2);      -- upper 8 bits
                adresl_reg <= "000000" & adc_in(1 downto 0); -- lower 2 bits
                adcon0_reg(2) <= '0';  -- clear GO/DONE (conversion done)
                pir1_reg(6) <= '1';    -- set ADIF
            end if;

            -- ---- External interrupt (RB0/INT) edge detection ----
            -- OPTION_REG bit6=INTEDG (1=rising, 0=falling)
            if intcon_reg(4) = '1' then  -- INTE enabled
                if option_reg(6) = '1' then  -- rising edge
                    if ext_int='1' and ext_int_prev='0' then intcon_reg(1)<='1'; end if;
                else  -- falling edge
                    if ext_int='0' and ext_int_prev='1' then intcon_reg(1)<='1'; end if;
                end if;
            end if;
            ext_int_prev <= ext_int;

            -- ---- USART TX: start(0), 8 data (LSB first), stop(1) ----
            if usart_tx_busy = '1' then
                if usart_baud_cnt >= to_integer(unsigned(spbrg_reg)) then
                    usart_baud_cnt <= 0;
                    if usart_tx_bit = 9 then
                        usart_tx_busy <= '0';
                        pir1_reg(4) <= '1';  -- set TXIF
                    else
                        usart_tx_bit <= usart_tx_bit + 1;
                    end if;
                else
                    usart_baud_cnt <= usart_baud_cnt + 1;
                end if;
            end if;
            -- ---- USART RX: detect start, sample 8 bits, check stop ----
            if usart_rxd='0' and usart_rx_busy='0' and rcsta_reg(7)='1' then
                usart_rx_busy<='1'; usart_rx_bit<=0; usart_rx_shift<=(others=>'0');
            elsif usart_rx_busy='1' then
                if usart_baud_cnt >= to_integer(unsigned(spbrg_reg)) then
                    usart_baud_cnt <= 0;
                    if usart_rx_bit = 8 then
                        usart_rx_busy <= '0';
                        rcreg_reg <= usart_rx_shift;
                        pir1_reg(5) <= '1';  -- set RCIF
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
        end if;
    end process;

    -- ==================================================================
    -- PROCESS: register_read -- combinational read mux
    -- Reading PORTx reads the physical pins, not the latch.
    -- ==================================================================
    process(re, addr, porta_in, portb_in, portc_in, portd_in,
            trisa_reg, trisb_reg, trisc_reg, trisd_reg,
            tmr0_reg, tmr1l_reg, tmr1h_reg, t1con_reg, tmr2_reg, pr2_reg, t2con_reg,
            intcon_reg, pir1_reg, option_reg,
            adcon0_reg, adcon1_reg, adresh_reg, adresl_reg,
            txsta_reg, rcsta_reg, spbrg_reg, txreg_reg, rcreg_reg,
            wdt_hrdata, rtc_hrdata, dac_hrdata)
    begin
        if re = '1' then
            if addr(8 downto 5) = "1000" then
                -- WDT register read (bank 2, 0x00-0x1F file range)
                dout <= wdt_hrdata(7 downto 0);
            elsif addr(8 downto 5) = "1001" then
                -- RTC register read (bank 2, 0x20-0x3F file range)
                dout <= rtc_hrdata(7 downto 0);
            elsif addr(8 downto 5) = "1010" then
                -- DAC register read (bank 2, 0x40-0x5F file range)
                dout <= dac_hrdata(7 downto 0);
            else
            case addr is
                when A_PORTA  => dout <= porta_in;  -- read physical pins
                when A_PORTB  => dout <= portb_in;
                when A_PORTC  => dout <= portc_in;
                when A_PORTD  => dout <= portd_in;
                when A_TRISA  => dout <= trisa_reg;  when A_TRISB => dout <= trisb_reg;
                when A_TRISC  => dout <= trisc_reg;  when A_TRISD => dout <= trisd_reg;
                when A_TMR0   => dout <= std_logic_vector(tmr0_reg);
                when A_TMR1L  => dout <= std_logic_vector(tmr1l_reg);
                when A_TMR1H  => dout <= std_logic_vector(tmr1h_reg);
                when A_T1CON  => dout <= t1con_reg;
                when A_TMR2   => dout <= std_logic_vector(tmr2_reg);
                when A_PR2    => dout <= std_logic_vector(pr2_reg);
                when A_T2CON  => dout <= t2con_reg;
                when A_INTCON => dout <= intcon_reg; when A_OPTION => dout <= option_reg;
                when A_PIR1   => dout <= pir1_reg;
                when A_ADCON0 => dout <= adcon0_reg; when A_ADCON1 => dout <= adcon1_reg;
                when A_ADRESH => dout <= adresh_reg; when A_ADRESL => dout <= adresl_reg;
                when A_TXSTA  => dout <= txsta_reg;  when A_RCSTA => dout <= rcsta_reg;
                when A_TXREG  => dout <= txreg_reg;
                when A_RCREG  => dout <= rcreg_reg;  -- 0x1A shared with SPBRG: read returns RX data
                when others   => dout <= (others => '0');
            end case;
            end if;
        else
            dout <= (others => '0');
        end if;
    end process;

    -- ==================================================================
    -- WDT Controller: AHB-Lite bridge and instantiation
    -- ==================================================================

    -- WDT address region: bank 2, file 0x00-0x1F (addr[8:5] = "1000")
    wdt_sel <= '1' when addr(8 downto 5) = "1000" else '0';

    -- PIC-to-AHB bridge for WDT controller
    wdt_hsel   <= wdt_sel and (we or re);
    wdt_hwrite <= we;
    wdt_hready <= '1';
    wdt_htrans <= "10" when (wdt_sel = '1' and (we = '1' or re = '1')) else "00";
    wdt_hsize  <= "001";  -- 8-bit transfer
    wdt_haddr  <= std_logic_vector(resize(unsigned(addr), 32));
    wdt_hwdata <= x"000000" & din;

    wdt_inst : wdt_controller
        port map (
            HCLK       => clk,
            HRESETn    => not reset,
            HSEL       => wdt_hsel,
            HWRITE     => wdt_hwrite,
            HREADY     => wdt_hready,
            HTRANS     => wdt_htrans,
            HADDR      => wdt_haddr,
            HWDATA     => wdt_hwdata,
            HRDATA     => wdt_hrdata,
            HRESP      => wdt_hresp,
            HREADYOUT  => wdt_hreadyout,
            wdt_int    => wdt_int,
            wdt_reset  => wdt_reset
        );

    -- ==================================================================
    -- RTC Controller: AHB-Lite bridge and instantiation
    -- ==================================================================

    -- RTC address region: bank 2, file 0x20-0x3F (addr[8:5] = "1001")
    rtc_sel <= '1' when addr(8 downto 5) = "1001" else '0';

    -- PIC-to-AHB bridge for RTC controller
    rtc_hsel   <= rtc_sel and (we or re);
    rtc_hwrite <= we;
    rtc_hready <= '1';
    rtc_htrans <= "10" when (rtc_sel = '1' and (we = '1' or re = '1')) else "00";
    rtc_hsize  <= "001";  -- 8-bit transfer
    rtc_haddr  <= std_logic_vector(resize(unsigned(addr), 32));
    rtc_hwdata <= x"000000" & din;

    rtc_inst : rtc_controller
        port map (
            HCLK       => clk,
            HRESETn    => not reset,
            HSEL       => rtc_hsel,
            HWRITE     => rtc_hwrite,
            HREADY     => rtc_hready,
            HTRANS     => rtc_htrans,
            HADDR      => rtc_haddr,
            HWDATA     => rtc_hwdata,
            HRDATA     => rtc_hrdata,
            HRESP      => rtc_hresp,
            HREADYOUT  => rtc_hreadyout,
            rtc_int    => rtc_int
        );

    -- ==================================================================
    -- DAC Controller: AHB-Lite bridge and instantiation
    -- ==================================================================

    -- DAC address region: bank 2, file 0x40-0x5F (addr[8:5] = "1010")
    dac_sel <= '1' when addr(8 downto 5) = "1010" else '0';

    -- PIC-to-AHB bridge for DAC controller
    dac_hsel   <= dac_sel and (we or re);
    dac_hwrite <= we;
    dac_hready <= '1';
    dac_htrans <= "10" when (dac_sel = '1' and (we = '1' or re = '1')) else "00";
    dac_hsize  <= "001";  -- 8-bit transfer
    dac_haddr  <= std_logic_vector(resize(unsigned(addr), 32));
    dac_hwdata <= x"000000" & din;

    dac_inst : dac_controller
        port map (
            HCLK       => clk,
            HRESETn    => not reset,
            HSEL       => dac_hsel,
            HWRITE     => dac_hwrite,
            HREADY     => dac_hready,
            HTRANS     => dac_htrans,
            HADDR      => dac_haddr,
            HWDATA     => dac_hwdata,
            HRDATA     => dac_hrdata,
            HRESP      => dac_hresp,
            HREADYOUT  => dac_hreadyout,
            dac_out    => dac_out
        );

    -- ==================================================================
    -- OUTPUT ASSIGNMENTS
    -- Write-through: during a write cycle the output immediately reflects
    -- the value on the data bus so external logic (and testbenches) can
    -- observe it without waiting for the registered signal to propagate
    -- through delta cycles.  After the write the output follows the
    -- registered latch value.
    -- ==================================================================
    porta_out <= din when (we='1' and addr=A_PORTA) else porta_reg;
    trisa_out <= din when (we='1' and addr=A_TRISA) else trisa_reg;
    portb_out <= din when (we='1' and addr=A_PORTB) else portb_reg;
    trisb_out <= din when (we='1' and addr=A_TRISB) else trisb_reg;
    portc_out <= din when (we='1' and addr=A_PORTC) else portc_reg;
    trisc_out <= din when (we='1' and addr=A_TRISC) else trisc_reg;
    portd_out <= din when (we='1' and addr=A_PORTD) else portd_reg;
    trisd_out <= din when (we='1' and addr=A_TRISD) else trisd_reg;
    -- Timer interrupts: flag AND enable AND GIE
    t0_int <= intcon_reg(2) and intcon_reg(5) and intcon_reg(7); -- T0IF AND T0IE AND GIE
    t1_int <= pir1_reg(0) and intcon_reg(7);  -- TMR1IF AND GIE
    t2_int <= pir1_reg(1) and intcon_reg(7);  -- TMR2IF AND GIE
    -- ADC interrupt: ADIF (PIR1 bit6) AND GIE
    adc_int <= pir1_reg(6) and intcon_reg(7);
    -- USART TX line: start(0), data(8), stop(1), idle high
    usart_txd <= '0' when (usart_tx_busy='1' and usart_tx_bit=0)
        else txreg_reg(usart_tx_bit-1)
             when (usart_tx_busy='1' and usart_tx_bit>=1 and usart_tx_bit<=8)
        else '1';
    -- USART interrupts: TXIF AND TXIE(PIE1 bit4 simplified), RCIF AND RCIE
    usart_tx_int <= pir1_reg(4) and intcon_reg(7);
    usart_rx_int <= pir1_reg(5) and intcon_reg(7);

    -- External interrupt: INTF AND INTE AND GIE
    ext_int_out <= intcon_reg(1) and intcon_reg(4) and intcon_reg(7);
    -- Global interrupt enable = INTCON bit7 (write-through during INTCON write)
    gie_out <= din(7) when (we='1' and addr=A_INTCON) else intcon_reg(7);

end architecture rtl;

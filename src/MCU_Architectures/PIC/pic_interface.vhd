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
        gie_out     : out std_logic
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

begin

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
            txsta_reg, rcsta_reg, spbrg_reg, txreg_reg, rcreg_reg)
    begin
        if re = '1' then
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
                when A_SPBRG  => dout <= spbrg_reg;  when A_TXREG => dout <= txreg_reg;
                when A_RCREG  => dout <= rcreg_reg;  -- read received data
                when others   => dout <= (others => '0');
            end case;
        else
            dout <= (others => '0');
        end if;
    end process;

    -- ==================================================================
    -- OUTPUT ASSIGNMENTS
    -- ==================================================================
    porta_out <= porta_reg; trisa_out <= trisa_reg;
    portb_out <= portb_reg; trisb_out <= trisb_reg;
    portc_out <= portc_reg; trisc_out <= trisc_reg;
    portd_out <= portd_reg; trisd_out <= trisd_reg;
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
    -- Global interrupt enable = INTCON bit7
    gie_out <= intcon_reg(7);

end architecture rtl;

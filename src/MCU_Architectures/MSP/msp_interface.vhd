-- ================================================================================
-- msp_interface : MSP430-style 16-bit peripheral bus interface model
-- Educational bus interface model -- not a full MSP430 CPU core.  Target: Cyclone III.
--
-- Models MSP430 peripherals: Port 1/2 with full interrupt support, Timer_A
-- (16-bit with CCR0/CCR1), ADC12, Watchdog Timer, Status Register (LPM),
-- and DMA controller (MSP430FR5xx/6xx style).
--
-- Peripheral Summary:
--   [Y] Port 1/2 with interrupt support
--   [Y] Timer_A (16-bit with CCR0/CCR1)
--   [Y] ADC12
--   [Y] Watchdog Timer
--   [Y] Status Register (LPM)
--   [Y] DMA controller (4-channel, bus master)
--
-- REGISTER MAP (9-bit addr, 16-bit data):
-- 0x020 P1IN   0x021 P1OUT  0x022 P1DIR  0x023 P1IFG  0x024 P1IES
-- 0x025 P1IE   0x026 P1SEL  0x027 P1REN
-- 0x028 P2IN   0x029 P2OUT  0x02A P2DIR  0x02B P2IFG  0x02C P2IES
-- 0x02D P2IE   0x02E P2SEL  0x02F P2REN
-- 0x060 TACTL  0x062 TAR    0x064 TACCR0 0x066 TACCR1 0x068 TAIFG/TACCTL0
-- 0x080 ADC12CTL0 0x082 ADC12CTL1 0x090 ADC12MEM0 0x092 ADC12IFG
-- 0x120 WDTCTL 0x122 WDTIFG
-- 0x002 SR (Status Register: CPUOFF/SCG0/SCG1/OSCOFF/GIE/N/Z/C)
-- 0x180-0x1FF DMA controller registers (mapped to DMA IP via AHB bridge)
--   DMA uses HADDR[7:4] for channel index, HADDR[3:2] for sub-register
--   Global DMA regs at offset 0x40-0x48
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity msp_interface is
    port (
        clk, reset  : in  std_logic;
        -- 16-bit data bus, 9-bit address (MSP430 peripherals are 16-bit)
        addr        : in  std_logic_vector(8 downto 0);
        din         : in  std_logic_vector(15 downto 0);
        dout        : out std_logic_vector(15 downto 0);
        we, re      : in  std_logic;
        -- Port 1
        p1out       : out std_logic_vector(7 downto 0);
        p1dir       : out std_logic_vector(7 downto 0);
        p1ren       : out std_logic_vector(7 downto 0);  -- pull resistor enable
        p1sel       : out std_logic_vector(7 downto 0);  -- function select
        p1in        : in  std_logic_vector(7 downto 0);
        p1int       : out std_logic;  -- Port 1 interrupt
        -- Port 2
        p2out       : out std_logic_vector(7 downto 0);
        p2dir       : out std_logic_vector(7 downto 0);
        p2ren       : out std_logic_vector(7 downto 0);
        p2sel       : out std_logic_vector(7 downto 0);
        p2in        : in  std_logic_vector(7 downto 0);
        p2int       : out std_logic;
        -- Timer_A
        ta_out      : out std_logic;  -- Timer_A output (TAR MSB toggle)
        ta_int      : out std_logic;  -- Timer_A interrupt
        -- ADC12
        adc_in      : in  std_logic_vector(11 downto 0);  -- 12-bit ADC
        adc_int     : out std_logic;
        -- Watchdog
        wdt_int     : out std_logic;  -- watchdog interrupt/reset
        -- Low-power mode
        lpm_out     : out std_logic_vector(2 downto 0);  -- LPM mode indicator

        -- DMA controller interface (MSP430FR5xx/6xx style)
        dma_int     : out std_logic;
        dma_m_addr  : out std_logic_vector(15 downto 0);
        dma_m_rdata : in  std_logic_vector(15 downto 0);
        dma_m_wdata : out std_logic_vector(15 downto 0);
        dma_m_we    : out std_logic;
        dma_m_req   : out std_logic;
        dma_m_ack   : in  std_logic;

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

        -- Real-Time Clock (RTC)
        rtc_int   : out std_logic;

        -- DAC (2-channel, 12-bit = 24 bits)
        dac_out   : out std_logic_vector(23 downto 0)
    );
end entity msp_interface;

architecture rtl of msp_interface is
    -- Register address constants (9-bit)
    constant A_P1IN   : std_logic_vector(8 downto 0) := "000100000"; -- 0x020
    constant A_P1OUT  : std_logic_vector(8 downto 0) := "000100001"; -- 0x021
    constant A_P1DIR  : std_logic_vector(8 downto 0) := "000100010"; -- 0x022
    constant A_P1IFG  : std_logic_vector(8 downto 0) := "000100011"; -- 0x023
    constant A_P1IES  : std_logic_vector(8 downto 0) := "000100100"; -- 0x024
    constant A_P1IE   : std_logic_vector(8 downto 0) := "000100101"; -- 0x025
    constant A_P1SEL  : std_logic_vector(8 downto 0) := "000100110"; -- 0x026
    constant A_P1REN  : std_logic_vector(8 downto 0) := "000100111"; -- 0x027
    constant A_P2IN   : std_logic_vector(8 downto 0) := "000101000"; -- 0x028
    constant A_P2OUT  : std_logic_vector(8 downto 0) := "000101001"; -- 0x029
    constant A_P2DIR  : std_logic_vector(8 downto 0) := "000101010"; -- 0x02A
    constant A_P2IFG  : std_logic_vector(8 downto 0) := "000101011"; -- 0x02B
    constant A_P2IES  : std_logic_vector(8 downto 0) := "000101100"; -- 0x02C
    constant A_P2IE   : std_logic_vector(8 downto 0) := "000101101"; -- 0x02D
    constant A_P2SEL  : std_logic_vector(8 downto 0) := "000101110"; -- 0x02E
    constant A_P2REN  : std_logic_vector(8 downto 0) := "000101111"; -- 0x02F
    constant A_TACTL  : std_logic_vector(8 downto 0) := "000110000"; -- 0x060
    constant A_TAR    : std_logic_vector(8 downto 0) := "000110010"; -- 0x062
    constant A_TACCR0 : std_logic_vector(8 downto 0) := "000110100"; -- 0x064
    constant A_TACCR1 : std_logic_vector(8 downto 0) := "000110110"; -- 0x066
    constant A_ADC12CTL0:std_logic_vector(8 downto 0) := "001000000"; -- 0x080
    constant A_ADC12CTL1:std_logic_vector(8 downto 0) := "001000010"; -- 0x082
    constant A_ADC12MEM0: std_logic_vector(8 downto 0) := "001010000"; -- 0x090
    constant A_ADC12IFG: std_logic_vector(8 downto 0) := "001010010"; -- 0x092
    constant A_WDTCTL : std_logic_vector(8 downto 0) := "010010000"; -- 0x120
    constant A_SR     : std_logic_vector(8 downto 0) := "000000010"; -- 0x002

    -- Port 1 registers
    signal p1out_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal p1dir_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal p1ren_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal p1sel_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal p1ifg_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal p1ies_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal p1ie_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal p1in_prev : std_logic_vector(7 downto 0) := (others => '0');

    -- Port 2 registers
    signal p2out_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal p2dir_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal p2ren_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal p2sel_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal p2ifg_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal p2ies_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal p2ie_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal p2in_prev : std_logic_vector(7 downto 0) := (others => '0');

    -- Timer_A: 16-bit counter, control, CCR0/CCR1, prescaler
    signal tar_reg    : unsigned(15 downto 0) := (others => '0');
    signal tactl_reg  : std_logic_vector(15 downto 0) := (others => '0');
    signal taccr0_reg : unsigned(15 downto 0) := (others => '0');
    signal taccr1_reg : unsigned(15 downto 0) := (others => '0');
    signal ta_ifg     : std_logic := '0';  -- Timer_A interrupt flag

    -- ADC12: control, memory, interrupt flag
    signal adc12ctl0_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal adc12ctl1_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal adc12mem0_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal adc12ifg_reg  : std_logic := '0';

    -- Watchdog: control, down-counter, interrupt flag
    signal wdtctl_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal wdt_cnt    : unsigned(15 downto 0) := (others => '0');
    signal wdt_ifg    : std_logic := '0';

    -- Status Register: bits [CPUOFF,SCG0,SCG1,OSCOFF,GIE,N,Z,C]
    signal sr_reg : std_logic_vector(15 downto 0) := (others => '0');

    -- ========================================================================
    -- DMA controller signals (AHB-Lite bridge)
    -- ========================================================================
    -- DMA address region: 0x180-0x1FF (addr[8:7] = "11")
    signal dma_sel : std_logic;

    -- AHB-Lite signals for DMA controller
    signal dma_hsel      : std_logic;
    signal dma_hwrite    : std_logic;
    signal dma_hready    : std_logic;
    signal dma_htrans    : std_logic_vector(1 downto 0);
    signal dma_hsize     : std_logic_vector(2 downto 0);
    signal dma_haddr     : std_logic_vector(31 downto 0);
    signal dma_hwdata    : std_logic_vector(31 downto 0);
    signal dma_hrdata    : std_logic_vector(31 downto 0);
    signal dma_hresp     : std_logic;
    signal dma_hreadyout : std_logic;

    -- DMA interrupt vector (4 channels) and external request inputs
    signal dma_int_vec   : std_logic_vector(3 downto 0);
    signal dma_req_in    : std_logic_vector(3 downto 0);

    -- DMA master interface (32-bit internal, lower 16 bits exported)
    signal dma_m_addr_i  : std_logic_vector(31 downto 0);
    signal dma_m_wdata_i : std_logic_vector(31 downto 0);

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
    -- Component declarations for RTC and DAC controllers
    -- ========================================================================
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
    -- PROCESS: register_write -- all register writes + peripheral logic
    -- ==================================================================
    process(clk, reset)
    begin
        if reset = '1' then
            -- Active-high reset: clear all registers
            p1out_reg<=(others=>'0'); p1dir_reg<=(others=>'0'); p1ren_reg<=(others=>'0');
            p1sel_reg<=(others=>'0'); p1ifg_reg<=(others=>'0'); p1ies_reg<=(others=>'0');
            p1ie_reg <=(others=>'0'); p1in_prev<=(others=>'0');
            p2out_reg<=(others=>'0'); p2dir_reg<=(others=>'0'); p2ren_reg<=(others=>'0');
            p2sel_reg<=(others=>'0'); p2ifg_reg<=(others=>'0'); p2ies_reg<=(others=>'0');
            p2ie_reg <=(others=>'0'); p2in_prev<=(others=>'0');
            tar_reg<=(others=>'0'); tactl_reg<=(others=>'0');
            taccr0_reg<=(others=>'0'); taccr1_reg<=(others=>'0');
            ta_ifg<='0';
            adc12ctl0_reg<=(others=>'0'); adc12ctl1_reg<=(others=>'0');
            adc12mem0_reg<=(others=>'0'); adc12ifg_reg<='0';
            wdtctl_reg<=(others=>'0'); wdt_cnt<=(others=>'0'); wdt_ifg<='0';
            sr_reg<=(others=>'0');
        elsif rising_edge(clk) then
            -- ---- CPU register writes ----
            if we = '1' then
                case addr is
                    when A_P1OUT  => p1out_reg <= din(7 downto 0);
                    when A_P1DIR  => p1dir_reg <= din(7 downto 0);
                    when A_P1REN  => p1ren_reg <= din(7 downto 0);
                    when A_P1SEL  => p1sel_reg <= din(7 downto 0);
                    when A_P1IES  => p1ies_reg <= din(7 downto 0);
                    when A_P1IE   => p1ie_reg  <= din(7 downto 0);
                    -- P1IFG: writing '1' clears flag (MSP430 convention)
                    when A_P1IFG  =>
                        for i in 0 to 7 loop
                            if din(i)='1' then p1ifg_reg(i)<='0'; end if;
                        end loop;
                    when A_P2OUT  => p2out_reg <= din(7 downto 0);
                    when A_P2DIR  => p2dir_reg <= din(7 downto 0);
                    when A_P2REN  => p2ren_reg <= din(7 downto 0);
                    when A_P2SEL  => p2sel_reg <= din(7 downto 0);
                    when A_P2IES  => p2ies_reg <= din(7 downto 0);
                    when A_P2IE   => p2ie_reg  <= din(7 downto 0);
                    when A_P2IFG  =>
                        for i in 0 to 7 loop
                            if din(i)='1' then p2ifg_reg(i)<='0'; end if;
                        end loop;
                    when A_TACTL  => tactl_reg <= din;
                    when A_TAR    => tar_reg <= unsigned(din);
                    when A_TACCR0 => taccr0_reg <= unsigned(din);
                    when A_TACCR1 => taccr1_reg <= unsigned(din);
                    when A_ADC12CTL0 => adc12ctl0_reg <= din;
                    when A_ADC12CTL1 => adc12ctl1_reg <= din;
                    when A_WDTCTL => wdtctl_reg <= din; wdt_cnt <= (others=>'0');
                    when A_SR     => sr_reg <= din;
                    when others => null;
                end case;
            end if;

            -- ---- Port 1 interrupt edge detection ----
            -- P1IES: '0'=rising edge, '1'=falling edge triggers interrupt
            for i in 0 to 7 loop
                if p1ie_reg(i) = '1' then
                    if p1ies_reg(i) = '0' then  -- rising edge
                        if p1in(i)='1' and p1in_prev(i)='0' then p1ifg_reg(i)<='1'; end if;
                    else  -- falling edge
                        if p1in(i)='0' and p1in_prev(i)='1' then p1ifg_reg(i)<='1'; end if;
                    end if;
                end if;
            end loop;
            p1in_prev <= p1in;

            -- ---- Port 2 interrupt edge detection ----
            for i in 0 to 7 loop
                if p2ie_reg(i) = '1' then
                    if p2ies_reg(i) = '0' then
                        if p2in(i)='1' and p2in_prev(i)='0' then p2ifg_reg(i)<='1'; end if;
                    else
                        if p2in(i)='0' and p2in_prev(i)='1' then p2ifg_reg(i)<='1'; end if;
                    end if;
                end if;
            end loop;
            p2in_prev <= p2in;

            -- ---- Timer_A: 16-bit up/continuous mode ----
            -- TACTL bit4=MC0, bit5=MC1 (mode control): 01=up, 10=continuous, 11=up/down
            -- Input divider: TACTL bits 7:6 (ID0:ID1): 00=/1, 01=/2, 10=/4, 11=/8
            -- Simplified: prescaler not implemented (always /1)
            if tactl_reg(4) = '1' or tactl_reg(5) = '1' then
                -- Mode 01 (up): count to TACCR0, then reset
                -- Mode 10 (continuous): count to 0xFFFF, then reset
                if tactl_reg(5 downto 4) = "01" then  -- up mode
                        if tar_reg = taccr0_reg then
                            tar_reg <= (others => '0');
                            ta_ifg <= '1';  -- set interrupt flag
                        else
                            tar_reg <= tar_reg + 1;
                        end if;
                    elsif tactl_reg(5 downto 4) = "10" then  -- continuous mode
                        if tar_reg = x"FFFF" then
                            tar_reg <= (others => '0');
                            ta_ifg <= '1';
                        else
                            tar_reg <= tar_reg + 1;
                        end if;
                    end if;
                    -- CCR1 compare match flag (simplified)
                    if tar_reg = taccr1_reg then
                        ta_ifg <= '1';
                    end if;
            end if;
            -- Clear TAIFG when CPU writes to TACTL with bit0='1'
            if we='1' and addr=A_TACTL and din(0)='1' then ta_ifg<='0'; end if;

            -- ---- ADC12: start conversion when ENC+SC set ----
            -- ADC12CTL0 bit4=ENC (enable), bit1=SC (start conversion)
            if adc12ctl0_reg(4)='1' and adc12ctl0_reg(1)='1' then
                adc12mem0_reg <= x"0" & adc_in;  -- store 12-bit result (left-justified)
                adc12ifg_reg <= '1';  -- set conversion complete flag
                adc12ctl0_reg(1) <= '0';  -- clear SC
            end if;
            -- Clear ADC12IFG on read or write '1'
            if we='1' and addr=A_ADC12IFG then adc12ifg_reg<='0'; end if;

            -- ---- Watchdog Timer: down-counter with interval ----
            -- WDTCTL bit5=TMSEL (0=watchdog, 1=timer), bits4:3=IS (interval)
            -- IS: 00=/32768, 01=/8192, 10=/512, 11=/64 (simplified)
            if wdtctl_reg(5) = '0' then  -- watchdog mode
                -- Count down; on underflow, set flag (reset in real HW)
                if wdt_cnt = 0 then
                    wdt_cnt <= x"FFFF";
                    wdt_ifg <= '1';
                else
                    wdt_cnt <= wdt_cnt - 1;
                end if;
            else  -- interval timer mode
                if wdt_cnt = 0 then
                    wdt_cnt <= x"FFFF";
                    wdt_ifg <= '1';
                else
                    wdt_cnt <= wdt_cnt - 1;
                end if;
            end if;
            -- Writing to WDTCTL clears WDTIFG and reloads counter
            if we='1' and addr=A_WDTCTL then wdt_ifg<='0'; wdt_cnt<=x"FFFF"; end if;
        end if;
    end process;

    -- ==================================================================
    -- PROCESS: register_read -- combinational read mux
    -- ==================================================================
    process(re, addr, p1in, p1out_reg, p1dir_reg, p1ren_reg, p1sel_reg,
            p1ifg_reg, p1ies_reg, p1ie_reg,
            p2in, p2out_reg, p2dir_reg, p2ren_reg, p2sel_reg,
            p2ifg_reg, p2ies_reg, p2ie_reg,
            tar_reg, tactl_reg, taccr0_reg, taccr1_reg, ta_ifg,
            adc12ctl0_reg, adc12ctl1_reg, adc12mem0_reg, adc12ifg_reg,
            wdtctl_reg, wdt_cnt, wdt_ifg, sr_reg, dma_hrdata,
            rtc_hrdata, dac_hrdata)
    begin
        if re = '1' then
            if addr(8 downto 7) = "11" then
                -- DMA register read (0x180-0x1FF region)
                dout <= dma_hrdata(15 downto 0);
            elsif addr(8 downto 5) = "01010" then
                -- RTC register read (0x140-0x15F region)
                dout <= rtc_hrdata(15 downto 0);
            elsif addr(8 downto 5) = "01011" then
                -- DAC register read (0x160-0x17F region)
                dout <= dac_hrdata(15 downto 0);
            else
                case addr is
                    when A_P1IN   => dout <= x"00" & p1in;
                    when A_P1OUT  => dout <= x"00" & p1out_reg;
                    when A_P1DIR  => dout <= x"00" & p1dir_reg;
                    when A_P1REN  => dout <= x"00" & p1ren_reg;
                    when A_P1SEL  => dout <= x"00" & p1sel_reg;
                    when A_P1IFG  => dout <= x"00" & p1ifg_reg;
                    when A_P1IES  => dout <= x"00" & p1ies_reg;
                    when A_P1IE   => dout <= x"00" & p1ie_reg;
                    when A_P2IN   => dout <= x"00" & p2in;
                    when A_P2OUT  => dout <= x"00" & p2out_reg;
                    when A_P2DIR  => dout <= x"00" & p2dir_reg;
                    when A_P2REN  => dout <= x"00" & p2ren_reg;
                    when A_P2SEL  => dout <= x"00" & p2sel_reg;
                    when A_P2IFG  => dout <= x"00" & p2ifg_reg;
                    when A_P2IES  => dout <= x"00" & p2ies_reg;
                    when A_P2IE   => dout <= x"00" & p2ie_reg;
                    when A_TAR    => dout <= std_logic_vector(tar_reg);
                    when A_TACTL  => dout <= tactl_reg;
                    when A_TACCR0 => dout <= std_logic_vector(taccr0_reg);
                    when A_TACCR1 => dout <= std_logic_vector(taccr1_reg);
                    when A_ADC12CTL0 => dout <= adc12ctl0_reg;
                    when A_ADC12CTL1 => dout <= adc12ctl1_reg;
                    when A_ADC12MEM0 => dout <= adc12mem0_reg;
                    when A_ADC12IFG  => dout <= x"000" & "000" & adc12ifg_reg;
                    when A_WDTCTL => dout <= wdtctl_reg;
                    when A_SR     => dout <= sr_reg;
                    when others   => dout <= (others => '0');
                end case;
            end if;
        else
            dout <= (others => '0');
        end if;
    end process;

    -- ==================================================================
    -- DMA Controller: AHB-Lite bridge and instantiation
    -- ==================================================================

    -- DMA address region: 0x180-0x1FF (addr[8:7] = "11")
    dma_sel <= '1' when addr(8 downto 7) = "11" else '0';

    -- MSP430-to-AHB bridge for DMA controller
    -- The MSP430 uses a simple register interface (we/re/addr/din/dout).
    -- We convert this to AHB-Lite signals for the DMA controller IP.
    dma_hsel   <= dma_sel and (we or re);
    dma_hwrite <= we;
    dma_hready <= '1';  -- CPU is always ready
    dma_htrans <= "10" when (dma_sel = '1' and (we = '1' or re = '1')) else "00";
    dma_hsize  <= "010";  -- 16-bit transfer
    dma_haddr  <= std_logic_vector(resize(unsigned(addr), 32));  -- zero-extend 9-bit address to 32-bit
    dma_hwdata <= x"0000" & din;     -- zero-extend 16-bit data to 32-bit

    -- External DMA request inputs (no peripheral-triggered requests)
    dma_req_in <= (others => '0');

    -- DMA controller instantiation (32-bit interface, lower 16 bits used)
    dma_inst : entity work.dma_controller
        generic map (
            NUM_CHANNELS => 4,
            DATA_WIDTH   => 32,
            ADDR_WIDTH   => 32
        )
        port map (
            HCLK       => clk,
            HRESETn    => not reset,
            HSEL       => dma_hsel,
            HWRITE     => dma_hwrite,
            HREADY     => dma_hready,
            HTRANS     => dma_htrans,
            HSIZE      => dma_hsize,
            HADDR      => dma_haddr,
            HWDATA     => dma_hwdata,
            HRDATA     => dma_hrdata,
            HRESP      => dma_hresp,
            HREADYOUT  => dma_hreadyout,
            m_addr     => dma_m_addr_i,
            m_rdata    => x"0000" & dma_m_rdata,  -- zero-extend 16-bit to 32-bit
            m_wdata    => dma_m_wdata_i,
            m_we       => dma_m_we,
            m_req      => dma_m_req,
            m_ack      => dma_m_ack,
            dma_int    => dma_int_vec,
            dma_req_in => dma_req_in
        );

    -- Export lower 16 bits of DMA master address and write data
    dma_m_addr  <= dma_m_addr_i(15 downto 0);
    dma_m_wdata <= dma_m_wdata_i(15 downto 0);

    -- OR all DMA channel interrupts into a single output
    dma_int <= dma_int_vec(0) or dma_int_vec(1) or
               dma_int_vec(2) or dma_int_vec(3);

    -- ==================================================================
    -- RTC Controller: AHB-Lite bridge and instantiation
    -- ==================================================================

    -- RTC address region: 0x140-0x15F (addr[8:5] = "01010")
    rtc_sel <= '1' when addr(8 downto 5) = "01010" else '0';

    -- MSP430-to-AHB bridge for RTC controller
    rtc_hsel   <= rtc_sel and (we or re);
    rtc_hwrite <= we;
    rtc_hready <= '1';
    rtc_htrans <= "10" when (rtc_sel = '1' and (we = '1' or re = '1')) else "00";
    rtc_hsize  <= "010";  -- 16-bit transfer
    rtc_haddr  <= std_logic_vector(resize(unsigned(addr), 32));
    rtc_hwdata <= x"0000" & din;

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

    -- DAC address region: 0x160-0x17F (addr[8:5] = "01011")
    dac_sel <= '1' when addr(8 downto 5) = "01011" else '0';

    -- MSP430-to-AHB bridge for DAC controller
    dac_hsel   <= dac_sel and (we or re);
    dac_hwrite <= we;
    dac_hready <= '1';
    dac_htrans <= "10" when (dac_sel = '1' and (we = '1' or re = '1')) else "00";
    dac_hsize  <= "010";  -- 16-bit transfer
    dac_haddr  <= std_logic_vector(resize(unsigned(addr), 32));
    dac_hwdata <= x"0000" & din;

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
    -- ==================================================================
    p1out <= din(7 downto 0) when (we='1' and addr=A_P1OUT) else p1out_reg;
    p1dir <= din(7 downto 0) when (we='1' and addr=A_P1DIR) else p1dir_reg;
    p1ren <= din(7 downto 0) when (we='1' and addr=A_P1REN) else p1ren_reg;
    p1sel <= p1sel_reg;
    p2out <= din(7 downto 0) when (we='1' and addr=A_P2OUT) else p2out_reg;
    p2dir <= din(7 downto 0) when (we='1' and addr=A_P2DIR) else p2dir_reg;
    p2ren <= p2ren_reg; p2sel <= p2sel_reg;

    -- Port interrupts: any IFG bit set AND corresponding IE bit AND GIE
    p1int <= '1' when (p1ifg_reg and p1ie_reg) /= "00000000" and sr_reg(3)='1' else '0';
    p2int <= '1' when (p2ifg_reg and p2ie_reg) /= "00000000" and sr_reg(3)='1' else '0';

    -- Timer_A interrupt: TAIFG AND GIE
    ta_int <= ta_ifg and sr_reg(3);
    -- Timer_A output: TAR MSB (simplified toggle indicator)
    ta_out <= tar_reg(15);

    -- ADC12 interrupt: ADC12IFG AND GIE
    adc_int <= adc12ifg_reg and sr_reg(3);

    -- Watchdog interrupt/reset: WDTIFG (always assert in watchdog mode)
    wdt_int <= wdt_ifg;

    -- Low-power mode: SR bits [CPUOFF(4), SCG0(5), SCG1(6), OSCOFF(7)]
    -- LPM0=CPUOFF, LPM1=CPUOFF+SCG0, LPM2=CPUOFF+SCG1, LPM3=CPUOFF+SCG0+SCG1, LPM4=+OSCOFF
    lpm_out <= sr_reg(7 downto 6) & sr_reg(4);  -- simplified 3-bit LPM indicator

end architecture rtl;

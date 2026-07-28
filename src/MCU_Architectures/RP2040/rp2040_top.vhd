-- ================================================================================
-- rp2040_top : Raspberry Pi RP2040 dual-core MCU implementation
-- ================================================================================
-- Implements the RP2040 architecture on Cyclone III FPGA:
--   * Dual Cortex-M0+ cores (core0 + core1)
--   * SIO (Single-cycle I/O) with inter-core FIFO, spinlocks, divider, interpolator
--   * 2x PIO blocks (4 state machines each = 8 total)
--   * 16-channel PWM controller
--   * QSPI XIP flash controller
--   * 2x UART, 2x SPI, 2x I2C
--   * USB 1.1 device controller
--   * 12-bit ADC (external)
--   * DMA controller (12 channels)
--   * WDT, RTC
--   * 30 GPIO pins
--
-- Memory map (RP2040-compatible):
--   0x00000000 - 0x000FFFFF : SRAM (mapped from FPGA block RAM / external)
--   0x10000000 - 0x1FFFFFFF : XIP flash (via QSPI)
--   0x40000000 - 0x40001FFF : SIO
--   0x40002000 - 0x40002FFF : PIO0
--   0x40003000 - 0x40003FFF : PIO1
--   0x40004000 - 0x40004FFF : PWM
--   0x40005000 - 0x40005FFF : QSPI XIP
--   0x40006000 - 0x40006FFF : USB
--   0x40007000 - 0x40007FFF : DMA
--   0x40008000 - 0x40008FFF : UART0
--   0x40009000 - 0x40009FFF : UART1
--   0x4000A000 - 0x4000AFFF : SPI0
--   0x4000B000 - 0x4000BFFF : SPI1
--   0x4000C000 - 0x4000CFFF : I2C0
--   0x4000D000 - 0x4000DFFF : I2C1
--   0x4000E000 - 0x4000EFFF : ADC
--   0x4000F000 - 0x4000FFFF : WDT / RTC
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rp2040_top is
    port (
        -- System
        CLK       : in  std_logic;          -- System clock (e.g., 12 MHz crystal)
        nRESET    : in  std_logic;          -- Active-low reset

        -- QSPI flash interface
        qspi_clk  : out std_logic;
        qspi_cs_n : out std_logic;
        qspi_dq   : inout std_logic_vector(3 downto 0);

        -- GPIO (30 pins as per RP2040)
        gpio      : inout std_logic_vector(29 downto 0);

        -- UART0 (primary console)
        uart0_tx  : out std_logic;
        uart0_rx  : in  std_logic;

        -- UART1
        uart1_tx  : out std_logic;
        uart1_rx  : in  std_logic;

        -- SPI0
        spi0_clk  : out std_logic;
        spi0_mosi : out std_logic;
        spi0_miso : in  std_logic;
        spi0_cs_n : out std_logic_vector(3 downto 0);

        -- SPI1
        spi1_clk  : out std_logic;
        spi1_mosi : out std_logic;
        spi1_miso : in  std_logic;
        spi1_cs_n : out std_logic_vector(3 downto 0);

        -- I2C0
        i2c0_sda  : inout std_logic;
        i2c0_scl  : inout std_logic;

        -- I2C1
        i2c1_sda  : inout std_logic;
        i2c1_scl  : inout std_logic;

        -- USB
        usb_dp    : inout std_logic;
        usb_dm    : inout std_logic;

        -- ADC input (4 channels, 12-bit each = 48 bits)
        adc_in    : in  std_logic_vector(47 downto 0) := (others => '0');

        -- SWD debug for core0
        swclk0    : in  std_logic;
        swdio0    : inout std_logic;

        -- SWD debug for core1
        swclk1    : in  std_logic;
        swdio1    : inout std_logic;

        -- Interrupt output (combined)
        irq_out   : out std_logic
    );
end entity rp2040_top;

architecture rtl of rp2040_top is

    -- ========================================================================
    -- Internal signals
    -- ========================================================================

    -- System
    signal HCLK      : std_logic := '0';
    signal HRESETn   : std_logic := '0';

    -- AHB-Lite bus (shared between both cores via arbiter)
    -- Core 0 AHB master
    signal c0_HSEL      : std_logic;
    signal c0_HWRITE    : std_logic;
    signal c0_HREADY    : std_logic;
    signal c0_HMASTLOCK : std_logic;
    signal c0_HTRANS    : std_logic_vector(1 downto 0);
    signal c0_HSIZE     : std_logic_vector(2 downto 0);
    signal c0_HPROT     : std_logic_vector(3 downto 0);
    signal c0_HADDR     : std_logic_vector(31 downto 0);
    signal c0_HWDATA    : std_logic_vector(31 downto 0);
    signal c0_HRDATA    : std_logic_vector(31 downto 0);
    signal c0_HRESP     : std_logic;
    signal c0_HREADYOUT : std_logic;

    -- Core 1 AHB master
    signal c1_HSEL      : std_logic;
    signal c1_HWRITE    : std_logic;
    signal c1_HREADY    : std_logic;
    signal c1_HMASTLOCK : std_logic;
    signal c1_HTRANS    : std_logic_vector(1 downto 0);
    signal c1_HSIZE     : std_logic_vector(2 downto 0);
    signal c1_HPROT     : std_logic_vector(3 downto 0);
    signal c1_HADDR     : std_logic_vector(31 downto 0);
    signal c1_HWDATA    : std_logic_vector(31 downto 0);
    signal c1_HRDATA    : std_logic_vector(31 downto 0);
    signal c1_HRESP     : std_logic;
    signal c1_HREADYOUT : std_logic;

    -- AHB arbiter (round-robin between core0 and core1)
    signal arb_sel      : std_logic := '0';  -- 0=core0, 1=core1
    signal arb_HSEL      : std_logic;
    signal arb_HWRITE    : std_logic;
    signal arb_HREADY    : std_logic;
    signal arb_HMASTLOCK : std_logic;
    signal arb_HTRANS    : std_logic_vector(1 downto 0);
    signal arb_HSIZE     : std_logic_vector(2 downto 0);
    signal arb_HPROT     : std_logic_vector(3 downto 0);
    signal arb_HADDR     : std_logic_vector(31 downto 0);
    signal arb_HWDATA    : std_logic_vector(31 downto 0);
    signal arb_HRDATA    : std_logic_vector(31 downto 0);
    signal arb_HRESP     : std_logic;
    signal arb_HREADYOUT : std_logic;

    -- Peripheral address decode
    signal periph_sel   : std_logic;
    signal sio_hsel     : std_logic;
    signal pio0_hsel    : std_logic;
    signal pio1_hsel    : std_logic;
    signal pwm_hsel     : std_logic;
    signal qspi_hsel    : std_logic;
    signal usb_hsel     : std_logic;
    signal dma_hsel     : std_logic;
    signal uart0_hsel   : std_logic;
    signal uart1_hsel   : std_logic;
    signal spi0_hsel    : std_logic;
    signal spi1_hsel    : std_logic;
    signal i2c0_hsel    : std_logic;
    signal i2c1_hsel    : std_logic;
    signal adc_hsel     : std_logic;
    signal wdt_hsel     : std_logic;
    signal rtc_hsel     : std_logic;

    -- Peripheral AHB read data mux
    signal sio_hrdata     : std_logic_vector(31 downto 0);
    signal sio_hresp      : std_logic;
    signal sio_hreadyout  : std_logic;
    signal pio0_hrdata    : std_logic_vector(31 downto 0);
    signal pio0_hresp     : std_logic;
    signal pio0_hreadyout : std_logic;
    signal pio1_hrdata    : std_logic_vector(31 downto 0);
    signal pio1_hresp     : std_logic;
    signal pio1_hreadyout : std_logic;
    signal pwm_hrdata     : std_logic_vector(31 downto 0);
    signal pwm_hresp      : std_logic;
    signal pwm_hreadyout  : std_logic;
    signal qspi_hrdata    : std_logic_vector(31 downto 0);
    signal qspi_hresp     : std_logic;
    signal qspi_hreadyout : std_logic;
    signal usb_hrdata     : std_logic_vector(31 downto 0);
    signal usb_hresp      : std_logic;
    signal usb_hreadyout  : std_logic;
    signal dma_hrdata     : std_logic_vector(31 downto 0);
    signal dma_hresp      : std_logic;
    signal dma_hreadyout  : std_logic;
    signal uart0_hrdata   : std_logic_vector(31 downto 0);
    signal uart0_hresp    : std_logic;
    signal uart0_hreadyout: std_logic;
    signal uart1_hrdata   : std_logic_vector(31 downto 0);
    signal uart1_hresp    : std_logic;
    signal uart1_hreadyout: std_logic;
    signal spi0_hrdata    : std_logic_vector(31 downto 0);
    signal spi0_hresp     : std_logic;
    signal spi0_hreadyout : std_logic;
    signal spi1_hrdata    : std_logic_vector(31 downto 0);
    signal spi1_hresp     : std_logic;
    signal spi1_hreadyout : std_logic;
    signal i2c0_hrdata    : std_logic_vector(31 downto 0);
    signal i2c0_hresp     : std_logic;
    signal i2c0_hreadyout : std_logic;
    signal i2c1_hrdata    : std_logic_vector(31 downto 0);
    signal i2c1_hresp     : std_logic;
    signal i2c1_hreadyout : std_logic;
    signal adc_hrdata     : std_logic_vector(31 downto 0);
    signal adc_hresp      : std_logic;
    signal adc_hreadyout  : std_logic;
    signal wdt_hrdata     : std_logic_vector(31 downto 0);
    signal wdt_hresp      : std_logic;
    signal wdt_hreadyout  : std_logic;
    signal rtc_hrdata     : std_logic_vector(31 downto 0);
    signal rtc_hresp      : std_logic;
    signal rtc_hreadyout  : std_logic;

    -- IRQ signals
    signal c0_irq_inputs  : std_logic_vector(31 downto 0) := (others => '0');
    signal c1_irq_inputs  : std_logic_vector(31 downto 0) := (others => '0');
    signal c0_irq_out     : std_logic;
    signal c1_irq_out     : std_logic;
    signal sio_fifo_irq   : std_logic;
    signal pio0_irq       : std_logic;
    signal pio1_irq       : std_logic;
    signal pwm_irq        : std_logic;
    signal uart0_irq      : std_logic;
    signal uart1_irq      : std_logic;
    signal spi0_irq       : std_logic;
    signal spi1_irq       : std_logic;
    signal i2c0_irq       : std_logic;
    signal i2c1_irq       : std_logic;
    signal adc_irq        : std_logic;
    signal wdt_irq        : std_logic;
    signal wdt_rst        : std_logic;
    signal rtc_irq        : std_logic;
    signal dma_irq        : std_logic;

    -- GPIO signals
    signal gpio_out_reg   : std_logic_vector(31 downto 0);
    signal gpio_in_reg    : std_logic_vector(31 downto 0);
    signal gpio_oe_reg    : std_logic_vector(31 downto 0);
    signal sio_gpio_out   : std_logic_vector(31 downto 0);
    signal sio_gpio_oe    : std_logic_vector(31 downto 0);
    signal sio_gpio_in    : std_logic_vector(31 downto 0);

    -- PIO pin signals
    signal pio0_pins_out  : std_logic_vector(31 downto 0);
    signal pio0_pins_oe   : std_logic_vector(31 downto 0);
    signal pio1_pins_out  : std_logic_vector(31 downto 0);
    signal pio1_pins_oe   : std_logic_vector(31 downto 0);

    -- PWM output
    signal pwm_out_reg    : std_logic_vector(31 downto 0);

    -- DMA master interface
    signal dma_m_addr     : std_logic_vector(31 downto 0);
    signal dma_m_rdata    : std_logic_vector(31 downto 0);
    signal dma_m_wdata    : std_logic_vector(31 downto 0);
    signal dma_m_we       : std_logic;
    signal dma_m_req      : std_logic;
    signal dma_m_ack      : std_logic;

    -- ADC extended input (96-bit for the existing controller)
    signal adc_in_ext     : std_logic_vector(95 downto 0) := (others => '0');

    -- Tie-off signals for unused I2C1 direct instance
    signal i2c1_sda_tie : std_logic := 'Z';
    signal i2c1_scl_tie : std_logic := 'Z';

begin

    -- ========================================================================
    -- Clock and reset
    -- ========================================================================
    HCLK    <= CLK;
    HRESETn <= nRESET;

    -- ========================================================================
    -- AHB Arbiter (round-robin between core0 and core1)
    -- ========================================================================
    ahb_arbiter : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            arb_sel <= '0';
        elsif rising_edge(HCLK) then
            -- Simple round-robin: toggle when both cores are requesting
            if arb_HREADYOUT = '1' then
                if c0_HTRANS /= "00" and c1_HTRANS /= "00" then
                    arb_sel <= not arb_sel;
                elsif c0_HTRANS /= "00" then
                    arb_sel <= '0';
                elsif c1_HTRANS /= "00" then
                    arb_sel <= '1';
                end if;
            end if;
        end if;
    end process ahb_arbiter;

    -- Mux AHB master signals to peripheral bus
    arb_HSEL      <= c0_HSEL      when arb_sel = '0' else c1_HSEL;
    arb_HWRITE    <= c0_HWRITE    when arb_sel = '0' else c1_HWRITE;
    arb_HMASTLOCK <= c0_HMASTLOCK when arb_sel = '0' else c1_HMASTLOCK;
    arb_HTRANS    <= c0_HTRANS    when arb_sel = '0' else c1_HTRANS;
    arb_HSIZE     <= c0_HSIZE     when arb_sel = '0' else c1_HSIZE;
    arb_HPROT     <= c0_HPROT     when arb_sel = '0' else c1_HPROT;
    arb_HADDR     <= c0_HADDR     when arb_sel = '0' else c1_HADDR;
    arb_HWDATA    <= c0_HWDATA    when arb_sel = '0' else c1_HWDATA;
    arb_HREADY    <= arb_HREADYOUT;

    -- Route read data back to the selected core
    c0_HRDATA    <= arb_HRDATA when arb_sel = '0' else (others => '0');
    c0_HRESP     <= arb_HRESP  when arb_sel = '0' else '0';
    c0_HREADYOUT <= arb_HREADYOUT when arb_sel = '0' else '1';

    c1_HRDATA    <= arb_HRDATA when arb_sel = '1' else (others => '0');
    c1_HRESP     <= arb_HRESP  when arb_sel = '1' else '0';
    c1_HREADYOUT <= arb_HREADYOUT when arb_sel = '1' else '1';

    -- ========================================================================
    -- Peripheral address decode
    -- ========================================================================
    periph_sel  <= '1' when arb_HADDR(31 downto 28) = x"4" else '0';

    sio_hsel    <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 5) = "00000000000") else '0';
    pio0_hsel   <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"2") else '0';
    pio1_hsel   <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"3") else '0';
    pwm_hsel    <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"4") else '0';
    qspi_hsel   <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"5") else '0';
    usb_hsel    <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"6") else '0';
    dma_hsel    <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"7") else '0';
    uart0_hsel  <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"8") else '0';
    uart1_hsel  <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"9") else '0';
    spi0_hsel   <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"A") else '0';
    spi1_hsel   <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"B") else '0';
    i2c0_hsel   <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"C") else '0';
    i2c1_hsel   <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"D") else '0';
    adc_hsel    <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"E") else '0';
    wdt_hsel    <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"F" and arb_HADDR(11 downto 8) = x"0") else '0';
    rtc_hsel    <= '1' when (arb_HSEL = '1' and periph_sel = '1' and arb_HADDR(15 downto 12) = x"F" and arb_HADDR(11 downto 8) = x"1") else '0';

    -- ========================================================================
    -- AHB read data mux (peripheral select)
    -- ========================================================================
    arb_HRDATA <= sio_hrdata     when sio_hsel    = '1'
             else pio0_hrdata    when pio0_hsel   = '1'
             else pio1_hrdata    when pio1_hsel   = '1'
             else pwm_hrdata     when pwm_hsel    = '1'
             else qspi_hrdata    when qspi_hsel   = '1'
             else usb_hrdata     when usb_hsel    = '1'
             else dma_hrdata     when dma_hsel    = '1'
             else uart0_hrdata   when uart0_hsel  = '1'
             else uart1_hrdata   when uart1_hsel  = '1'
             else spi0_hrdata    when spi0_hsel   = '1'
             else spi1_hrdata    when spi1_hsel   = '1'
             else i2c0_hrdata    when i2c0_hsel   = '1'
             else i2c1_hrdata    when i2c1_hsel   = '1'
             else adc_hrdata     when adc_hsel    = '1'
             else wdt_hrdata     when wdt_hsel    = '1'
             else rtc_hrdata     when rtc_hsel    = '1'
             else (others => '0');

    arb_HRESP <= sio_hresp     when sio_hsel    = '1'
            else pio0_hresp    when pio0_hsel   = '1'
            else pio1_hresp    when pio1_hsel   = '1'
            else pwm_hresp     when pwm_hsel    = '1'
            else qspi_hresp    when qspi_hsel   = '1'
            else usb_hresp     when usb_hsel    = '1'
            else dma_hresp     when dma_hsel    = '1'
            else uart0_hresp   when uart0_hsel  = '1'
            else uart1_hresp   when uart1_hsel  = '1'
            else spi0_hresp    when spi0_hsel   = '1'
            else spi1_hresp    when spi1_hsel   = '1'
            else i2c0_hresp    when i2c0_hsel   = '1'
            else i2c1_hresp    when i2c1_hsel   = '1'
            else adc_hresp     when adc_hsel    = '1'
            else wdt_hresp     when wdt_hsel    = '1'
            else rtc_hresp     when rtc_hsel    = '1'
            else '0';

    arb_HREADYOUT <= sio_hreadyout     when sio_hsel    = '1'
                else pio0_hreadyout    when pio0_hsel   = '1'
                else pio1_hreadyout    when pio1_hsel   = '1'
                else pwm_hreadyout     when pwm_hsel    = '1'
                else qspi_hreadyout    when qspi_hsel   = '1'
                else usb_hreadyout     when usb_hsel    = '1'
                else dma_hreadyout     when dma_hsel    = '1'
                else uart0_hreadyout   when uart0_hsel  = '1'
                else uart1_hreadyout   when uart1_hsel  = '1'
                else spi0_hreadyout    when spi0_hsel   = '1'
                else spi1_hreadyout    when spi1_hsel   = '1'
                else i2c0_hreadyout    when i2c0_hsel   = '1'
                else i2c1_hreadyout    when i2c1_hsel   = '1'
                else adc_hreadyout     when adc_hsel    = '1'
                else wdt_hreadyout     when wdt_hsel    = '1'
                else rtc_hreadyout     when rtc_hsel    = '1'
                else '1';

    -- ========================================================================
    -- IRQ mapping
    -- ========================================================================
    -- Core 0 IRQ inputs (RP2040 IRQ numbers)
    c0_irq_inputs(0)  <= uart0_irq;      -- IRQ 0: UART0
    c0_irq_inputs(1)  <= uart1_irq;      -- IRQ 1: UART1
    c0_irq_inputs(2)  <= spi0_irq;       -- IRQ 2: SPI0
    c0_irq_inputs(3)  <= spi1_irq;       -- IRQ 3: SPI1
    c0_irq_inputs(4)  <= i2c0_irq;       -- IRQ 4: I2C0
    c0_irq_inputs(5)  <= i2c1_irq;       -- IRQ 5: I2C1
    c0_irq_inputs(6)  <= dma_irq;        -- IRQ 6: DMA
    c0_irq_inputs(7)  <= pio0_irq;       -- IRQ 7: PIO0
    c0_irq_inputs(8)  <= pio1_irq;       -- IRQ 8: PIO1
    c0_irq_inputs(9)  <= pwm_irq;        -- IRQ 9: PWM
    c0_irq_inputs(10) <= usb_hrdata(0);  -- IRQ 10: USB (simplified)
    c0_irq_inputs(11) <= adc_irq;        -- IRQ 11: ADC
    c0_irq_inputs(12) <= rtc_irq;        -- IRQ 12: RTC
    c0_irq_inputs(13) <= wdt_irq;        -- IRQ 13: WDT
    c0_irq_inputs(14) <= sio_fifo_irq;   -- IRQ 14: SIO FIFO

    -- Core 1 gets the same IRQs (simplified - RP2040 has separate masking)
    c1_irq_inputs <= c0_irq_inputs;

    irq_out <= c0_irq_out or c1_irq_out;

    -- ========================================================================
    -- GPIO pin muxing
    -- ========================================================================
    -- SIO controls GPIO output/enable; PIO can also drive pins
    -- For simplicity: SIO has priority, PIO can override via AFSEL
    gpio_in_reg <= (others => '0');
    gpio_in_reg(29 downto 0) <= gpio;

    -- Drive GPIO pins
    gpio(29 downto 0) <= sio_gpio_out(29 downto 0) when sio_gpio_oe(29 downto 0) /= (29 downto 0 => '0')
                        else (others => 'Z');

    -- ========================================================================
    -- Core 0: Cortex-M0+ interface
    -- ========================================================================
    core0_inst : entity work.cortex_m0plus_interface
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => c0_HSEL, HWRITE => c0_HWRITE, HREADY => c0_HREADY,
            HMASTLOCK => c0_HMASTLOCK, HTRANS => c0_HTRANS,
            HSIZE => c0_HSIZE, HPROT => c0_HPROT,
            HADDR => c0_HADDR, HWDATA => c0_HWDATA,
            HRDATA => c0_HRDATA, HRESP => c0_HRESP, HREADYOUT => c0_HREADYOUT,
            irq_inputs => c0_irq_inputs, nmi => '0',
            irq_out => c0_irq_out, irq_num => open,
            mclk => HCLK, systick_int => open,
            gpio_in => gpio_in_reg, gpio_out => open, gpio_dir => open,
            scio_out => open, scio_in => (others => '0'),
            wic_en => '0', wic_irq_out => open,
            sleep_out => open,
            mtb_en => '0',
            swclk => swclk0, swdio => swdio0,
            -- DMA (core0 owns DMA)
            dma_int => dma_irq, dma_m_addr => dma_m_addr,
            dma_m_rdata => dma_m_rdata, dma_m_wdata => dma_m_wdata,
            dma_m_we => dma_m_we, dma_m_req => dma_m_req, dma_m_ack => dma_m_ack,
            -- I2C0
            i2c_sda => i2c0_sda, i2c_scl => i2c0_scl, i2c_int => i2c0_irq,
            -- SPI0
            spi_sclk => spi0_clk, spi_mosi => spi0_mosi, spi_miso => spi0_miso, spi_int => spi0_irq,
            -- UART0
            uart_txd => uart0_tx, uart_rxd => uart0_rx, uart_int => uart0_irq,
            -- I2S (not used on RP2040, but part of the interface)
            i2s_sck => open, i2s_ws => open, i2s_sd_tx => open, i2s_sd_rx => '0', i2s_int => open,
            -- WDT
            wdt_int => wdt_irq, wdt_reset => wdt_rst,
            -- RTC
            rtc_int => rtc_irq,
            -- ADC
            adc_in => adc_in_ext, adc_int => adc_irq,
            -- DAC (RP2040 has no DAC, but interface requires it)
            dac_out => open
        );

    -- DMA ack (simplified: always ready)
    dma_m_ack <= '1';
    dma_m_rdata <= (others => '0');

    -- ========================================================================
    -- Core 1: Cortex-M0+ interface
    -- ========================================================================
    core1_inst : entity work.cortex_m0plus_interface
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => c1_HSEL, HWRITE => c1_HWRITE, HREADY => c1_HREADY,
            HMASTLOCK => c1_HMASTLOCK, HTRANS => c1_HTRANS,
            HSIZE => c1_HSIZE, HPROT => c1_HPROT,
            HADDR => c1_HADDR, HWDATA => c1_HWDATA,
            HRDATA => c1_HRDATA, HRESP => c1_HRESP, HREADYOUT => c1_HREADYOUT,
            irq_inputs => c1_irq_inputs, nmi => '0',
            irq_out => c1_irq_out, irq_num => open,
            mclk => HCLK, systick_int => open,
            gpio_in => gpio_in_reg, gpio_out => open, gpio_dir => open,
            scio_out => open, scio_in => (others => '0'),
            wic_en => '0', wic_irq_out => open,
            sleep_out => open,
            mtb_en => '0',
            swclk => swclk1, swdio => swdio1,
            -- Core1 DMA (not used, tied off)
            dma_int => open, dma_m_addr => open,
            dma_m_rdata => (others => '0'), dma_m_wdata => open,
            dma_m_we => open, dma_m_req => open, dma_m_ack => '1',
            -- I2C1
            i2c_sda => i2c1_sda, i2c_scl => i2c1_scl, i2c_int => i2c1_irq,
            -- SPI1
            spi_sclk => spi1_clk, spi_mosi => spi1_mosi, spi_miso => spi1_miso, spi_int => spi1_irq,
            -- UART1
            uart_txd => uart1_tx, uart_rxd => uart1_rx, uart_int => uart1_irq,
            -- I2S (not used)
            i2s_sck => open, i2s_ws => open, i2s_sd_tx => open, i2s_sd_rx => '0', i2s_int => open,
            -- WDT (shared with core0)
            wdt_int => open, wdt_reset => open,
            -- RTC (shared)
            rtc_int => open,
            -- ADC (shared)
            adc_in => (others => '0'), adc_int => open,
            -- DAC (not used)
            dac_out => open
        );

    -- ========================================================================
    -- SIO (Single-cycle I/O) - core0's instance
    -- ========================================================================
    sio_inst : entity work.sio_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => sio_hsel, HWRITE => arb_HWRITE, HREADY => arb_HREADY,
            HTRANS => arb_HTRANS, HSIZE => arb_HSIZE,
            HADDR => arb_HADDR, HWDATA => arb_HWDATA,
            HRDATA => sio_hrdata, HRESP => sio_hresp, HREADYOUT => sio_hreadyout,
            core_id => arb_sel,  -- which core is accessing
            gpio_out => sio_gpio_out, gpio_in => gpio_in_reg, gpio_oe => sio_gpio_oe,
            fifo_irq => sio_fifo_irq
        );

    -- ========================================================================
    -- PIO Block 0
    -- ========================================================================
    pio0_inst : entity work.pio_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => pio0_hsel, HWRITE => arb_HWRITE, HREADY => arb_HREADY,
            HTRANS => arb_HTRANS, HSIZE => arb_HSIZE,
            HADDR => arb_HADDR, HWDATA => arb_HWDATA,
            HRDATA => pio0_hrdata, HRESP => pio0_hresp, HREADYOUT => pio0_hreadyout,
            pio_pins_out => pio0_pins_out, pio_pins_in => gpio_in_reg,
            pio_pins_oe => pio0_pins_oe,
            pio_irq_out => pio0_irq
        );

    -- ========================================================================
    -- PIO Block 1
    -- ========================================================================
    pio1_inst : entity work.pio_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => pio1_hsel, HWRITE => arb_HWRITE, HREADY => arb_HREADY,
            HTRANS => arb_HTRANS, HSIZE => arb_HSIZE,
            HADDR => arb_HADDR, HWDATA => arb_HWDATA,
            HRDATA => pio1_hrdata, HRESP => pio1_hresp, HREADYOUT => pio1_hreadyout,
            pio_pins_out => pio1_pins_out, pio_pins_in => gpio_in_reg,
            pio_pins_oe => pio1_pins_oe,
            pio_irq_out => pio1_irq
        );

    -- ========================================================================
    -- PWM Controller (16 slices = 32 channels)
    -- ========================================================================
    pwm_inst : entity work.pwm_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => pwm_hsel, HWRITE => arb_HWRITE, HREADY => arb_HREADY,
            HTRANS => arb_HTRANS, HSIZE => arb_HSIZE,
            HADDR => arb_HADDR, HWDATA => arb_HWDATA,
            HRDATA => pwm_hrdata, HRESP => pwm_hresp, HREADYOUT => pwm_hreadyout,
            pwm_out => pwm_out_reg,
            pwm_int => pwm_irq
        );

    -- ========================================================================
    -- QSPI XIP Flash Controller
    -- ========================================================================
    qspi_inst : entity work.qspi_xip_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => qspi_hsel, HWRITE => arb_HWRITE, HREADY => arb_HREADY,
            HTRANS => arb_HTRANS, HSIZE => arb_HSIZE,
            HADDR => arb_HADDR, HWDATA => arb_HWDATA,
            HRDATA => qspi_hrdata, HRESP => qspi_hresp, HREADYOUT => qspi_hreadyout,
            qspi_clk => qspi_clk, qspi_cs_n => qspi_cs_n, qspi_dq => qspi_dq,
            qspi_int => open
        );

    -- ========================================================================
    -- USB 1.1 Device Controller
    -- ========================================================================
    usb_inst : entity work.usb_device
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => usb_hsel, HWRITE => arb_HWRITE, HREADY => arb_HREADY,
            HTRANS => arb_HTRANS, HSIZE => arb_HSIZE,
            HADDR => arb_HADDR, HWDATA => arb_HWDATA,
            HRDATA => usb_hrdata, HRESP => usb_hresp, HREADYOUT => usb_hreadyout,
            usb_dp => usb_dp, usb_dm => usb_dm,
            usb_clk => HCLK,
            usb_int => open
        );

    -- ========================================================================
    -- UART1 (second UART, instantiated directly)
    -- ========================================================================
    uart1_inst : entity work.uart_ahb
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => uart1_hsel, HWRITE => arb_HWRITE, HREADY => arb_HREADY,
            HTRANS => arb_HTRANS, HSIZE => arb_HSIZE,
            HADDR => arb_HADDR, HWDATA => arb_HWDATA,
            HRDATA => uart1_hrdata, HRESP => uart1_hresp, HREADYOUT => uart1_hreadyout,
            txd => open, rxd => '1',  -- UART1 is handled by core1_inst above
            uart_int => open
        );

    -- ========================================================================
    -- SPI1 (second SPI, instantiated directly)
    -- ========================================================================
    spi1_inst : entity work.spi_master_ahb
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => spi1_hsel, HWRITE => arb_HWRITE, HREADY => arb_HREADY,
            HTRANS => arb_HTRANS, HSIZE => arb_HSIZE,
            HADDR => arb_HADDR, HWDATA => arb_HWDATA,
            HRDATA => spi1_hrdata, HRESP => spi1_hresp, HREADYOUT => spi1_hreadyout,
            sclk => open, mosi => open, miso => '1',  -- SPI1 handled by core1_inst
            ss_n => open, spi_int => open
        );

    -- ========================================================================
    -- I2C1 (second I2C, instantiated directly)
    -- ========================================================================
    i2c1_inst : entity work.i2c_master_ahb
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => i2c1_hsel, HWRITE => arb_HWRITE, HREADY => arb_HREADY,
            HTRANS => arb_HTRANS, HSIZE => arb_HSIZE,
            HADDR => arb_HADDR, HWDATA => arb_HWDATA,
            HRDATA => i2c1_hrdata, HRESP => i2c1_hresp, HREADYOUT => i2c1_hreadyout,
            sda => i2c1_sda_tie, scl => i2c1_scl_tie,  -- I2C1 handled by core1_inst
            i2c_int => open
        );

    -- ========================================================================
    -- ADC Controller
    -- ========================================================================
    adc_in_ext(47 downto 0) <= adc_in;

    adc_inst : entity work.adc_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => adc_hsel, HWRITE => arb_HWRITE, HREADY => arb_HREADY,
            HTRANS => arb_HTRANS, HADDR => arb_HADDR, HWDATA => arb_HWDATA,
            HRDATA => adc_hrdata, HRESP => adc_hresp, HREADYOUT => adc_hreadyout,
            adc_in => adc_in_ext,
            adc_int => open
        );

    -- ========================================================================
    -- WDT Controller
    -- ========================================================================
    wdt_inst : entity work.wdt_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => wdt_hsel, HWRITE => arb_HWRITE, HREADY => arb_HREADY,
            HTRANS => arb_HTRANS, HADDR => arb_HADDR, HWDATA => arb_HWDATA,
            HRDATA => wdt_hrdata, HRESP => wdt_hresp, HREADYOUT => wdt_hreadyout,
            wdt_int => open, wdt_reset => open
        );

    -- ========================================================================
    -- RTC Controller
    -- ========================================================================
    rtc_inst : entity work.rtc_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => rtc_hsel, HWRITE => arb_HWRITE, HREADY => arb_HREADY,
            HTRANS => arb_HTRANS, HADDR => arb_HADDR, HWDATA => arb_HWDATA,
            HRDATA => rtc_hrdata, HRESP => rtc_hresp, HREADYOUT => rtc_hreadyout,
            rtc_int => open
        );

end architecture rtl;

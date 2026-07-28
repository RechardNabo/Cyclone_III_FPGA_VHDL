-- ================================================================================
-- synergy_s5_interface : Renesas Synergy S5 MCU interface
-- Based on: ARM Cortex-M4 with FPU (high-performance variant)
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- The S5 is the high-performance variant with DMA and USB, suitable for
-- data-intensive applications requiring high throughput.
--
-- Peripheral set (S5 - HIGH-PERFORMANCE):
--   [Y] GPIO  - 32-bit | [Y] Timer | [Y] UART | [Y] SPI | [Y] I2C | [Y] ADC
--   [Y] DMA   - DMA controller for high-speed data transfers
--   [Y] USB   - USB device interface
--   [Y] CAN   - CAN 2.0B bus controller (x2 on real S5)
--   [Y] Ethernet - Ethernet MAC with MII interface
--   [N] LCD/Security - Not included
--
-- AHB-Lite Register Map (block-select via HADDR[11:8]):
--   Block 0 (0x000-0x0FF): Original peripherals
--     0x00: GPIO_DATA | 0x04: GPIO_DIR | 0x08: TIMER_CTRL | 0x0C: TIMER_LOAD
--     0x10: UART_DATA | 0x14: UART_STATUS | 0x18: SPI_CTRL | 0x1C: SPI_DATA
--     0x20: I2C_CTRL  | 0x24: I2C_DATA  | 0x28: ADC_CTRL  | 0x2C: ADC_DATA
--     0x30: DMA_CTRL  | 0x34: USB_CTRL  | 0x38: USB_DATA
--   Block 1 (0x100-0x1FF): CAN controller registers
--   Block 2 (0x200-0x2FF): Ethernet MAC registers
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_s5_interface is
    generic (
        GPIO_WIDTH : integer := 32
    );
    port (
        -- AHB-Lite bus interface (ARM Cortex-M4 with FPU, active-low reset)
        HCLK, HRESETn, HSEL, HWRITE, HREADY, HMASTLOCK : in std_logic;
        HTRANS : in std_logic_vector(1 downto 0);
        HSIZE  : in std_logic_vector(2 downto 0);
        HPROT  : in std_logic_vector(3 downto 0);
        HADDR  : in std_logic_vector(31 downto 0);
        HWDATA : in std_logic_vector(31 downto 0);
        HRDATA : out std_logic_vector(31 downto 0);
        HRESP  : out std_logic;
        HREADYOUT : out std_logic;
        -- GPIO
        gpio_in  : in  std_logic_vector(31 downto 0);
        gpio_out : out std_logic_vector(31 downto 0);
        gpio_dir : out std_logic_vector(31 downto 0);
        -- Timer
        timer_int : out std_logic;
        -- UART
        uart_txd : out std_logic;  uart_rxd : in std_logic;  uart_int : out std_logic;
        -- SPI (present on S5)
        spi_sclk, spi_mosi : out std_logic;  spi_miso : in std_logic;  spi_int : out std_logic;
        -- I2C (present on S5)
        i2c_sda : inout std_logic;  i2c_scl : inout std_logic;  i2c_int : out std_logic;
        -- ADC (present on S5)
        adc_in  : in  std_logic_vector(11 downto 0);  adc_int : out std_logic;
        -- DMA (present on S5 - DMA controller)
        dma_req : out std_logic;  dma_done : in std_logic;
        -- DMA master interface (full DMA controller)
        dma_int     : out std_logic;
        dma_m_addr  : out std_logic_vector(31 downto 0);
        dma_m_rdata : in  std_logic_vector(31 downto 0);
        dma_m_wdata : out std_logic_vector(31 downto 0);
        dma_m_we    : out std_logic;
        dma_m_req   : out std_logic;
        dma_m_ack   : in  std_logic;
        -- CAN (present on S5)
        can_tx : out std_logic;  can_rx : in std_logic;  can_int : out std_logic;
        -- Ethernet (present on S5) - MII interface
        eth_txd : out std_logic_vector(3 downto 0);  eth_rxd : in std_logic_vector(3 downto 0);
        eth_int : out std_logic;
        mii_tx_en  : out std_logic;
        mii_tx_clk : in  std_logic;
        mii_rx_clk : in  std_logic;
        mii_rx_dv  : in  std_logic;
        mii_tx_er  : out std_logic;
        mii_rx_er  : in  std_logic;
        mii_crs    : in  std_logic;
        mii_col    : in  std_logic;
        mdc        : out std_logic;
        mdio       : inout std_logic;
        -- USB (present on S5 - high-performance feature)
        usb_dp, usb_dm : inout std_logic;  usb_int : out std_logic;
        -- LCD (NOT present on S5)
        lcd_data : out std_logic_vector(15 downto 0);
        lcd_hsync, lcd_vsync, lcd_clk : out std_logic;
        -- Security (NOT present on S5)
        trng_valid, secure_boot : out std_logic;

        -- WDT interface
        wdt_int   : out std_logic;
        wdt_reset : out std_logic;

        -- RTC interface
        rtc_int   : out std_logic;

        -- DAC interface
        dac_out   : out std_logic_vector(23 downto 0);

        -- I2S interface (audio)
        i2s_sck   : out std_logic;
        i2s_ws    : out std_logic;
        i2s_sd_tx : out std_logic;
        i2s_sd_rx : in  std_logic;
        i2s_int   : out std_logic
    );
end entity synergy_s5_interface;

architecture rtl of synergy_s5_interface is
    -- Peripheral registers
    signal gpio_data_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_dir_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal timer_ctrl    : std_logic_vector(31 downto 0) := (others => '0');
    signal timer_load    : std_logic_vector(31 downto 0) := (others => '0');
    signal timer_count   : unsigned(31 downto 0) := (others => '0');
    signal uart_data_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal uart_status   : std_logic_vector(31 downto 0) := x"00000001";
    signal spi_ctrl      : std_logic_vector(31 downto 0) := (others => '0');
    signal spi_data_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal i2c_ctrl      : std_logic_vector(31 downto 0) := (others => '0');
    signal i2c_data_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal adc_ctrl      : std_logic_vector(31 downto 0) := (others => '0');
    signal adc_data_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal usb_ctrl      : std_logic_vector(31 downto 0) := (others => '0'); -- USB control
    signal usb_data_reg  : std_logic_vector(31 downto 0) := (others => '0'); -- USB data
    signal reg_sel       : integer range 0 to 15;

    -- AHB block-select decode (HADDR[11:8] selects peripheral block)
    signal block_sel   : std_logic_vector(3 downto 0);
    signal orig_hsel   : std_logic;
    signal can_hsel    : std_logic;
    signal eth_hsel    : std_logic;

    -- Peripheral AHB response signals
    signal orig_hrdata    : std_logic_vector(31 downto 0);
    signal can_hrdata     : std_logic_vector(31 downto 0);
    signal eth_hrdata     : std_logic_vector(31 downto 0);
    signal can_hresp      : std_logic;
    signal eth_hresp      : std_logic;
    signal can_hreadyout  : std_logic;
    signal eth_hreadyout  : std_logic;

    -- CAN clkout (unused externally)
    signal can_clkout : std_logic;

    -- WDT AHB decode and response signals
    signal wdt_hsel       : std_logic;
    signal wdt_hrdata     : std_logic_vector(31 downto 0);
    signal wdt_hresp      : std_logic;
    signal wdt_hreadyout  : std_logic;

    -- RTC AHB decode and response signals
    signal rtc_hsel       : std_logic;
    signal rtc_hrdata     : std_logic_vector(31 downto 0);
    signal rtc_hresp      : std_logic;
    signal rtc_hreadyout  : std_logic;

    -- DAC AHB decode and response signals
    signal dac_hsel       : std_logic;
    signal dac_hrdata     : std_logic_vector(31 downto 0);
    signal dac_hresp      : std_logic;
    signal dac_hreadyout  : std_logic;

    -- DMA controller AHB signals
    signal dma_hsel       : std_logic;
    signal dma_hrdata     : std_logic_vector(31 downto 0);
    signal dma_hresp      : std_logic;
    signal dma_hreadyout  : std_logic;
    signal dma_int_vec    : std_logic_vector(3 downto 0);

    -- I2S AHB-Lite component
    component i2s_master_ahb is
        port (
            HCLK      : in  std_logic;
            HRESETn   : in  std_logic;
            HSEL      : in  std_logic;
            HWRITE    : in  std_logic;
            HREADY    : in  std_logic;
            HTRANS    : in  std_logic_vector(1 downto 0);
            HSIZE     : in  std_logic_vector(2 downto 0);
            HADDR     : in  std_logic_vector(31 downto 0);
            HWDATA    : in  std_logic_vector(31 downto 0);
            HRDATA    : out std_logic_vector(31 downto 0);
            HRESP     : out std_logic;
            HREADYOUT : out std_logic;
            sck       : out std_logic;
            ws        : out std_logic;
            sd_tx     : out std_logic;
            sd_rx     : in  std_logic;
            mclk      : out std_logic;
            i2s_int   : out std_logic
        );
    end component;

    -- I2S AHB decode and response signals
    signal i2s_hsel       : std_logic;
    signal i2s_hrdata     : std_logic_vector(31 downto 0);
    signal i2s_hresp      : std_logic;
    signal i2s_hreadyout  : std_logic;
    signal i2s_mclk       : std_logic;
begin

    -- I2S address decode: HADDR(15 downto 12) = "0100" (base 0x4000)
    i2s_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0100") else '0';
    -- WDT address decode: HADDR(15 downto 12) = "0101" (base 0x5000)
    wdt_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0101") else '0';
    -- RTC address decode: HADDR(15 downto 12) = "0110" (base 0x6000)
    rtc_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0110") else '0';
    -- DAC address decode: HADDR(15 downto 12) = "1000" (base 0x8000)
    dac_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "1000") else '0';

    -- =========================================================================
    -- AHB BLOCK-SELECT DECODE
    -- HADDR[11:8] selects peripheral block:
    --   0 = original peripherals (GPIO, Timer, UART, SPI, I2C, ADC, USB)
    --   1 = CAN controller
    --   2 = Ethernet MAC
    --   3 = DMA controller
    -- =========================================================================
    block_sel <= HADDR(11 downto 8);
    orig_hsel <= HSEL when block_sel = x"0" else '0';
    can_hsel  <= HSEL when block_sel = x"1" else '0';
    eth_hsel  <= HSEL when block_sel = x"2" else '0';
    dma_hsel  <= HSEL when block_sel = x"3" else '0';

    reg_sel <= to_integer(unsigned(HADDR(5 downto 2)));

    -- =========================================================================
    -- AHB-LITE WRITE PROCESS (Block 0: original peripherals)
    -- =========================================================================
    process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            gpio_data_reg <= (others => '0'); gpio_dir_reg <= (others => '0');
            timer_ctrl <= (others => '0'); timer_load <= (others => '0');
            timer_count <= (others => '0');
            uart_data_reg <= (others => '0'); uart_status <= x"00000001";
            spi_ctrl <= (others => '0'); spi_data_reg <= (others => '0');
            i2c_ctrl <= (others => '0'); i2c_data_reg <= (others => '0');
            adc_ctrl <= (others => '0'); adc_data_reg <= (others => '0');
            usb_ctrl <= (others => '0');
            usb_data_reg <= (others => '0');
        elsif rising_edge(HCLK) then
            if orig_hsel = '1' and HREADY = '1' and HWRITE = '1' then
                case reg_sel is
                    when 0 => gpio_data_reg <= HWDATA;     -- GPIO_DATA
                    when 1 => gpio_dir_reg  <= HWDATA;     -- GPIO_DIR
                    when 2 => timer_ctrl    <= HWDATA;     -- TIMER_CTRL
                    when 3 => timer_load    <= HWDATA; timer_count <= unsigned(HWDATA);
                    when 4 => uart_data_reg <= HWDATA;     -- UART_DATA
                    when 6 => spi_ctrl      <= HWDATA;     -- SPI_CTRL
                    when 7 => spi_data_reg  <= HWDATA;     -- SPI_DATA
                    when 8 => i2c_ctrl      <= HWDATA;     -- I2C_CTRL
                    when 9 => i2c_data_reg  <= HWDATA;     -- I2C_DATA
                    when 10 => adc_ctrl     <= HWDATA;     -- ADC_CTRL
                    when 13 => usb_ctrl     <= HWDATA;     -- USB_CTRL
                    when 14 => usb_data_reg <= HWDATA;     -- USB_DATA (TX)
                    when others => null;
                end case;
            end if;
            -- ADC: capture input when conversion started
            if adc_ctrl(0) = '1' then adc_data_reg <= x"00000" & adc_in; end if;
            -- SPI: capture MISO
            if spi_ctrl(0) = '1' then spi_data_reg(0) <= spi_miso; end if;
            uart_status(0) <= '1';
        end if;
    end process;

    -- =========================================================================
    -- AHB-LITE READ MULTIPLEXER (Block 0: original peripherals)
    -- =========================================================================
    process(orig_hsel, reg_sel, gpio_data_reg, gpio_dir_reg, timer_ctrl, timer_load,
            timer_count, uart_data_reg, uart_status, spi_ctrl, spi_data_reg,
            i2c_ctrl, i2c_data_reg, adc_ctrl, adc_data_reg,
            usb_ctrl, usb_data_reg, gpio_in)
    begin
        if orig_hsel = '1' then
            case reg_sel is
                when 0 => orig_hrdata <= gpio_data_reg;
                when 1 => orig_hrdata <= gpio_dir_reg;
                when 2 => orig_hrdata <= timer_ctrl;
                when 3 => orig_hrdata <= std_logic_vector(timer_count);
                when 4 => orig_hrdata <= uart_data_reg;
                when 5 => orig_hrdata <= uart_status;
                when 6 => orig_hrdata <= spi_ctrl;
                when 7 => orig_hrdata <= spi_data_reg;
                when 8 => orig_hrdata <= i2c_ctrl;
                when 9 => orig_hrdata <= i2c_data_reg;
                when 10 => orig_hrdata <= adc_ctrl;
                when 11 => orig_hrdata <= adc_data_reg;
                when 13 => orig_hrdata <= usb_ctrl;
                when 14 => orig_hrdata <= usb_data_reg;
                when others => orig_hrdata <= (others => '0');
            end case;
        else
            orig_hrdata <= (others => '0');
        end if;
    end process;

    -- =========================================================================
    -- AHB-LITE OUTPUT MULTIPLEXER (selects between peripheral blocks)
    -- =========================================================================
    process(HSEL, i2s_hsel, wdt_hsel, rtc_hsel, dac_hsel, block_sel, orig_hrdata,
            can_hrdata, eth_hrdata, dma_hrdata,
            can_hresp, eth_hresp, dma_hresp,
            can_hreadyout, eth_hreadyout, dma_hreadyout,
            wdt_hrdata, wdt_hresp, wdt_hreadyout,
            rtc_hrdata, rtc_hresp, rtc_hreadyout,
            dac_hrdata, dac_hresp, dac_hreadyout,
            i2s_hrdata, i2s_hresp, i2s_hreadyout)
    begin
        if i2s_hsel = '1' then
            HRDATA <= i2s_hrdata;
            HRESP  <= i2s_hresp;
            HREADYOUT <= i2s_hreadyout;
        elsif wdt_hsel = '1' then
            HRDATA <= wdt_hrdata;
            HRESP  <= wdt_hresp;
            HREADYOUT <= wdt_hreadyout;
        elsif rtc_hsel = '1' then
            HRDATA <= rtc_hrdata;
            HRESP  <= rtc_hresp;
            HREADYOUT <= rtc_hreadyout;
        elsif dac_hsel = '1' then
            HRDATA <= dac_hrdata;
            HRESP  <= dac_hresp;
            HREADYOUT <= dac_hreadyout;
        else
            case block_sel is
                when x"0" =>
                    HRDATA <= orig_hrdata;
                    HRESP  <= '0';
                    HREADYOUT <= '1';
                when x"1" =>
                    HRDATA <= can_hrdata;
                    HRESP  <= can_hresp;
                    HREADYOUT <= can_hreadyout;
                when x"2" =>
                    HRDATA <= eth_hrdata;
                    HRESP  <= eth_hresp;
                    HREADYOUT <= eth_hreadyout;
                when x"3" =>
                    HRDATA <= dma_hrdata;
                    HRESP  <= dma_hresp;
                    HREADYOUT <= dma_hreadyout;
                when others =>
                    HRDATA <= (others => '0');
                    HRESP  <= '0';
                    HREADYOUT <= '1';
            end case;
        end if;
    end process;

    gpio_out <= gpio_data_reg; gpio_dir <= gpio_dir_reg;

    -- Timer
    process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then timer_count <= (others => '0');
        elsif rising_edge(HCLK) then
            if timer_ctrl(0) = '1' then
                if timer_count = 0 then timer_count <= unsigned(timer_load);
                else timer_count <= timer_count - 1; end if;
            end if;
        end if;
    end process;
    timer_int <= '1' when (timer_ctrl(0) = '1' and timer_ctrl(1) = '1'
                           and timer_count = 0) else '0';

    -- UART
    uart_txd <= uart_data_reg(0);
    uart_int <= '1' when (uart_status(1) = '1') else '0';

    -- SPI
    spi_sclk <= spi_ctrl(1) when spi_ctrl(0) = '1' else '0';
    spi_mosi <= spi_data_reg(0) when spi_ctrl(0) = '1' else '0';
    spi_int  <= '1' when spi_ctrl(2) = '1' else '0';

    -- I2C
    i2c_scl <= i2c_ctrl(0) when i2c_ctrl(4) = '1' else 'Z';
    i2c_sda <= i2c_ctrl(1) when i2c_ctrl(4) = '1' else 'Z';
    i2c_int <= '1' when i2c_ctrl(5) = '1' else '0';

    -- ADC
    adc_int <= '1' when (adc_ctrl(0) = '1' and adc_ctrl(1) = '1') else '0';

    -- DMA (legacy req/done pins driven to 0; full master interface below)
    dma_req <= '0';

    -- USB (simplified: drive D+/D- from data register when enabled)
    usb_dp  <= usb_data_reg(0) when usb_ctrl(0) = '1' else 'Z';
    usb_dm  <= usb_data_reg(1) when usb_ctrl(0) = '1' else 'Z';
    usb_int <= '1' when usb_ctrl(1) = '1' else '0';

    -- =========================================================================
    -- DMA CONTROLLER INSTANCE (Block 3)
    -- =========================================================================
    dma_inst : entity work.dma_controller
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => dma_hsel,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HSIZE     => HSIZE,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => dma_hrdata,
            HRESP     => dma_hresp,
            HREADYOUT => dma_hreadyout,
            m_addr    => dma_m_addr,
            m_rdata   => dma_m_rdata,
            m_wdata   => dma_m_wdata,
            m_we      => dma_m_we,
            m_req     => dma_m_req,
            m_ack     => dma_m_ack,
            dma_int   => dma_int_vec,
            dma_req_in => (others => '0')
        );

    -- Aggregate DMA interrupt (OR of all channel interrupts)
    dma_int <= '0' when dma_int_vec = "0000" else '1';

    -- =========================================================================
    -- WDT CONTROLLER (AHB-Lite) - base address 0x5000
    -- =========================================================================
    u_wdt : entity work.wdt_controller
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => wdt_hsel,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => wdt_hrdata,
            HRESP     => wdt_hresp,
            HREADYOUT => wdt_hreadyout,
            wdt_int   => wdt_int,
            wdt_reset => wdt_reset
        );

    -- =========================================================================
    -- RTC CONTROLLER (AHB-Lite) - base address 0x6000
    -- =========================================================================
    u_rtc : entity work.rtc_controller
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => rtc_hsel,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => rtc_hrdata,
            HRESP     => rtc_hresp,
            HREADYOUT => rtc_hreadyout,
            rtc_int   => rtc_int
        );

    -- =========================================================================
    -- DAC CONTROLLER (AHB-Lite) - base address 0x8000
    -- =========================================================================
    u_dac : entity work.dac_controller
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => dac_hsel,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => dac_hrdata,
            HRESP     => dac_hresp,
            HREADYOUT => dac_hreadyout,
            dac_out   => dac_out
        );

    -- =========================================================================
    -- CAN CONTROLLER INSTANCE (Block 1)
    -- =========================================================================
    can_inst : entity work.can_controller_ahb
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => can_hsel,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HSIZE     => HSIZE,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => can_hrdata,
            HRESP     => can_hresp,
            HREADYOUT => can_hreadyout,
            can_tx    => can_tx,
            can_rx    => can_rx,
            can_clkout => can_clkout,
            can_int   => can_int
        );

    -- =========================================================================
    -- ETHERNET MAC INSTANCE (Block 2)
    -- =========================================================================
    eth_inst : entity work.ethernet_mac_ahb
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => eth_hsel,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HSIZE     => HSIZE,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => eth_hrdata,
            HRESP     => eth_hresp,
            HREADYOUT => eth_hreadyout,
            mii_txd   => eth_txd,
            mii_rxd   => eth_rxd,
            mii_tx_en => mii_tx_en,
            mii_tx_clk => mii_tx_clk,
            mii_rx_clk => mii_rx_clk,
            mii_rx_dv  => mii_rx_dv,
            mii_tx_er  => mii_tx_er,
            mii_rx_er  => mii_rx_er,
            mii_crs    => mii_crs,
            mii_col    => mii_col,
            mdc        => mdc,
            mdio       => mdio,
            eth_int    => eth_int
        );

    -- =========================================================================
    -- UNUSED PERIPHERAL OUTPUTS (S5 does not have LCD, Security)
    -- =========================================================================
    lcd_data <= (others => '0'); lcd_hsync <= '0'; lcd_vsync <= '0'; lcd_clk <= '0';
    trng_valid <= '0'; secure_boot <= '0';

    -- =========================================================================
    -- I2S MASTER (AHB-Lite) - base address 0x4000
    -- =========================================================================
    u_i2s_master : i2s_master_ahb
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => i2s_hsel,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HSIZE     => HSIZE,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => i2s_hrdata,
            HRESP     => i2s_hresp,
            HREADYOUT => i2s_hreadyout,
            sck       => i2s_sck,
            ws        => i2s_ws,
            sd_tx     => i2s_sd_tx,
            sd_rx     => i2s_sd_rx,
            mclk      => i2s_mclk,
            i2s_int   => i2s_int
        );

end architecture rtl;

-- ================================================================================
-- synergy_s4_interface : Renesas Synergy S4 MCU interface
-- Based on: ARM Cortex-M4 with FPU (connectivity-focused variant)
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- The S4 is designed for connectivity applications. It includes CAN bus and
-- Ethernet, making it suitable for industrial networking and IoT gateways.
--
-- Peripheral set (S4 - CONNECTIVITY):
--   [Y] GPIO  - 32-bit | [Y] Timer | [Y] UART | [Y] SPI | [Y] I2C
--   [Y] CAN   - CAN bus controller (industrial networking)
--   [Y] Ethernet - 4-bit MII Ethernet interface
--   [Y] DMA   - DMA controller for high-speed data transfers
--   [N] ADC/USB/LCD/Security - Not included
--
-- AHB-Lite Register Map:
--   0x00: GPIO_DATA | 0x04: GPIO_DIR | 0x08: TIMER_CTRL | 0x0C: TIMER_LOAD
--   0x10: UART_DATA | 0x14: UART_STATUS | 0x18: SPI_CTRL | 0x1C: SPI_DATA
--   0x20: I2C_CTRL  | 0x24: I2C_DATA  | 0x28: CAN_CTRL  | 0x2C: CAN_DATA
--   0x30: ETH_CTRL  | 0x34: ETH_TXDATA | 0x38: ETH_RXDATA
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_s4_interface is
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
        -- SPI (present on S4)
        spi_sclk, spi_mosi : out std_logic;  spi_miso : in std_logic;  spi_int : out std_logic;
        -- I2C (present on S4)
        i2c_sda : inout std_logic;  i2c_scl : inout std_logic;  i2c_int : out std_logic;
        -- ADC (present on S4 - ADC controller, 8 channels x 12-bit)
        adc_in  : in  std_logic_vector(95 downto 0) := (others => '0');  adc_int : out std_logic;
        -- DMA (present on S4 - DMA controller)
        dma_req : out std_logic;  dma_done : in std_logic;
        -- DMA master interface (full DMA controller)
        dma_int     : out std_logic;
        dma_m_addr  : out std_logic_vector(31 downto 0);
        dma_m_rdata : in  std_logic_vector(31 downto 0);
        dma_m_wdata : out std_logic_vector(31 downto 0);
        dma_m_we    : out std_logic;
        dma_m_req   : out std_logic;
        dma_m_ack   : in  std_logic;
        -- CAN (present on S4 - connectivity feature)
        can_tx : out std_logic;  can_rx : in std_logic;  can_int : out std_logic;
        -- Ethernet (present on S4 - connectivity feature)
        eth_txd : out std_logic_vector(3 downto 0);  eth_rxd : in std_logic_vector(3 downto 0);
        eth_int : out std_logic;
        -- USB (NOT present on S4)
        usb_dp, usb_dm : inout std_logic;  usb_int : out std_logic;
        -- LCD (NOT present on S4)
        lcd_data : out std_logic_vector(15 downto 0);
        lcd_hsync, lcd_vsync, lcd_clk : out std_logic;
        -- Security (NOT present on S4)
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
end entity synergy_s4_interface;

architecture rtl of synergy_s4_interface is
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
    signal can_ctrl      : std_logic_vector(31 downto 0) := (others => '0'); -- CAN control
    signal can_data_reg  : std_logic_vector(31 downto 0) := (others => '0'); -- CAN TX/RX
    signal eth_ctrl      : std_logic_vector(31 downto 0) := (others => '0'); -- Ethernet ctrl
    signal eth_txdata    : std_logic_vector(31 downto 0) := (others => '0'); -- Eth TX data
    signal eth_rxdata    : std_logic_vector(31 downto 0) := (others => '0'); -- Eth RX data
    signal reg_sel       : integer range 0 to 15;
    -- DMA controller signals
    signal dma_hsel        : std_logic;
    signal periph_hsel     : std_logic;
    signal dma_hrdata      : std_logic_vector(31 downto 0);
    signal dma_hresp       : std_logic;
    signal dma_hreadyout   : std_logic;
    signal periph_hrdata   : std_logic_vector(31 downto 0);
    signal periph_hresp    : std_logic;
    signal periph_hreadyout: std_logic;
    signal dma_int_vec     : std_logic_vector(3 downto 0);

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

    -- ADC AHB decode and response signals
    signal adc_hsel       : std_logic;
    signal adc_hrdata     : std_logic_vector(31 downto 0);
    signal adc_hresp      : std_logic;
    signal adc_hreadyout  : std_logic;
begin

    -- I2S address decode: HADDR(15 downto 12) = "0100" (base 0x4000)
    i2s_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0100") else '0';
    -- WDT address decode: HADDR(15 downto 12) = "0101" (base 0x5000)
    wdt_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0101") else '0';
    -- RTC address decode: HADDR(15 downto 12) = "0110" (base 0x6000)
    rtc_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0110") else '0';
    -- ADC address decode: HADDR(15 downto 12) = "0111" (base 0x7000)
    adc_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0111") else '0';
    -- DAC address decode: HADDR(15 downto 12) = "1000" (base 0x8000)
    dac_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "1000") else '0';

    -- Block address decode: HADDR[11:8] selects peripheral block
    periph_hsel <= HSEL when HADDR(11 downto 8) = x"0" else '0';
    dma_hsel    <= HSEL when HADDR(11 downto 8) = x"1" else '0';

    reg_sel <= to_integer(unsigned(HADDR(5 downto 2)));

    -- =========================================================================
    -- AHB-LITE WRITE PROCESS
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
            can_ctrl <= (others => '0'); can_data_reg <= (others => '0');
            eth_ctrl <= (others => '0'); eth_txdata <= (others => '0');
            eth_rxdata <= (others => '0');
        elsif rising_edge(HCLK) then
            if periph_hsel = '1' and HREADY = '1' and HWRITE = '1' then
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
                    when 10 => can_ctrl     <= HWDATA;     -- CAN_CTRL
                    when 11 => can_data_reg <= HWDATA;     -- CAN_DATA (TX)
                    when 12 => eth_ctrl     <= HWDATA;     -- ETH_CTRL
                    when 13 => eth_txdata   <= HWDATA;     -- ETH_TXDATA
                    when others => null;
                end case;
            end if;
            -- SPI: capture MISO
            if spi_ctrl(0) = '1' then spi_data_reg(0) <= spi_miso; end if;
            -- CAN: capture RX bit into data register
            if can_ctrl(0) = '1' then can_data_reg(0) <= can_rx; end if;
            -- Ethernet: capture RX data (4-bit nibble)
            if eth_ctrl(0) = '1' then
                eth_rxdata(3 downto 0) <= eth_rxd;
            end if;
            uart_status(0) <= '1';
        end if;
    end process;

    -- =========================================================================
    -- AHB-LITE READ MULTIPLEXER
    -- =========================================================================
    process(periph_hsel, reg_sel, gpio_data_reg, gpio_dir_reg, timer_ctrl, timer_load,
            timer_count, uart_data_reg, uart_status, spi_ctrl, spi_data_reg,
            i2c_ctrl, i2c_data_reg, can_ctrl, can_data_reg, eth_ctrl,
            eth_txdata, eth_rxdata, gpio_in)
    begin
        if periph_hsel = '1' then
            case reg_sel is
                when 0 => periph_hrdata <= gpio_data_reg;
                when 1 => periph_hrdata <= gpio_dir_reg;
                when 2 => periph_hrdata <= timer_ctrl;
                when 3 => periph_hrdata <= std_logic_vector(timer_count);
                when 4 => periph_hrdata <= uart_data_reg;
                when 5 => periph_hrdata <= uart_status;
                when 6 => periph_hrdata <= spi_ctrl;
                when 7 => periph_hrdata <= spi_data_reg;
                when 8 => periph_hrdata <= i2c_ctrl;
                when 9 => periph_hrdata <= i2c_data_reg;
                when 10 => periph_hrdata <= can_ctrl;
                when 11 => periph_hrdata <= can_data_reg;
                when 12 => periph_hrdata <= eth_ctrl;
                when 13 => periph_hrdata <= eth_txdata;
                when 14 => periph_hrdata <= eth_rxdata;
                when others => periph_hrdata <= (others => '0');
            end case;
        else
            periph_hrdata <= (others => '0');
        end if;
    end process;

    periph_hresp <= '0'; periph_hreadyout <= '1';

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

    -- CAN (simplified: TX from data register bit 0, interrupt on ctrl bit1)
    can_tx  <= can_data_reg(0) when can_ctrl(0) = '1' else '0';
    can_int <= '1' when can_ctrl(1) = '1' else '0';

    -- Ethernet (simplified: TX from eth_txdata lower nibble, interrupt on ctrl bit1)
    eth_txd <= eth_txdata(3 downto 0) when eth_ctrl(0) = '1' else (others => '0');
    eth_int <= '1' when eth_ctrl(1) = '1' else '0';

    -- =========================================================================
    -- DMA CONTROLLER INSTANCE
    -- =========================================================================
    dma_inst : entity work.dma_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => dma_hsel, HWRITE => HWRITE, HREADY => HREADY,
            HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => dma_hrdata, HRESP => dma_hresp, HREADYOUT => dma_hreadyout,
            m_addr => dma_m_addr, m_rdata => dma_m_rdata,
            m_wdata => dma_m_wdata, m_we => dma_m_we,
            m_req => dma_m_req, m_ack => dma_m_ack,
            dma_int => dma_int_vec,
            dma_req_in => (others => '0')
        );

    -- Aggregate DMA interrupt (OR of all channel interrupts)
    dma_int <= '0' when dma_int_vec = "0000" else '1';

    -- =========================================================================
    -- AHB BUS MULTIPLEXER: select between peripheral blocks
    -- =========================================================================
    HRDATA <= i2s_hrdata when i2s_hsel = '1' else
              wdt_hrdata when wdt_hsel = '1' else
              rtc_hrdata when rtc_hsel = '1' else
              adc_hrdata when adc_hsel = '1' else
              dac_hrdata when dac_hsel = '1' else
              dma_hrdata when dma_hsel = '1' else periph_hrdata;
    HRESP  <= i2s_hresp  when i2s_hsel = '1' else
              wdt_hresp  when wdt_hsel = '1' else
              rtc_hresp  when rtc_hsel = '1' else
              adc_hresp  when adc_hsel = '1' else
              dac_hresp  when dac_hsel = '1' else
              dma_hresp  when dma_hsel = '1' else periph_hresp;
    HREADYOUT <= i2s_hreadyout when i2s_hsel = '1' else
                 wdt_hreadyout when wdt_hsel = '1' else
                 rtc_hreadyout when rtc_hsel = '1' else
                 adc_hreadyout when adc_hsel = '1' else
                 dac_hreadyout when dac_hsel = '1' else
                 dma_hreadyout when dma_hsel = '1' else periph_hreadyout;

    -- =========================================================================
    -- UNUSED PERIPHERAL OUTPUTS (S4 does not have USB, LCD, Security)
    -- =========================================================================
    dma_req <= '0';
    usb_dp <= 'Z'; usb_dm <= 'Z'; usb_int <= '0';
    lcd_data <= (others => '0'); lcd_hsync <= '0'; lcd_vsync <= '0'; lcd_clk <= '0';
    trng_valid <= '0'; secure_boot <= '0';

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
    -- ADC CONTROLLER (AHB-Lite) - base address 0x7000
    -- =========================================================================
    u_adc : entity work.adc_controller
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => adc_hsel,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => adc_hrdata,
            HRESP     => adc_hresp,
            HREADYOUT => adc_hreadyout,
            adc_in    => adc_in,
            adc_int   => adc_int
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

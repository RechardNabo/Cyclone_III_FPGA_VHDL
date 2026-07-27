-- ================================================================================
-- synergy_s6_interface : Renesas Synergy S6 MCU interface
-- Based on: ARM Cortex-M4 with FPU (graphics-focused variant)
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- The S6 is designed for graphics/display applications. It includes an LCD
-- controller for driving TFT displays, making it suitable for HMI panels.
--
-- Peripheral set (S6 - GRAPHICS):
--   [Y] GPIO  - 32-bit | [Y] Timer | [Y] UART | [Y] SPI | [Y] I2C | [Y] ADC
--   [Y] LCD   - LCD controller with 16-bit RGB data, HSYNC, VSYNC, PCLK
--   [N] DMA/CAN/Ethernet/USB/Security - Not included
--
-- AHB-Lite Register Map:
--   0x00: GPIO_DATA | 0x04: GPIO_DIR | 0x08: TIMER_CTRL | 0x0C: TIMER_LOAD
--   0x10: UART_DATA | 0x14: UART_STATUS | 0x18: SPI_CTRL | 0x1C: SPI_DATA
--   0x20: I2C_CTRL  | 0x24: I2C_DATA  | 0x28: ADC_CTRL  | 0x2C: ADC_DATA
--   0x30: LCD_CTRL  | 0x34: LCD_DATA  | 0x38: LCD_HSYNC_CFG | 0x3C: LCD_VSYNC_CFG
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_s6_interface is
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
        -- SPI (present on S6)
        spi_sclk, spi_mosi : out std_logic;  spi_miso : in std_logic;  spi_int : out std_logic;
        -- I2C (present on S6)
        i2c_sda : inout std_logic;  i2c_scl : inout std_logic;  i2c_int : out std_logic;
        -- ADC (present on S6)
        adc_in  : in  std_logic_vector(11 downto 0);  adc_int : out std_logic;
        -- DMA (NOT present on S6)
        dma_req : out std_logic;  dma_done : in std_logic;
        -- CAN (NOT present on S6)
        can_tx : out std_logic;  can_rx : in std_logic;  can_int : out std_logic;
        -- Ethernet (NOT present on S6)
        eth_txd : out std_logic_vector(3 downto 0);  eth_rxd : in std_logic_vector(3 downto 0);
        eth_int : out std_logic;
        -- USB (NOT present on S6)
        usb_dp, usb_dm : inout std_logic;  usb_int : out std_logic;
        -- LCD (present on S6 - graphics feature: 16-bit RGB + sync signals)
        lcd_data : out std_logic_vector(15 downto 0);  -- 16-bit RGB565 data
        lcd_hsync: out std_logic;                      -- Horizontal sync pulse
        lcd_vsync: out std_logic;                      -- Vertical sync pulse
        lcd_clk  : out std_logic;                      -- Pixel clock
        -- Security (NOT present on S6)
        trng_valid, secure_boot : out std_logic
    );
end entity synergy_s6_interface;

architecture rtl of synergy_s6_interface is
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
    signal lcd_ctrl      : std_logic_vector(31 downto 0) := (others => '0'); -- LCD control
    signal lcd_data_reg  : std_logic_vector(31 downto 0) := (others => '0'); -- LCD pixel data
    signal lcd_hcnt      : unsigned(15 downto 0) := (others => '0'); -- H pixel counter
    signal lcd_vcnt      : unsigned(15 downto 0) := (others => '0'); -- V line counter
    signal reg_sel       : integer range 0 to 15;
begin

    reg_sel <= to_integer(unsigned(HADDR(7 downto 4)));

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
            adc_ctrl <= (others => '0'); adc_data_reg <= (others => '0');
            lcd_ctrl <= (others => '0'); lcd_data_reg <= (others => '0');
            lcd_hcnt <= (others => '0'); lcd_vcnt <= (others => '0');
        elsif rising_edge(HCLK) then
            if HSEL = '1' and HREADY = '1' and HWRITE = '1' then
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
                    when 12 => lcd_ctrl     <= HWDATA;     -- LCD_CTRL
                    when 13 => lcd_data_reg <= HWDATA;     -- LCD_DATA (pixel)
                    when others => null;
                end case;
            end if;
            -- ADC capture
            if adc_ctrl(0) = '1' then adc_data_reg <= x"00000" & adc_in; end if;
            -- SPI capture
            if spi_ctrl(0) = '1' then spi_data_reg(0) <= spi_miso; end if;
            uart_status(0) <= '1';
        end if;
    end process;

    -- =========================================================================
    -- AHB-LITE READ MULTIPLEXER
    -- =========================================================================
    process(HSEL, reg_sel, gpio_data_reg, gpio_dir_reg, timer_ctrl, timer_load,
            timer_count, uart_data_reg, uart_status, spi_ctrl, spi_data_reg,
            i2c_ctrl, i2c_data_reg, adc_ctrl, adc_data_reg, lcd_ctrl,
            lcd_data_reg, gpio_in)
    begin
        if HSEL = '1' then
            case reg_sel is
                when 0 => HRDATA <= gpio_data_reg;
                when 1 => HRDATA <= gpio_dir_reg;
                when 2 => HRDATA <= timer_ctrl;
                when 3 => HRDATA <= std_logic_vector(timer_count);
                when 4 => HRDATA <= uart_data_reg;
                when 5 => HRDATA <= uart_status;
                when 6 => HRDATA <= spi_ctrl;
                when 7 => HRDATA <= spi_data_reg;
                when 8 => HRDATA <= i2c_ctrl;
                when 9 => HRDATA <= i2c_data_reg;
                when 10 => HRDATA <= adc_ctrl;
                when 11 => HRDATA <= adc_data_reg;
                when 12 => HRDATA <= lcd_ctrl;
                when 13 => HRDATA <= lcd_data_reg;
                when others => HRDATA <= (others => '0');
            end case;
        else
            HRDATA <= (others => '0');
        end if;
    end process;

    HRESP <= '0'; HREADYOUT <= '1';

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

    -- =========================================================================
    -- LCD CONTROLLER (simplified graphics display interface)
    -- Generates HSYNC, VSYNC, and pixel clock. Outputs 16-bit RGB565 data.
    -- The pixel data is read from lcd_data_reg (simplified: static frame).
    -- In a real implementation, a frame buffer and DMA would feed the data.
    -- =========================================================================
    process(HCLK, HRESETn)
        constant H_MAX : integer := 800; -- Horizontal total pixels (simplified)
        constant V_MAX : integer := 480; -- Vertical total lines (simplified)
    begin
        if HRESETn = '0' then
            lcd_hcnt <= (others => '0');
            lcd_vcnt <= (others => '0');
        elsif rising_edge(HCLK) then
            if lcd_ctrl(0) = '1' then -- LCD enabled
                -- Horizontal counter: counts pixels across each line
                if lcd_hcnt = H_MAX - 1 then
                    lcd_hcnt <= (others => '0');
                    -- Vertical counter: increments at end of each line
                    if lcd_vcnt = V_MAX - 1 then
                        lcd_vcnt <= (others => '0');
                    else
                        lcd_vcnt <= lcd_vcnt + 1;
                    end if;
                else
                    lcd_hcnt <= lcd_hcnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- LCD outputs: data from register, sync signals from counters
    lcd_data  <= lcd_data_reg(15 downto 0);                     -- 16-bit RGB565
    lcd_clk   <= HCLK when lcd_ctrl(0) = '1' else '0';          -- Pixel clock
    lcd_hsync <= '1' when (lcd_hcnt < 96) else '0';             -- HSYNC pulse (96px)
    lcd_vsync <= '1' when (lcd_vcnt < 2) else '0';              -- VSYNC pulse (2 lines)

    -- =========================================================================
    -- UNUSED PERIPHERAL OUTPUTS (S6 does not have DMA, CAN, Ethernet, USB, Security)
    -- =========================================================================
    dma_req <= '0'; can_tx <= '0'; can_int <= '0';
    eth_txd <= (others => '0'); eth_int <= '0';
    usb_dp <= 'Z'; usb_dm <= 'Z'; usb_int <= '0';
    trng_valid <= '0'; secure_boot <= '0';

end architecture rtl;

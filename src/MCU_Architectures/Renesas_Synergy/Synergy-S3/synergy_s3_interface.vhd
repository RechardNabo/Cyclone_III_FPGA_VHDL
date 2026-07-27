-- ================================================================================
-- synergy_s3_interface : Renesas Synergy S3 MCU interface
-- Based on: ARM Cortex-M4 with FPU (mid-range, balanced peripherals)
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- The S3 is a mid-range variant with a full peripheral set suitable for
-- general-purpose embedded applications. It adds SPI to the S2's set.
--
-- Peripheral set (S3 - MID-RANGE):
--   [Y] GPIO  - 32-bit general purpose I/O
--   [Y] Timer - 32-bit timer with interrupt
--   [Y] UART  - Single UART channel
--   [Y] SPI   - SPI master interface
--   [Y] I2C   - I2C master interface
--   [Y] ADC   - 12-bit ADC
--   [N] DMA/CAN/Ethernet/USB/LCD/Security - Not included
--
-- AHB-Lite Register Map:
--   0x00: GPIO_DATA | 0x04: GPIO_DIR | 0x08: TIMER_CTRL | 0x0C: TIMER_LOAD
--   0x10: UART_DATA | 0x14: UART_STATUS | 0x18: SPI_CTRL | 0x1C: SPI_DATA
--   0x20: I2C_CTRL  | 0x24: I2C_DATA  | 0x28: ADC_CTRL  | 0x2C: ADC_DATA
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_s3_interface is
    generic (
        GPIO_WIDTH : integer := 32  -- S3 has full 32-bit GPIO
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
        -- GPIO (32-bit)
        gpio_in  : in  std_logic_vector(31 downto 0);
        gpio_out : out std_logic_vector(31 downto 0);
        gpio_dir : out std_logic_vector(31 downto 0);
        -- Timer
        timer_int : out std_logic;
        -- UART
        uart_txd : out std_logic;  uart_rxd : in std_logic;  uart_int : out std_logic;
        -- SPI (present on S3)
        spi_sclk, spi_mosi : out std_logic;  spi_miso : in std_logic;  spi_int : out std_logic;
        -- I2C (present on S3)
        i2c_sda : inout std_logic;  i2c_scl : inout std_logic;  i2c_int : out std_logic;
        -- ADC (present on S3)
        adc_in  : in  std_logic_vector(11 downto 0);  adc_int : out std_logic;
        -- DMA (NOT present on S3)
        dma_req : out std_logic;  dma_done : in std_logic;
        -- CAN (NOT present on S3)
        can_tx : out std_logic;  can_rx : in std_logic;  can_int : out std_logic;
        -- Ethernet (NOT present on S3)
        eth_txd : out std_logic_vector(3 downto 0);  eth_rxd : in std_logic_vector(3 downto 0);
        eth_int : out std_logic;
        -- USB (NOT present on S3)
        usb_dp, usb_dm : inout std_logic;  usb_int : out std_logic;
        -- LCD (NOT present on S3)
        lcd_data : out std_logic_vector(15 downto 0);
        lcd_hsync, lcd_vsync, lcd_clk : out std_logic;
        -- Security (NOT present on S3)
        trng_valid, secure_boot : out std_logic
    );
end entity synergy_s3_interface;

architecture rtl of synergy_s3_interface is
    -- Peripheral registers
    signal gpio_data_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_dir_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal timer_ctrl    : std_logic_vector(31 downto 0) := (others => '0');
    signal timer_load    : std_logic_vector(31 downto 0) := (others => '0');
    signal timer_count   : unsigned(31 downto 0) := (others => '0');
    signal uart_data_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal uart_status   : std_logic_vector(31 downto 0) := x"00000001";
    signal spi_ctrl      : std_logic_vector(31 downto 0) := (others => '0'); -- SPI control
    signal spi_data_reg  : std_logic_vector(31 downto 0) := (others => '0'); -- SPI TX/RX data
    signal i2c_ctrl      : std_logic_vector(31 downto 0) := (others => '0');
    signal i2c_data_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal adc_ctrl      : std_logic_vector(31 downto 0) := (others => '0');
    signal adc_data_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_sel       : integer range 0 to 15;
begin

    -- Address decoder: HADDR bits [7:4] select register
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
        elsif rising_edge(HCLK) then
            if HSEL = '1' and HREADY = '1' and HWRITE = '1' then
                case reg_sel is
                    when 0 => gpio_data_reg <= HWDATA;     -- GPIO_DATA
                    when 1 => gpio_dir_reg  <= HWDATA;     -- GPIO_DIR
                    when 2 => timer_ctrl    <= HWDATA;     -- TIMER_CTRL
                    when 3 => timer_load    <= HWDATA;     -- TIMER_LOAD
                              timer_count   <= unsigned(HWDATA);
                    when 4 => uart_data_reg <= HWDATA;     -- UART_DATA
                    when 6 => spi_ctrl      <= HWDATA;     -- SPI_CTRL
                    when 7 => spi_data_reg  <= HWDATA;     -- SPI_DATA (TX)
                    when 8 => i2c_ctrl      <= HWDATA;     -- I2C_CTRL
                    when 9 => i2c_data_reg  <= HWDATA;     -- I2C_DATA
                    when 10 => adc_ctrl     <= HWDATA;     -- ADC_CTRL
                    when others => null;
                end case;
            end if;
            -- ADC: capture input when conversion started (ctrl bit0 = start)
            if adc_ctrl(0) = '1' then
                adc_data_reg <= x"00000" & adc_in;
            end if;
            -- SPI: capture MISO into data register when enabled
            if spi_ctrl(0) = '1' then
                spi_data_reg(0) <= spi_miso; -- Simplified: read 1 bit
            end if;
            uart_status(0) <= '1';
        end if;
    end process;

    -- =========================================================================
    -- AHB-LITE READ MULTIPLEXER
    -- =========================================================================
    process(HSEL, reg_sel, gpio_data_reg, gpio_dir_reg, timer_ctrl, timer_load,
            timer_count, uart_data_reg, uart_status, spi_ctrl, spi_data_reg,
            i2c_ctrl, i2c_data_reg, adc_ctrl, adc_data_reg, gpio_in)
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
                when 12 => HRDATA <= gpio_in; -- Full 32-bit GPIO input read
                when others => HRDATA <= (others => '0');
            end case;
        else
            HRDATA <= (others => '0');
        end if;
    end process;

    HRESP <= '0'; HREADYOUT <= '1';

    -- GPIO outputs
    gpio_out <= gpio_data_reg;
    gpio_dir <= gpio_dir_reg;

    -- Timer (countdown with interrupt)
    process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            timer_count <= (others => '0');
        elsif rising_edge(HCLK) then
            if timer_ctrl(0) = '1' then
                if timer_count = 0 then timer_count <= unsigned(timer_load);
                else timer_count <= timer_count - 1; end if;
            end if;
        end if;
    end process;
    timer_int <= '1' when (timer_ctrl(0) = '1' and timer_ctrl(1) = '1'
                           and timer_count = 0) else '0';

    -- UART (simplified)
    uart_txd <= uart_data_reg(0);
    uart_int <= '1' when (uart_status(1) = '1') else '0';

    -- SPI (simplified: SCLK from ctrl bit1, MOSI from data reg bit0)
    spi_sclk <= spi_ctrl(1) when spi_ctrl(0) = '1' else '0';
    spi_mosi <= spi_data_reg(0) when spi_ctrl(0) = '1' else '0';
    spi_int  <= '1' when spi_ctrl(2) = '1' else '0'; -- Interrupt on completion

    -- I2C (simplified)
    i2c_scl <= i2c_ctrl(0) when i2c_ctrl(4) = '1' else 'Z';
    i2c_sda <= i2c_ctrl(1) when i2c_ctrl(4) = '1' else 'Z';
    i2c_int <= '1' when i2c_ctrl(5) = '1' else '0';

    -- ADC interrupt
    adc_int <= '1' when (adc_ctrl(0) = '1' and adc_ctrl(1) = '1') else '0';

    -- =========================================================================
    -- UNUSED PERIPHERAL OUTPUTS (S3 does not have these)
    -- =========================================================================
    dma_req <= '0'; can_tx <= '0'; can_int <= '0';
    eth_txd <= (others => '0'); eth_int <= '0';
    usb_dp <= 'Z'; usb_dm <= 'Z'; usb_int <= '0';
    lcd_data <= (others => '0'); lcd_hsync <= '0'; lcd_vsync <= '0'; lcd_clk <= '0';
    trng_valid <= '0'; secure_boot <= '0';

end architecture rtl;

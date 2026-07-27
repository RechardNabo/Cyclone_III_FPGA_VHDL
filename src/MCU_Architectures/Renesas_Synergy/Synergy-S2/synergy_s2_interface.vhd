-- ================================================================================
-- synergy_s2_interface : Renesas Synergy S2 MCU interface
-- Based on: ARM Cortex-M0+ (low-power, expanded peripherals)
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- The S2 adds I2C and ADC to the S1's minimal set, making it suitable for
-- analog sensor applications that need multi-drop communication.
--
-- Peripheral set (S2 - LOW-POWER):
--   [Y] GPIO  - 24-bit general purpose I/O
--   [Y] Timer - 16-bit timer with interrupt
--   [Y] UART  - Single UART channel
--   [N] SPI   - Not included
--   [Y] I2C   - I2C master interface
--   [Y] ADC   - 12-bit ADC (4 channels multiplexed)
--   [N] DMA/CAN/Ethernet/USB/LCD/Security - Not included
--
-- AHB-Lite Register Map:
--   0x00: GPIO_DATA  | 0x04: GPIO_DIR  | 0x08: TIMER_CTRL | 0x0C: TIMER_LOAD
--   0x10: UART_DATA  | 0x14: UART_STATUS | 0x18: I2C_CTRL | 0x1C: I2C_DATA
--   0x20: ADC_CTRL   | 0x24: ADC_DATA
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_s2_interface is
    generic (
        GPIO_WIDTH : integer := 24  -- S2 has 24-bit GPIO (expanded from S1)
    );
    port (
        -- AHB-Lite bus interface (ARM Cortex-M0+ compatible, active-low reset)
        HCLK, HRESETn, HSEL, HWRITE, HREADY, HMASTLOCK : in std_logic;
        HTRANS : in std_logic_vector(1 downto 0);
        HSIZE  : in std_logic_vector(2 downto 0);
        HPROT  : in std_logic_vector(3 downto 0);
        HADDR  : in std_logic_vector(31 downto 0);
        HWDATA : in std_logic_vector(31 downto 0);
        HRDATA : out std_logic_vector(31 downto 0);
        HRESP  : out std_logic;
        HREADYOUT : out std_logic;
        -- GPIO (24-bit for S2)
        gpio_in  : in  std_logic_vector(31 downto 0);
        gpio_out : out std_logic_vector(31 downto 0);
        gpio_dir : out std_logic_vector(31 downto 0);
        -- Timer
        timer_int : out std_logic;
        -- UART
        uart_txd : out std_logic;  uart_rxd : in std_logic;  uart_int : out std_logic;
        -- SPI (NOT present on S2)
        spi_sclk, spi_mosi : out std_logic;  spi_miso : in std_logic;  spi_int : out std_logic;
        -- I2C (present on S2)
        i2c_sda : inout std_logic;  i2c_scl : inout std_logic;  i2c_int : out std_logic;
        -- ADC (present on S2, 12-bit)
        adc_in  : in  std_logic_vector(11 downto 0);  adc_int : out std_logic;
        -- DMA (NOT present on S2)
        dma_req : out std_logic;  dma_done : in std_logic;
        -- CAN (NOT present on S2)
        can_tx : out std_logic;  can_rx : in std_logic;  can_int : out std_logic;
        -- Ethernet (NOT present on S2)
        eth_txd : out std_logic_vector(3 downto 0);  eth_rxd : in std_logic_vector(3 downto 0);
        eth_int : out std_logic;
        -- USB (NOT present on S2)
        usb_dp, usb_dm : inout std_logic;  usb_int : out std_logic;
        -- LCD (NOT present on S2)
        lcd_data : out std_logic_vector(15 downto 0);
        lcd_hsync, lcd_vsync, lcd_clk : out std_logic;
        -- Security (NOT present on S2)
        trng_valid, secure_boot : out std_logic
    );
end entity synergy_s2_interface;

architecture rtl of synergy_s2_interface is
    -- Peripheral registers
    signal gpio_data_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_dir_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal timer_ctrl    : std_logic_vector(31 downto 0) := (others => '0');
    signal timer_load    : std_logic_vector(31 downto 0) := (others => '0');
    signal timer_count   : unsigned(31 downto 0) := (others => '0');
    signal uart_data_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal uart_status   : std_logic_vector(31 downto 0) := x"00000001";
    signal i2c_ctrl      : std_logic_vector(31 downto 0) := (others => '0'); -- I2C control
    signal i2c_data_reg  : std_logic_vector(31 downto 0) := (others => '0'); -- I2C data
    signal adc_ctrl      : std_logic_vector(31 downto 0) := (others => '0'); -- ADC control
    signal adc_data_reg  : std_logic_vector(31 downto 0) := (others => '0'); -- ADC result
    signal reg_sel       : integer range 0 to 15;
begin

    -- Address decoder: HADDR bits [7:4] select register (16 word-aligned slots)
    reg_sel <= to_integer(unsigned(HADDR(7 downto 4)));

    -- =========================================================================
    -- AHB-LITE WRITE PROCESS: store HWDATA to selected register on write
    -- =========================================================================
    process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            gpio_data_reg <= (others => '0'); gpio_dir_reg <= (others => '0');
            timer_ctrl <= (others => '0'); timer_load <= (others => '0');
            timer_count <= (others => '0');
            uart_data_reg <= (others => '0'); uart_status <= x"00000001";
            i2c_ctrl <= (others => '0'); i2c_data_reg <= (others => '0');
            adc_ctrl <= (others => '0'); adc_data_reg <= (others => '0');
        elsif rising_edge(HCLK) then
            if HSEL = '1' and HREADY = '1' and HWRITE = '1' then
                case reg_sel is
                    when 0 => gpio_data_reg <= HWDATA;          -- GPIO_DATA
                    when 1 => gpio_dir_reg  <= HWDATA;          -- GPIO_DIR
                    when 2 => timer_ctrl    <= HWDATA;          -- TIMER_CTRL
                    when 3 => timer_load    <= HWDATA;          -- TIMER_LOAD
                              timer_count   <= unsigned(HWDATA);
                    when 4 => uart_data_reg <= HWDATA;          -- UART_DATA (TX)
                    when 6 => i2c_ctrl      <= HWDATA;          -- I2C_CTRL
                    when 7 => i2c_data_reg  <= HWDATA;          -- I2C_DATA
                    when 8 => adc_ctrl      <= HWDATA;          -- ADC_CTRL (start conv)
                    when others => null;
                end case;
            end if;
            -- ADC conversion: when ctrl bit0=1, capture adc_in into data reg
            if adc_ctrl(0) = '1' then
                adc_data_reg <= x"00000" & adc_in; -- Store 12-bit ADC value
            end if;
            uart_status(0) <= '1'; -- tx_ready always ready in this model
        end if;
    end process;

    -- =========================================================================
    -- AHB-LITE READ MULTIPLEXER: return selected register on HRDATA
    -- =========================================================================
    process(HSEL, reg_sel, gpio_data_reg, gpio_dir_reg, timer_ctrl, timer_load,
            timer_count, uart_data_reg, uart_status, i2c_ctrl, i2c_data_reg,
            adc_ctrl, adc_data_reg, gpio_in)
    begin
        if HSEL = '1' then
            case reg_sel is
                when 0 => HRDATA <= gpio_data_reg;
                when 1 => HRDATA <= gpio_dir_reg;
                when 2 => HRDATA <= timer_ctrl;
                when 3 => HRDATA <= std_logic_vector(timer_count);
                when 4 => HRDATA <= uart_data_reg;
                when 5 => HRDATA <= uart_status;
                when 6 => HRDATA <= i2c_ctrl;
                when 7 => HRDATA <= i2c_data_reg;
                when 8 => HRDATA <= adc_ctrl;
                when 9 => HRDATA <= adc_data_reg;
                when 10 => HRDATA <= x"00" & gpio_in(23 downto 0); -- GPIO inputs
                when others => HRDATA <= (others => '0');
            end case;
        else
            HRDATA <= (others => '0');
        end if;
    end process;

    HRESP <= '0'; HREADYOUT <= '1'; -- Always OK, single-cycle

    -- GPIO outputs
    gpio_out <= gpio_data_reg;
    gpio_dir <= gpio_dir_reg;

    -- Timer: countdown with interrupt on zero
    process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            timer_count <= (others => '0');
        elsif rising_edge(HCLK) then
            if timer_ctrl(0) = '1' then
                if timer_count = 0 then
                    timer_count <= unsigned(timer_load);
                else
                    timer_count <= timer_count - 1;
                end if;
            end if;
        end if;
    end process;
    timer_int <= '1' when (timer_ctrl(0) = '1' and timer_ctrl(1) = '1'
                           and timer_count = 0) else '0';

    -- UART (simplified model)
    uart_txd <= uart_data_reg(0);
    uart_int <= '1' when (uart_status(1) = '1') else '0';

    -- I2C (simplified model: SDA/SCL driven from control register)
    -- bit0 of i2c_ctrl = SCL, bit1 = SDA output, bit2 = start, bit3 = stop
    i2c_scl <= i2c_ctrl(0) when i2c_ctrl(4) = '1' else 'Z'; -- Output when enabled
    i2c_sda <= i2c_ctrl(1) when i2c_ctrl(4) = '1' else 'Z'; -- Output when enabled
    i2c_int <= '1' when i2c_ctrl(5) = '1' else '0';         -- Interrupt on completion

    -- ADC interrupt: assert when conversion complete (ctrl bit1 = interrupt enable)
    adc_int <= '1' when (adc_ctrl(0) = '1' and adc_ctrl(1) = '1') else '0';

    -- =========================================================================
    -- UNUSED PERIPHERAL OUTPUTS (S2 does not have these)
    -- =========================================================================
    spi_sclk <= '0'; spi_mosi <= '0'; spi_int <= '0';
    dma_req <= '0'; can_tx <= '0'; can_int <= '0';
    eth_txd <= (others => '0'); eth_int <= '0';
    usb_dp <= 'Z'; usb_dm <= 'Z'; usb_int <= '0';
    lcd_data <= (others => '0'); lcd_hsync <= '0'; lcd_vsync <= '0'; lcd_clk <= '0';
    trng_valid <= '0'; secure_boot <= '0';

end architecture rtl;

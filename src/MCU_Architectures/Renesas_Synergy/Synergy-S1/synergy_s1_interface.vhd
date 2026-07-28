-- ================================================================================
-- synergy_s1_interface : Renesas Synergy S1 MCU interface
-- Based on: ARM Cortex-M0+ (ultra-low-power, minimal peripherals)
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- The S1 is the entry-level Synergy variant designed for ultra-low-power
-- applications. It has a minimal peripheral set: GPIO, a simple timer, and
-- one UART. This makes it ideal for battery-powered sensor nodes.
--
-- Peripheral set (S1 - MINIMAL):
--   [Y] GPIO  - 16-bit general purpose I/O (reduced width for low power)
--   [Y] Timer - Basic 16-bit timer with interrupt
--   [Y] UART  - Single UART channel
--   [N] SPI   - Not included (drive spi_* outputs to '0')
--   [N] I2C   - Not included
--   [N] ADC   - Not included
--   [N] DMA   - Not included
--   [N] CAN   - Not included
--   [N] Ethernet - Not included
--   [N] USB   - Not included
--   [N] LCD   - Not included
--   [N] Security - Not included
--
-- AHB-Lite Register Map (word-aligned, offset from base address):
--   0x00: GPIO_DATA  - GPIO output data register (read/write)
--   0x04: GPIO_DIR   - GPIO direction register (1=output, 0=input)
--   0x08: TIMER_CTRL - Timer control: bit0=enable, bit1=interrupt enable
--   0x0C: TIMER_LOAD - Timer load value (counts down from this)
--   0x10: UART_DATA  - UART transmit/receive data register
--   0x14: UART_STATUS- UART status: bit0=tx_ready, bit1=rx_ready
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_s1_interface is
    generic (
        GPIO_WIDTH : integer := 16  -- S1 has reduced GPIO width (ultra-low-power)
    );
    port (
        -- AHB-Lite bus interface (slave side, ARM Cortex-M0+ compatible)
        HCLK      : in  std_logic;                     -- AHB bus clock
        HRESETn   : in  std_logic;                     -- AHB active-low reset (ARM style)
        HSEL      : in  std_logic;                     -- AHB slave select
        HWRITE    : in  std_logic;                     -- 1=write, 0=read
        HREADY    : in  std_logic;                     -- Bus ready from master
        HMASTLOCK : in  std_logic;                     -- Master lock (atomic access)
        HTRANS    : in  std_logic_vector(1 downto 0);  -- Transfer type
        HSIZE     : in  std_logic_vector(2 downto 0);  -- Transfer size
        HPROT     : in  std_logic_vector(3 downto 0);  -- Protection control
        HADDR     : in  std_logic_vector(31 downto 0); -- AHB address bus
        HWDATA    : in  std_logic_vector(31 downto 0); -- AHB write data bus
        HRDATA    : out std_logic_vector(31 downto 0); -- AHB read data bus
        HRESP     : out std_logic;                     -- AHB response (0=OK, 1=ERROR)
        HREADYOUT : out std_logic;                     -- Slave ready output

        -- GPIO interface (16-bit for S1 ultra-low-power variant)
        gpio_in  : in  std_logic_vector(31 downto 0);  -- GPIO input pins (upper bits unused)
        gpio_out : out std_logic_vector(31 downto 0);  -- GPIO output pins
        gpio_dir : out std_logic_vector(31 downto 0);  -- GPIO direction (1=output)

        -- Timer interface
        timer_int : out std_logic;                     -- Timer interrupt output

        -- UART interface (single channel)
        uart_txd : out std_logic;                      -- UART transmit data
        uart_rxd : in  std_logic;                      -- UART receive data
        uart_int : out std_logic;                      -- UART interrupt

        -- SPI interface (NOT present on S1 - drive outputs to '0')
        spi_sclk : out std_logic;
        spi_mosi : out std_logic;
        spi_miso : in  std_logic;
        spi_int  : out std_logic;

        -- I2C interface (NOT present on S1)
        i2c_sda : inout std_logic;
        i2c_scl : inout std_logic;
        i2c_int : out std_logic;

        -- ADC interface (NOT present on S1)
        adc_in  : in  std_logic_vector(11 downto 0);
        adc_int : out std_logic;

        -- DMA interface (NOT present on S1)
        dma_req : out std_logic;
        dma_done: in  std_logic;

        -- CAN interface (NOT present on S1)
        can_tx  : out std_logic;
        can_rx  : in  std_logic;
        can_int : out std_logic;

        -- Ethernet interface (NOT present on S1)
        eth_txd : out std_logic_vector(3 downto 0);
        eth_rxd : in  std_logic_vector(3 downto 0);
        eth_int : out std_logic;

        -- USB interface (NOT present on S1)
        usb_dp  : inout std_logic;
        usb_dm  : inout std_logic;
        usb_int : out std_logic;

        -- LCD interface (NOT present on S1)
        lcd_data : out std_logic_vector(15 downto 0);
        lcd_hsync: out std_logic;
        lcd_vsync: out std_logic;
        lcd_clk  : out std_logic;

        -- Security interface (NOT present on S1)
        trng_valid  : out std_logic;
        secure_boot : out std_logic;

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
end entity synergy_s1_interface;

architecture rtl of synergy_s1_interface is

    -- Peripheral register storage signals
    signal gpio_data_reg : std_logic_vector(31 downto 0) := (others => '0'); -- GPIO output data
    signal gpio_dir_reg  : std_logic_vector(31 downto 0) := (others => '0'); -- GPIO direction
    signal timer_ctrl    : std_logic_vector(31 downto 0) := (others => '0'); -- Timer control
    signal timer_load    : std_logic_vector(31 downto 0) := (others => '0'); -- Timer load value
    signal timer_count   : unsigned(31 downto 0) := (others => '0');         -- Timer counter
    signal uart_data_reg : std_logic_vector(31 downto 0) := (others => '0'); -- UART data buffer
    signal uart_status   : std_logic_vector(31 downto 0) := x"00000001";    -- UART status (tx_ready=1)

    -- Address decode helper: top 8 bits of address select the register
    signal reg_sel : integer range 0 to 15;

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
    signal orig_hsel      : std_logic;
    signal reg_hrdata     : std_logic_vector(31 downto 0);

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
begin

    -- I2S address decode: HADDR(15 downto 12) = "0100" (base 0x4000)
    i2s_hsel  <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0100") else '0';
    -- WDT address decode: HADDR(15 downto 12) = "0101" (base 0x5000)
    wdt_hsel  <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0101") else '0';
    -- RTC address decode: HADDR(15 downto 12) = "0110" (base 0x6000)
    rtc_hsel  <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0110") else '0';
    -- DAC address decode: HADDR(15 downto 12) = "1000" (base 0x8000)
    dac_hsel  <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "1000") else '0';
    -- Original peripherals: everything not decoded above
    orig_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) /= "0100"
                           and HADDR(15 downto 12) /= "0101"
                           and HADDR(15 downto 12) /= "0110"
                           and HADDR(15 downto 12) /= "1000") else '0';

    -- Address decoder: map HADDR bits [7:4] to register index (16 word-aligned regs)
    -- This gives us 16 x 32-bit registers at 16-byte spacing
    reg_sel <= to_integer(unsigned(HADDR(5 downto 2)));

    -- =========================================================================
    -- AHB-LITE SLAVE REGISTER INTERFACE
    -- Handles read and write transactions on the AHB-Lite bus.
    -- On write: decode address and store HWDATA to the selected register.
    -- On read: return the selected register value on HRDATA.
    -- =========================================================================
    process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            -- ARM-style active-low reset: clear all registers
            gpio_data_reg <= (others => '0');
            gpio_dir_reg  <= (others => '0');
            timer_ctrl    <= (others => '0');
            timer_load    <= (others => '0');
            timer_count   <= (others => '0');
            uart_data_reg <= (others => '0');
            uart_status   <= x"00000001"; -- tx_ready=1 after reset
        elsif rising_edge(HCLK) then
            -- Write transaction: orig_hsel=1, HREADY=1, HWRITE=1
            if orig_hsel = '1' and HREADY = '1' and HWRITE = '1' then
                case reg_sel is
                    when 0 => gpio_data_reg <= HWDATA;     -- 0x00: GPIO_DATA
                    when 1 => gpio_dir_reg  <= HWDATA;     -- 0x04: GPIO_DIR
                    when 2 => timer_ctrl    <= HWDATA;     -- 0x08: TIMER_CTRL
                    when 3 => timer_load    <= HWDATA;     -- 0x0C: TIMER_LOAD
                              timer_count   <= unsigned(HWDATA); -- Load counter
                    when 4 => uart_data_reg <= HWDATA;     -- 0x10: UART_DATA (write=TX)
                              uart_status(1) <= '0';       -- Clear rx_ready on write
                    when others => null;                   -- Unmapped: ignore
                end case;
            end if;

            -- Simulate UART receive: set rx_ready when data arrives
            -- (In real hardware this would be driven by a baud-rate sampler)
            uart_status(0) <= '1'; -- tx_ready always ready in this model
        end if;
    end process;

    -- =========================================================================
    -- AHB-LITE READ DATA MULTIPLEXER
    -- Returns the selected register value on HRDATA during read transactions
    -- =========================================================================
    process(orig_hsel, reg_sel, gpio_data_reg, gpio_dir_reg, timer_ctrl,
            timer_load, timer_count, uart_data_reg, uart_status, gpio_in)
    begin
        if orig_hsel = '1' then
            case reg_sel is
                when 0 => reg_hrdata <= gpio_data_reg;              -- Read GPIO output data
                when 1 => reg_hrdata <= gpio_dir_reg;               -- Read GPIO direction
                when 2 => reg_hrdata <= timer_ctrl;                 -- Read timer control
                when 3 => reg_hrdata <= std_logic_vector(timer_count); -- Read timer counter
                when 4 => reg_hrdata <= uart_data_reg;              -- Read UART data (RX)
                when 5 => reg_hrdata <= uart_status;                -- Read UART status
                when 6 => reg_hrdata <= x"0000" & gpio_in(15 downto 0); -- Read GPIO inputs
                when others => reg_hrdata <= (others => '0');       -- Unmapped: return 0
            end case;
        else
            reg_hrdata <= (others => '0'); -- Not selected: return zeros
        end if;
    end process;

    -- AHB-Lite response mux: select between internal registers, I2S, WDT, RTC, DAC
    HRDATA    <= i2s_hrdata when i2s_hsel = '1' else
                 wdt_hrdata when wdt_hsel = '1' else
                 rtc_hrdata when rtc_hsel = '1' else
                 dac_hrdata when dac_hsel = '1' else reg_hrdata;
    HRESP     <= i2s_hresp  when i2s_hsel = '1' else
                 wdt_hresp  when wdt_hsel = '1' else
                 rtc_hresp  when rtc_hsel = '1' else
                 dac_hresp  when dac_hsel = '1' else '0';
    HREADYOUT <= i2s_hreadyout when i2s_hsel = '1' else
                 wdt_hreadyout when wdt_hsel = '1' else
                 rtc_hreadyout when rtc_hsel = '1' else
                 dac_hreadyout when dac_hsel = '1' else '1';

    -- =========================================================================
    -- GPIO PERIPHERAL OUTPUT
    -- Drive GPIO output pins from the data register (only for enabled width)
    -- Upper bits beyond GPIO_WIDTH are driven to 0
    -- =========================================================================
    gpio_out <= gpio_data_reg;
    gpio_dir <= gpio_dir_reg;

    -- =========================================================================
    -- TIMER PERIPHERAL
    -- Simple countdown timer: when enabled, counts down from load value.
    -- When counter reaches 0, generates an interrupt and reloads.
    -- =========================================================================
    process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            timer_count <= (others => '0');
        elsif rising_edge(HCLK) then
            if timer_ctrl(0) = '1' then -- Timer enabled (bit 0 of control reg)
                if timer_count = 0 then
                    timer_count <= unsigned(timer_load); -- Reload from load value
                else
                    timer_count <= timer_count - 1;      -- Decrement counter
                end if;
            end if;
        end if;
    end process;

    -- Timer interrupt: assert when counter reaches 0 and interrupt enable is set
    timer_int <= '1' when (timer_ctrl(0) = '1' and timer_ctrl(1) = '1'
                           and timer_count = 0) else '0';

    -- =========================================================================
    -- UART PERIPHERAL (simplified model)
    -- TX: serializes data from uart_data_reg (model: txd = bit 0 of data reg)
    -- RX: captures rxd into uart_data_reg (model: status bit 1 = rx_ready)
    -- In a real implementation, a baud-rate generator and shift register
    -- would handle proper serial communication.
    -- =========================================================================
    uart_txd <= uart_data_reg(0); -- Simplified: drive LSB of TX data
    uart_int <= '1' when (uart_status(1) = '1') else '0'; -- Interrupt on RX ready

    -- =========================================================================
    -- UNUSED PERIPHERAL OUTPUTS (S1 does not have these)
    -- Drive all unused peripheral outputs to '0' to avoid floating signals
    -- =========================================================================
    spi_sclk <= '0';  spi_mosi <= '0';  spi_int <= '0';
    i2c_sda <= 'Z';   i2c_scl <= 'Z';   i2c_int <= '0';
    adc_int <= '0';
    dma_req <= '0';
    can_tx  <= '0';   can_int <= '0';
    eth_txd <= (others => '0'); eth_int <= '0';
    usb_dp <= 'Z';    usb_dm <= 'Z';    usb_int <= '0';
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

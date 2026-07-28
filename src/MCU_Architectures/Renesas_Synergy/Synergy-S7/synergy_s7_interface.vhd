-- ================================================================================
-- synergy_s7_interface : Renesas Synergy S7 MCU interface
-- Based on: ARM Cortex-M23 with TrustZone (secure variant)
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- The S7 is the secure variant featuring ARM TrustZone technology and a
-- True Random Number Generator (TRNG). It is designed for applications
-- requiring hardware-level security such as IoT authentication and secure boot.
--
-- Peripheral set (S7 - SECURE):
--   [Y] GPIO  - 32-bit | [Y] Timer | [Y] UART | [Y] SPI | [Y] I2C | [Y] ADC
--   [Y] Security - TrustZone secure/non-secure partitioning
--   [Y] TRNG    - True Random Number Generator for cryptographic keys
--   [Y] DMA     - Multi-channel DMA controller
--   [Y] CAN     - CAN 2.0B bus controller (x2 on real S7)
--   [Y] Ethernet - Ethernet MAC with MII interface (x2 on real S7)
--   [Y] USB     - USB 2.0 Full-Speed device controller
--   [N] LCD - Not included
--
-- AHB-Lite Register Map (block-select via HADDR[11:8]):
--   Block 0 (0x000-0x0FF): Original peripherals
--     0x00: GPIO_DATA | 0x04: GPIO_DIR | 0x08: TIMER_CTRL | 0x0C: TIMER_LOAD
--     0x10: UART_DATA | 0x14: UART_STATUS | 0x18: SPI_CTRL | 0x1C: SPI_DATA
--     0x20: I2C_CTRL  | 0x24: I2C_DATA  | 0x28: ADC_CTRL  | 0x2C: ADC_DATA
--     0x30: SEC_CTRL  | 0x34: TRNG_DATA | 0x38: SEC_STATUS
--   Block 1 (0x100-0x1FF): DMA controller registers
--   Block 2 (0x200-0x2FF): CAN controller registers
--   Block 3 (0x300-0x3FF): Ethernet MAC registers
--   Block 4 (0x400-0x4FF): USB device controller registers
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_s7_interface is
    generic (
        GPIO_WIDTH : integer := 32
    );
    port (
        -- AHB-Lite bus interface (ARM Cortex-M23 with TrustZone, active-low reset)
        -- HPROT bit 1 indicates secure vs non-secure access (TrustZone)
        HCLK, HRESETn, HSEL, HWRITE, HREADY, HMASTLOCK : in std_logic;
        HTRANS : in std_logic_vector(1 downto 0);
        HSIZE  : in std_logic_vector(2 downto 0);
        HPROT  : in std_logic_vector(3 downto 0);  -- bit1=secure access indicator
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
        -- SPI (present on S7)
        spi_sclk, spi_mosi : out std_logic;  spi_miso : in std_logic;  spi_int : out std_logic;
        -- I2C (present on S7)
        i2c_sda : inout std_logic;  i2c_scl : inout std_logic;  i2c_int : out std_logic;
        -- ADC (present on S7)
        adc_in  : in  std_logic_vector(11 downto 0);  adc_int : out std_logic;
        -- DMA (present on S7) - bus master interface
        dma_req    : out std_logic;  -- DMA bus master request (= m_req)
        dma_done   : in  std_logic;  -- DMA bus master acknowledge (= m_ack)
        dma_m_addr : out std_logic_vector(31 downto 0);
        dma_m_rdata: in  std_logic_vector(31 downto 0);
        dma_m_wdata: out std_logic_vector(31 downto 0);
        dma_m_we   : out std_logic;
        dma_irq    : out std_logic;  -- OR of all DMA channel interrupts
        -- CAN (present on S7)
        can_tx : out std_logic;  can_rx : in std_logic;  can_int : out std_logic;
        -- Ethernet (present on S7) - MII interface
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
        -- USB (present on S7) - USB 2.0 Full-Speed device
        usb_dp, usb_dm : inout std_logic;  usb_int : out std_logic;
        usb_clk   : in  std_logic;  -- 48 MHz USB clock
        -- LCD (NOT present on S7)
        lcd_data : out std_logic_vector(15 downto 0);
        lcd_hsync, lcd_vsync, lcd_clk : out std_logic;
        -- Security (present on S7 - TrustZone + TRNG)
        trng_valid  : out std_logic;  -- TRNG data valid (new random number ready)
        secure_boot : out std_logic;  -- Secure boot status (1=boot verified)

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
end entity synergy_s7_interface;

architecture rtl of synergy_s7_interface is
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
    signal sec_ctrl      : std_logic_vector(31 downto 0) := (others => '0'); -- Security ctrl
    signal trng_data     : std_logic_vector(31 downto 0) := (others => '0'); -- TRNG output
    signal trng_lfsr     : unsigned(31 downto 0) := x"A5A5A5A5";             -- LFSR state
    signal sec_status    : std_logic_vector(31 downto 0) := (others => '0'); -- Security status
    signal reg_sel       : integer range 0 to 15;

    -- AHB block-select decode (HADDR[11:8] selects peripheral block)
    signal block_sel   : std_logic_vector(3 downto 0);
    signal orig_hsel   : std_logic;
    signal dma_hsel    : std_logic;
    signal can_hsel    : std_logic;
    signal eth_hsel    : std_logic;
    signal usb_hsel    : std_logic;

    -- Peripheral AHB response signals
    signal orig_hrdata    : std_logic_vector(31 downto 0);
    signal dma_hrdata     : std_logic_vector(31 downto 0);
    signal can_hrdata     : std_logic_vector(31 downto 0);
    signal eth_hrdata     : std_logic_vector(31 downto 0);
    signal usb_hrdata     : std_logic_vector(31 downto 0);
    signal dma_hresp      : std_logic;
    signal can_hresp      : std_logic;
    signal eth_hresp      : std_logic;
    signal usb_hresp      : std_logic;
    signal dma_hreadyout  : std_logic;
    signal can_hreadyout  : std_logic;
    signal eth_hreadyout  : std_logic;
    signal usb_hreadyout  : std_logic;

    -- DMA controller internal signals
    constant DMA_NUM_CHANNELS : integer := 4;
    signal dma_int_vec    : std_logic_vector(DMA_NUM_CHANNELS-1 downto 0);
    signal dma_req_in_vec : std_logic_vector(DMA_NUM_CHANNELS-1 downto 0) := (others => '0');

    -- CAN clkout (unused externally)
    signal can_clkout : std_logic;

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
    --   0 = original peripherals (GPIO, Timer, UART, SPI, I2C, ADC, Security)
    --   1 = DMA controller
    --   2 = CAN controller
    --   3 = Ethernet MAC
    --   4 = USB device
    -- =========================================================================
    block_sel <= HADDR(11 downto 8);
    orig_hsel <= HSEL when block_sel = x"0" else '0';
    dma_hsel  <= HSEL when block_sel = x"1" else '0';
    can_hsel  <= HSEL when block_sel = x"2" else '0';
    eth_hsel  <= HSEL when block_sel = x"3" else '0';
    usb_hsel  <= HSEL when block_sel = x"4" else '0';

    reg_sel <= to_integer(unsigned(HADDR(5 downto 2)));

    -- =========================================================================
    -- AHB-LITE WRITE PROCESS (Block 0: original peripherals)
    -- TrustZone: HPROT(1) = 1 indicates secure access. Non-secure accesses
    -- to security registers (0x30-0x38) are blocked and return error.
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
            sec_ctrl <= (others => '0'); trng_data <= (others => '0');
            sec_status <= (others => '0');
        elsif rising_edge(HCLK) then
            if orig_hsel = '1' and HREADY = '1' and HWRITE = '1' then
                -- TrustZone access control: security regs require secure access
                if reg_sel >= 12 and HPROT(1) = '0' then
                    -- Non-secure access to security registers: BLOCKED
                    -- (In real hardware, this would trigger a security fault)
                    null;
                else
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
                        when 12 => sec_ctrl     <= HWDATA;     -- SEC_CTRL (secure only)
                        when others => null;
                    end case;
                end if;
            end if;
            -- ADC capture
            if adc_ctrl(0) = '1' then adc_data_reg <= x"00000" & adc_in; end if;
            -- SPI capture
            if spi_ctrl(0) = '1' then spi_data_reg(0) <= spi_miso; end if;
            uart_status(0) <= '1';
        end if;
    end process;

    -- =========================================================================
    -- TRNG (True Random Number Generator) - simplified LFSR-based model
    -- Uses a 32-bit Linear Feedback Shift Register to generate pseudo-random
    -- numbers. In real hardware, this would use thermal noise or other
    -- physical entropy sources. The LFSR advances each clock cycle when
    -- enabled (sec_ctrl bit0 = TRNG enable).
    -- =========================================================================
    process(HCLK, HRESETn)
        variable feedback : std_logic;
    begin
        if HRESETn = '0' then
            trng_lfsr <= x"A5A5A5A5"; -- Non-zero seed (must not be all zeros)
            trng_data <= (others => '0');
        elsif rising_edge(HCLK) then
            if sec_ctrl(0) = '1' then -- TRNG enabled
                -- Galois LFSR: XOR feedback from taps at positions 31, 21, 1, 0
                feedback := trng_lfsr(0) xor trng_lfsr(1) xor
                            trng_lfsr(21) xor trng_lfsr(31);
                trng_lfsr <= trng_lfsr(30 downto 0) & feedback;
                trng_data <= std_logic_vector(trng_lfsr); -- Output current random value
            end if;
        end if;
    end process;

    -- TRNG valid: high when a new random number is available
    trng_valid <= sec_ctrl(0);

    -- Secure boot status: bit0 of sec_ctrl enables secure boot verification
    -- In this model, secure_boot is asserted when sec_ctrl(1) is set
    secure_boot <= sec_ctrl(1);

    -- Security status: bit0=TRNG ready, bit1=secure boot verified, bit2=TrustZone active
    sec_status(0) <= sec_ctrl(0);
    sec_status(1) <= sec_ctrl(1);
    sec_status(2) <= '1'; -- TrustZone always active in S7

    -- =========================================================================
    -- AHB-LITE READ MULTIPLEXER (Block 0: original peripherals)
    -- Security registers require secure access (HPROT(1) = 1)
    -- =========================================================================
    process(orig_hsel, reg_sel, HPROT, gpio_data_reg, gpio_dir_reg, timer_ctrl,
            timer_load, timer_count, uart_data_reg, uart_status, spi_ctrl,
            spi_data_reg, i2c_ctrl, i2c_data_reg, adc_ctrl, adc_data_reg,
            sec_ctrl, trng_data, sec_status, gpio_in)
    begin
        if orig_hsel = '1' then
            -- TrustZone: block non-secure reads of security registers
            if reg_sel >= 12 and HPROT(1) = '0' then
                orig_hrdata <= (others => '0'); -- Return zeros for non-secure access
            else
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
                    when 12 => orig_hrdata <= sec_ctrl;    -- SEC_CTRL (secure only)
                    when 13 => orig_hrdata <= trng_data;   -- TRNG_DATA (secure only)
                    when 14 => orig_hrdata <= sec_status;  -- SEC_STATUS (secure only)
                    when others => orig_hrdata <= (others => '0');
                end case;
            end if;
        else
            orig_hrdata <= (others => '0');
        end if;
    end process;

    -- =========================================================================
    -- AHB-LITE OUTPUT MULTIPLEXER (selects between peripheral blocks)
    -- =========================================================================
    process(HSEL, i2s_hsel, wdt_hsel, rtc_hsel, dac_hsel, block_sel, orig_hrdata, dma_hrdata, can_hrdata, eth_hrdata,
            usb_hrdata, dma_hresp, can_hresp, eth_hresp, usb_hresp,
            dma_hreadyout, can_hreadyout, eth_hreadyout, usb_hreadyout, HPROT,
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
                    -- TrustZone: return error for blocked non-secure access to security regs
                    HRDATA <= orig_hrdata;
                    HRESP  <= '1' when (reg_sel >= 12 and HPROT(1) = '0') else '0';
                    HREADYOUT <= '1';
                when x"1" =>
                    HRDATA <= dma_hrdata;
                    HRESP  <= dma_hresp;
                    HREADYOUT <= dma_hreadyout;
                when x"2" =>
                    HRDATA <= can_hrdata;
                    HRESP  <= can_hresp;
                    HREADYOUT <= can_hreadyout;
                when x"3" =>
                    HRDATA <= eth_hrdata;
                    HRESP  <= eth_hresp;
                    HREADYOUT <= eth_hreadyout;
                when x"4" =>
                    HRDATA <= usb_hrdata;
                    HRESP  <= usb_hresp;
                    HREADYOUT <= usb_hreadyout;
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
    -- DMA CONTROLLER INSTANCE (Block 1)
    -- Multi-channel DMA with AHB-Lite slave and bus master interface.
    -- The bus master (m_req/m_ack) is exposed via dma_req/dma_done ports.
    -- =========================================================================
    dma_inst : entity work.dma_controller
        generic map (
            NUM_CHANNELS => DMA_NUM_CHANNELS,
            DATA_WIDTH   => 32,
            ADDR_WIDTH   => 32
        )
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
            m_req     => dma_req,
            m_ack     => dma_done,
            dma_int   => dma_int_vec,
            dma_req_in => dma_req_in_vec
        );

    -- OR all DMA channel interrupts into a single IRQ line
    dma_irq <= '0' when (dma_int_vec = (dma_int_vec'range => '0')) else '1';

    -- =========================================================================
    -- CAN CONTROLLER INSTANCE (Block 2)
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
    -- ETHERNET MAC INSTANCE (Block 3)
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
    -- USB DEVICE CONTROLLER INSTANCE (Block 4)
    -- USB 2.0 Full-Speed device controller with 48 MHz usb_clk.
    -- =========================================================================
    usb_inst : entity work.usb_device
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => usb_hsel,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HSIZE     => HSIZE,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => usb_hrdata,
            HRESP     => usb_hresp,
            HREADYOUT => usb_hreadyout,
            usb_dp    => usb_dp,
            usb_dm    => usb_dm,
            usb_clk   => usb_clk,
            usb_int   => usb_int
        );

    -- =========================================================================
    -- UNUSED PERIPHERAL OUTPUTS (S7 does not have LCD)
    -- =========================================================================
    lcd_data <= (others => '0'); lcd_hsync <= '0'; lcd_vsync <= '0'; lcd_clk <= '0';

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

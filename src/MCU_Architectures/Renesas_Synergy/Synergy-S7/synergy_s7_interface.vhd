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
--   [N] DMA/CAN/Ethernet/USB/LCD - Not included
--
-- AHB-Lite Register Map:
--   0x00: GPIO_DATA | 0x04: GPIO_DIR | 0x08: TIMER_CTRL | 0x0C: TIMER_LOAD
--   0x10: UART_DATA | 0x14: UART_STATUS | 0x18: SPI_CTRL | 0x1C: SPI_DATA
--   0x20: I2C_CTRL  | 0x24: I2C_DATA  | 0x28: ADC_CTRL  | 0x2C: ADC_DATA
--   0x30: SEC_CTRL  | 0x34: TRNG_DATA | 0x38: SEC_STATUS
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
        -- DMA (NOT present on S7)
        dma_req : out std_logic;  dma_done : in std_logic;
        -- CAN (NOT present on S7)
        can_tx : out std_logic;  can_rx : in std_logic;  can_int : out std_logic;
        -- Ethernet (NOT present on S7)
        eth_txd : out std_logic_vector(3 downto 0);  eth_rxd : in std_logic_vector(3 downto 0);
        eth_int : out std_logic;
        -- USB (NOT present on S7)
        usb_dp, usb_dm : inout std_logic;  usb_int : out std_logic;
        -- LCD (NOT present on S7)
        lcd_data : out std_logic_vector(15 downto 0);
        lcd_hsync, lcd_vsync, lcd_clk : out std_logic;
        -- Security (present on S7 - TrustZone + TRNG)
        trng_valid  : out std_logic;  -- TRNG data valid (new random number ready)
        secure_boot : out std_logic   -- Secure boot status (1=boot verified)
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
begin

    reg_sel <= to_integer(unsigned(HADDR(7 downto 4)));

    -- =========================================================================
    -- AHB-LITE WRITE PROCESS
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
            if HSEL = '1' and HREADY = '1' and HWRITE = '1' then
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
    -- AHB-LITE READ MULTIPLEXER
    -- Security registers require secure access (HPROT(1) = 1)
    -- =========================================================================
    process(HSEL, reg_sel, HPROT, gpio_data_reg, gpio_dir_reg, timer_ctrl,
            timer_load, timer_count, uart_data_reg, uart_status, spi_ctrl,
            spi_data_reg, i2c_ctrl, i2c_data_reg, adc_ctrl, adc_data_reg,
            sec_ctrl, trng_data, sec_status, gpio_in)
    begin
        if HSEL = '1' then
            -- TrustZone: block non-secure reads of security registers
            if reg_sel >= 12 and HPROT(1) = '0' then
                HRDATA <= (others => '0'); -- Return zeros for non-secure access
            else
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
                    when 12 => HRDATA <= sec_ctrl;    -- SEC_CTRL (secure only)
                    when 13 => HRDATA <= trng_data;   -- TRNG_DATA (secure only)
                    when 14 => HRDATA <= sec_status;  -- SEC_STATUS (secure only)
                    when others => HRDATA <= (others => '0');
                end case;
            end if;
        else
            HRDATA <= (others => '0');
        end if;
    end process;

    -- AHB response: return error for blocked non-secure access to security regs
    HRESP <= '1' when (HSEL = '1' and reg_sel >= 12 and HPROT(1) = '0')
             else '0';
    HREADYOUT <= '1';

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
    -- UNUSED PERIPHERAL OUTPUTS (S7 does not have DMA, CAN, Ethernet, USB, LCD)
    -- =========================================================================
    dma_req <= '0'; can_tx <= '0'; can_int <= '0';
    eth_txd <= (others => '0'); eth_int <= '0';
    usb_dp <= 'Z'; usb_dm <= 'Z'; usb_int <= '0';
    lcd_data <= (others => '0'); lcd_hsync <= '0'; lcd_vsync <= '0'; lcd_clk <= '0';

end architecture rtl;

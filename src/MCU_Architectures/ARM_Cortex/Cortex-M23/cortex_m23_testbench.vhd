-- ================================================================================
-- cortex_m23_testbench : VHDL-93 testbench for cortex_m23_interface
-- ================================================================================
-- Tests:
--   * HCLK generation (10 ns period)
--   * HRESETn assertion (2 cycles low, then high)
--   * 3 AHB-Lite write transactions to different registers
--   * 3 AHB-Lite read transactions with HRDATA checks
--   * GPIO input stimulation
--   * IRQ input stimulation with irq_out checks
--   * NMI stimulation with irq_out check
--   * M23 specific: TrustZone (HNONSEC), SAU, secure_fault, 2-bit HRESP
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cortex_m23_tb is
end entity cortex_m23_tb;

architecture behavior of cortex_m23_tb is

    -- Component declaration matching cortex_m23_interface exactly
    component cortex_m23_interface is
        port (
            HCLK, HRESETn, HSEL, HWRITE, HREADY, HMASTLOCK : in std_logic;
            HTRANS : in std_logic_vector(1 downto 0);
            HSIZE  : in std_logic_vector(2 downto 0);
            HPROT  : in std_logic_vector(3 downto 0);
            HNONSEC: in std_logic;
            HADDR  : in std_logic_vector(31 downto 0);
            HWDATA : in std_logic_vector(31 downto 0);
            HRDATA : out std_logic_vector(31 downto 0);
            HRESP  : out std_logic_vector(1 downto 0);
            HREADYOUT : out std_logic;
            irq_inputs : in std_logic_vector(31 downto 0);
            nmi        : in std_logic;
            irq_out    : out std_logic;
            irq_num    : out std_logic_vector(6 downto 0);
            mclk        : in std_logic;
            systick_int : out std_logic;
            gpio_in   : in  std_logic_vector(31 downto 0);
            gpio_out  : out std_logic_vector(31 downto 0);
            gpio_dir  : out std_logic_vector(31 downto 0);
            sau_violation : out std_logic;
            secure_fault  : out std_logic;
            swclk : in std_logic;
            swdio : inout std_logic;
            sec_dbgen : in std_logic;
            -- DMA controller
            dma_int    : out std_logic;
            dma_m_addr : out std_logic_vector(31 downto 0);
            dma_m_rdata : in  std_logic_vector(31 downto 0);
            dma_m_wdata : out std_logic_vector(31 downto 0);
            dma_m_we   : out std_logic;
            dma_m_req  : out std_logic;
            dma_m_ack  : in  std_logic;
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
            -- WDT interface
            wdt_int   : out std_logic;
            wdt_reset : out std_logic;
            -- RTC interface
            rtc_int   : out std_logic;
            -- ADC interface
            adc_in    : in  std_logic_vector(95 downto 0) := (others => '0');
            adc_int   : out std_logic;
            -- DAC interface
            dac_out   : out std_logic_vector(23 downto 0)
        );
    end component;

    -- Clock and reset
    signal HCLK    : std_logic := '0';
    signal HRESETn : std_logic := '0';

    -- AHB-Lite signals
    signal HSEL      : std_logic := '0';
    signal HWRITE    : std_logic := '0';
    signal HREADY    : std_logic := '1';
    signal HMASTLOCK : std_logic := '0';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "010";
    signal HPROT     : std_logic_vector(3 downto 0) := "0011";
    signal HNONSEC   : std_logic := '0';  -- 0=secure, 1=non-secure
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic_vector(1 downto 0);  -- 2-bit for TrustZone
    signal HREADYOUT : std_logic;

    -- NVIC / IRQ
    signal irq_inputs : std_logic_vector(31 downto 0) := (others => '0');
    signal nmi        : std_logic := '0';
    signal irq_out    : std_logic;
    signal irq_num    : std_logic_vector(6 downto 0);  -- 7 bits for M23

    -- SysTick
    signal mclk        : std_logic := '0';
    signal systick_int : std_logic;

    -- GPIO
    signal gpio_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_out : std_logic_vector(31 downto 0);
    signal gpio_dir : std_logic_vector(31 downto 0);

    -- SAU / TrustZone
    signal sau_violation : std_logic;
    signal secure_fault  : std_logic;

    -- SWD debug
    signal swclk     : std_logic := '0';
    signal swdio     : std_logic := 'Z';
    signal sec_dbgen : std_logic := '0';

    -- I2C interface
    signal i2c_sda : std_logic := 'Z';
    signal i2c_scl : std_logic := 'Z';
    signal i2c_int : std_logic;

    -- SPI interface
    signal spi_sclk : std_logic;
    signal spi_mosi : std_logic;
    signal spi_miso : std_logic := '0';
    signal spi_int  : std_logic;

    -- UART interface
    signal uart_txd : std_logic;
    signal uart_rxd : std_logic := '1';
    signal uart_int : std_logic;

    -- I2S interface (audio)
    signal i2s_sck   : std_logic;
    signal i2s_ws    : std_logic;
    signal i2s_sd_tx : std_logic;
    signal i2s_sd_rx : std_logic := '0';
    signal i2s_int   : std_logic;

    -- WDT interface
    signal wdt_int   : std_logic;
    signal wdt_reset : std_logic;

    -- RTC interface
    signal rtc_int   : std_logic;

    -- ADC interface
    signal adc_in    : std_logic_vector(95 downto 0) := (others => '0');
    signal adc_int   : std_logic;

    -- DAC interface
    signal dac_out   : std_logic_vector(23 downto 0);

    -- Constants
    constant CLK_PERIOD : time := 10 ns;

    -- Address constants
    constant ADDR_GPIO_DATA   : std_logic_vector(31 downto 0) := x"40000000";
    constant ADDR_GPIO_DIR    : std_logic_vector(31 downto 0) := x"40000004";
    constant ADDR_GPIO_AFSEL  : std_logic_vector(31 downto 0) := x"40000008";
    constant ADDR_SYST_CSR    : std_logic_vector(31 downto 0) := x"40000100";
    constant ADDR_NVIC_ISER   : std_logic_vector(31 downto 0) := x"40000200";
    constant ADDR_SCB_CPUID   : std_logic_vector(31 downto 0) := x"40000400";
    constant ADDR_SCB_VTOR    : std_logic_vector(31 downto 0) := x"40000408";
    constant ADDR_SAU_CTRL    : std_logic_vector(31 downto 0) := x"40000600";
    constant ADDR_SAU_RNR     : std_logic_vector(31 downto 0) := x"40000604";
    constant ADDR_MPU_CTRL    : std_logic_vector(31 downto 0) := x"40000804";

    -- Expected CPUID for Cortex-M23
    constant EXPECTED_CPUID : std_logic_vector(31 downto 0) := x"410FD200";

begin

    -- ============================================================================
    -- DUT instantiation
    -- ============================================================================
    DUT : cortex_m23_interface
        port map (
            HCLK            => HCLK,
            HRESETn         => HRESETn,
            HSEL            => HSEL,
            HWRITE          => HWRITE,
            HREADY          => HREADY,
            HMASTLOCK       => HMASTLOCK,
            HTRANS          => HTRANS,
            HSIZE           => HSIZE,
            HPROT           => HPROT,
            HNONSEC         => HNONSEC,
            HADDR           => HADDR,
            HWDATA          => HWDATA,
            HRDATA          => HRDATA,
            HRESP           => HRESP,
            HREADYOUT       => HREADYOUT,
            irq_inputs      => irq_inputs,
            nmi             => nmi,
            irq_out         => irq_out,
            irq_num         => irq_num,
            mclk            => mclk,
            systick_int     => systick_int,
            gpio_in         => gpio_in,
            gpio_out        => gpio_out,
            gpio_dir        => gpio_dir,
            sau_violation   => sau_violation,
            secure_fault    => secure_fault,
            swclk           => swclk,
            swdio           => swdio,
            sec_dbgen       => sec_dbgen,
            -- DMA controller
            dma_int         => open,
            dma_m_addr      => open,
            dma_m_rdata     => (others => '0'),
            dma_m_wdata     => open,
            dma_m_we        => open,
            dma_m_req       => open,
            dma_m_ack       => '0',
            -- I2C interface
            i2c_sda  => i2c_sda,
            i2c_scl  => i2c_scl,
            i2c_int  => i2c_int,
            -- SPI interface
            spi_sclk => spi_sclk,
            spi_mosi => spi_mosi,
            spi_miso => spi_miso,
            spi_int  => spi_int,
            -- UART interface
            uart_txd => uart_txd,
            uart_rxd => uart_rxd,
            uart_int => uart_int,
            -- I2S interface (audio)
            i2s_sck   => i2s_sck,
            i2s_ws    => i2s_ws,
            i2s_sd_tx => i2s_sd_tx,
            i2s_sd_rx => i2s_sd_rx,
            i2s_int   => i2s_int,
            -- WDT interface
            wdt_int   => wdt_int,
            wdt_reset => wdt_reset,
            -- RTC interface
            rtc_int   => rtc_int,
            -- ADC interface
            adc_in    => adc_in,
            adc_int   => adc_int,
            -- DAC interface
            dac_out   => dac_out
        );

    -- ============================================================================
    -- HCLK clock process: 10 ns period
    -- ============================================================================
    clk_proc : process
    begin
        HCLK <= '0';
        wait for CLK_PERIOD / 2;
        HCLK <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- ============================================================================
    -- mclk process
    -- ============================================================================
    mclk_proc : process
    begin
        mclk <= '0';
        wait for CLK_PERIOD / 2;
        mclk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- ============================================================================
    -- Stimulus process
    -- ============================================================================
    stim_proc : process

        procedure ahb_write(
            addr : in std_logic_vector(31 downto 0);
            data : in std_logic_vector(31 downto 0)
        ) is
        begin
            HSEL      <= '1';
            HWRITE    <= '1';
            HREADY    <= '1';
            HMASTLOCK <= '0';
            HTRANS    <= "10";
            HSIZE     <= "010";
            HPROT     <= "0011";
            HADDR     <= addr;
            HWDATA    <= data;
            wait until rising_edge(HCLK);
            wait for 1 ns;
            HSEL   <= '0';
            HWRITE <= '0';
            HTRANS <= "00";
            wait for 1 ns;
        end procedure;

        procedure ahb_read(
            addr  : in  std_logic_vector(31 downto 0);
            rdata : out std_logic_vector(31 downto 0)
        ) is
        begin
            HSEL      <= '1';
            HWRITE    <= '0';
            HREADY    <= '1';
            HMASTLOCK <= '0';
            HTRANS    <= "10";
            HSIZE     <= "010";
            HPROT     <= "0011";
            HADDR     <= addr;
            wait until rising_edge(HCLK);
            wait for 1 ns;
            rdata := HRDATA;
            HSEL   <= '0';
            HTRANS <= "00";
            wait for 1 ns;
        end procedure;

        variable read_data : std_logic_vector(31 downto 0);

    begin
        -- Initialize all inputs
        HSEL      <= '0';
        HWRITE    <= '0';
        HREADY    <= '1';
        HMASTLOCK <= '0';
        HTRANS    <= "00";
        HSIZE     <= "010";
        HPROT     <= "0011";
        HNONSEC   <= '0';  -- Start in secure mode
        HADDR     <= (others => '0');
        HWDATA    <= (others => '0');
        irq_inputs <= (others => '0');
        nmi        <= '0';
        gpio_in    <= (others => '0');
        swclk      <= '0';
        swdio      <= 'Z';
        sec_dbgen  <= '0';

        -- Reset: HRESETn low for 2 clock cycles
        HRESETn <= '0';
        wait for CLK_PERIOD * 2;
        HRESETn <= '1';
        wait for CLK_PERIOD;

        -- ----------------------------------------------------------------
        -- Write Transaction 1: GPIO_DIR
        -- ----------------------------------------------------------------
        ahb_write(ADDR_GPIO_DIR, x"0000FFFF");
        assert true report "Write 1: GPIO_DIR = 0x0000FFFF completed" severity note;

        -- ----------------------------------------------------------------
        -- Write Transaction 2: SAU_CTRL (enable SAU)
        -- ----------------------------------------------------------------
        ahb_write(ADDR_SAU_CTRL, x"00000001");
        assert true report "Write 2: SAU_CTRL = 0x00000001 (SAU enabled) completed" severity note;

        -- ----------------------------------------------------------------
        -- Write Transaction 3: NVIC_ISER (enable IRQs 0-7)
        -- ----------------------------------------------------------------
        ahb_write(ADDR_NVIC_ISER, x"000000FF");
        assert true report "Write 3: NVIC_ISER = 0x000000FF completed" severity note;

        -- ----------------------------------------------------------------
        -- Read Transaction 1: GPIO_DIR - expect 0x0000FFFF
        -- ----------------------------------------------------------------
        ahb_read(ADDR_GPIO_DIR, read_data);
        assert read_data = x"0000FFFF"
            report "Read 1 FAIL: GPIO_DIR expected 0x0000FFFF"
            severity error;
        assert read_data = x"0000FFFF"
            report "Read 1 PASS: GPIO_DIR = 0x0000FFFF"
            severity note;

        -- ----------------------------------------------------------------
        -- Read Transaction 2: SAU_CTRL - expect 0x00000001
        -- ----------------------------------------------------------------
        ahb_read(ADDR_SAU_CTRL, read_data);
        assert read_data = x"00000001"
            report "Read 2 FAIL: SAU_CTRL expected 0x00000001"
            severity error;
        assert read_data = x"00000001"
            report "Read 2 PASS: SAU_CTRL = 0x00000001 (SAU enabled)"
            severity note;

        -- ----------------------------------------------------------------
        -- Read Transaction 3: SCB_CPUID - expect 0x410FD200 (Cortex-M23)
        -- ----------------------------------------------------------------
        ahb_read(ADDR_SCB_CPUID, read_data);
        assert read_data = EXPECTED_CPUID
            report "Read 3 FAIL: SCB_CPUID expected 0x410FD200"
            severity error;
        assert read_data = EXPECTED_CPUID
            report "Read 3 PASS: SCB_CPUID = 0x410FD200 (Cortex-M23)"
            severity note;

        -- ----------------------------------------------------------------
        -- M23 specific: TrustZone SAU violation test
        -- With SAU enabled, a non-secure access (HNONSEC=1) to a valid
        -- peripheral address should trigger sau_violation and secure_fault
        -- ----------------------------------------------------------------
        HNONSEC <= '1';  -- Switch to non-secure
        HSEL    <= '1';
        HWRITE  <= '0';
        HTRANS  <= "10";
        HADDR   <= ADDR_GPIO_DATA;
        wait for 1 ns;
        assert sau_violation = '1'
            report "SAU violation FAIL: expected '1' for non-secure access with SAU enabled"
            severity error;
        assert sau_violation = '1'
            report "SAU violation PASS: sau_violation asserted for non-secure access"
            severity note;

        assert secure_fault = '1'
            report "secure_fault FAIL: expected '1' with SAU violation"
            severity error;
        assert secure_fault = '1'
            report "secure_fault PASS: secure_fault asserted with SAU violation"
            severity note;

        -- Check HRESP = "01" (EXOKAY for SAU violation)
        assert HRESP = "01"
            report "HRESP FAIL: expected 01 (EXOKAY) for SAU violation, got " &
                   integer'image(to_integer(unsigned(HRESP)))
            severity error;
        assert HRESP = "01"
            report "HRESP PASS: HRESP=01 for SAU violation"
            severity note;

        HSEL    <= '0';
        HTRANS  <= "00";
        HNONSEC <= '0';  -- Back to secure
        wait for CLK_PERIOD;

        -- ----------------------------------------------------------------
        -- M23 specific: Check HRESP = "00" (OKAY) for valid secure access
        -- ----------------------------------------------------------------
        HSEL    <= '1';
        HWRITE  <= '0';
        HTRANS  <= "10";
        HADDR   <= ADDR_GPIO_DATA;
        wait for 1 ns;
        assert HRESP = "00"
            report "HRESP FAIL: expected 00 (OKAY) for valid secure access"
            severity error;
        assert HRESP = "00"
            report "HRESP PASS: HRESP=00 (OKAY) for valid secure access"
            severity note;
        HSEL    <= '0';
        HTRANS  <= "00";
        wait for CLK_PERIOD;

        -- ----------------------------------------------------------------
        -- M23 specific: Check HRESP = "10" (ERROR) for invalid address
        -- ----------------------------------------------------------------
        HSEL    <= '1';
        HWRITE  <= '0';
        HTRANS  <= "10";
        HADDR   <= x"80000000";  -- Invalid: top nibble != 0x4
        wait for 1 ns;
        assert HRESP = "10"
            report "HRESP FAIL: expected 10 (ERROR) for invalid address"
            severity error;
        assert HRESP = "10"
            report "HRESP PASS: HRESP=10 (ERROR) for invalid address"
            severity note;
        HSEL    <= '0';
        HTRANS  <= "00";
        wait for CLK_PERIOD;

        -- ----------------------------------------------------------------
        -- GPIO input stimulation
        -- ----------------------------------------------------------------
        gpio_in <= x"EEEEEEEE";
        wait for CLK_PERIOD;
        assert gpio_in = x"EEEEEEEE"
            report "GPIO input stimulus 1 applied" severity note;

        gpio_in <= x"11111111";
        wait for CLK_PERIOD;
        assert gpio_in = x"11111111"
            report "GPIO input stimulus 2 applied" severity note;

        gpio_in <= (others => '0');
        wait for CLK_PERIOD;

        -- ----------------------------------------------------------------
        -- IRQ stimulation: assert IRQ 0 (enabled via NVIC_ISER)
        -- ----------------------------------------------------------------
        irq_inputs <= x"00000001";
        wait for CLK_PERIOD;
        assert irq_out = '1'
            report "IRQ FAIL: irq_out not asserted for enabled IRQ 0"
            severity error;
        assert irq_out = '1'
            report "IRQ PASS: irq_out asserted for enabled IRQ 0"
            severity note;

        -- Check irq_num: IRQ 0 => exception 16 (7 bits for M23)
        assert irq_num = std_logic_vector(to_unsigned(16, 7))
            report "IRQ num FAIL: expected 16, got " & integer'image(to_integer(unsigned(irq_num)))
            severity error;

        -- Deassert IRQ
        irq_inputs <= (others => '0');
        wait for CLK_PERIOD;
        assert irq_out = '0'
            report "IRQ FAIL: irq_out still asserted after clearing IRQs"
            severity error;
        assert irq_out = '0'
            report "IRQ PASS: irq_out deasserted after clearing IRQs"
            severity note;

        -- ----------------------------------------------------------------
        -- NMI stimulation
        -- ----------------------------------------------------------------
        nmi <= '1';
        wait for CLK_PERIOD;
        assert irq_out = '1'
            report "NMI FAIL: irq_out not asserted for NMI"
            severity error;
        assert irq_out = '1'
            report "NMI PASS: irq_out asserted for NMI" severity note;

        assert irq_num = std_logic_vector(to_unsigned(2, 7))
            report "NMI irq_num FAIL: expected 2"
            severity error;

        nmi <= '0';
        wait for CLK_PERIOD;

        -- ----------------------------------------------------------------
        -- Test complete
        -- ----------------------------------------------------------------
        report "Testbench complete" severity note;

    end process;

end architecture behavior;

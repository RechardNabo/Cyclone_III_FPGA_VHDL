-- ================================================================================
-- cortex_m0_testbench : VHDL-93 testbench for cortex_m0_interface
-- ================================================================================
-- Tests:
--   * HCLK generation (10 ns period)
--   * HRESETn assertion (2 cycles low, then high)
--   * 3 AHB-Lite write transactions to different registers
--   * 3 AHB-Lite read transactions with HRDATA checks
--   * GPIO input stimulation
--   * IRQ input stimulation with irq_out checks
--   * NMI stimulation with irq_out check
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cortex_m0_tb is
end entity cortex_m0_tb;

architecture behavior of cortex_m0_tb is

    -- Component declaration matching cortex_m0_interface exactly
    component cortex_m0_interface is
        port (
            HCLK      : in  std_logic;
            HRESETn   : in  std_logic;
            HSEL      : in  std_logic;
            HWRITE    : in  std_logic;
            HREADY    : in  std_logic;
            HMASTLOCK : in  std_logic;
            HTRANS    : in  std_logic_vector(1 downto 0);
            HSIZE     : in  std_logic_vector(2 downto 0);
            HPROT     : in  std_logic_vector(3 downto 0);
            HADDR     : in  std_logic_vector(31 downto 0);
            HWDATA    : in  std_logic_vector(31 downto 0);
            HRDATA    : out std_logic_vector(31 downto 0);
            HRESP     : out std_logic;
            HREADYOUT : out std_logic;
            irq_inputs : in  std_logic_vector(31 downto 0);
            nmi        : in  std_logic;
            irq_out    : out std_logic;
            irq_num    : out std_logic_vector(5 downto 0);
            mclk        : in  std_logic;
            systick_int : out std_logic;
            gpio_in   : in  std_logic_vector(31 downto 0);
            gpio_out  : out std_logic_vector(31 downto 0);
            gpio_dir  : out std_logic_vector(31 downto 0);
            swclk : in  std_logic;
            swdio : inout std_logic;
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
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;

    -- NVIC / IRQ
    signal irq_inputs : std_logic_vector(31 downto 0) := (others => '0');
    signal nmi        : std_logic := '0';
    signal irq_out    : std_logic;
    signal irq_num    : std_logic_vector(5 downto 0);

    -- SysTick
    signal mclk        : std_logic := '0';
    signal systick_int : std_logic;

    -- GPIO
    signal gpio_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_out : std_logic_vector(31 downto 0);
    signal gpio_dir : std_logic_vector(31 downto 0);

    -- SWD
    signal swclk : std_logic := '0';
    signal swdio : std_logic := 'Z';

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

    -- Address constants (based on HADDR(11 downto 4) decode)
    constant ADDR_GPIO_DATA   : std_logic_vector(31 downto 0) := x"40000000";
    constant ADDR_GPIO_DIR    : std_logic_vector(31 downto 0) := x"40000004";
    constant ADDR_GPIO_AFSEL  : std_logic_vector(31 downto 0) := x"40000008";
    constant ADDR_SYST_CSR    : std_logic_vector(31 downto 0) := x"40000100";
    constant ADDR_SYST_RVR    : std_logic_vector(31 downto 0) := x"40000104";
    constant ADDR_NVIC_ISER   : std_logic_vector(31 downto 0) := x"40000200";
    constant ADDR_NVIC_ISPR   : std_logic_vector(31 downto 0) := x"40000204";
    constant ADDR_SCB_CPUID   : std_logic_vector(31 downto 0) := x"40000400";
    constant ADDR_SCB_VTOR    : std_logic_vector(31 downto 0) := x"40000408";

    -- Expected CPUID for Cortex-M0
    constant EXPECTED_CPUID : std_logic_vector(31 downto 0) := x"410CC200";

begin

    -- ============================================================================
    -- DUT instantiation
    -- ============================================================================
    DUT : cortex_m0_interface
        port map (
            HCLK        => HCLK,
            HRESETn     => HRESETn,
            HSEL        => HSEL,
            HWRITE      => HWRITE,
            HREADY      => HREADY,
            HMASTLOCK   => HMASTLOCK,
            HTRANS      => HTRANS,
            HSIZE       => HSIZE,
            HPROT       => HPROT,
            HADDR       => HADDR,
            HWDATA      => HWDATA,
            HRDATA      => HRDATA,
            HRESP       => HRESP,
            HREADYOUT   => HREADYOUT,
            irq_inputs  => irq_inputs,
            nmi         => nmi,
            irq_out     => irq_out,
            irq_num     => irq_num,
            mclk        => mclk,
            systick_int => systick_int,
            gpio_in     => gpio_in,
            gpio_out    => gpio_out,
            gpio_dir    => gpio_dir,
            swclk       => swclk,
            swdio       => swdio,
            -- DMA controller
            dma_int     => open,
            dma_m_addr  => open,
            dma_m_rdata => (others => '0'),
            dma_m_wdata => open,
            dma_m_we    => open,
            dma_m_req   => open,
            dma_m_ack   => '0',
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
    -- HCLK clock process: 10 ns period (5 ns high, 5 ns low)
    -- ============================================================================
    clk_proc : process
    begin
        HCLK <= '0';
        wait for CLK_PERIOD / 2;
        HCLK <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- ============================================================================
    -- mclk process: SysTick reference clock (same 10 ns period)
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

        -- ------------------------------------------------------------------
        -- AHB-Lite write procedure
        -- Sets up address phase and data phase, writes on rising edge
        -- ------------------------------------------------------------------
        procedure ahb_write(
            addr : in std_logic_vector(31 downto 0);
            data : in std_logic_vector(31 downto 0)
        ) is
        begin
            HSEL      <= '1';
            HWRITE    <= '1';
            HREADY    <= '1';
            HMASTLOCK <= '0';
            HTRANS    <= "10";   -- NONSEQ
            HSIZE     <= "010";  -- Word
            HPROT     <= "0011";
            HADDR     <= addr;
            HWDATA    <= data;
            wait until rising_edge(HCLK);
            wait for 1 ns;
            -- Deassert bus after write
            HSEL   <= '0';
            HWRITE <= '0';
            HTRANS <= "00";
            wait for 1 ns;
        end procedure;

        -- ------------------------------------------------------------------
        -- AHB-Lite read procedure
        -- Sets up address phase, reads combinational HRDATA
        -- ------------------------------------------------------------------
        procedure ahb_read(
            addr  : in  std_logic_vector(31 downto 0);
            rdata : out std_logic_vector(31 downto 0)
        ) is
        begin
            HSEL      <= '1';
            HWRITE    <= '0';
            HREADY    <= '1';
            HMASTLOCK <= '0';
            HTRANS    <= "10";   -- NONSEQ
            HSIZE     <= "010";  -- Word
            HPROT     <= "0011";
            HADDR     <= addr;
            wait until rising_edge(HCLK);
            wait for 1 ns;
            rdata := HRDATA;
            -- Deassert bus after read
            HSEL   <= '0';
            HTRANS <= "00";
            wait for 1 ns;
        end procedure;

        variable read_data : std_logic_vector(31 downto 0);

    begin
        -- ----------------------------------------------------------------
        -- Initialize all inputs
        -- ----------------------------------------------------------------
        HSEL      <= '0';
        HWRITE    <= '0';
        HREADY    <= '1';
        HMASTLOCK <= '0';
        HTRANS    <= "00";
        HSIZE     <= "010";
        HPROT     <= "0011";
        HADDR     <= (others => '0');
        HWDATA    <= (others => '0');
        irq_inputs <= (others => '0');
        nmi        <= '0';
        gpio_in    <= (others => '0');
        swclk      <= '0';
        swdio      <= 'Z';

        -- ----------------------------------------------------------------
        -- Reset: HRESETn low for 2 clock cycles, then high
        -- ----------------------------------------------------------------
        HRESETn <= '0';
        wait for CLK_PERIOD * 2;
        HRESETn <= '1';
        wait for CLK_PERIOD;

        -- ----------------------------------------------------------------
        -- Write Transaction 1: GPIO_DIR register
        -- Set pins 15-0 as outputs
        -- ----------------------------------------------------------------
        ahb_write(ADDR_GPIO_DIR, x"0000FFFF");
        assert true report "Write 1: GPIO_DIR = 0x0000FFFF completed" severity note;

        -- ----------------------------------------------------------------
        -- Write Transaction 2: GPIO_DATA register
        -- Write test pattern to GPIO output data
        -- ----------------------------------------------------------------
        ahb_write(ADDR_GPIO_DATA, x"DEADBEEF");
        assert true report "Write 2: GPIO_DATA = 0xDEADBEEF completed" severity note;

        -- ----------------------------------------------------------------
        -- Write Transaction 3: NVIC_ISER register
        -- Enable IRQs 0-7
        -- ----------------------------------------------------------------
        ahb_write(ADDR_NVIC_ISER, x"000000FF");
        assert true report "Write 3: NVIC_ISER = 0x000000FF completed" severity note;

        -- ----------------------------------------------------------------
        -- Read Transaction 1: GPIO_DIR - expect 0x0000FFFF
        -- ----------------------------------------------------------------
        ahb_read(ADDR_GPIO_DIR, read_data);
        assert read_data = x"0000FFFF"
            report "Read 1 FAIL: GPIO_DIR expected 0x0000FFFF, got " &
                   integer'image(to_integer(unsigned(read_data)))
            severity error;
        assert read_data = x"0000FFFF"
            report "Read 1 PASS: GPIO_DIR = 0x0000FFFF"
            severity note;

        -- ----------------------------------------------------------------
        -- Read Transaction 2: GPIO_DATA - expect 0xDEADBEEF
        -- ----------------------------------------------------------------
        ahb_read(ADDR_GPIO_DATA, read_data);
        assert read_data = x"DEADBEEF"
            report "Read 2 FAIL: GPIO_DATA expected 0xDEADBEEF"
            severity error;
        assert read_data = x"DEADBEEF"
            report "Read 2 PASS: GPIO_DATA = 0xDEADBEEF"
            severity note;

        -- ----------------------------------------------------------------
        -- Read Transaction 3: SCB_CPUID - expect 0x410CC200 (Cortex-M0)
        -- ----------------------------------------------------------------
        ahb_read(ADDR_SCB_CPUID, read_data);
        assert read_data = EXPECTED_CPUID
            report "Read 3 FAIL: SCB_CPUID expected 0x410CC200"
            severity error;
        assert read_data = EXPECTED_CPUID
            report "Read 3 PASS: SCB_CPUID = 0x410CC200 (Cortex-M0)"
            severity note;

        -- ----------------------------------------------------------------
        -- GPIO input stimulation
        -- ----------------------------------------------------------------
        gpio_in <= x"AAAAAAAA";
        wait for CLK_PERIOD;
        assert gpio_in = x"AAAAAAAA"
            report "GPIO input stimulus 1 applied"
            severity note;

        gpio_in <= x"55555555";
        wait for CLK_PERIOD;
        assert gpio_in = x"55555555"
            report "GPIO input stimulus 2 applied"
            severity note;

        gpio_in <= x"00000000";
        wait for CLK_PERIOD;

        -- ----------------------------------------------------------------
        -- IRQ stimulation: assert IRQ 0 (enabled via NVIC_ISER)
        -- ----------------------------------------------------------------
        irq_inputs <= x"00000001";  -- IRQ 0
        wait for CLK_PERIOD;
        assert irq_out = '1'
            report "IRQ FAIL: irq_out not asserted when IRQ 0 enabled and asserted"
            severity error;
        assert irq_out = '1'
            report "IRQ PASS: irq_out asserted for enabled IRQ 0"
            severity note;

        -- Check irq_num: IRQ 0 => exception 16 => 0x10
        assert irq_num = std_logic_vector(to_unsigned(16, 6))
            report "IRQ num FAIL: expected 16 (0x10), got " & integer'image(to_integer(unsigned(irq_num)))
            severity error;

        -- ----------------------------------------------------------------
        -- Deassert IRQ input
        -- ----------------------------------------------------------------
        irq_inputs <= (others => '0');
        wait for CLK_PERIOD;
        assert irq_out = '0'
            report "IRQ FAIL: irq_out still asserted after deasserting IRQ inputs"
            severity error;
        assert irq_out = '0'
            report "IRQ PASS: irq_out deasserted after clearing IRQ inputs"
            severity note;

        -- ----------------------------------------------------------------
        -- NMI stimulation
        -- ----------------------------------------------------------------
        nmi <= '1';
        wait for CLK_PERIOD;
        assert irq_out = '1'
            report "NMI FAIL: irq_out not asserted when NMI asserted"
            severity error;
        assert irq_out = '1'
            report "NMI PASS: irq_out asserted for NMI"
            severity note;

        -- Check irq_num for NMI: exception 2
        assert irq_num = std_logic_vector(to_unsigned(2, 6))
            report "NMI irq_num FAIL: expected 2, got " & integer'image(to_integer(unsigned(irq_num)))
            severity error;

        nmi <= '0';
        wait for CLK_PERIOD;

        -- ----------------------------------------------------------------
        -- Verify HRESP for invalid address
        -- ----------------------------------------------------------------
        HSEL   <= '1';
        HWRITE <= '0';
        HTRANS <= "10";
        HADDR  <= x"80000000";  -- Invalid: top nibble != 0x4
        wait for 1 ns;
        assert HRESP = '1'
            report "HRESP FAIL: expected ERROR for invalid address 0x80000000"
            severity error;
        assert HRESP = '1'
            report "HRESP PASS: ERROR response for invalid address"
            severity note;
        HSEL   <= '0';
        HTRANS <= "00";
        wait for CLK_PERIOD;

        -- ----------------------------------------------------------------
        -- Test complete
        -- ----------------------------------------------------------------
        report "Testbench complete" severity note;

    end process;

end architecture behavior;

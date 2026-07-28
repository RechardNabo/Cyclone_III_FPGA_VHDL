-- ================================================================================
-- cortex_m0_interface : Cortex-M0 AHB-Lite peripheral interface (educational)
-- ================================================================================
-- ARMv6-M (Cortex-M0) features modeled here:
--   * Full AHB-Lite slave signals (HSIZE, HTRANS, HPROT, HMASTLOCK, HRESP)
--   * NVIC: 32 external IRQs + NMI, 2 priority levels, enable/pending regs
--   * SysTick: 24-bit down-counter with reload, control, count flag, interrupt
--   * GPIO: 32-bit port with direction, output, input, alternate-function select
--   * SWD debug interface (SWCLK, SWDIO)
--   * Memory map decode: Code / SRAM / Peripheral / System regions
--   * HRESP error response for invalid addresses
--   [Y] DMA - DMA controller for high-speed data transfers
--
-- Memory map (Peripheral space 0x40000000):
--   0x40000000 - 0x4000000F : GPIO  (offset 0x00)
--   0x40000010 - 0x4000001F : SYSTICK (offset 0x10)
--   0x40000020 - 0x4000003F : NVIC  (offset 0x20)
--   0x40000040 - 0x4000005F : SCB   (offset 0x40)
--   0x40000100 - 0x400001FF : DMA   (offset 0x100)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cortex_m0_interface is
    port (
        -- AHB-Lite slave interface
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
        HRESP     : out std_logic;            -- 0=OKAY, 1=ERROR
        HREADYOUT : out std_logic;
        -- NVIC interface
        irq_inputs : in  std_logic_vector(31 downto 0); -- 32 external IRQs
        nmi        : in  std_logic;                    -- Non-Maskable Interrupt
        irq_out    : out std_logic;                    -- Interrupt to CPU
        irq_num    : out std_logic_vector(5 downto 0); -- Exception number
        -- SysTick timer
        mclk        : in  std_logic;                   -- SysTick reference clock
        systick_int : out std_logic;                   -- SysTick interrupt
        -- GPIO port (32-bit)
        gpio_in   : in  std_logic_vector(31 downto 0);
        gpio_out  : out std_logic_vector(31 downto 0);
        gpio_dir  : out std_logic_vector(31 downto 0); -- 1=output, 0=input
        -- SWD debug interface
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
end entity cortex_m0_interface;

architecture rtl of cortex_m0_interface is

    -- ---- Address decode constants (sub-block within HADDR[11:8]=0x0) ----
    constant OFF_GPIO     : std_logic_vector(3 downto 0) := x"0";
    constant OFF_SYSTICK  : std_logic_vector(3 downto 0) := x"1";
    constant OFF_NVIC     : std_logic_vector(3 downto 0) := x"2";
    constant OFF_SCB      : std_logic_vector(3 downto 0) := x"4";

    -- ---- GPIO register offsets (word-aligned within GPIO block) ----
    constant GPIO_DATA   : std_logic_vector(3 downto 0) := x"0"; -- offset 0x00
    constant GPIO_DIR_OFF   : std_logic_vector(3 downto 0) := x"1"; -- offset 0x04
    constant GPIO_AFSEL_OFF : std_logic_vector(3 downto 0) := x"2"; -- offset 0x08

    -- ---- SysTick register offsets ----
    constant SYST_CSR_OFF   : std_logic_vector(3 downto 0) := x"0"; -- Control/Status
    constant SYST_RVR_OFF   : std_logic_vector(3 downto 0) := x"1"; -- Reload Value
    constant SYST_CVR_OFF   : std_logic_vector(3 downto 0) := x"2"; -- Current Value
    constant SYST_CALIB  : std_logic_vector(3 downto 0) := x"3"; -- Calibration

    -- ---- NVIC register offsets ----
    constant NVIC_ISER_OFF  : std_logic_vector(3 downto 0) := x"0"; -- Interrupt Set-Enable
    constant NVIC_ISPR_OFF  : std_logic_vector(3 downto 0) := x"1"; -- Interrupt Set-Pending
    constant NVIC_IPR_OFF   : std_logic_vector(3 downto 0) := x"4"; -- Interrupt Priority

    -- ---- SCB register offsets ----
    constant SCB_CPUID   : std_logic_vector(3 downto 0) := x"0"; -- CPU ID
    constant SCB_ICSR    : std_logic_vector(3 downto 0) := x"1"; -- Interrupt Control/State
    constant SCB_VTOR_OFF   : std_logic_vector(3 downto 0) := x"2"; -- Vector Table Offset

    -- ---- GPIO registers ----
    signal gpio_data_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_dir_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_afsel    : std_logic_vector(31 downto 0) := (others => '0');

    -- ---- SysTick registers ----
    signal syst_csr   : std_logic_vector(31 downto 0) := (others => '0');
    signal syst_rvr   : std_logic_vector(31 downto 0) := (others => '0');
    signal syst_cvr   : unsigned(23 downto 0)         := (others => '0');
    signal syst_countflag : std_logic := '0';

    -- ---- NVIC registers ----
    signal nvic_iser : std_logic_vector(31 downto 0) := (others => '0');
    signal nvic_ispr : std_logic_vector(31 downto 0) := (others => '0');
    signal nvic_ipr  : std_logic_vector(31 downto 0) := (others => '0'); -- 16 x 2-bit priorities packed

    -- ---- SCB registers ----
    signal scb_vtor  : std_logic_vector(31 downto 0) := (others => '0');

    -- ---- Internal helpers ----
    signal addr_off  : std_logic_vector(3 downto 0);
    signal addr_sub  : std_logic_vector(3 downto 0);
    signal block_sel : std_logic_vector(3 downto 0);
    signal write_en  : std_logic;
    signal read_en   : std_logic;
    signal valid_addr: std_logic;
    signal nvic_pending_combined : std_logic_vector(31 downto 0);
    signal highest_irq : integer range 0 to 31;

    -- ---- DMA controller signals ----
    signal dma_hsel      : std_logic;
    signal dma_hrdata    : std_logic_vector(31 downto 0);
    signal dma_hresp     : std_logic;
    signal dma_hreadyout : std_logic;
    signal dma_int_vec   : std_logic_vector(3 downto 0);
    signal orig_hrdata   : std_logic_vector(31 downto 0);

    -- ---- I2C/SPI/UART/I2S AHB peripheral signals ----
    signal i2c_hsel      : std_logic;
    signal i2c_hrdata    : std_logic_vector(31 downto 0);
    signal i2c_hresp     : std_logic;
    signal i2c_hreadyout : std_logic;

    signal spi_hsel      : std_logic;
    signal spi_hrdata    : std_logic_vector(31 downto 0);
    signal spi_hresp     : std_logic;
    signal spi_hreadyout : std_logic;
    signal spi_ss_n      : std_logic_vector(3 downto 0);

    signal uart_hsel      : std_logic;
    signal uart_hrdata    : std_logic_vector(31 downto 0);
    signal uart_hresp     : std_logic;
    signal uart_hreadyout : std_logic;

    signal i2s_hsel      : std_logic;
    signal i2s_hrdata    : std_logic_vector(31 downto 0);
    signal i2s_hresp     : std_logic;
    signal i2s_hreadyout : std_logic;
    signal i2s_mclk_sig  : std_logic;

    -- ---- WDT/RTC/ADC/DAC AHB peripheral signals ----
    signal wdt_hsel      : std_logic;
    signal wdt_hrdata    : std_logic_vector(31 downto 0);
    signal wdt_hresp     : std_logic;
    signal wdt_hreadyout : std_logic;

    signal rtc_hsel      : std_logic;
    signal rtc_hrdata    : std_logic_vector(31 downto 0);
    signal rtc_hresp     : std_logic;
    signal rtc_hreadyout : std_logic;

    signal adc_hsel      : std_logic;
    signal adc_hrdata    : std_logic_vector(31 downto 0);
    signal adc_hresp     : std_logic;
    signal adc_hreadyout : std_logic;

    signal dac_hsel      : std_logic;
    signal dac_hrdata    : std_logic_vector(31 downto 0);
    signal dac_hresp     : std_logic;
    signal dac_hreadyout : std_logic;

begin

    -- Address decode: HADDR[11:8] = block select (256-byte stride), [5:2] = register
    addr_off  <= HADDR(11 downto 8);
    addr_sub  <= HADDR(5 downto 2);
    block_sel <= HADDR(11 downto 8);

    -- Write strobe: active on selected, ready, write, non-idle transfer
    -- Simplified: accept when HSEL=1, HREADY=1, HWRITE=1
    write_en <= HSEL and HREADY and HWRITE;
    read_en  <= HSEL and HREADY and (not HWRITE);

    -- Valid peripheral address (top 4 bits = 0x4 => peripheral space)
    valid_addr <= '1' when HADDR(31 downto 28) = x"4" else '0';

    -- DMA block select: HADDR[11:8] = 0x9 => DMA register block (0x900-0x9FF)
    dma_hsel <= '1' when (HSEL = '1' and valid_addr = '1' and block_sel = x"9") else '0';

    -- Protocol peripheral address decode (HADDR[15:12] selects peripheral)
    i2c_hsel  <= '1' when (HSEL = '1' and valid_addr = '1' and HADDR(15 downto 12) = "0001") else '0';
    spi_hsel  <= '1' when (HSEL = '1' and valid_addr = '1' and HADDR(15 downto 12) = "0010") else '0';
    uart_hsel <= '1' when (HSEL = '1' and valid_addr = '1' and HADDR(15 downto 12) = "0011") else '0';
    i2s_hsel  <= '1' when (HSEL = '1' and valid_addr = '1' and HADDR(15 downto 12) = "0100") else '0';

    -- WDT/RTC/ADC/DAC address decode (HADDR[15:12] selects peripheral)
    wdt_hsel <= '1' when (HSEL = '1' and valid_addr = '1' and HADDR(15 downto 12) = "0101") else '0';
    rtc_hsel <= '1' when (HSEL = '1' and valid_addr = '1' and HADDR(15 downto 12) = "0110") else '0';
    adc_hsel <= '1' when (HSEL = '1' and valid_addr = '1' and HADDR(15 downto 12) = "0111") else '0';
    dac_hsel <= '1' when (HSEL = '1' and valid_addr = '1' and HADDR(15 downto 12) = "1000") else '0';

    -- ------------------------------------------------------------------------
    -- AHB-Lite write process
    -- ------------------------------------------------------------------------
    ahb_write : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            gpio_data_reg <= (others => '0');
            gpio_dir_reg  <= (others => '0');
            gpio_afsel    <= (others => '0');
            syst_csr      <= (others => '0');
            syst_rvr      <= (others => '0');
            syst_cvr      <= (others => '0');
            nvic_iser     <= (others => '0');
            nvic_ispr     <= (others => '0');
            nvic_ipr      <= (others => '0');
            scb_vtor      <= (others => '0');
        elsif rising_edge(HCLK) then
            if write_en = '1' and valid_addr = '1' and block_sel /= x"9" and HADDR(15 downto 12) = "0000" then
                case addr_off is
                    when OFF_GPIO =>
                        case addr_sub is
                            when GPIO_DATA  => gpio_data_reg <= HWDATA;
                            when GPIO_DIR_OFF  => gpio_dir_reg  <= HWDATA;
                            when GPIO_AFSEL_OFF=> gpio_afsel    <= HWDATA;
                            when others     => null;
                        end case;
                    when OFF_SYSTICK =>
                        case addr_sub is
                            when SYST_CSR_OFF=> syst_csr <= HWDATA;
                            when SYST_RVR_OFF=> syst_rvr <= HWDATA;
                            when SYST_CVR_OFF=> syst_cvr <= unsigned(HWDATA(23 downto 0));
                            when others   => null;
                        end case;
                    when OFF_NVIC =>
                        case addr_sub is
                            when NVIC_ISER_OFF=> nvic_iser <= nvic_iser or HWDATA;
                            when NVIC_ISPR_OFF=> nvic_ispr <= nvic_ispr or HWDATA;
                            when NVIC_IPR_OFF => nvic_ipr  <= HWDATA;
                            when others    => null;
                        end case;
                    when OFF_SCB =>
                        case addr_sub is
                            when SCB_VTOR_OFF=> scb_vtor <= HWDATA;
                            when others   => null;
                        end case;
                    when others => null;
                end case;
            end if;
        end if;
    end process ahb_write;

    -- ------------------------------------------------------------------------
    -- AHB-Lite read mux
    -- ------------------------------------------------------------------------
    ahb_read : process(HSEL, HADDR, valid_addr, addr_off, addr_sub,
                       gpio_data_reg, gpio_dir_reg, gpio_afsel,
                       syst_csr, syst_rvr, syst_cvr, syst_countflag,
                       nvic_iser, nvic_ispr, nvic_ipr, scb_vtor,
                       gpio_in)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' and valid_addr = '1' then
            case addr_off is
                when OFF_GPIO =>
                    case addr_sub is
                        when GPIO_DATA  => rdata := gpio_data_reg;
                        when GPIO_DIR_OFF  => rdata := gpio_dir_reg;
                        when GPIO_AFSEL_OFF=> rdata := gpio_afsel;
                        when others     => rdata := (others => '0');
                    end case;
                when OFF_SYSTICK =>
                    case addr_sub is
                        when SYST_CSR_OFF=> rdata := syst_csr;
                        when SYST_RVR_OFF=> rdata := syst_rvr;
                        when SYST_CVR_OFF=> rdata := std_logic_vector(syst_cvr);
                        when others   => rdata := (others => '0');
                    end case;
                when OFF_NVIC =>
                    case addr_sub is
                        when NVIC_ISER_OFF=> rdata := nvic_iser;
                        when NVIC_ISPR_OFF=> rdata := nvic_ispr;
                        when NVIC_IPR_OFF => rdata := nvic_ipr;
                        when others    => rdata := (others => '0');
                    end case;
                when OFF_SCB =>
                    case addr_sub is
                        when SCB_CPUID => rdata := x"410CC200"; -- Cortex-M0 CPUID
                        when SCB_ICSR  => rdata := nvic_ispr;
                        when SCB_VTOR_OFF => rdata := scb_vtor;
                        when others    => rdata := (others => '0');
                    end case;
                when others => rdata := (others => '0');
            end case;
        end if;
        orig_hrdata <= rdata;
    end process ahb_read;

    -- AHB output mux: DMA / protocol peripherals / new peripherals / original
    HRDATA <= dma_hrdata    when dma_hsel = '1'
        else i2c_hrdata  when i2c_hsel = '1'
        else spi_hrdata  when spi_hsel = '1'
        else uart_hrdata when uart_hsel = '1'
        else i2s_hrdata  when i2s_hsel = '1'
        else wdt_hrdata  when wdt_hsel = '1'
        else rtc_hrdata  when rtc_hsel = '1'
        else adc_hrdata  when adc_hsel = '1'
        else dac_hrdata  when dac_hsel = '1'
        else orig_hrdata;

    HRESP <= dma_hresp     when dma_hsel = '1'
        else i2c_hresp  when i2c_hsel = '1'
        else spi_hresp  when spi_hsel = '1'
        else uart_hresp when uart_hsel = '1'
        else i2s_hresp  when i2s_hsel = '1'
        else wdt_hresp  when wdt_hsel = '1'
        else rtc_hresp  when rtc_hsel = '1'
        else adc_hresp  when adc_hsel = '1'
        else dac_hresp  when dac_hsel = '1'
        else '1' when (HSEL = '1' and valid_addr = '0') else '0';

    HREADYOUT <= dma_hreadyout when dma_hsel = '1'
        else i2c_hreadyout when i2c_hsel = '1'
        else spi_hreadyout when spi_hsel = '1'
        else uart_hreadyout when uart_hsel = '1'
        else i2s_hreadyout when i2s_hsel = '1'
        else wdt_hreadyout when wdt_hsel = '1'
        else rtc_hreadyout when rtc_hsel = '1'
        else adc_hreadyout when adc_hsel = '1'
        else dac_hreadyout when dac_hsel = '1'
        else '1';

    -- ------------------------------------------------------------------------
    -- GPIO output: drive pins where direction = output
    -- ------------------------------------------------------------------------
    gpio_out <= gpio_data_reg when gpio_dir_reg(0) = '1' else gpio_data_reg;
    -- (Simplified: data_reg drives output directly; real HW would mask by dir)
    gpio_dir <= gpio_dir_reg;

    -- ------------------------------------------------------------------------
    -- SysTick 24-bit down-counter
    --   CSR bit0 = ENABLE, bit1 = TICKINT, bit2 = CLKSOURCE
    -- ------------------------------------------------------------------------
    systick_proc : process(mclk, HRESETn)
    begin
        if HRESETn = '0' then
            syst_cvr       <= (others => '0');
            syst_countflag <= '0';
        elsif rising_edge(mclk) then
            syst_countflag <= '0';
            if syst_csr(0) = '1' then  -- ENABLE
                if syst_cvr = 0 then
                    syst_cvr       <= unsigned(syst_rvr(23 downto 0));
                    syst_countflag <= '1';
                else
                    syst_cvr <= syst_cvr - 1;
                end if;
            end if;
        end if;
    end process systick_proc;

    -- SysTick interrupt: count flag + TICKINT enabled
    systick_int <= syst_countflag and syst_csr(1);

    -- ------------------------------------------------------------------------
    -- NVIC: combine external IRQs with pending register, find highest priority
    -- ------------------------------------------------------------------------
    nvic_pending_combined <= (nvic_ispr or (irq_inputs and nvic_iser));

    -- Find highest-numbered active+enabled IRQ (simplified priority)
    find_irq : process(nvic_pending_combined, nmi)
        variable found : boolean;
    begin
        found := false;
        highest_irq <= 0;
        if nmi = '1' then
            highest_irq <= 2;  -- NMI = exception 2
            found := true;
        else
            for i in 31 downto 0 loop
                if nvic_pending_combined(i) = '1' and not found then
                    highest_irq <= i;
                    found := true;
                end if;
            end loop;
        end if;
    end process find_irq;

    -- Interrupt output: active if any enabled+pending or NMI
    irq_out  <= '1' when (nmi = '1' or unsigned(nvic_pending_combined) /= 0) else '0';
    -- NMI is exception 2 (no offset); external IRQs map to exceptions 16+
    irq_num  <= std_logic_vector(to_unsigned(highest_irq, 6)) when nmi = '1'
           else std_logic_vector(to_unsigned(highest_irq + 16, 6));

    -- ------------------------------------------------------------------------
    -- SWD debug: minimal pass-through (placeholder for debug access)
    -- ------------------------------------------------------------------------
    swdio <= 'Z';  -- tri-stated by default; real impl would drive during ACK

    -- ------------------------------------------------------------------------
    -- DMA controller instantiation
    --   DMA register block at HADDR[11:8] = 0x9 (offset 0x900-0x9FF)
    -- ------------------------------------------------------------------------
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

    -- Combine 4-channel DMA interrupts into single interrupt output
    dma_int <= dma_int_vec(0) or dma_int_vec(1) or dma_int_vec(2) or dma_int_vec(3);

    -- ------------------------------------------------------------------------
    -- I2C master controller instantiation
    --   I2C register block at HADDR[15:12] = 0x1 (base 0x40001000)
    -- ------------------------------------------------------------------------
    i2c_inst : entity work.i2c_master_ahb
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => i2c_hsel, HWRITE => HWRITE, HREADY => HREADY,
            HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => i2c_hrdata, HRESP => i2c_hresp, HREADYOUT => i2c_hreadyout,
            sda => i2c_sda, scl => i2c_scl,
            i2c_int => i2c_int
        );

    -- ------------------------------------------------------------------------
    -- SPI master controller instantiation
    --   SPI register block at HADDR[15:12] = 0x2 (base 0x40002000)
    -- ------------------------------------------------------------------------
    spi_inst : entity work.spi_master_ahb
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => spi_hsel, HWRITE => HWRITE, HREADY => HREADY,
            HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => spi_hrdata, HRESP => spi_hresp, HREADYOUT => spi_hreadyout,
            sclk => spi_sclk, mosi => spi_mosi, miso => spi_miso,
            ss_n => spi_ss_n,
            spi_int => spi_int
        );

    -- ------------------------------------------------------------------------
    -- UART controller instantiation
    --   UART register block at HADDR[15:12] = 0x3 (base 0x40003000)
    -- ------------------------------------------------------------------------
    uart_inst : entity work.uart_ahb
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => uart_hsel, HWRITE => HWRITE, HREADY => HREADY,
            HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => uart_hrdata, HRESP => uart_hresp, HREADYOUT => uart_hreadyout,
            txd => uart_txd, rxd => uart_rxd,
            uart_int => uart_int
        );

    -- ------------------------------------------------------------------------
    -- I2S master controller instantiation
    --   I2S register block at HADDR[15:12] = 0x4 (base 0x40004000)
    -- ------------------------------------------------------------------------
    i2s_inst : entity work.i2s_master_ahb
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => i2s_hsel, HWRITE => HWRITE, HREADY => HREADY,
            HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => i2s_hrdata, HRESP => i2s_hresp, HREADYOUT => i2s_hreadyout,
            sck => i2s_sck, ws => i2s_ws,
            sd_tx => i2s_sd_tx, sd_rx => i2s_sd_rx,
            mclk => i2s_mclk_sig,
            i2s_int => i2s_int
        );

    -- ------------------------------------------------------------------------
    -- WDT controller instantiation
    --   WDT register block at HADDR[15:12] = 0x5 (base 0x40005000)
    -- ------------------------------------------------------------------------
    wdt_inst : entity work.wdt_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => wdt_hsel, HWRITE => HWRITE, HREADY => HREADY,
            HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => wdt_hrdata, HRESP => wdt_hresp, HREADYOUT => wdt_hreadyout,
            wdt_int => wdt_int, wdt_reset => wdt_reset
        );

    -- ------------------------------------------------------------------------
    -- RTC controller instantiation
    --   RTC register block at HADDR[15:12] = 0x6 (base 0x40006000)
    -- ------------------------------------------------------------------------
    rtc_inst : entity work.rtc_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => rtc_hsel, HWRITE => HWRITE, HREADY => HREADY,
            HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => rtc_hrdata, HRESP => rtc_hresp, HREADYOUT => rtc_hreadyout,
            rtc_int => rtc_int
        );

    -- ------------------------------------------------------------------------
    -- ADC controller instantiation
    --   ADC register block at HADDR[15:12] = 0x7 (base 0x40007000)
    -- ------------------------------------------------------------------------
    adc_inst : entity work.adc_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => adc_hsel, HWRITE => HWRITE, HREADY => HREADY,
            HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => adc_hrdata, HRESP => adc_hresp, HREADYOUT => adc_hreadyout,
            adc_in => adc_in, adc_int => adc_int
        );

    -- ------------------------------------------------------------------------
    -- DAC controller instantiation
    --   DAC register block at HADDR[15:12] = 0x8 (base 0x40008000)
    -- ------------------------------------------------------------------------
    dac_inst : entity work.dac_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            HSEL => dac_hsel, HWRITE => HWRITE, HREADY => HREADY,
            HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => dac_hrdata, HRESP => dac_hresp, HREADYOUT => dac_hreadyout,
            dac_out => dac_out
        );

end architecture rtl;

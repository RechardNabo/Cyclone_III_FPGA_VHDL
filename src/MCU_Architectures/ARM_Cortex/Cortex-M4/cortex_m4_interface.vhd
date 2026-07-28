-- ================================================================================
-- cortex_m4_interface : Cortex-M4 AHB-Lite peripheral interface (educational)
-- ================================================================================
-- ARMv7E-M (Cortex-M4) adds over M3:
--   * FPU (FPv4-SP): FPCCR, FPCAR, FPDSCR, FPSCR, FPU enable, FPU exception
--   * DSP instructions enable (CPACR register)
--   * Data Watchpoint and Trace (DWT): 2 watchpoint comparators
--   * Instrumentation Trace Macrocell (ITM): stimulus ports, ATB output
--   * DMA controller (4-channel, bus master interface)
--   * CAN 2.0B bus controller
--   * Ethernet MAC with 4-bit MII interface
--   * USB 2.0 Full-Speed device controller
--
-- Memory map (Peripheral 0x40000000, HADDR[15:12] selects peripheral page):
--   Page 0x0 (0x40000xxx) - Core peripherals:
--     0x40000000 GPIO | 0x40000010 SYSTICK | 0x40000020 NVIC
--     0x40000040 SCB  | 0x40000060 MPU     | 0x40000080 FAULT
--     0x400000A0 FPU  | 0x400000B0 DWT     | 0x400000C0 ITM
--   Page 0x1 (0x40001xxx) - DMA controller:
--     0x40001000+ch*16 DMA_CTRL/SRC_ADDR/DST_ADDR/COUNT per channel
--     0x40001040 DMA_STATUS | 0x40001044 DMA_IRQ_STATUS | 0x40001048 DMA_IRQ_CLEAR
--   Page 0x2 (0x40002xxx) - CAN controller:
--     0x40002000 CAN_CTRL | 0x40002004 CAN_STATUS | 0x40002008 CAN_BTR
--     0x4000200C CAN_ID | 0x40002010 CAN_DLC | 0x40002014 CAN_DATA_L
--     0x40002018 CAN_DATA_H | 0x4000201C CAN_TX_CTRL | 0x40002020 CAN_RX_CTRL
--     0x40002024 CAN_RX_ID | 0x40002028 CAN_RX_DLC | 0x4000202C CAN_RX_DATA_L
--     0x40002030 CAN_RX_DATA_H | 0x40002034 CAN_ERR_CNT
--     0x40002038 CAN_ACCEPT_MASK | 0x4000203C CAN_ACCEPT_ID
--   Page 0x3 (0x40003xxx) - Ethernet MAC:
--     0x40003000 ETH_CTRL | 0x40003004 ETH_STATUS | 0x40003008 ETH_MAC_ADDR_L
--     0x4000300C ETH_MAC_ADDR_H | 0x40003010 ETH_TX_CTRL | 0x40003014 ETH_TX_LEN
--     0x40003018 ETH_TX_DATA | 0x4000301C ETH_TX_STATUS | 0x40003020 ETH_RX_CTRL
--     0x40003024 ETH_RX_LEN | 0x40003028 ETH_RX_DATA | 0x4000302C ETH_RX_STATUS
--     0x40003030 ETH_IRQ_STATUS | 0x40003034 ETH_IRQ_CLEAR
--     0x40003038 ETH_HASH_L | 0x4000303C ETH_HASH_H
--   Page 0x4 (0x40004xxx) - USB device:
--     0x40004000 USB_CTRL | 0x40004004 USB_ADDR | 0x40004008 USB_STATUS
--     0x4000400C USB_IRQ_STATUS | 0x40004010 USB_IRQ_ENABLE | 0x40004014 USB_IRQ_CLEAR
--     0x40004018 USB_FRAME_NUM | 0x4000401C USB_EP_CTRL | 0x40004020 USB_EP_STATUS
--     0x40004024 USB_EP_DATA | 0x40004028 USB_EP_COUNT | 0x4000402C USB_EP_ADDR
--     0x40004030 USB_EP_MAX_PKT | 0x40004034 USB_EP_FIFO_CTRL
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cortex_m4_interface is
    port (
        HCLK, HRESETn, HSEL, HWRITE, HREADY, HMASTLOCK : in std_logic;
        HTRANS : in std_logic_vector(1 downto 0);
        HSIZE  : in std_logic_vector(2 downto 0);
        HPROT  : in std_logic_vector(3 downto 0);
        HADDR  : in std_logic_vector(31 downto 0);
        HWDATA : in std_logic_vector(31 downto 0);
        HRDATA : out std_logic_vector(31 downto 0);
        HRESP  : out std_logic;
        HREADYOUT : out std_logic;
        -- NVIC
        irq_inputs : in std_logic_vector(31 downto 0);
        nmi        : in std_logic;
        irq_out    : out std_logic;
        irq_num    : out std_logic_vector(8 downto 0);
        -- SysTick
        mclk        : in std_logic;
        systick_int : out std_logic;
        -- GPIO
        gpio_in   : in  std_logic_vector(31 downto 0);
        gpio_out  : out std_logic_vector(31 downto 0);
        gpio_dir  : out std_logic_vector(31 downto 0);
        -- MPU
        mpu_region_violation : out std_logic;
        -- Debug
        tck, tms, tdi : in std_logic;
        tdo : out std_logic;
        swclk : in std_logic;
        swdio : inout std_logic;
        -- Faults
        hardfault, busfault, memfault, usagefault : out std_logic;
        -- M4 specific: FPU
        fpu_enable : out std_logic;
        fpu_int    : out std_logic;
        fpscr      : out std_logic_vector(31 downto 0);
        -- M4 specific: DWT
        dwt_cmp0_addr  : in  std_logic_vector(31 downto 0);
        dwt_cmp0_match : out std_logic;
        dwt_cmp1_addr  : in  std_logic_vector(31 downto 0);
        dwt_cmp1_match : out std_logic;
        -- M4 specific: ITM
        itm_stim0 : in std_logic_vector(31 downto 0);
        itm_stim1 : in std_logic_vector(31 downto 0);
        itm_atb   : out std_logic;
        -- DMA controller
        dma_int    : out std_logic;
        dma_req_in : in  std_logic_vector(3 downto 0);
        m_addr     : out std_logic_vector(31 downto 0);
        m_rdata    : in  std_logic_vector(31 downto 0);
        m_wdata    : out std_logic_vector(31 downto 0);
        m_we       : out std_logic;
        m_req      : out std_logic;
        m_ack      : in  std_logic;
        -- CAN controller
        can_tx     : out std_logic;
        can_rx     : in  std_logic;
        can_clkout : out std_logic;
        can_int    : out std_logic;
        -- Ethernet MAC (MII interface)
        mii_txd    : out std_logic_vector(3 downto 0);
        mii_rxd    : in  std_logic_vector(3 downto 0);
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
        eth_int    : out std_logic;
        -- USB device
        usb_dp     : inout std_logic;
        usb_dm     : inout std_logic;
        usb_clk    : in  std_logic;
        usb_int    : out std_logic;

        -- I2C interface
        i2c_sda : inout std_logic;
        i2c_scl : inout std_logic;
        i2c_int : out std_logic;

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

        -- Power management
        sleep_out  : out std_logic;   -- SLEEPDEEP mode indicator
        sleep_on_exit : out std_logic; -- SLEEPONEXIT bit
        event_on   : out std_logic;   -- SEVONPEND bit

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
end entity cortex_m4_interface;

architecture rtl of cortex_m4_interface is

    constant OFF_GPIO    : std_logic_vector(7 downto 0) := x"00";
    constant OFF_SYSTICK : std_logic_vector(7 downto 0) := x"10";
    constant OFF_NVIC    : std_logic_vector(7 downto 0) := x"20";
    constant OFF_SCB     : std_logic_vector(7 downto 0) := x"40";
    constant OFF_MPU     : std_logic_vector(7 downto 0) := x"60";
    constant OFF_FAULT   : std_logic_vector(7 downto 0) := x"80";
    constant OFF_FPU     : std_logic_vector(7 downto 0) := x"A0";
    constant OFF_DWT     : std_logic_vector(7 downto 0) := x"B0";
    constant OFF_ITM     : std_logic_vector(7 downto 0) := x"C0";

    constant GPIO_DATA  : std_logic_vector(3 downto 0) := x"0";
    constant GPIO_DIR_OFF  : std_logic_vector(3 downto 0) := x"1";
    constant GPIO_AFSEL_OFF: std_logic_vector(3 downto 0) := x"2";

    constant SYST_CSR_OFF: std_logic_vector(3 downto 0) := x"0";
    constant SYST_RVR_OFF: std_logic_vector(3 downto 0) := x"1";
    constant SYST_CVR_OFF: std_logic_vector(3 downto 0) := x"2";

    constant NVIC_ISER_OFF: std_logic_vector(3 downto 0) := x"0";
    constant NVIC_ISPR_OFF: std_logic_vector(3 downto 0) := x"1";
    constant NVIC_ICER : std_logic_vector(3 downto 0) := x"2";
    constant NVIC_ICPR : std_logic_vector(3 downto 0) := x"3";
    constant NVIC_IPR_OFF : std_logic_vector(3 downto 0) := x"4";

    constant SCB_CPUID : std_logic_vector(3 downto 0) := x"0";
    constant SCB_ICSR  : std_logic_vector(3 downto 0) := x"1";
    constant SCB_VTOR_OFF : std_logic_vector(3 downto 0) := x"2";
    constant SCB_CPACR_OFF: std_logic_vector(3 downto 0) := x"3"; -- Coprocessor Access Control
    constant SCB_SCR_OFF  : std_logic_vector(3 downto 0) := x"4"; -- System Control Register

    constant MPU_CTRL : std_logic_vector(3 downto 0) := x"1";
    constant MPU_RNR_OFF : std_logic_vector(3 downto 0) := x"2";
    constant MPU_RBAR_OFF: std_logic_vector(3 downto 0) := x"3";
    constant MPU_RASR_OFF: std_logic_vector(3 downto 0) := x"4";

    constant FAULT_HFSR : std_logic_vector(3 downto 0) := x"0";
    constant FAULT_CFSR : std_logic_vector(3 downto 0) := x"1";

    constant FPU_FPCCR_OFF : std_logic_vector(3 downto 0) := x"0";
    constant FPU_FPCAR_OFF : std_logic_vector(3 downto 0) := x"1";
    constant FPU_FPDSCR_OFF: std_logic_vector(3 downto 0) := x"2";
    constant FPU_FPSCR_OFF : std_logic_vector(3 downto 0) := x"3";

    constant DWT_CTRL_OFF  : std_logic_vector(3 downto 0) := x"0";
    constant DWT_COMP0_OFF : std_logic_vector(3 downto 0) := x"1";
    constant DWT_COMP1_OFF : std_logic_vector(3 downto 0) := x"2";

    constant ITM_STIM0_OFF : std_logic_vector(3 downto 0) := x"0";
    constant ITM_STIM1_OFF : std_logic_vector(3 downto 0) := x"1";
    constant ITM_CTRL_OFF  : std_logic_vector(3 downto 0) := x"2";

    -- GPIO
    signal gpio_data_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_dir_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_afsel    : std_logic_vector(31 downto 0) := (others => '0');

    -- SysTick
    signal syst_csr   : std_logic_vector(31 downto 0) := (others => '0');
    signal syst_rvr   : std_logic_vector(31 downto 0) := (others => '0');
    signal syst_cvr   : unsigned(23 downto 0)         := (others => '0');
    signal syst_countflag : std_logic := '0';

    -- NVIC
    signal nvic_iser : std_logic_vector(31 downto 0) := (others => '0');
    signal nvic_ispr : std_logic_vector(31 downto 0) := (others => '0');
    signal nvic_ipr  : std_logic_vector(31 downto 0) := (others => '0');

    -- SCB
    signal scb_vtor  : std_logic_vector(31 downto 0) := (others => '0');
    signal scb_cpacr : std_logic_vector(31 downto 0) := (others => '0');
    signal scb_scr   : std_logic_vector(31 downto 0) := (others => '0');

    -- MPU
    type mpu_rbar_array is array(0 to 7) of std_logic_vector(31 downto 0);
    type mpu_rasr_array is array(0 to 7) of std_logic_vector(31 downto 0);
    signal mpu_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal mpu_rnr      : integer range 0 to 7 := 0;
    signal mpu_rbar     : mpu_rbar_array := (others => (others => '0'));
    signal mpu_rasr     : mpu_rasr_array := (others => (others => '0'));

    -- Faults
    signal hfsr : std_logic_vector(31 downto 0) := (others => '0');
    signal cfsr : std_logic_vector(31 downto 0) := (others => '0');

    -- FPU
    signal fpu_fpccr  : std_logic_vector(31 downto 0) := (others => '0');
    signal fpu_fpcar  : std_logic_vector(31 downto 0) := (others => '0');
    signal fpu_fpdscr : std_logic_vector(31 downto 0) := (others => '0');
    signal fpu_fpscr  : std_logic_vector(31 downto 0) := (others => '0');

    -- DWT
    signal dwt_ctrl  : std_logic_vector(31 downto 0) := (others => '0');
    signal dwt_comp0 : std_logic_vector(31 downto 0) := (others => '0');
    signal dwt_comp1 : std_logic_vector(31 downto 0) := (others => '0');

    -- ITM
    signal itm_ctrl  : std_logic_vector(31 downto 0) := (others => '0');

    signal addr_off  : std_logic_vector(7 downto 0);
    signal addr_sub  : std_logic_vector(3 downto 0);
    signal write_en  : std_logic;
    signal valid_addr: std_logic;
    signal nvic_pending_combined : std_logic_vector(31 downto 0);
    signal highest_irq : integer range 0 to 31;

    -- Peripheral page select (HADDR[15:12])
    signal periph_page    : std_logic_vector(3 downto 0);
    signal hsel_orig      : std_logic;
    signal hsel_dma       : std_logic;
    signal hsel_can       : std_logic;
    signal hsel_eth       : std_logic;
    signal hsel_usb       : std_logic;

    -- Internal bus mux signals for original peripherals
    signal hrdata_orig    : std_logic_vector(31 downto 0);
    signal hresp_orig     : std_logic;
    signal hreadyout_orig : std_logic;

    -- DMA controller internal signals
    signal dma_hrdata     : std_logic_vector(31 downto 0);
    signal dma_hresp      : std_logic;
    signal dma_hreadyout  : std_logic;
    signal dma_int_vec    : std_logic_vector(3 downto 0);

    -- CAN controller internal signals
    signal can_hrdata     : std_logic_vector(31 downto 0);
    signal can_hresp      : std_logic;
    signal can_hreadyout  : std_logic;

    -- Ethernet MAC internal signals
    signal eth_hrdata     : std_logic_vector(31 downto 0);
    signal eth_hresp      : std_logic;
    signal eth_hreadyout  : std_logic;

    -- USB device internal signals
    signal usb_hrdata     : std_logic_vector(31 downto 0);
    signal usb_hresp      : std_logic;
    signal usb_hreadyout  : std_logic;

    -- I2C controller internal signals
    signal i2c_hrdata     : std_logic_vector(31 downto 0);
    signal i2c_hresp      : std_logic;
    signal i2c_hreadyout  : std_logic;

    -- UART controller internal signals
    signal uart_hrdata    : std_logic_vector(31 downto 0);
    signal uart_hresp     : std_logic;
    signal uart_hreadyout : std_logic;

    -- I2S controller internal signals
    signal i2s_hrdata     : std_logic_vector(31 downto 0);
    signal i2s_hresp      : std_logic;
    signal i2s_hreadyout  : std_logic;
    signal i2s_mclk_int   : std_logic;

    -- Peripheral select for I2C, UART, I2S
    signal hsel_i2c       : std_logic;
    signal hsel_uart      : std_logic;
    signal hsel_i2s       : std_logic;

    -- WDT/RTC/ADC/DAC controller internal signals
    signal wdt_hrdata     : std_logic_vector(31 downto 0);
    signal wdt_hresp      : std_logic;
    signal wdt_hreadyout  : std_logic;

    signal rtc_hrdata     : std_logic_vector(31 downto 0);
    signal rtc_hresp      : std_logic;
    signal rtc_hreadyout  : std_logic;

    signal adc_hrdata     : std_logic_vector(31 downto 0);
    signal adc_hresp      : std_logic;
    signal adc_hreadyout  : std_logic;

    signal dac_hrdata     : std_logic_vector(31 downto 0);
    signal dac_hresp      : std_logic;
    signal dac_hreadyout  : std_logic;

    signal hsel_wdt       : std_logic;
    signal hsel_rtc       : std_logic;
    signal hsel_adc       : std_logic;
    signal hsel_dac       : std_logic;

begin

    addr_off     <= HADDR(11 downto 4);
    addr_sub     <= HADDR(5 downto 2);
    valid_addr   <= '1' when HADDR(31 downto 28) = x"4" else '0';
    periph_page  <= HADDR(15 downto 12);

    -- Peripheral block select: HADDR[15:12] selects peripheral page
    -- Sub-decode on HADDR[11] separates existing and new peripherals on same page
    hsel_orig    <= HSEL when (valid_addr = '1' and periph_page = x"0") else '0';
    hsel_dma     <= HSEL when (valid_addr = '1' and periph_page = x"1" and HADDR(11) = '0') else '0';
    hsel_can     <= HSEL when (valid_addr = '1' and periph_page = x"2") else '0';
    hsel_eth     <= HSEL when (valid_addr = '1' and periph_page = x"3" and HADDR(11) = '0') else '0';
    hsel_usb     <= HSEL when (valid_addr = '1' and periph_page = x"4" and HADDR(11) = '0') else '0';
    hsel_i2c     <= HSEL when (valid_addr = '1' and periph_page = x"1" and HADDR(11) = '1') else '0';
    hsel_uart    <= HSEL when (valid_addr = '1' and periph_page = x"3" and HADDR(11) = '1') else '0';
    hsel_i2s     <= HSEL when (valid_addr = '1' and periph_page = x"4" and HADDR(11) = '1') else '0';

    -- WDT/RTC/ADC/DAC peripheral select (HADDR[15:12] selects peripheral page)
    hsel_wdt     <= HSEL when (valid_addr = '1' and periph_page = x"5") else '0';
    hsel_rtc     <= HSEL when (valid_addr = '1' and periph_page = x"6") else '0';
    hsel_adc     <= HSEL when (valid_addr = '1' and periph_page = x"7") else '0';
    hsel_dac     <= HSEL when (valid_addr = '1' and periph_page = x"8") else '0';

    write_en     <= hsel_orig and HREADY and HWRITE;

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
            scb_cpacr     <= (others => '0');
            scb_scr       <= (others => '0');
            mpu_ctrl_reg  <= (others => '0');
            mpu_rnr       <= 0;
            mpu_rbar      <= (others => (others => '0'));
            mpu_rasr      <= (others => (others => '0'));
            hfsr          <= (others => '0');
            cfsr          <= (others => '0');
            fpu_fpccr     <= (others => '0');
            fpu_fpcar     <= (others => '0');
            fpu_fpdscr    <= (others => '0');
            fpu_fpscr     <= (others => '0');
            dwt_ctrl      <= (others => '0');
            dwt_comp0     <= (others => '0');
            dwt_comp1     <= (others => '0');
            itm_ctrl      <= (others => '0');
        elsif rising_edge(HCLK) then
            if write_en = '1' and valid_addr = '1' then
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
                            when NVIC_ICER => nvic_iser <= nvic_iser and not HWDATA;
                            when NVIC_ICPR => nvic_ispr <= nvic_ispr and not HWDATA;
                            when NVIC_IPR_OFF => nvic_ipr  <= HWDATA;
                            when others    => null;
                        end case;
                    when OFF_SCB =>
                        case addr_sub is
                            when SCB_VTOR_OFF => scb_vtor  <= HWDATA;
                            when SCB_CPACR_OFF=> scb_cpacr <= HWDATA;
                            when SCB_SCR_OFF  => scb_scr   <= HWDATA;
                            when others    => null;
                        end case;
                    when OFF_MPU =>
                        case addr_sub is
                            when MPU_CTRL => mpu_ctrl_reg <= HWDATA;
                            when MPU_RNR_OFF => mpu_rnr <= to_integer(unsigned(HWDATA(2 downto 0)));
                            when MPU_RBAR_OFF=> mpu_rbar(mpu_rnr) <= HWDATA;
                            when MPU_RASR_OFF=> mpu_rasr(mpu_rnr) <= HWDATA;
                            when others   => null;
                        end case;
                    when OFF_FAULT =>
                        case addr_sub is
                            when FAULT_HFSR => hfsr <= HWDATA;
                            when FAULT_CFSR => cfsr <= HWDATA;
                            when others     => null;
                        end case;
                    when OFF_FPU =>
                        case addr_sub is
                            when FPU_FPCCR_OFF => fpu_fpccr  <= HWDATA;
                            when FPU_FPCAR_OFF => fpu_fpcar  <= HWDATA;
                            when FPU_FPDSCR_OFF=> fpu_fpdscr <= HWDATA;
                            when FPU_FPSCR_OFF => fpu_fpscr  <= HWDATA;
                            when others     => null;
                        end case;
                    when OFF_DWT =>
                        case addr_sub is
                            when DWT_CTRL_OFF => dwt_ctrl  <= HWDATA;
                            when DWT_COMP0_OFF=> dwt_comp0 <= HWDATA;
                            when DWT_COMP1_OFF=> dwt_comp1 <= HWDATA;
                            when others    => null;
                        end case;
                    when OFF_ITM =>
                        case addr_sub is
                            when ITM_CTRL_OFF=> itm_ctrl <= HWDATA;
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
    ahb_read : process(hsel_orig, HADDR, addr_off, addr_sub,
                       gpio_data_reg, gpio_dir_reg, gpio_afsel,
                       syst_csr, syst_rvr, syst_cvr,
                       nvic_iser, nvic_ispr, nvic_ipr,
                       scb_vtor, scb_cpacr, scb_scr,
                       mpu_ctrl_reg, mpu_rnr, mpu_rbar, mpu_rasr,
                       hfsr, cfsr,
                       fpu_fpccr, fpu_fpcar, fpu_fpdscr, fpu_fpscr,
                       dwt_ctrl, dwt_comp0, dwt_comp1, itm_ctrl)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if hsel_orig = '1' then
            case addr_off is
                when OFF_GPIO =>
                    case addr_sub is
                        when GPIO_DATA  => rdata := gpio_data_reg;
                        when GPIO_DIR_OFF  => rdata := gpio_dir_reg;
                        when GPIO_AFSEL_OFF=> rdata := gpio_afsel;
                        when others     => null;
                    end case;
                when OFF_SYSTICK =>
                    case addr_sub is
                        when SYST_CSR_OFF=> rdata := syst_csr;
                        when SYST_RVR_OFF=> rdata := syst_rvr;
                        when SYST_CVR_OFF=> rdata := std_logic_vector(syst_cvr);
                        when others   => null;
                    end case;
                when OFF_NVIC =>
                    case addr_sub is
                        when NVIC_ISER_OFF=> rdata := nvic_iser;
                        when NVIC_ISPR_OFF=> rdata := nvic_ispr;
                        when NVIC_ICER => rdata := nvic_iser;
                        when NVIC_ICPR => rdata := nvic_ispr;
                        when NVIC_IPR_OFF => rdata := nvic_ipr;
                        when others    => null;
                    end case;
                when OFF_SCB =>
                    case addr_sub is
                        when SCB_CPUID => rdata := x"410FC240"; -- Cortex-M4 r0p1
                        when SCB_ICSR  => rdata := nvic_ispr;
                        when SCB_VTOR_OFF => rdata := scb_vtor;
                        when SCB_CPACR_OFF=> rdata := scb_cpacr;
                        when SCB_SCR_OFF  => rdata := scb_scr;
                        when others    => null;
                    end case;
                when OFF_MPU =>
                    case addr_sub is
                        when MPU_CTRL => rdata := mpu_ctrl_reg;
                        when MPU_RNR_OFF => rdata := std_logic_vector(to_unsigned(mpu_rnr, 32));
                        when MPU_RBAR_OFF=> rdata := mpu_rbar(mpu_rnr);
                        when MPU_RASR_OFF=> rdata := mpu_rasr(mpu_rnr);
                        when others   => null;
                    end case;
                when OFF_FAULT =>
                    case addr_sub is
                        when FAULT_HFSR => rdata := hfsr;
                        when FAULT_CFSR => rdata := cfsr;
                        when others     => null;
                    end case;
                when OFF_FPU =>
                    case addr_sub is
                        when FPU_FPCCR_OFF => rdata := fpu_fpccr;
                        when FPU_FPCAR_OFF => rdata := fpu_fpcar;
                        when FPU_FPDSCR_OFF=> rdata := fpu_fpdscr;
                        when FPU_FPSCR_OFF => rdata := fpu_fpscr;
                        when others     => null;
                    end case;
                when OFF_DWT =>
                    case addr_sub is
                        when DWT_CTRL_OFF => rdata := dwt_ctrl;
                        when DWT_COMP0_OFF=> rdata := dwt_comp0;
                        when DWT_COMP1_OFF=> rdata := dwt_comp1;
                        when others    => null;
                    end case;
                when OFF_ITM =>
                    case addr_sub is
                        when ITM_CTRL_OFF=> rdata := itm_ctrl;
                        when others   => null;
                    end case;
                when others => null;
            end case;
        end if;
        hrdata_orig <= rdata;
    end process ahb_read;

    hresp_orig     <= '1' when (HSEL = '1' and valid_addr = '0') else '0';
    hreadyout_orig <= '1';

    -- GPIO
    gpio_out <= gpio_data_reg;
    gpio_dir <= gpio_dir_reg;

    -- SysTick
    systick_proc : process(mclk, HRESETn)
    begin
        if HRESETn = '0' then
            syst_cvr       <= (others => '0');
            syst_countflag <= '0';
        elsif rising_edge(mclk) then
            syst_countflag <= '0';
            if syst_csr(0) = '1' then
                if syst_cvr = 0 then
                    syst_cvr       <= unsigned(syst_rvr(23 downto 0));
                    syst_countflag <= '1';
                else
                    syst_cvr <= syst_cvr - 1;
                end if;
            end if;
        end if;
    end process systick_proc;

    systick_int <= syst_countflag and syst_csr(1);

    -- NVIC
    nvic_pending_combined <= (nvic_ispr or (irq_inputs and nvic_iser));

    find_irq : process(nvic_pending_combined, nmi)
        variable found : boolean;
    begin
        found := false;
        highest_irq <= 0;
        if nmi = '1' then
            highest_irq <= 2;
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

    irq_out <= '1' when (nmi = '1' or unsigned(nvic_pending_combined) /= 0) else '0';
    irq_num <= std_logic_vector(to_unsigned(highest_irq, 9)) when nmi = '1'
           else std_logic_vector(to_unsigned(highest_irq + 16, 9));

    -- MPU violation
    mpu_region_violation <= '1' when (mpu_ctrl_reg(0) = '1' and valid_addr = '0' and HSEL = '1') else '0';

    -- Faults
    hardfault  <= hfsr(31) or hfsr(30) or hfsr(1);
    busfault   <= cfsr(15) or cfsr(14) or cfsr(13) or cfsr(12) or cfsr(11) or cfsr(10) or cfsr(9) or cfsr(8) or cfsr(7) or cfsr(2) or cfsr(1);
    memfault   <= cfsr(7) or cfsr(6) or cfsr(5) or cfsr(4) or cfsr(3) or cfsr(2) or cfsr(1) or cfsr(0);
    usagefault <= cfsr(31) or cfsr(30) or cfsr(29) or cfsr(28) or cfsr(27) or cfsr(26) or cfsr(25) or cfsr(24) or cfsr(18) or cfsr(17) or cfsr(16);

    -- FPU: enable from CPACR bits 20-23 (CP10/CP11 full access)
    fpu_enable <= scb_cpacr(23) and scb_cpacr(22) and scb_cpacr(21) and scb_cpacr(20);
    fpu_int    <= fpu_fpscr(3);  -- IOC (Invalid Operation Cumulative) flag
    fpscr      <= fpu_fpscr;

    -- DWT watchpoint comparators
    dwt_cmp0_match <= '1' when (dwt_ctrl(0) = '1' and HADDR = dwt_cmp0_addr) else '0';
    dwt_cmp1_match <= '1' when (dwt_ctrl(0) = '1' and HADDR = dwt_cmp1_addr) else '0';

    -- ITM: ATB valid when stimulus port written
    itm_atb <= '1' when (itm_ctrl(0) = '1' and (unsigned(itm_stim0) /= 0 or unsigned(itm_stim1) /= 0)) else '0';

    -- Debug
    tdo   <= tdi;
    swdio <= 'Z';

    -- Power management: SCB_SCR bits
    -- bit0 = SLEEPONEXIT, bit1 = SLEEPDEEP, bit2 = SEVONPEND
    sleep_out     <= scb_scr(1);  -- SLEEPDEEP
    sleep_on_exit <= scb_scr(0);  -- SLEEPONEXIT
    event_on      <= scb_scr(2);  -- SEVONPEND

    -- ------------------------------------------------------------------------
    -- DMA controller (4-channel, bus master interface)
    -- ------------------------------------------------------------------------
    dma_inst : entity work.dma_controller
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => hsel_dma,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HSIZE     => HSIZE,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => dma_hrdata,
            HRESP     => dma_hresp,
            HREADYOUT => dma_hreadyout,
            m_addr    => m_addr,
            m_rdata   => m_rdata,
            m_wdata   => m_wdata,
            m_we      => m_we,
            m_req     => m_req,
            m_ack     => m_ack,
            dma_int   => dma_int_vec,
            dma_req_in => dma_req_in
        );

    -- OR all channel interrupts into a single DMA interrupt output
    dma_int <= dma_int_vec(0) or dma_int_vec(1) or dma_int_vec(2) or dma_int_vec(3);

    -- ------------------------------------------------------------------------
    -- CAN 2.0B bus controller
    -- ------------------------------------------------------------------------
    can_inst : entity work.can_controller_ahb
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => hsel_can,
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
            can_clkout=> can_clkout,
            can_int   => can_int
        );

    -- ------------------------------------------------------------------------
    -- Ethernet MAC with 4-bit MII interface
    -- ------------------------------------------------------------------------
    eth_inst : entity work.ethernet_mac_ahb
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => hsel_eth,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HSIZE     => HSIZE,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => eth_hrdata,
            HRESP     => eth_hresp,
            HREADYOUT => eth_hreadyout,
            mii_txd   => mii_txd,
            mii_rxd   => mii_rxd,
            mii_tx_en => mii_tx_en,
            mii_tx_clk=> mii_tx_clk,
            mii_rx_clk=> mii_rx_clk,
            mii_rx_dv => mii_rx_dv,
            mii_tx_er => mii_tx_er,
            mii_rx_er => mii_rx_er,
            mii_crs   => mii_crs,
            mii_col   => mii_col,
            mdc       => mdc,
            mdio      => mdio,
            eth_int   => eth_int
        );

    -- ------------------------------------------------------------------------
    -- USB 2.0 Full-Speed device controller
    -- ------------------------------------------------------------------------
    usb_inst : entity work.usb_device
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => hsel_usb,
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

    -- ------------------------------------------------------------------------
    -- I2C master controller (AHB-Lite wrapped)
    -- ------------------------------------------------------------------------
    i2c_inst : entity work.i2c_master_ahb
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => hsel_i2c,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HSIZE     => HSIZE,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => i2c_hrdata,
            HRESP     => i2c_hresp,
            HREADYOUT => i2c_hreadyout,
            sda       => i2c_sda,
            scl       => i2c_scl,
            i2c_int   => i2c_int
        );

    -- ------------------------------------------------------------------------
    -- UART controller (AHB-Lite wrapped)
    -- ------------------------------------------------------------------------
    uart_inst : entity work.uart_ahb
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => hsel_uart,
            HWRITE    => HWRITE,
            HREADY    => HREADY,
            HTRANS    => HTRANS,
            HSIZE     => HSIZE,
            HADDR     => HADDR,
            HWDATA    => HWDATA,
            HRDATA    => uart_hrdata,
            HRESP     => uart_hresp,
            HREADYOUT => uart_hreadyout,
            txd       => uart_txd,
            rxd       => uart_rxd,
            uart_int  => uart_int
        );

    -- ------------------------------------------------------------------------
    -- I2S master controller (AHB-Lite wrapped)
    -- ------------------------------------------------------------------------
    i2s_inst : entity work.i2s_master_ahb
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => hsel_i2s,
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
            mclk      => i2s_mclk_int,
            i2s_int   => i2s_int
        );

    -- ------------------------------------------------------------------------
    -- WDT controller instantiation
    --   WDT register block at HADDR[15:12] = 0x5 (base 0x40005000)
    -- ------------------------------------------------------------------------
    wdt_inst : entity work.wdt_controller
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => hsel_wdt,
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

    -- ------------------------------------------------------------------------
    -- RTC controller instantiation
    --   RTC register block at HADDR[15:12] = 0x6 (base 0x40006000)
    -- ------------------------------------------------------------------------
    rtc_inst : entity work.rtc_controller
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => hsel_rtc,
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

    -- ------------------------------------------------------------------------
    -- ADC controller instantiation
    --   ADC register block at HADDR[15:12] = 0x7 (base 0x40007000)
    -- ------------------------------------------------------------------------
    adc_inst : entity work.adc_controller
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => hsel_adc,
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

    -- ------------------------------------------------------------------------
    -- DAC controller instantiation
    --   DAC register block at HADDR[15:12] = 0x8 (base 0x40008000)
    -- ------------------------------------------------------------------------
    dac_inst : entity work.dac_controller
        port map (
            HCLK      => HCLK,
            HRESETn   => HRESETn,
            HSEL      => hsel_dac,
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

    -- ------------------------------------------------------------------------
    -- AHB bus multiplexer: select HRDATA/HRESP/HREADYOUT from active peripheral
    -- based on HADDR[15:12] (periph_page), sub-decoded by HADDR[11]
    -- ------------------------------------------------------------------------
    ahb_mux : process(periph_page, HADDR(11), hrdata_orig, hresp_orig, hreadyout_orig,
                      dma_hrdata, dma_hresp, dma_hreadyout,
                      can_hrdata, can_hresp, can_hreadyout,
                      eth_hrdata, eth_hresp, eth_hreadyout,
                      usb_hrdata, usb_hresp, usb_hreadyout,
                      i2c_hrdata, i2c_hresp, i2c_hreadyout,
                      uart_hrdata, uart_hresp, uart_hreadyout,
                      i2s_hrdata, i2s_hresp, i2s_hreadyout,
                      wdt_hrdata, wdt_hresp, wdt_hreadyout,
                      rtc_hrdata, rtc_hresp, rtc_hreadyout,
                      adc_hrdata, adc_hresp, adc_hreadyout,
                      dac_hrdata, dac_hresp, dac_hreadyout,
                      HSEL, valid_addr)
    begin
        case periph_page is
            when x"0" =>
                HRDATA     <= hrdata_orig;
                HRESP      <= hresp_orig;
                HREADYOUT  <= hreadyout_orig;
            when x"1" =>
                if HADDR(11) = '0' then
                    HRDATA     <= dma_hrdata;
                    HRESP      <= dma_hresp;
                    HREADYOUT  <= dma_hreadyout;
                else
                    HRDATA     <= i2c_hrdata;
                    HRESP      <= i2c_hresp;
                    HREADYOUT  <= i2c_hreadyout;
                end if;
            when x"2" =>
                HRDATA     <= can_hrdata;
                HRESP      <= can_hresp;
                HREADYOUT  <= can_hreadyout;
            when x"3" =>
                if HADDR(11) = '0' then
                    HRDATA     <= eth_hrdata;
                    HRESP      <= eth_hresp;
                    HREADYOUT  <= eth_hreadyout;
                else
                    HRDATA     <= uart_hrdata;
                    HRESP      <= uart_hresp;
                    HREADYOUT  <= uart_hreadyout;
                end if;
            when x"4" =>
                if HADDR(11) = '0' then
                    HRDATA     <= usb_hrdata;
                    HRESP      <= usb_hresp;
                    HREADYOUT  <= usb_hreadyout;
                else
                    HRDATA     <= i2s_hrdata;
                    HRESP      <= i2s_hresp;
                    HREADYOUT  <= i2s_hreadyout;
                end if;
            when x"5" =>
                HRDATA     <= wdt_hrdata;
                HRESP      <= wdt_hresp;
                HREADYOUT  <= wdt_hreadyout;
            when x"6" =>
                HRDATA     <= rtc_hrdata;
                HRESP      <= rtc_hresp;
                HREADYOUT  <= rtc_hreadyout;
            when x"7" =>
                HRDATA     <= adc_hrdata;
                HRESP      <= adc_hresp;
                HREADYOUT  <= adc_hreadyout;
            when x"8" =>
                HRDATA     <= dac_hrdata;
                HRESP      <= dac_hresp;
                HREADYOUT  <= dac_hreadyout;
            when others =>
                HRDATA     <= (others => '0');
                HRESP      <= '1' when (HSEL = '1' and valid_addr = '1') else '0';
                HREADYOUT  <= '1';
        end case;
    end process ahb_mux;

end architecture rtl;

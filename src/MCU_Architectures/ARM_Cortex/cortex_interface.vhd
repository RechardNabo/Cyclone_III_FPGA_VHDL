-- ================================================================================
-- cortex_interface : Generic configurable AHB-Lite peripheral controller
-- ================================================================================
-- This is a GENERIC Cortex-style interface (not variant-specific).
-- It provides a parameterizable register file, GPIO, and interrupt aggregator
-- that can be used as a building block for any ARM Cortex-M peripheral.
--
-- Generics:
--   NUM_REGS   : number of 32-bit registers in the register file (default 8)
--   GPIO_WIDTH : width of the GPIO port (default 32)
--   NUM_IRQ    : number of interrupt inputs to aggregate (default 16)
--
-- Memory map (Peripheral 0x40000000):
--   0x40000000 - 0x400000xx : Register file (NUM_REGS x 4 bytes)
--   0x40000100 - 0x4000010F : GPIO (data, dir, afsel)
--   0x40000200 - 0x4000020F : Interrupt aggregator (enable, pending, status)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cortex_interface is
    generic (
        NUM_REGS   : integer := 8;
        GPIO_WIDTH : integer := 32;
        NUM_IRQ    : integer := 16
    );
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
        -- Interrupt aggregator
        irq_inputs : in  std_logic_vector(NUM_IRQ-1 downto 0);
        irq_out    : out std_logic;
        -- GPIO
        gpio_in   : in  std_logic_vector(GPIO_WIDTH-1 downto 0);
        gpio_out  : out std_logic_vector(GPIO_WIDTH-1 downto 0);
        gpio_dir  : out std_logic_vector(GPIO_WIDTH-1 downto 0);

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
end entity cortex_interface;

architecture rtl of cortex_interface is

    -- Address block selects (bits [11:8])
    constant BLK_REGS : std_logic_vector(3 downto 0) := x"0"; -- 0x40000000
    constant BLK_GPIO : std_logic_vector(3 downto 0) := x"1"; -- 0x40000100
    constant BLK_IRQ  : std_logic_vector(3 downto 0) := x"2"; -- 0x40000200

    -- GPIO sub-register selects (bits [5:2])
    constant GPIO_DATA   : std_logic_vector(3 downto 0) := x"0";
    constant GPIO_DIR_OFF  : std_logic_vector(3 downto 0) := x"1";
    constant GPIO_AFSEL_OFF: std_logic_vector(3 downto 0) := x"2";

    -- IRQ sub-register selects
    constant IRQ_ENABLE_OFF  : std_logic_vector(3 downto 0) := x"0";
    constant IRQ_PENDING_OFF : std_logic_vector(3 downto 0) := x"1";
    constant IRQ_STATUS_OFF  : std_logic_vector(3 downto 0) := x"2";

    -- Register file storage
    type reg_file_array is array(0 to NUM_REGS-1) of std_logic_vector(31 downto 0);
    signal reg_file : reg_file_array := (others => (others => '0'));

    -- GPIO registers (extended to 32 bits internally, masked on output)
    signal gpio_data_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_dir_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_afsel    : std_logic_vector(31 downto 0) := (others => '0');

    -- Interrupt aggregator registers
    signal irq_enable  : std_logic_vector(31 downto 0) := (others => '0');
    signal irq_pending : std_logic_vector(31 downto 0) := (others => '0');

    -- Address decode
    signal addr_blk  : std_logic_vector(3 downto 0);
    signal addr_sub  : std_logic_vector(3 downto 0);
    signal reg_index : integer range 0 to NUM_REGS-1;
    signal write_en  : std_logic;
    signal valid_addr: std_logic;
    signal irq_combined : std_logic_vector(31 downto 0);
    signal zero_pad     : std_logic_vector(31 downto 0) := (others => '0');

    -- WDT/RTC/ADC/DAC AHB peripheral signals
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

    signal orig_hrdata   : std_logic_vector(31 downto 0);

begin

    addr_blk <= HADDR(11 downto 8);
    addr_sub <= HADDR(5 downto 2);
    reg_index <= to_integer(unsigned(HADDR(7 downto 2))) when
                 to_integer(unsigned(HADDR(7 downto 2))) < NUM_REGS else 0;
    write_en <= HSEL and HREADY and HWRITE;
    valid_addr <= '1' when HADDR(31 downto 28) = x"4" else '0';

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
            reg_file       <= (others => (others => '0'));
            gpio_data_reg  <= (others => '0');
            gpio_dir_reg   <= (others => '0');
            gpio_afsel     <= (others => '0');
            irq_enable     <= (others => '0');
            irq_pending    <= (others => '0');
        elsif rising_edge(HCLK) then
            if write_en = '1' and valid_addr = '1' and HADDR(15 downto 12) = "0000" then
                case addr_blk is
                    when BLK_REGS =>
                        if to_integer(unsigned(HADDR(7 downto 2))) < NUM_REGS then
                            reg_file(reg_index) <= HWDATA;
                        end if;
                    when BLK_GPIO =>
                        case addr_sub is
                            when GPIO_DATA     => gpio_data_reg <= HWDATA;
                            when GPIO_DIR_OFF  => gpio_dir_reg  <= HWDATA;
                            when GPIO_AFSEL_OFF=> gpio_afsel    <= HWDATA;
                            when others     => null;
                        end case;
                    when BLK_IRQ =>
                        case addr_sub is
                            when IRQ_ENABLE_OFF  => irq_enable  <= irq_enable or HWDATA;
                            when IRQ_PENDING_OFF => irq_pending <= irq_pending or HWDATA;
                            when IRQ_STATUS_OFF  => irq_pending <= irq_pending and not HWDATA; -- clear
                            when others      => null;
                        end case;
                    when others => null;
                end case;
            end if;
        end if;
    end process ahb_write;

    -- ------------------------------------------------------------------------
    -- AHB-Lite read mux
    -- ------------------------------------------------------------------------
    ahb_read : process(HSEL, HADDR, valid_addr, addr_blk, addr_sub,
                       reg_file, gpio_data_reg, gpio_dir_reg, gpio_afsel,
                       irq_enable, irq_pending, irq_combined, reg_index)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' and valid_addr = '1' then
            case addr_blk is
                when BLK_REGS =>
                    if to_integer(unsigned(HADDR(7 downto 2))) < NUM_REGS then
                        rdata := reg_file(reg_index);
                    end if;
                when BLK_GPIO =>
                    case addr_sub is
                        when GPIO_DATA     => rdata := gpio_data_reg;
                        when GPIO_DIR_OFF  => rdata := gpio_dir_reg;
                        when GPIO_AFSEL_OFF=> rdata := gpio_afsel;
                        when others     => null;
                    end case;
                when BLK_IRQ =>
                    case addr_sub is
                        when IRQ_ENABLE_OFF  => rdata := irq_enable;
                        when IRQ_PENDING_OFF => rdata := irq_pending;
                        when IRQ_STATUS_OFF  => rdata := irq_combined;
                        when others      => null;
                    end case;
                when others => null;
            end case;
        end if;
        orig_hrdata <= rdata;
    end process ahb_read;

    -- AHB output mux: new peripherals / original
    HRDATA <= wdt_hrdata  when wdt_hsel = '1'
        else rtc_hrdata  when rtc_hsel = '1'
        else adc_hrdata  when adc_hsel = '1'
        else dac_hrdata  when dac_hsel = '1'
        else orig_hrdata;

    HRESP <= wdt_hresp  when wdt_hsel = '1'
        else rtc_hresp  when rtc_hsel = '1'
        else adc_hresp  when adc_hsel = '1'
        else dac_hresp  when dac_hsel = '1'
        else '1' when (HSEL = '1' and valid_addr = '0') else '0';

    HREADYOUT <= wdt_hreadyout when wdt_hsel = '1'
        else rtc_hreadyout when rtc_hsel = '1'
        else adc_hreadyout when adc_hsel = '1'
        else dac_hreadyout when dac_hsel = '1'
        else '1';

    -- GPIO outputs (masked to GPIO_WIDTH)
    gpio_out <= gpio_data_reg(GPIO_WIDTH-1 downto 0);
    gpio_dir <= gpio_dir_reg(GPIO_WIDTH-1 downto 0);

    -- ------------------------------------------------------------------------
    -- Interrupt aggregator: combine external IRQs with pending, mask by enable
    -- ------------------------------------------------------------------------
    irq_combined(31 downto 0) <= (irq_pending(31 downto 0) or
                                   (zero_pad(31 downto NUM_IRQ) & irq_inputs)) and
                                  irq_enable(31 downto 0);

    irq_out <= '1' when unsigned(irq_combined) /= 0 else '0';

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

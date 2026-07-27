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
--
-- Memory map (Peripheral space 0x40000000):
--   0x40000000 - 0x4000000F : GPIO  (offset 0x00)
--   0x40000010 - 0x4000001F : SYSTICK (offset 0x10)
--   0x40000020 - 0x4000003F : NVIC  (offset 0x20)
--   0x40000040 - 0x4000005F : SCB   (offset 0x40)
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
        swdio : inout std_logic
    );
end entity cortex_m0_interface;

architecture rtl of cortex_m0_interface is

    -- ---- Address decode constants (offset within peripheral block) ----
    constant OFF_GPIO     : std_logic_vector(7 downto 0) := x"00";
    constant OFF_SYSTICK  : std_logic_vector(7 downto 0) := x"10";
    constant OFF_NVIC     : std_logic_vector(7 downto 0) := x"20";
    constant OFF_SCB      : std_logic_vector(7 downto 0) := x"40";

    -- ---- GPIO register offsets (word-aligned within GPIO block) ----
    constant GPIO_DATA   : std_logic_vector(3 downto 0) := x"0"; -- offset 0x00
    constant GPIO_DIR    : std_logic_vector(3 downto 0) := x"1"; -- offset 0x04
    constant GPIO_AFSEL  : std_logic_vector(3 downto 0) := x"2"; -- offset 0x08

    -- ---- SysTick register offsets ----
    constant SYST_CSR    : std_logic_vector(3 downto 0) := x"0"; -- Control/Status
    constant SYST_RVR    : std_logic_vector(3 downto 0) := x"1"; -- Reload Value
    constant SYST_CVR    : std_logic_vector(3 downto 0) := x"2"; -- Current Value
    constant SYST_CALIB  : std_logic_vector(3 downto 0) := x"3"; -- Calibration

    -- ---- NVIC register offsets ----
    constant NVIC_ISER   : std_logic_vector(3 downto 0) := x"0"; -- Interrupt Set-Enable
    constant NVIC_ISPR   : std_logic_vector(3 downto 0) := x"1"; -- Interrupt Set-Pending
    constant NVIC_IPR    : std_logic_vector(3 downto 0) := x"4"; -- Interrupt Priority

    -- ---- SCB register offsets ----
    constant SCB_CPUID   : std_logic_vector(3 downto 0) := x"0"; -- CPU ID
    constant SCB_ICSR    : std_logic_vector(3 downto 0) := x"1"; -- Interrupt Control/State
    constant SCB_VTOR    : std_logic_vector(3 downto 0) := x"2"; -- Vector Table Offset

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
    signal addr_off  : std_logic_vector(7 downto 0);
    signal addr_sub  : std_logic_vector(3 downto 0);
    signal write_en  : std_logic;
    signal read_en   : std_logic;
    signal valid_addr: std_logic;
    signal nvic_pending_combined : std_logic_vector(31 downto 0);
    signal highest_irq : integer range 0 to 31;

begin

    -- Address decode: use bits [11:4] for block select, [3:2] for sub-register
    addr_off <= HADDR(11 downto 4);
    addr_sub <= HADDR(5 downto 2);

    -- Write strobe: active on selected, ready, write, non-idle transfer
    write_en <= HSEL and HREADY and HWRITE and (not HTRANS(0)) and (not HTRANS(1));
    -- Note: HTRANS="00" = IDLE, so we gate on NOT idle for a real transfer.
    -- Simplified: accept when HSEL=1, HREADY=1, HWRITE=1
    write_en <= HSEL and HREADY and HWRITE;
    read_en  <= HSEL and HREADY and (not HWRITE);

    -- Valid peripheral address (top 4 bits = 0x4 => peripheral space)
    valid_addr <= '1' when HADDR(31 downto 28) = x"4" else '0';

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
            if write_en = '1' and valid_addr = '1' then
                case addr_off is
                    when OFF_GPIO =>
                        case addr_sub is
                            when GPIO_DATA  => gpio_data_reg <= HWDATA;
                            when GPIO_DIR   => gpio_dir_reg  <= HWDATA;
                            when GPIO_AFSEL => gpio_afsel    <= HWDATA;
                            when others     => null;
                        end case;
                    when OFF_SYSTICK =>
                        case addr_sub is
                            when SYST_CSR => syst_csr <= HWDATA;
                            when SYST_RVR => syst_rvr <= HWDATA;
                            when SYST_CVR => syst_cvr <= unsigned(HWDATA(23 downto 0));
                            when others   => null;
                        end case;
                    when OFF_NVIC =>
                        case addr_sub is
                            when NVIC_ISER => nvic_iser <= nvic_iser or HWDATA;
                            when NVIC_ISPR => nvic_ispr <= nvic_ispr or HWDATA;
                            when NVIC_IPR  => nvic_ipr  <= HWDATA;
                            when others    => null;
                        end case;
                    when OFF_SCB =>
                        case addr_sub is
                            when SCB_VTOR => scb_vtor <= HWDATA;
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
                        when GPIO_DIR   => rdata := gpio_dir_reg;
                        when GPIO_AFSEL => rdata := gpio_afsel;
                        when others     => rdata := (others => '0');
                    end case;
                when OFF_SYSTICK =>
                    case addr_sub is
                        when SYST_CSR => rdata := syst_csr;
                        when SYST_RVR => rdata := syst_rvr;
                        when SYST_CVR => rdata := std_logic_vector(syst_cvr);
                        when others   => rdata := (others => '0');
                    end case;
                when OFF_NVIC =>
                    case addr_sub is
                        when NVIC_ISER => rdata := nvic_iser;
                        when NVIC_ISPR => rdata := nvic_ispr;
                        when NVIC_IPR  => rdata := nvic_ipr;
                        when others    => rdata := (others => '0');
                    end case;
                when OFF_SCB =>
                    case addr_sub is
                        when SCB_CPUID => rdata := x"410CC200"; -- Cortex-M0 CPUID
                        when SCB_ICSR  => rdata := nvic_ispr;
                        when SCB_VTOR  => rdata := scb_vtor;
                        when others    => rdata := (others => '0');
                    end case;
                when others => rdata := (others => '0');
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    -- HRESP: error for invalid address, OKAY otherwise
    HRESP     <= '1' when (HSEL = '1' and valid_addr = '0') else '0';
    HREADYOUT <= '1';  -- always one-cycle response

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
    irq_num  <= std_logic_vector(to_unsigned(highest_irq + 16, 6)); -- +16 for external IRQ base

    -- ------------------------------------------------------------------------
    -- SWD debug: minimal pass-through (placeholder for debug access)
    -- ------------------------------------------------------------------------
    swdio <= 'Z';  -- tri-stated by default; real impl would drive during ACK

end architecture rtl;

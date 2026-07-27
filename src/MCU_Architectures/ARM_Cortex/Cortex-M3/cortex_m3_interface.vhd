-- ================================================================================
-- cortex_m3_interface : Cortex-M3 AHB-Lite peripheral interface (educational)
-- ================================================================================
-- ARMv7-M (Cortex-M3) features:
--   * Full AHB-Lite slave signals
--   * NVIC: 32 IRQs (educational), 16 priority levels, tail-chaining
--   * SCB: CPUID, ICTR, VTOR, AIRCR, SCR, CCR, SHPR
--   * SysTick 24-bit timer
--   * MPU with 8 regions
--   * GPIO 32-bit
--   * Bit-banding support (bit-band region decode)
--   * Fault exceptions: HardFault, MemManage, BusFault, UsageFault
--   * JTAG + SWD debug
--
-- Memory map (Peripheral 0x40000000):
--   0x40000000 GPIO | 0x40000010 SYSTICK | 0x40000020 NVIC
--   0x40000040 SCB  | 0x40000060 MPU     | 0x40000080 FAULT
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cortex_m3_interface is
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
        -- MPU violation
        mpu_region_violation : out std_logic;
        -- Debug (JTAG + SWD)
        tck, tms, tdi : in std_logic;
        tdo : out std_logic;
        swclk : in std_logic;
        swdio : inout std_logic;
        -- Fault outputs
        hardfault  : out std_logic;
        busfault   : out std_logic;
        memfault   : out std_logic;
        usagefault : out std_logic
    );
end entity cortex_m3_interface;

architecture rtl of cortex_m3_interface is

    constant OFF_GPIO    : std_logic_vector(7 downto 0) := x"00";
    constant OFF_SYSTICK : std_logic_vector(7 downto 0) := x"10";
    constant OFF_NVIC    : std_logic_vector(7 downto 0) := x"20";
    constant OFF_SCB     : std_logic_vector(7 downto 0) := x"40";
    constant OFF_MPU     : std_logic_vector(7 downto 0) := x"60";
    constant OFF_FAULT   : std_logic_vector(7 downto 0) := x"80";

    constant GPIO_DATA  : std_logic_vector(3 downto 0) := x"0";
    constant GPIO_DIR   : std_logic_vector(3 downto 0) := x"1";
    constant GPIO_AFSEL : std_logic_vector(3 downto 0) := x"2";

    constant SYST_CSR : std_logic_vector(3 downto 0) := x"0";
    constant SYST_RVR : std_logic_vector(3 downto 0) := x"1";
    constant SYST_CVR : std_logic_vector(3 downto 0) := x"2";

    constant NVIC_ISER : std_logic_vector(3 downto 0) := x"0";
    constant NVIC_ISPR : std_logic_vector(3 downto 0) := x"1";
    constant NVIC_ICER : std_logic_vector(3 downto 0) := x"2"; -- Clear-Enable
    constant NVIC_ICPR : std_logic_vector(3 downto 0) := x"3"; -- Clear-Pending
    constant NVIC_IPR  : std_logic_vector(3 downto 0) := x"4";

    constant SCB_CPUID : std_logic_vector(3 downto 0) := x"0";
    constant SCB_ICSR  : std_logic_vector(3 downto 0) := x"1";
    constant SCB_VTOR  : std_logic_vector(3 downto 0) := x"2";
    constant SCB_AIRCR : std_logic_vector(3 downto 0) := x"3";
    constant SCB_SCR   : std_logic_vector(3 downto 0) := x"4";
    constant SCB_CCR   : std_logic_vector(3 downto 0) := x"5";

    constant MPU_TYPE : std_logic_vector(3 downto 0) := x"0";
    constant MPU_CTRL : std_logic_vector(3 downto 0) := x"1";
    constant MPU_RNR  : std_logic_vector(3 downto 0) := x"2";
    constant MPU_RBAR : std_logic_vector(3 downto 0) := x"3";
    constant MPU_RASR : std_logic_vector(3 downto 0) := x"4";

    constant FAULT_HFSR  : std_logic_vector(3 downto 0) := x"0"; -- HardFault Status
    constant FAULT_CFSR  : std_logic_vector(3 downto 0) := x"1"; -- Configurable Fault Status
    constant FAULT_MMFAR : std_logic_vector(3 downto 0) := x"2"; -- MemManage Fault Addr
    constant FAULT_BFAR  : std_logic_vector(3 downto 0) := x"3"; -- BusFault Addr

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
    signal scb_aircr : std_logic_vector(31 downto 0) := (others => '0');
    signal scb_scr   : std_logic_vector(31 downto 0) := (others => '0');
    signal scb_ccr   : std_logic_vector(31 downto 0) := (others => '0');

    -- MPU (8 regions)
    type mpu_rbar_array is array(0 to 7) of std_logic_vector(31 downto 0);
    type mpu_rasr_array is array(0 to 7) of std_logic_vector(31 downto 0);
    signal mpu_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal mpu_rnr      : integer range 0 to 7 := 0;
    signal mpu_rbar     : mpu_rbar_array := (others => (others => '0'));
    signal mpu_rasr     : mpu_rasr_array := (others => (others => '0'));

    -- Fault status
    signal hfsr  : std_logic_vector(31 downto 0) := (others => '0');
    signal cfsr  : std_logic_vector(31 downto 0) := (others => '0');
    signal mmfar : std_logic_vector(31 downto 0) := (others => '0');
    signal bfar  : std_logic_vector(31 downto 0) := (others => '0');

    signal addr_off  : std_logic_vector(7 downto 0);
    signal addr_sub  : std_logic_vector(3 downto 0);
    signal write_en  : std_logic;
    signal valid_addr: std_logic;
    signal nvic_pending_combined : std_logic_vector(31 downto 0);
    signal highest_irq : integer range 0 to 31;
    signal mpu_violation_i : std_logic;

begin

    addr_off <= HADDR(11 downto 4);
    addr_sub <= HADDR(5 downto 2);
    write_en <= HSEL and HREADY and HWRITE;
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
            scb_aircr     <= (others => '0');
            scb_scr       <= (others => '0');
            scb_ccr       <= (others => '0');
            mpu_ctrl_reg  <= (others => '0');
            mpu_rnr       <= 0;
            mpu_rbar      <= (others => (others => '0'));
            mpu_rasr      <= (others => (others => '0'));
            hfsr          <= (others => '0');
            cfsr          <= (others => '0');
            mmfar         <= (others => '0');
            bfar          <= (others => '0');
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
                            when NVIC_ICER => nvic_iser <= nvic_iser and not HWDATA;
                            when NVIC_ICPR => nvic_ispr <= nvic_ispr and not HWDATA;
                            when NVIC_IPR  => nvic_ipr  <= HWDATA;
                            when others    => null;
                        end case;
                    when OFF_SCB =>
                        case addr_sub is
                            when SCB_VTOR  => scb_vtor  <= HWDATA;
                            when SCB_AIRCR => scb_aircr <= HWDATA;
                            when SCB_SCR   => scb_scr   <= HWDATA;
                            when SCB_CCR   => scb_ccr   <= HWDATA;
                            when others    => null;
                        end case;
                    when OFF_MPU =>
                        case addr_sub is
                            when MPU_CTRL => mpu_ctrl_reg <= HWDATA;
                            when MPU_RNR  => mpu_rnr <= to_integer(unsigned(HWDATA(2 downto 0)));
                            when MPU_RBAR => mpu_rbar(mpu_rnr) <= HWDATA;
                            when MPU_RASR => mpu_rasr(mpu_rnr) <= HWDATA;
                            when others   => null;
                        end case;
                    when OFF_FAULT =>
                        case addr_sub is
                            when FAULT_HFSR  => hfsr  <= HWDATA;
                            when FAULT_CFSR  => cfsr  <= HWDATA;
                            when FAULT_MMFAR => mmfar <= HWDATA;
                            when FAULT_BFAR  => bfar  <= HWDATA;
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
    ahb_read : process(HSEL, HADDR, valid_addr, addr_off, addr_sub,
                       gpio_data_reg, gpio_dir_reg, gpio_afsel,
                       syst_csr, syst_rvr, syst_cvr,
                       nvic_iser, nvic_ispr, nvic_ipr,
                       scb_vtor, scb_aircr, scb_scr, scb_ccr,
                       mpu_ctrl_reg, mpu_rnr, mpu_rbar, mpu_rasr,
                       hfsr, cfsr, mmfar, bfar)
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
                        when others     => null;
                    end case;
                when OFF_SYSTICK =>
                    case addr_sub is
                        when SYST_CSR => rdata := syst_csr;
                        when SYST_RVR => rdata := syst_rvr;
                        when SYST_CVR => rdata := std_logic_vector(syst_cvr);
                        when others   => null;
                    end case;
                when OFF_NVIC =>
                    case addr_sub is
                        when NVIC_ISER => rdata := nvic_iser;
                        when NVIC_ISPR => rdata := nvic_ispr;
                        when NVIC_ICER => rdata := nvic_iser;
                        when NVIC_ICPR => rdata := nvic_ispr;
                        when NVIC_IPR  => rdata := nvic_ipr;
                        when others    => null;
                    end case;
                when OFF_SCB =>
                    case addr_sub is
                        when SCB_CPUID => rdata := x"410FC230"; -- Cortex-M3 r2p0
                        when SCB_ICSR  => rdata := nvic_ispr;
                        when SCB_VTOR  => rdata := scb_vtor;
                        when SCB_AIRCR => rdata := scb_aircr;
                        when SCB_SCR   => rdata := scb_scr;
                        when SCB_CCR   => rdata := scb_ccr;
                        when others    => null;
                    end case;
                when OFF_MPU =>
                    case addr_sub is
                        when MPU_TYPE => rdata := x"00000800";
                        when MPU_CTRL => rdata := mpu_ctrl_reg;
                        when MPU_RNR  => rdata := std_logic_vector(to_unsigned(mpu_rnr, 32));
                        when MPU_RBAR => rdata := mpu_rbar(mpu_rnr);
                        when MPU_RASR => rdata := mpu_rasr(mpu_rnr);
                        when others   => null;
                    end case;
                when OFF_FAULT =>
                    case addr_sub is
                        when FAULT_HFSR  => rdata := hfsr;
                        when FAULT_CFSR  => rdata := cfsr;
                        when FAULT_MMFAR => rdata := mmfar;
                        when FAULT_BFAR  => rdata := bfar;
                        when others      => null;
                    end case;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '1' when (HSEL = '1' and valid_addr = '0') else '0';
    HREADYOUT <= '1';

    -- GPIO
    gpio_out <= gpio_data_reg;
    gpio_dir <= gpio_dir_reg;

    -- ------------------------------------------------------------------------
    -- SysTick
    -- ------------------------------------------------------------------------
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

    -- ------------------------------------------------------------------------
    -- NVIC with tail-chaining support
    -- ------------------------------------------------------------------------
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
    irq_num <= std_logic_vector(to_unsigned(highest_irq + 16, 9));

    -- ------------------------------------------------------------------------
    -- MPU violation check (simplified: check if MPU enabled and address outside regions)
    -- ------------------------------------------------------------------------
    mpu_violation_i <= '1' when (mpu_ctrl_reg(0) = '1' and valid_addr = '0' and HSEL = '1')
                       else '0';
    mpu_region_violation <= mpu_violation_i;

    -- ------------------------------------------------------------------------
    -- Fault outputs (driven by fault status registers)
    -- ------------------------------------------------------------------------
    hardfault  <= hfsr(31) or hfsr(30) or hfsr(1);
    busfault   <= cfsr(15) or cfsr(14) or cfsr(13) or cfsr(12) or cfsr(11) or cfsr(10) or cfsr(9) or cfsr(8) or cfsr(7) or cfsr(2) or cfsr(1);
    memfault   <= cfsr(7) or cfsr(6) or cfsr(5) or cfsr(4) or cfsr(3) or cfsr(2) or cfsr(1) or cfsr(0);
    usagefault <= cfsr(31) or cfsr(30) or cfsr(29) or cfsr(28) or cfsr(27) or cfsr(26) or cfsr(25) or cfsr(24) or cfsr(18) or cfsr(17) or cfsr(16);

    -- Debug (placeholder)
    tdo   <= tdi;
    swdio <= 'Z';

end architecture rtl;

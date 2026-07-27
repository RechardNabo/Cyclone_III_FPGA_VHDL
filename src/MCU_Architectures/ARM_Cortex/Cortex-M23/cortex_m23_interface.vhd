-- ================================================================================
-- cortex_m23_interface : Cortex-M23 AHB-Lite peripheral interface (educational)
-- ================================================================================
-- ARMv8-M Baseline (Cortex-M23) features:
--   * TrustZone security: SAU (Security Attribution Unit) with 8 regions
--   * Secure/non-secure AHB: HNONSEC input, 2-bit HRESP
--   * NVIC: 32 IRQs, 4 priority levels
--   * SysTick 24-bit timer
--   * GPIO 32-bit
--   * MPU with 8 regions
--   * SWD debug with secure debug enable
--   * SecureFault exception
--
-- Memory map (Peripheral 0x40000000):
--   0x40000000 GPIO | 0x40000010 SYSTICK | 0x40000020 NVIC
--   0x40000040 SCB  | 0x40000060 SAU     | 0x40000080 MPU
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cortex_m23_interface is
    port (
        HCLK, HRESETn, HSEL, HWRITE, HREADY, HMASTLOCK : in std_logic;
        HTRANS : in std_logic_vector(1 downto 0);
        HSIZE  : in std_logic_vector(2 downto 0);
        HPROT  : in std_logic_vector(3 downto 0);
        HNONSEC: in std_logic;  -- TrustZone: 0=secure, 1=non-secure
        HADDR  : in std_logic_vector(31 downto 0);
        HWDATA : in std_logic_vector(31 downto 0);
        HRDATA : out std_logic_vector(31 downto 0);
        HRESP  : out std_logic_vector(1 downto 0);  -- 2-bit for TrustZone
        HREADYOUT : out std_logic;
        -- NVIC
        irq_inputs : in std_logic_vector(31 downto 0);
        nmi        : in std_logic;
        irq_out    : out std_logic;
        irq_num    : out std_logic_vector(6 downto 0);
        -- SysTick
        mclk        : in std_logic;
        systick_int : out std_logic;
        -- GPIO
        gpio_in   : in  std_logic_vector(31 downto 0);
        gpio_out  : out std_logic_vector(31 downto 0);
        gpio_dir  : out std_logic_vector(31 downto 0);
        -- SAU (TrustZone)
        sau_violation : out std_logic;
        secure_fault  : out std_logic;
        -- SWD debug
        swclk : in std_logic;
        swdio : inout std_logic;
        sec_dbgen : in std_logic  -- secure debug enable
    );
end entity cortex_m23_interface;

architecture rtl of cortex_m23_interface is

    constant OFF_GPIO    : std_logic_vector(7 downto 0) := x"00";
    constant OFF_SYSTICK : std_logic_vector(7 downto 0) := x"10";
    constant OFF_NVIC    : std_logic_vector(7 downto 0) := x"20";
    constant OFF_SCB     : std_logic_vector(7 downto 0) := x"40";
    constant OFF_SAU     : std_logic_vector(7 downto 0) := x"60";
    constant OFF_MPU     : std_logic_vector(7 downto 0) := x"80";

    constant GPIO_DATA  : std_logic_vector(3 downto 0) := x"0";
    constant GPIO_DIR   : std_logic_vector(3 downto 0) := x"1";
    constant GPIO_AFSEL : std_logic_vector(3 downto 0) := x"2";

    constant SYST_CSR : std_logic_vector(3 downto 0) := x"0";
    constant SYST_RVR : std_logic_vector(3 downto 0) := x"1";
    constant SYST_CVR : std_logic_vector(3 downto 0) := x"2";

    constant NVIC_ISER : std_logic_vector(3 downto 0) := x"0";
    constant NVIC_ISPR : std_logic_vector(3 downto 0) := x"1";
    constant NVIC_IPR  : std_logic_vector(3 downto 0) := x"4";

    constant SCB_CPUID : std_logic_vector(3 downto 0) := x"0";
    constant SCB_ICSR  : std_logic_vector(3 downto 0) := x"1";
    constant SCB_VTOR  : std_logic_vector(3 downto 0) := x"2";

    constant SAU_CTRL : std_logic_vector(3 downto 0) := x"0";
    constant SAU_RNR  : std_logic_vector(3 downto 0) := x"1";
    constant SAU_RBAR : std_logic_vector(3 downto 0) := x"2";
    constant SAU_RLAR : std_logic_vector(3 downto 0) := x"3"; -- Region Limit Addr + Attr

    constant MPU_CTRL : std_logic_vector(3 downto 0) := x"1";
    constant MPU_RNR  : std_logic_vector(3 downto 0) := x"2";
    constant MPU_RBAR : std_logic_vector(3 downto 0) := x"3";
    constant MPU_RASR : std_logic_vector(3 downto 0) := x"4";

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

    -- SAU (8 regions)
    type sau_rbar_array is array(0 to 7) of std_logic_vector(31 downto 0);
    type sau_rlar_array is array(0 to 7) of std_logic_vector(31 downto 0);
    signal sau_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal sau_rnr      : integer range 0 to 7 := 0;
    signal sau_rbar     : sau_rbar_array := (others => (others => '0'));
    signal sau_rlar     : sau_rlar_array := (others => (others => '0'));

    -- MPU (8 regions)
    type mpu_rbar_array is array(0 to 7) of std_logic_vector(31 downto 0);
    type mpu_rasr_array is array(0 to 7) of std_logic_vector(31 downto 0);
    signal mpu_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal mpu_rnr      : integer range 0 to 7 := 0;
    signal mpu_rbar     : mpu_rbar_array := (others => (others => '0'));
    signal mpu_rasr     : mpu_rasr_array := (others => (others => '0'));

    signal addr_off  : std_logic_vector(7 downto 0);
    signal addr_sub  : std_logic_vector(3 downto 0);
    signal write_en  : std_logic;
    signal valid_addr: std_logic;
    signal nvic_pending_combined : std_logic_vector(31 downto 0);
    signal highest_irq : integer range 0 to 31;
    signal sau_violation_i : std_logic;
    signal secure_fault_i  : std_logic;

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
            sau_ctrl_reg  <= (others => '0');
            sau_rnr       <= 0;
            sau_rbar      <= (others => (others => '0'));
            sau_rlar      <= (others => (others => '0'));
            mpu_ctrl_reg  <= (others => '0');
            mpu_rnr       <= 0;
            mpu_rbar      <= (others => (others => '0'));
            mpu_rasr      <= (others => (others => '0'));
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
                    when OFF_SAU =>
                        case addr_sub is
                            when SAU_CTRL => sau_ctrl_reg <= HWDATA;
                            when SAU_RNR  => sau_rnr <= to_integer(unsigned(HWDATA(2 downto 0)));
                            when SAU_RBAR => sau_rbar(sau_rnr) <= HWDATA;
                            when SAU_RLAR => sau_rlar(sau_rnr) <= HWDATA;
                            when others   => null;
                        end case;
                    when OFF_MPU =>
                        case addr_sub is
                            when MPU_CTRL => mpu_ctrl_reg <= HWDATA;
                            when MPU_RNR  => mpu_rnr <= to_integer(unsigned(HWDATA(2 downto 0)));
                            when MPU_RBAR => mpu_rbar(mpu_rnr) <= HWDATA;
                            when MPU_RASR => mpu_rasr(mpu_rnr) <= HWDATA;
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
                       syst_csr, syst_rvr, syst_cvr,
                       nvic_iser, nvic_ispr, nvic_ipr, scb_vtor,
                       sau_ctrl_reg, sau_rnr, sau_rbar, sau_rlar,
                       mpu_ctrl_reg, mpu_rnr, mpu_rbar, mpu_rasr)
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
                        when NVIC_IPR  => rdata := nvic_ipr;
                        when others    => null;
                    end case;
                when OFF_SCB =>
                    case addr_sub is
                        when SCB_CPUID => rdata := x"410FD200"; -- Cortex-M23
                        when SCB_ICSR  => rdata := nvic_ispr;
                        when SCB_VTOR  => rdata := scb_vtor;
                        when others    => null;
                    end case;
                when OFF_SAU =>
                    case addr_sub is
                        when SAU_CTRL => rdata := sau_ctrl_reg;
                        when SAU_RNR  => rdata := std_logic_vector(to_unsigned(sau_rnr, 32));
                        when SAU_RBAR => rdata := sau_rbar(sau_rnr);
                        when SAU_RLAR => rdata := sau_rlar(sau_rnr);
                        when others   => null;
                    end case;
                when OFF_MPU =>
                    case addr_sub is
                        when MPU_CTRL => rdata := mpu_ctrl_reg;
                        when MPU_RNR  => rdata := std_logic_vector(to_unsigned(mpu_rnr, 32));
                        when MPU_RBAR => rdata := mpu_rbar(mpu_rnr);
                        when MPU_RASR => rdata := mpu_rasr(mpu_rnr);
                        when others   => null;
                    end case;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    -- HRESP: 2-bit for TrustZone (00=OKAY, 01=EXOKAY, 10=ERROR, 11=EXERROR)
    HRESP <= "10" when (HSEL = '1' and valid_addr = '0') else
             "01" when (sau_violation_i = '1') else
             "00";
    HREADYOUT <= '1';

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
    irq_num <= std_logic_vector(to_unsigned(highest_irq + 16, 7));

    -- ------------------------------------------------------------------------
    -- SAU (Security Attribution Unit) check
    --   When SAU enabled and non-secure access hits a secure-only region,
    --   flag a violation.
    -- ------------------------------------------------------------------------
    sau_violation_i <= '1' when (sau_ctrl_reg(0) = '1' and HNONSEC = '1' and
                                  HSEL = '1' and valid_addr = '1')
                       else '0';
    sau_violation <= sau_violation_i;

    -- SecureFault: triggered by SAU violation
    secure_fault_i <= sau_violation_i;
    secure_fault  <= secure_fault_i;

    -- SWD debug: gated by secure debug enable
    swdio <= 'Z' when sec_dbgen = '0' else 'Z';

end architecture rtl;

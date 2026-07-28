-- ================================================================================
-- nmi_controller : Non-Maskable Interrupt Controller with Priority
-- ================================================================================
-- 8 NMI sources with priority encoding and masking.
-- Register Map:
--   0x00 CTRL     - bit0=global_en, bit1=irq_en
--   0x04 STAT     - bit0=nmi_pending, bits[15:8]=active_sources
--   0x08 NMI_SRC  - 8-bit source status (RO, write to clear pending)
--   0x0C NMI_MASK - 8-bit mask (RW, 1=enabled)
--   0x10 NMI_PRIO - 8x2-bit priority levels (RW)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity nmi_controller is
    port (
        -- AHB-Lite slave interface
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

        -- NMI interface
        nmi_out   : out std_logic;
        nmi_src   : in  std_logic_vector(7 downto 0)
    );
end entity nmi_controller;

architecture rtl of nmi_controller is
    constant NMI_CTRL  : std_logic_vector(3 downto 0) := "0000";
    constant NMI_STAT  : std_logic_vector(3 downto 0) := "0001";
    constant NMI_SRC_REG   : std_logic_vector(3 downto 0) := "0010";
    constant NMI_MASK  : std_logic_vector(3 downto 0) := "0011";
    constant NMI_PRIO  : std_logic_vector(3 downto 0) := "0100";

    signal ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal mask_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal prio_reg    : std_logic_vector(31 downto 0) := (others => '0');

    signal pending     : std_logic_vector(7 downto 0) := (others => '0');
    signal nmi_pending : std_logic := '0';

    signal reg_sel     : std_logic_vector(3 downto 0);
    signal write_en    : std_logic;
    signal read_en     : std_logic;

    -- Priority encoder: returns index of highest-priority pending source
    function prio_encode(sources : std_logic_vector;
                         prios   : std_logic_vector) return integer is
        variable best_idx  : integer := 0;
        variable best_prio : integer := 0;
        variable found     : boolean := false;
    begin
        for i in 0 to 7 loop
            if sources(i) = '1' then
                if not found then
                    best_idx  := i;
                    best_prio := to_integer(unsigned(prios(i*2+1 downto i*2)));
                    found     := true;
                elsif to_integer(unsigned(prios(i*2+1 downto i*2))) > best_prio then
                    best_idx  := i;
                    best_prio := to_integer(unsigned(prios(i*2+1 downto i*2)));
                end if;
            end if;
        end loop;
        return best_idx;
    end function;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- NMI source capture and pending logic
    nmi_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                pending     <= (others => '0');
                nmi_pending <= '0';
            else
                -- Capture new source edges
                for i in 0 to 7 loop
                    if nmi_src(i) = '1' and mask_reg(i) = '1' then
                        pending(i) <= '1';
                    end if;
                end loop;

                -- Clear pending on NMI_SRC write
                if write_en = '1' and reg_sel = NMI_SRC_REG then
                    for i in 0 to 7 loop
                        if HWDATA(i) = '1' then
                            pending(i) <= '0';
                        end if;
                    end loop;
                end if;

                -- Update NMI pending status
                if pending /= x"00" and ctrl_reg(0) = '1' then
                    nmi_pending <= '1';
                else
                    nmi_pending <= '0';
                end if;
            end if;
        end if;
    end process nmi_proc;

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg <= (others => '0');
                mask_reg <= (others => '0');
                prio_reg <= (others => '0');
            elsif write_en = '1' then
                case reg_sel is
                    when NMI_CTRL =>
                        ctrl_reg <= HWDATA;
                    when NMI_MASK =>
                        mask_reg <= HWDATA;
                    when NMI_PRIO =>
                        prio_reg <= HWDATA;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, nmi_pending, pending,
                       mask_reg, prio_reg)
    begin
        case reg_sel is
            when NMI_CTRL =>
                HRDATA <= ctrl_reg;
            when NMI_STAT =>
                HRDATA <= (0 => nmi_pending, others => '0');
            when NMI_SRC_REG =>
                HRDATA <= x"000000" & pending;
            when NMI_MASK =>
                HRDATA <= mask_reg;
            when NMI_PRIO =>
                HRDATA <= prio_reg;
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    nmi_out <= nmi_pending and ctrl_reg(1);

end architecture rtl;

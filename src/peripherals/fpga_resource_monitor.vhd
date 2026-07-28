-- ================================================================================
-- fpga_resource_monitor : Resource utilization monitor
-- ================================================================================
-- Monitors FPGA resource utilization for Cyclone III devices.
--
-- Features:
--   * Counts active Logic Elements (LEs)
--   * Counts active M9K memory blocks
--   * Counts active DSP blocks (embedded multipliers)
--   * Counts active PLLs
--   * Configurable total resource limits
--   * Interrupt when utilization exceeds threshold
--
-- Register Map:
--   0x00: LE_COUNT    - active LE count (RO)
--   0x04: M9K_COUNT   - active M9K block count (RO)
--   0x08: DSP_COUNT   - active DSP block count (RO)
--   0x0C: PLL_COUNT   - active PLL count (RO)
--   0x10: TOTAL_LE    - total available LEs (RW)
--   0x14: TOTAL_M9K   - total available M9K blocks (RW)
--   0x18: TOTAL_DSP   - total available DSP blocks (RW)
--   0x1C: THRESHOLD   - utilization threshold percentage for IRQ (RW)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fpga_resource_monitor is
    generic (
        -- Cyclone III EP3C16 default resource counts
        DEFAULT_TOTAL_LE  : integer := 15408;
        DEFAULT_TOTAL_M9K : integer := 56;
        DEFAULT_TOTAL_DSP : integer := 56;
        DEFAULT_TOTAL_PLL : integer := 4
    );
    port (
        -- AHB-Lite slave interface
        HCLK      : in  std_logic;
        HRESETn   : in  std_logic;
        HSEL      : in  std_logic;
        HWRITE    : in  std_logic;
        HREADY    : in  std_logic;
        HTRANS    : in  std_logic_vector(1 downto 0);
        HADDR     : in  std_logic_vector(31 downto 0);
        HWDATA    : in  std_logic_vector(31 downto 0);
        HRDATA    : out std_logic_vector(31 downto 0);
        HRESP     : out std_logic;
        HREADYOUT : out std_logic;

        -- Resource interrupt
        resource_irq : out std_logic;

        -- External resource count inputs (from synthesis/PR)
        le_count_in  : in  unsigned(31 downto 0) := (others => '0');
        m9k_count_in : in  unsigned(31 downto 0) := (others => '0');
        dsp_count_in : in  unsigned(31 downto 0) := (others => '0');
        pll_count_in : in  unsigned(31 downto 0) := (others => '0')
    );
end entity fpga_resource_monitor;

architecture rtl of fpga_resource_monitor is

    constant REG_LE_COUNT    : std_logic_vector(3 downto 0) := "0000";
    constant REG_M9K_COUNT   : std_logic_vector(3 downto 0) := "0001";
    constant REG_DSP_COUNT   : std_logic_vector(3 downto 0) := "0010";
    constant REG_PLL_COUNT   : std_logic_vector(3 downto 0) := "0011";
    constant REG_TOTAL_LE    : std_logic_vector(3 downto 0) := "0100";
    constant REG_TOTAL_M9K   : std_logic_vector(3 downto 0) := "0101";
    constant REG_TOTAL_DSP   : std_logic_vector(3 downto 0) := "0110";
    constant REG_THRESHOLD   : std_logic_vector(3 downto 0) := "0111";

    -- Active resource counters (sampled from inputs)
    signal le_count  : unsigned(31 downto 0) := (others => '0');
    signal m9k_count : unsigned(31 downto 0) := (others => '0');
    signal dsp_count : unsigned(31 downto 0) := (others => '0');
    signal pll_count : unsigned(31 downto 0) := (others => '0');

    -- Total available resources (configurable)
    signal total_le   : unsigned(31 downto 0) := to_unsigned(DEFAULT_TOTAL_LE, 32);
    signal total_m9k  : unsigned(31 downto 0) := to_unsigned(DEFAULT_TOTAL_M9K, 32);
    signal total_dsp  : unsigned(31 downto 0) := to_unsigned(DEFAULT_TOTAL_DSP, 32);
    signal total_pll  : unsigned(31 downto 0) := to_unsigned(DEFAULT_TOTAL_PLL, 32);

    -- Threshold percentage (0-100)
    signal threshold  : unsigned(31 downto 0) := to_unsigned(80, 32);

    -- IRQ status
    signal irq_flag   : std_logic := '0';
    signal irq_en     : std_logic := '0';

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                total_le   <= to_unsigned(DEFAULT_TOTAL_LE, 32);
                total_m9k  <= to_unsigned(DEFAULT_TOTAL_M9K, 32);
                total_dsp  <= to_unsigned(DEFAULT_TOTAL_DSP, 32);
                total_pll  <= to_unsigned(DEFAULT_TOTAL_PLL, 32);
                threshold  <= to_unsigned(80, 32);
                irq_flag   <= '0';
                irq_en     <= '0';
            elsif write_en = '1' then
                case reg_sel is
                    when REG_TOTAL_LE =>
                        total_le <= unsigned(HWDATA);
                    when REG_TOTAL_M9K =>
                        total_m9k <= unsigned(HWDATA);
                    when REG_TOTAL_DSP =>
                        total_dsp <= unsigned(HWDATA);
                    when REG_THRESHOLD =>
                        threshold <= unsigned(HWDATA);
                        irq_en    <= HWDATA(8);
                        if HWDATA(31) = '1' then
                            irq_flag <= '0';  -- clear flag
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Resource sampling process (sample external inputs periodically)
    sample_proc : process(HCLK)
        variable le_pct   : unsigned(63 downto 0);
        variable m9k_pct  : unsigned(63 downto 0);
        variable dsp_pct  : unsigned(63 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                le_count  <= (others => '0');
                m9k_count <= (others => '0');
                dsp_count <= (others => '0');
                pll_count <= (others => '0');
                irq_flag  <= '0';
            else
                -- Sample current resource usage
                le_count  <= le_count_in;
                m9k_count <= m9k_count_in;
                dsp_count <= dsp_count_in;
                pll_count <= pll_count_in;

                -- Check threshold (simplified: compare count vs total*threshold/100)
                -- Using integer arithmetic for percentage
                if total_le > 0 and le_count_in * 100 > total_le * threshold then
                    irq_flag <= '1';
                elsif total_m9k > 0 and m9k_count_in * 100 > total_m9k * threshold then
                    irq_flag <= '1';
                elsif total_dsp > 0 and dsp_count_in * 100 > total_dsp * threshold then
                    irq_flag <= '1';
                end if;
            end if;
        end if;
    end process sample_proc;

    -- Register read mux
    reg_read : process(reg_sel, le_count, m9k_count, dsp_count, pll_count,
                       total_le, total_m9k, total_dsp, total_pll, threshold, irq_flag)
    begin
        case reg_sel is
            when REG_LE_COUNT =>
                HRDATA <= std_logic_vector(le_count);
            when REG_M9K_COUNT =>
                HRDATA <= std_logic_vector(m9k_count);
            when REG_DSP_COUNT =>
                HRDATA <= std_logic_vector(dsp_count);
            when REG_PLL_COUNT =>
                HRDATA <= std_logic_vector(pll_count);
            when REG_TOTAL_LE =>
                HRDATA <= std_logic_vector(total_le);
            when REG_TOTAL_M9K =>
                HRDATA <= std_logic_vector(total_m9k);
            when REG_TOTAL_DSP =>
                HRDATA <= std_logic_vector(total_dsp);
            when REG_THRESHOLD =>
                HRDATA <= irq_flag & "0000000" & irq_en & "00000000" &
                         std_logic_vector(threshold(7 downto 0));
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    resource_irq <= irq_flag and irq_en;

end architecture rtl;

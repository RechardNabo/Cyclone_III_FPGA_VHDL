-- ================================================================================
-- psc_controller : Power and Sleep Controller with AHB-Lite slave interface
-- ================================================================================
-- Educational Power and Sleep Controller for Cyclone III FPGA.
--
-- Features:
--   * Per-peripheral clock gating (32-bit mask)
--   * Sleep and deep-sleep mode entry/exit
--   * Configurable wake sources
--   * Interrupt on wake event
--
-- Register Map:
--   0x00: CTRL
--       bit0 = sleep_en     (RW) - enable sleep mode entry
--       bit1 = deep_sleep   (RW) - deep sleep mode
--       bit2 = force_sleep  (RW) - force immediate sleep entry
--       bit3 = irq_en       (RW) - wake interrupt enable
--   0x04: STAT
--       bit0 = sleeping      (RO) - currently in sleep mode
--       bit1 = deep_sleeping (RO) - currently in deep sleep
--       bit2 = wake_event    (RO) - wake event latched
--   0x08: PERI_GATE - 32-bit peripheral clock gate mask (RW)
--   0x0C: SLEEP_CFG
--       bits[3:0] = sleep delay cycles (RW)
--   0x10: WAKE_SRC - 32-bit wake source enable mask (RW)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity psc_controller is
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

        -- Power management interface
        wake_req      : in  std_logic;  -- external wake request
        sleep_out     : out std_logic;  -- sleep mode active
        deep_sleep_out: out std_logic;  -- deep sleep mode active
        peri_clk_en   : out std_logic_vector(31 downto 0); -- per-peripheral enable
        psc_irq       : out std_logic   -- wake interrupt
    );
end entity psc_controller;

architecture rtl of psc_controller is
    constant PSC_CTRL     : std_logic_vector(3 downto 0) := "0000";
    constant PSC_STAT     : std_logic_vector(3 downto 0) := "0001";
    constant PSC_PERI_GATE: std_logic_vector(3 downto 0) := "0010";
    constant PSC_SLEEP_CFG: std_logic_vector(3 downto 0) := "0011";
    constant PSC_WAKE_SRC : std_logic_vector(3 downto 0) := "0100";

    signal ctrl_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal peri_gate_reg  : std_logic_vector(31 downto 0) := (others => '1');
    signal sleep_cfg_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal wake_src_reg   : std_logic_vector(31 downto 0) := (others => '0');

    signal sleeping       : std_logic := '0';
    signal deep_sleeping  : std_logic := '0';
    signal wake_event     : std_logic := '0';
    signal sleep_delay    : unsigned(3 downto 0) := (others => '0');

    signal reg_sel        : std_logic_vector(3 downto 0);
    signal write_en       : std_logic;
    signal read_en        : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    sleep_out      <= sleeping;
    deep_sleep_out <= deep_sleeping;
    peri_clk_en    <= peri_gate_reg when sleeping = '0' else (others => '0');

    -- Sleep/wake state machine
    sleep_fsm : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                sleeping      <= '0';
                deep_sleeping <= '0';
                wake_event    <= '0';
                sleep_delay   <= (others => '0');
            else
                -- Check for wake condition
                if sleeping = '1' and (wake_req = '1' or
                   (wake_src_reg and x"0000FFFF") /= x"00000000") then
                    sleeping      <= '0';
                    deep_sleeping <= '0';
                    wake_event    <= '1';
                    sleep_delay   <= (others => '0');
                -- Enter sleep
                elsif ctrl_reg(2) = '1' and sleeping = '0' then
                    if sleep_delay = unsigned(sleep_cfg_reg(3 downto 0)) then
                        sleeping      <= '1';
                        deep_sleeping <= ctrl_reg(1);
                        sleep_delay   <= (others => '0');
                    else
                        sleep_delay <= sleep_delay + 1;
                    end if;
                end if;

                -- Clear wake_event on status read or ctrl write
                if write_en = '1' and reg_sel = PSC_STAT then
                    wake_event <= '0';
                end if;
            end if;
        end if;
    end process sleep_fsm;

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg      <= (others => '0');
                peri_gate_reg <= (others => '1');
                sleep_cfg_reg <= (others => '0');
                wake_src_reg  <= (others => '0');
            elsif write_en = '1' then
                case reg_sel is
                    when PSC_CTRL =>
                        ctrl_reg <= HWDATA;
                    when PSC_PERI_GATE =>
                        peri_gate_reg <= HWDATA;
                    when PSC_SLEEP_CFG =>
                        sleep_cfg_reg <= HWDATA;
                    when PSC_WAKE_SRC =>
                        wake_src_reg <= HWDATA;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, sleeping, deep_sleeping, wake_event,
                       peri_gate_reg, sleep_cfg_reg, wake_src_reg)
    begin
        case reg_sel is
            when PSC_CTRL =>
                HRDATA <= ctrl_reg;
            when PSC_STAT =>
                HRDATA <= (0 => sleeping, 1 => deep_sleeping,
                           2 => wake_event, others => '0');
            when PSC_PERI_GATE =>
                HRDATA <= peri_gate_reg;
            when PSC_SLEEP_CFG =>
                HRDATA <= sleep_cfg_reg;
            when PSC_WAKE_SRC =>
                HRDATA <= wake_src_reg;
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    psc_irq <= wake_event and ctrl_reg(3);

end architecture rtl;

-- ================================================================================
-- rtc_controller : Real-Time Clock with AHB-Lite slave interface
-- ================================================================================
-- Educational RTC for Cyclone III FPGA.
--
-- Features:
--   * 32-bit seconds counter (Unix epoch time)
--   * Sub-second counter (configurable resolution)
--   * Alarm match with interrupt
--   * Configuration via AHB-Lite register interface
--   * Software time-set capability
--
-- Register Map:
--   0x00: RTC_CTRL
--       bit0 = enable    (RW) - RTC counting enable
--       bit1 = irq_en    (RW) - alarm interrupt enable
--   0x04: RTC_SECONDS - current seconds count (RO, write to set time)
--   0x08: RTC_SUBSEC  - sub-second counter (RO)
--   0x0C: RTC_ALARM   - alarm match value (RW)
--   0x10: RTC_STATUS
--       bit0 = alarm_match (RO) - alarm triggered flag
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rtc_controller is
    generic (
        CLK_FREQ : integer := 50000000  -- system clock in Hz
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

        -- RTC outputs
        rtc_int   : out std_logic  -- alarm interrupt
    );
end entity rtc_controller;

architecture rtl of rtc_controller is
    constant RTC_CTRL    : std_logic_vector(3 downto 0) := "0000";
    constant RTC_SECONDS : std_logic_vector(3 downto 0) := "0001";
    constant RTC_SUBSEC  : std_logic_vector(3 downto 0) := "0010";
    constant RTC_ALARM   : std_logic_vector(3 downto 0) := "0011";
    constant RTC_STATUS  : std_logic_vector(3 downto 0) := "0100";

    signal ctrl_reg     : std_logic_vector(31 downto 0) := (0 => '1', others => '0');
    signal seconds_reg  : unsigned(31 downto 0) := (others => '0');
    signal subsec_cnt   : unsigned(31 downto 0) := (others => '0');
    signal alarm_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal alarm_match  : std_logic := '0';

    signal reg_sel      : std_logic_vector(3 downto 0);
    signal write_en     : std_logic;
    signal read_en      : std_logic;

    constant TICK_MAX   : unsigned(31 downto 0) := to_unsigned(CLK_FREQ, 32);

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- RTC counting process
    rtc_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                seconds_reg <= (others => '0');
                subsec_cnt  <= (others => '0');
                alarm_match <= '0';
            elsif ctrl_reg(0) = '1' then  -- enabled
                if subsec_cnt = TICK_MAX - 1 then
                    subsec_cnt  <= (others => '0');
                    seconds_reg <= seconds_reg + 1;
                    -- Check alarm match
                    if std_logic_vector(seconds_reg + 1) = alarm_reg then
                        alarm_match <= '1';
                    end if;
                else
                    subsec_cnt <= subsec_cnt + 1;
                end if;
            end if;
        end if;
    end process rtc_proc;

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg  <= (0 => '1', others => '0');
                alarm_reg <= (others => '0');
            elsif write_en = '1' then
                case reg_sel is
                    when RTC_CTRL =>
                        ctrl_reg <= HWDATA;
                    when RTC_SECONDS =>
                        seconds_reg <= unsigned(HWDATA);
                        subsec_cnt  <= (others => '0');
                    when RTC_ALARM =>
                        alarm_reg   <= HWDATA;
                        alarm_match <= '0';
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, seconds_reg, subsec_cnt, alarm_reg, alarm_match)
    begin
        case reg_sel is
            when RTC_CTRL =>
                HRDATA <= ctrl_reg;
            when RTC_SECONDS =>
                HRDATA <= std_logic_vector(seconds_reg);
            when RTC_SUBSEC =>
                HRDATA <= std_logic_vector(subsec_cnt);
            when RTC_ALARM =>
                HRDATA <= alarm_reg;
            when RTC_STATUS =>
                HRDATA <= (0 => alarm_match, others => '0');
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    rtc_int <= alarm_match and ctrl_reg(1);

end architecture rtl;

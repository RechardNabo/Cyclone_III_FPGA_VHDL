-- ================================================================================
-- rtcc_controller : Real-Time Calendar Controller (enhanced RTC with alarm)
-- ================================================================================
-- Maintains calendar time (seconds through years) with alarm matching.
--   * BCD-encoded time fields (seconds, minutes, hours, days, months, years)
--   * Alarm with mask fields for flexible matching
--   * 1 Hz tick from prescaler
--
-- AHB-Lite register map:
--   0x00 : CTRL  - [0] enable, [1] irq_en, [2] alarm_en, [3] hr_format(0=24h)
--   0x04 : STAT  - [0] running, [1] alarm_triggered
--   0x08 : SECONDS   0x0C : MINUTES   0x10 : HOURS
--   0x14 : DAYS      0x18 : MONTHS    0x1C : YEARS
--   0x20 : ALRM_SECONDS  0x24 : ALRM_MINUTES  0x28 : ALRM_HOURS
--   0x2C : ALRM_DAYS     0x30 : ALRM_MONTHS   0x34 : ALRM_YEARS
--   0x38 : ALRM_MASK  - [0]=sec match, [1]=min, [2]=hr, [3]=day, [4]=month, [5]=year
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rtcc_controller is
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

        -- RTC interface
        rtcc_irq  : out std_logic
    );
end entity rtcc_controller;

architecture rtl of rtcc_controller is
    signal ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal seconds     : unsigned(5 downto 0) := (others => '0');  -- 0-59
    signal minutes     : unsigned(5 downto 0) := (others => '0');  -- 0-59
    signal hours       : unsigned(4 downto 0) := (others => '0');  -- 0-23
    signal days        : unsigned(4 downto 0) := (others => '1');  -- 1-31
    signal months      : unsigned(3 downto 0) := (others => '1');  -- 1-12
    signal years       : unsigned(6 downto 0) := (others => '0');  -- 0-99

    signal alrm_sec    : unsigned(5 downto 0) := (others => '0');
    signal alrm_min    : unsigned(5 downto 0) := (others => '0');
    signal alrm_hr     : unsigned(4 downto 0) := (others => '0');
    signal alrm_day    : unsigned(4 downto 0) := (others => '0');
    signal alrm_mon    : unsigned(3 downto 0) := (others => '0');
    signal alrm_year   : unsigned(6 downto 0) := (others => '0');
    signal alrm_mask   : std_logic_vector(31 downto 0) := (others => '0');

    signal alarm_trig  : std_logic := '0';
    signal irq_pending : std_logic := '0';
    signal prescaler   : unsigned(31 downto 0) := (others => '0');
    constant TICK_DIV  : unsigned(31 downto 0) := x"012C4F80";  -- ~20 MHz -> 1 Hz

    signal reg_offset  : std_logic_vector(7 downto 0);
    signal write_en    : std_logic;
begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;

    ahb_write : process(HCLK, HRESETn)
        variable alarm_match : boolean;
    begin
        if HRESETn = '0' then
            ctrl_reg    <= (others => '0');
            seconds     <= (others => '0');
            minutes     <= (others => '0');
            hours       <= (others => '0');
            days        <= (others => '1');
            months      <= (others => '1');
            years       <= (others => '0');
            alrm_sec    <= (others => '0');
            alrm_min    <= (others => '0');
            alrm_hr     <= (others => '0');
            alrm_day    <= (others => '0');
            alrm_mon    <= (others => '0');
            alrm_year   <= (others => '0');
            alrm_mask   <= (others => '0');
            alarm_trig  <= '0';
            irq_pending <= '0';
            prescaler   <= (others => '0');
        elsif rising_edge(HCLK) then
            irq_pending <= '0';
            if write_en = '1' then
                case reg_offset is
                    when x"00" => ctrl_reg  <= HWDATA;
                    when x"08" => seconds   <= unsigned(HWDATA(5 downto 0));
                    when x"0C" => minutes   <= unsigned(HWDATA(5 downto 0));
                    when x"10" => hours     <= unsigned(HWDATA(4 downto 0));
                    when x"14" => days      <= unsigned(HWDATA(4 downto 0));
                    when x"18" => months    <= unsigned(HWDATA(3 downto 0));
                    when x"1C" => years     <= unsigned(HWDATA(6 downto 0));
                    when x"20" => alrm_sec  <= unsigned(HWDATA(5 downto 0));
                    when x"24" => alrm_min  <= unsigned(HWDATA(5 downto 0));
                    when x"28" => alrm_hr   <= unsigned(HWDATA(4 downto 0));
                    when x"2C" => alrm_day  <= unsigned(HWDATA(4 downto 0));
                    when x"30" => alrm_mon  <= unsigned(HWDATA(3 downto 0));
                    when x"34" => alrm_year <= unsigned(HWDATA(6 downto 0));
                    when x"38" => alrm_mask <= HWDATA;
                    when others => null;
                end case;
            end if;

            -- 1 Hz tick from prescaler
            if ctrl_reg(0) = '1' then
                if prescaler = TICK_DIV then
                    prescaler <= (others => '0');
                    -- Increment seconds
                    if seconds = 59 then
                        seconds <= (others => '0');
                        if minutes = 59 then
                            minutes <= (others => '0');
                            if hours = 23 then
                                hours <= (others => '0');
                                -- Day rollover (simplified: 31 days per month)
                                if days = 31 then
                                    days <= (others => '1');
                                    if months = 12 then
                                        months <= (others => '1');
                                        years <= years + 1;
                                    else
                                        months <= months + 1;
                                    end if;
                                else
                                    days <= days + 1;
                                end if;
                            else
                                hours <= hours + 1;
                            end if;
                        else
                            minutes <= minutes + 1;
                        end if;
                    else
                        seconds <= seconds + 1;
                    end if;

                    -- Alarm matching
                    alarm_match := true;
                    if alrm_mask(0) = '1' and seconds /= alrm_sec then alarm_match := false; end if;
                    if alrm_mask(1) = '1' and minutes /= alrm_min then alarm_match := false; end if;
                    if alrm_mask(2) = '1' and hours   /= alrm_hr  then alarm_match := false; end if;
                    if alrm_mask(3) = '1' and days    /= alrm_day then alarm_match := false; end if;
                    if alrm_mask(4) = '1' and months  /= alrm_mon then alarm_match := false; end if;
                    if alrm_mask(5) = '1' and years   /= alrm_year then alarm_match := false; end if;

                    if alarm_match and ctrl_reg(2) = '1' then
                        alarm_trig <= '1';
                        irq_pending <= ctrl_reg(1);
                    end if;
                else
                    prescaler <= prescaler + 1;
                end if;
            end if;

            -- Clear alarm trigger on STAT write
            if write_en = '1' and reg_offset = x"04" then
                if HWDATA(1) = '1' then alarm_trig <= '0'; end if;
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, seconds, minutes, hours,
                       days, months, years, alrm_sec, alrm_min, alrm_hr,
                       alrm_day, alrm_mon, alrm_year, alrm_mask, alarm_trig)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"00" => rdata := ctrl_reg;
                when x"04" =>
                    rdata(0) := ctrl_reg(0);
                    rdata(1) := alarm_trig;
                when x"08" => rdata := x"000000" & "00" & std_logic_vector(seconds);
                when x"0C" => rdata := x"000000" & "00" & std_logic_vector(minutes);
                when x"10" => rdata := x"000000" & "000" & std_logic_vector(hours);
                when x"14" => rdata := x"000000" & "000" & std_logic_vector(days);
                when x"18" => rdata := x"000000" & "0000" & std_logic_vector(months);
                when x"1C" => rdata := x"000000" & "0" & std_logic_vector(years);
                when x"20" => rdata := x"000000" & "00" & std_logic_vector(alrm_sec);
                when x"24" => rdata := x"000000" & "00" & std_logic_vector(alrm_min);
                when x"28" => rdata := x"000000" & "000" & std_logic_vector(alrm_hr);
                when x"2C" => rdata := x"000000" & "000" & std_logic_vector(alrm_day);
                when x"30" => rdata := x"000000" & "0000" & std_logic_vector(alrm_mon);
                when x"34" => rdata := x"000000" & "0" & std_logic_vector(alrm_year);
                when x"38" => rdata := alrm_mask;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    rtcc_irq  <= irq_pending;

end architecture rtl;

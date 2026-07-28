-- ================================================================================
-- tsc_controller : Touch Sense Controller (capacitive touch via charge transfer)
-- ================================================================================
-- Implements capacitive touch sensing using charge transfer principle.
-- 8 channels with configurable charge/discharge timing and thresholds.
--   * Per-channel threshold comparison
--   * Automatic charge/discharge cycle
--   * Interrupt when touch detected (value < threshold)
--
-- AHB-Lite register map:
--   0x00 : CTRL          - [0] enable, [1] irq_en, [2] start_scan, [3] continuous
--   0x04 : STAT          - [0] busy, [1] done, [8:15] touch_detected per channel
--   0x08 : CHARGE_TIME   - charge transfer cycles (per channel)
--   0x0C : DISCHARGE_TIME- discharge cycles (per channel)
--   0x10-0x2C : THRESHOLD0-7 - per-channel touch thresholds
--   0x30-0x4C : VALUE0-7     - per-channel measured values (read-only)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tsc_controller is
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

        -- TSC IO interface (charge/discharge pins per channel)
        tsc_io    : out std_logic_vector(7 downto 0);
        tsc_irq   : out std_logic
    );
end entity tsc_controller;

architecture rtl of tsc_controller is
    constant NUM_CH : integer := 8;
    type thresh_arr_t is array(0 to NUM_CH-1) of std_logic_vector(15 downto 0);
    type value_arr_t  is array(0 to NUM_CH-1) of std_logic_vector(15 downto 0);

    signal ctrl_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal charge_time    : std_logic_vector(31 downto 0) := (others => '0');
    signal discharge_time : std_logic_vector(31 downto 0) := (others => '0');
    signal thresholds     : thresh_arr_t := (others => (others => '0'));
    signal values         : value_arr_t  := (others => (others => '0'));
    signal touch_detected : std_logic_vector(NUM_CH-1 downto 0) := (others => '0');

    signal scan_busy      : std_logic := '0';
    signal scan_done      : std_logic := '0';
    signal irq_pending    : std_logic := '0';
    signal cur_channel    : integer range 0 to NUM_CH-1 := 0;
    signal cycle_cnt      : unsigned(15 downto 0) := (others => '0');
    signal charge_cnt     : unsigned(15 downto 0) := (others => '0');
    signal scan_state     : integer range 0 to 3 := 0;  -- 0=idle,1=charge,2=discharge,3=measure

    signal reg_offset     : std_logic_vector(7 downto 0);
    signal write_en       : std_logic;
    signal tsc_io_int     : std_logic_vector(7 downto 0) := (others => '0');
begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;
    tsc_io     <= tsc_io_int when ctrl_reg(0) = '1' else (others => '0');

    ahb_write : process(HCLK, HRESETn)
        variable ch_idx : integer range 0 to NUM_CH-1;
    begin
        if HRESETn = '0' then
            ctrl_reg       <= (others => '0');
            charge_time    <= (others => '0');
            discharge_time <= (others => '0');
            thresholds     <= (others => (others => '0'));
            values         <= (others => (others => '0'));
            touch_detected <= (others => '0');
            scan_busy      <= '0';
            scan_done      <= '0';
            irq_pending    <= '0';
            cur_channel    <= 0;
            cycle_cnt      <= (others => '0');
            charge_cnt     <= (others => '0');
            scan_state     <= 0;
            tsc_io_int     <= (others => '0');
        elsif rising_edge(HCLK) then
            irq_pending <= '0';
            scan_done <= '0';
            if write_en = '1' then
                case to_integer(unsigned(reg_offset)) is
                    when 16#00# =>
                        ctrl_reg <= HWDATA;
                        if HWDATA(2) = '1' and scan_busy = '0' then
                            scan_busy <= '1';
                            cur_channel <= 0;
                            scan_state <= 1;
                            cycle_cnt <= (others => '0');
                            charge_cnt <= (others => '0');
                        end if;
                    when 16#08# => charge_time    <= HWDATA;
                    when 16#0C# => discharge_time <= HWDATA;
                    when 16#10# to 16#2C# =>
                        ch_idx := to_integer(unsigned(reg_offset(4 downto 2)));
                        thresholds(ch_idx) <= HWDATA(15 downto 0);
                    when others => null;
                end case;
            end if;

            -- Charge transfer scan state machine
            if scan_busy = '1' then
                case scan_state is
                    when 1 =>  -- Charge phase
                        tsc_io_int(cur_channel) <= '1';
                        if charge_cnt = unsigned(charge_time(15 downto 0)) then
                            charge_cnt <= (others => '0');
                            scan_state <= 2;
                        else
                            charge_cnt <= charge_cnt + 1;
                        end if;
                    when 2 =>  -- Discharge phase
                        tsc_io_int(cur_channel) <= '0';
                        if charge_cnt = unsigned(discharge_time(15 downto 0)) then
                            charge_cnt <= (others => '0');
                            scan_state <= 3;
                        else
                            charge_cnt <= charge_cnt + 1;
                        end if;
                    when 3 =>  -- Measure (count cycles until pin stabilizes)
                        values(cur_channel) <= std_logic_vector(cycle_cnt(15 downto 0));
                        if cycle_cnt < unsigned(thresholds(cur_channel)) then
                            touch_detected(cur_channel) <= '1';
                        else
                            touch_detected(cur_channel) <= '0';
                        end if;
                        if cur_channel = NUM_CH-1 then
                            scan_busy <= '0';
                            scan_done <= '1';
                            irq_pending <= ctrl_reg(1);
                            scan_state <= 0;
                            tsc_io_int <= (others => '0');
                        else
                            cur_channel <= cur_channel + 1;
                            scan_state <= 1;
                            cycle_cnt <= (others => '0');
                        end if;
                    when others =>
                        cycle_cnt <= cycle_cnt + 1;
                        scan_state <= 3;
                end case;
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, charge_time, discharge_time,
                       thresholds, values, touch_detected, scan_busy, scan_done)
        variable rdata : std_logic_vector(31 downto 0);
        variable ridx  : integer range 0 to NUM_CH-1;
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case to_integer(unsigned(reg_offset)) is
                when 16#00# => rdata := ctrl_reg;
                when 16#04# =>
                    rdata(0) := scan_busy;
                    rdata(1) := scan_done;
                    rdata(15 downto 8) := touch_detected;
                when 16#08# => rdata := charge_time;
                when 16#0C# => rdata := discharge_time;
                when 16#10# to 16#2C# =>
                    ridx := to_integer(unsigned(reg_offset(4 downto 2)));
                    rdata := x"0000" & thresholds(ridx);
                when 16#30# to 16#4C# =>
                    ridx := to_integer(unsigned(reg_offset(4 downto 2)));
                    rdata := x"0000" & values(ridx);
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    tsc_irq   <= irq_pending;

end architecture rtl;

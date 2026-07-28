-- ================================================================================
-- pga_controller : Programmable Gain ADC controller
-- ================================================================================
-- 8-channel ADC with programmable gain amplifier per channel.
--   * Per-channel gain settings (1x, 2x, 4x, 8x, 16x, 32x, 64x)
--   * Sequential or single-channel scan mode
--   * 12-bit ADC simulation with gain applied
--
-- AHB-Lite register map:
--   0x00 : CTRL         - [0] enable, [1] irq_en, [2] start_scan, [3] continuous
--   0x04 : STAT         - [0] busy, [1] done, [2] channel_ready
--   0x08 : CHANNEL_CFG  - [3:0] active channel, [7:4] scan_mask
--   0x10-0x2C : GAIN0-7 - per-channel gain (3-bit: 0=1x..6=64x)
--   0x30-0x4C : VALUE0-7- per-channel converted values (12-bit, read-only)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pga_controller is
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

        -- PGA output interface
        pga_out   : out std_logic_vector(7 downto 0);  -- channel select out
        pga_irq   : out std_logic
    );
end entity pga_controller;

architecture rtl of pga_controller is
    constant NUM_CH : integer := 8;
    constant CONV_CYCLES : integer := 16;
    type gain_arr_t  is array(0 to NUM_CH-1) of std_logic_vector(2 downto 0);
    type value_arr_t is array(0 to NUM_CH-1) of std_logic_vector(11 downto 0);

    signal ctrl_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal channel_cfg    : std_logic_vector(31 downto 0) := (others => '0');
    signal gains          : gain_arr_t  := (others => "000");
    signal values         : value_arr_t := (others => (others => '0'));

    signal scan_busy      : std_logic := '0';
    signal scan_done      : std_logic := '0';
    signal irq_pending    : std_logic := '0';
    signal cur_channel    : integer range 0 to NUM_CH-1 := 0;
    signal conv_cnt       : integer range 0 to CONV_CYCLES := 0;
    signal adc_sim        : unsigned(11 downto 0) := (others => '0');

    signal reg_offset     : std_logic_vector(7 downto 0);
    signal write_en       : std_logic;

    -- Gain lookup (simplified: shift left by gain exponent)
    function apply_gain(raw : unsigned(11 downto 0); gain : std_logic_vector(2 downto 0))
                        return std_logic_vector is
        variable result : unsigned(11 downto 0);
        variable g : integer;
    begin
        g := to_integer(unsigned(gain));
        case g is
            when 0 => result := raw;              -- 1x
            when 1 => result := raw(10 downto 0) & '0';  -- 2x
            when 2 => result := raw(9 downto 0) & "00";  -- 4x
            when 3 => result := raw(8 downto 0) & "000"; -- 8x
            when 4 => result := raw(7 downto 0) & x"0";  -- 16x
            when 5 => result := raw(6 downto 0) & "00000"; -- 32x
            when 6 => result := raw(5 downto 0) & "000000"; -- 64x
            when others => result := raw;
        end case;
        return std_logic_vector(result);
    end function;

begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;
    pga_out    <= std_logic_vector(to_unsigned(cur_channel, 8)) when scan_busy = '1'
                  else (others => '0');

    ahb_write : process(HCLK, HRESETn)
        variable ch_idx : integer range 0 to NUM_CH-1;
    begin
        if HRESETn = '0' then
            ctrl_reg    <= (others => '0');
            channel_cfg <= (others => '0');
            gains       <= (others => "000");
            values      <= (others => (others => '0'));
            scan_busy   <= '0';
            scan_done   <= '0';
            irq_pending <= '0';
            cur_channel <= 0;
            conv_cnt    <= 0;
            adc_sim     <= (others => '0');
        elsif rising_edge(HCLK) then
            irq_pending <= '0';
            scan_done <= '0';
            if write_en = '1' then
                case to_integer(unsigned(reg_offset)) is
                    when 16#00# =>
                        ctrl_reg <= HWDATA;
                        if HWDATA(2) = '1' and scan_busy = '0' then
                            scan_busy <= '1';
                            cur_channel <= to_integer(unsigned(channel_cfg(3 downto 0)));
                            conv_cnt <= 0;
                        end if;
                    when 16#08# => channel_cfg <= HWDATA;
                    when 16#10# to 16#2C# =>
                        ch_idx := to_integer(unsigned(reg_offset(4 downto 2)));
                        gains(ch_idx) <= HWDATA(2 downto 0);
                    when others => null;
                end case;
            end if;

            -- ADC conversion simulation
            if scan_busy = '1' then
                if conv_cnt < CONV_CYCLES then
                    conv_cnt <= conv_cnt + 1;
                    adc_sim <= adc_sim + 37;  -- pseudo-random ramp
                else
                    -- Store converted value with gain applied
                    values(cur_channel) <= apply_gain(adc_sim, gains(cur_channel));
                    conv_cnt <= 0;
                    adc_sim <= (others => '0');

                    -- Check scan mode
                    if channel_cfg(7 downto 4) = "0000" then
                        -- Single channel mode
                        scan_busy <= '0';
                        scan_done <= '1';
                        irq_pending <= ctrl_reg(1);
                    else
                        -- Scan mode: advance to next enabled channel
                        if cur_channel = NUM_CH-1 then
                            scan_busy <= '0';
                            scan_done <= '1';
                            irq_pending <= ctrl_reg(1);
                            if ctrl_reg(3) = '1' and ctrl_reg(0) = '1' then
                                -- Continuous mode: restart
                                scan_busy <= '1';
                                cur_channel <= 0;
                            end if;
                        else
                            cur_channel <= cur_channel + 1;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, channel_cfg, gains, values,
                       scan_busy, scan_done, cur_channel)
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
                when 16#08# => rdata := channel_cfg;
                when 16#10# to 16#2C# =>
                    ridx := to_integer(unsigned(reg_offset(4 downto 2)));
                    rdata := x"000000" & "0" & gains(ridx);
                when 16#30# to 16#4C# =>
                    ridx := to_integer(unsigned(reg_offset(4 downto 2)));
                    rdata := x"00000" & values(ridx);
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    pga_irq   <= irq_pending;

end architecture rtl;

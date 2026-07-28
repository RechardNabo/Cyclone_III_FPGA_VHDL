-- ================================================================================
-- adc_controller : Analog-to-Digital Converter with AHB-Lite slave interface
-- ================================================================================
-- Educational ADC controller for Cyclone III FPGA.
--
-- Features:
--   * Configurable number of channels (default 8)
--   * 12-bit resolution
--   * Single-conversion and continuous-scan modes
--   * Conversion start via software trigger
--   * Per-channel result registers
--   * End-of-conversion interrupt
--
-- Register Map:
--   0x00: ADC_CTRL
--       bit0    = enable       (RW) - ADC enable
--       bit1    = irq_en       (RW) - interrupt enable
--       bit2    = continuous   (RW) - continuous scan mode
--       bit3    = start        (WO)  - write 1 to start conversion
--       bit4    = busy         (RO)  - conversion in progress
--       bit5    = done         (RO)  - conversion complete
--   0x04: ADC_CHAN_SEL - channel select for single mode (RW)
--   0x08: ADC_STATUS  - bit0..N = channel done flags (RO)
--   0x10..0x10+4*N: ADC_RESULT0..N - per-channel 12-bit results (RO)
--
-- The external analog inputs are provided as a vector of 12-bit values.
-- In a real FPGA, these would come from an external ADC chip or FPGA hard IP.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity adc_controller is
    generic (
        NUM_CHANNELS : integer := 8;
        CONV_CYCLES  : integer := 16  -- simulated conversion time in clock cycles
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

        -- External analog inputs (12-bit per channel)
        adc_in    : in  std_logic_vector(NUM_CHANNELS*12-1 downto 0);

        -- ADC outputs
        adc_int   : out std_logic  -- end-of-conversion interrupt
    );
end entity adc_controller;

architecture rtl of adc_controller is
    type result_array is array(0 to NUM_CHANNELS-1) of std_logic_vector(31 downto 0);
    signal results     : result_array := (others => (others => '0'));
    signal ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal chan_sel    : integer range 0 to NUM_CHANNELS-1 := 0;
    signal status_reg  : std_logic_vector(NUM_CHANNELS-1 downto 0) := (others => '0');

    signal conv_active : std_logic := '0';
    signal conv_cnt    : integer range 0 to CONV_CYCLES := 0;
    signal current_ch  : integer range 0 to NUM_CHANNELS-1 := 0;
    signal scan_mode   : std_logic := '0';

    signal write_en    : std_logic;
    signal start_pulse : std_logic := '0';

begin

    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- ADC conversion process
    adc_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                conv_active <= '0';
                conv_cnt    <= 0;
                current_ch  <= 0;
                status_reg  <= (others => '0');
                scan_mode   <= '0';
                start_pulse <= '0';
                results     <= (others => (others => '0'));
            else
                start_pulse <= '0';
                -- Latch start command
                if write_en = '1' and HADDR(5 downto 2) = "0000" and HWDATA(3) = '1' then
                    start_pulse <= '1';
                    if ctrl_reg(2) = '1' then
                        scan_mode <= '1';
                        current_ch <= 0;
                    else
                        scan_mode <= '0';
                        current_ch <= chan_sel;
                    end if;
                end if;

                if ctrl_reg(0) = '1' then  -- enabled
                    if start_pulse = '1' and conv_active = '0' then
                        conv_active <= '1';
                        conv_cnt    <= 0;
                        status_reg  <= (others => '0');
                    elsif conv_active = '1' then
                        if conv_cnt = CONV_CYCLES - 1 then
                            -- Conversion complete for current channel
                            results(current_ch) <= x"00000" & adc_in(current_ch*12+11 downto current_ch*12);
                            status_reg(current_ch) <= '1';
                            conv_cnt <= 0;

                            if scan_mode = '1' then
                                if current_ch = NUM_CHANNELS - 1 then
                                    conv_active <= '0';
                                    scan_mode   <= '0';
                                else
                                    current_ch <= current_ch + 1;
                                end if;
                            else
                                conv_active <= '0';
                            end if;
                        else
                            conv_cnt <= conv_cnt + 1;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process adc_proc;

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg <= (others => '0');
                chan_sel <= 0;
            elsif write_en = '1' then
                case HADDR(5 downto 2) is
                    when "0000" =>
                        ctrl_reg <= HWDATA;
                    when "0001" =>
                        if to_integer(unsigned(HWDATA)) < NUM_CHANNELS then
                            chan_sel <= to_integer(unsigned(HWDATA));
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(HADDR, ctrl_reg, chan_sel, status_reg, results, conv_active)
        variable ch_idx : integer;
    begin
        if HADDR(5 downto 2) = "0000" then
            -- ADC_CTRL: merge busy into readback
            HRDATA <= ctrl_reg(31 downto 5) & conv_active & ctrl_reg(3 downto 0);
        elsif HADDR(5 downto 2) = "0001" then
            HRDATA <= std_logic_vector(to_unsigned(chan_sel, 32));
        elsif HADDR(5 downto 2) = "0010" then
            HRDATA <= std_logic_vector(resize(unsigned(status_reg), 32));
        elsif HADDR(5 downto 4) = "01" then
            -- Result registers: 0x10 + 4*channel
            ch_idx := to_integer(unsigned(HADDR(3 downto 2)));
            if ch_idx < NUM_CHANNELS then
                HRDATA <= results(ch_idx);
            else
                HRDATA <= (others => '0');
            end if;
        else
            HRDATA <= (others => '0');
        end if;
    end process reg_read;

    -- Interrupt: fires when conversion is done and IRQ is enabled
    adc_int <= '1' when (ctrl_reg(1) = '1' and conv_active = '0' and
                         status_reg /= (status_reg'range => '0'))
               else '0';

end architecture rtl;

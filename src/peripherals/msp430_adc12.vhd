-- ================================================================================
-- msp430_adc12 : MSP430 12-bit ADC with sequence mode (8 channels)
-- ================================================================================
-- 8-channel 12-bit ADC with sequential sampling and interrupt support.
-- Registers: ADC12CTL0/1, ADC12MEM0-7, ADC12MCTL0-7, ADC12IE, ADC12IFG.
--
-- Register Map (HADDR[8:2]):
--   0x00: ADC12CTL0 - ADC control 0
--   0x04: ADC12CTL1 - ADC control 1
--   0x08-0x24: ADC12MEM0-7  - conversion results (RO)
--   0x28-0x44: ADC12MCTL0-7 - channel control registers
--   0x48: ADC12IE  - interrupt enable
--   0x4C: ADC12IFG - interrupt flags (RC)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity msp430_adc12 is
    generic ( NUM_CHANNELS : integer := 8 );
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

        -- Analog inputs and interrupt
        adc12_in  : in  std_logic_vector(NUM_CHANNELS-1 downto 0);
        adc12_irq : out std_logic
    );
end entity msp430_adc12;

architecture rtl of msp430_adc12 is

    constant REG_ADC12CTL0 : std_logic_vector(6 downto 0) := "0000000";
    constant REG_ADC12CTL1 : std_logic_vector(6 downto 0) := "0000001";
    constant REG_ADC12MEM0 : std_logic_vector(6 downto 0) := "0000010";
    constant REG_ADC12MCTL0: std_logic_vector(6 downto 0) := "0001010";
    constant REG_ADC12IE   : std_logic_vector(6 downto 0) := "0010010";
    constant REG_ADC12IFG  : std_logic_vector(6 downto 0) := "0010011";

    signal ctl0_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal ctl1_reg : std_logic_vector(15 downto 0) := (others => '0');
    type mem_arr  is array(0 to NUM_CHANNELS-1) of std_logic_vector(15 downto 0);
    type mctl_arr is array(0 to NUM_CHANNELS-1) of std_logic_vector(7 downto 0);
    signal mem_reg  : mem_arr := (others => (others => '0'));
    signal mctl_reg : mctl_arr := (others => (others => '0'));
    signal ie_reg   : std_logic_vector(15 downto 0) := (others => '0');
    signal ifg_reg  : std_logic_vector(15 downto 0) := (others => '0');

    -- ADC state machine
    type adc_state_t is (IDLE, SAMPLE, CONVERT, DONE);
    signal adc_state : adc_state_t := IDLE;
    signal cur_chan  : integer range 0 to NUM_CHANNELS-1 := 0;
    signal sample_cnt: unsigned(7 downto 0) := (others => '0');
    signal adc_data  : unsigned(11 downto 0) := (others => '0');

    signal reg_sel  : std_logic_vector(6 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(8 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- ADC conversion state machine
    adc_proc : process(HCLK)
        variable enc : std_logic;
        variable sht : unsigned(3 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctl0_reg <= (others => '0');
                ctl1_reg <= (others => '0');
                mctl_reg <= (others => (others => '0'));
                ie_reg   <= (others => '0');
                ifg_reg  <= (others => '0');
                mem_reg  <= (others => (others => '0'));
                adc_state <= IDLE;
                cur_chan  <= 0;
                sample_cnt <= (others => '0');
            else
                enc := ctl0_reg(0); -- ENC bit
                sht := unsigned(ctl0_reg(11 downto 8)); -- sample-and-hold time

                -- Register writes
                if write_en = '1' then
                    case reg_sel is
                        when REG_ADC12CTL0 =>
                            ctl0_reg <= HWDATA(15 downto 0);
                            -- ADC12SC: start conversion
                            if HWDATA(1) = '1' and enc = '1' and adc_state = IDLE then
                                adc_state <= SAMPLE;
                                cur_chan <= 0;
                                sample_cnt <= (others => '0');
                            end if;
                        when REG_ADC12CTL1 => ctl1_reg <= HWDATA(15 downto 0);
                        when REG_ADC12IE   => ie_reg <= HWDATA(15 downto 0);
                        when REG_ADC12IFG  => ifg_reg <= ifg_reg and not HWDATA(15 downto 0);
                        when others =>
                            if unsigned(reg_sel) >= unsigned(REG_ADC12MCTL0) and
                               unsigned(reg_sel) < unsigned(REG_ADC12MCTL0) + NUM_CHANNELS then
                                mctl_reg(to_integer(unsigned(reg_sel) - unsigned(REG_ADC12MCTL0))) <= HWDATA(7 downto 0);
                            end if;
                    end case;
                end if;

                -- ADC state machine
                case adc_state is
                    when IDLE => null;
                    when SAMPLE =>
                        if sample_cnt = sht then
                            sample_cnt <= (others => '0');
                            adc_state <= CONVERT;
                            -- Capture: convert digital input to 12-bit value
                            -- Simplified: use input pin as MSB, extend to 12 bits
                            if adc12_in(cur_chan) = '1' then
                                adc_data <= (others => '1');
                            else
                                adc_data <= (others => '0');
                            end if;
                        else
                            sample_cnt <= sample_cnt + 1;
                        end if;
                    when CONVERT =>
                        mem_reg(cur_chan) <= x"0" & std_logic_vector(adc_data);
                        ifg_reg(cur_chan) <= '1';
                        if cur_chan = NUM_CHANNELS - 1 then
                            adc_state <= DONE;
                        else
                            cur_chan <= cur_chan + 1;
                            adc_state <= SAMPLE;
                        end if;
                    when DONE =>
                        adc_state <= IDLE;
                end case;
            end if;
        end if;
    end process adc_proc;

    -- Register read mux
    reg_read : process(reg_sel, ctl0_reg, ctl1_reg, mem_reg, mctl_reg, ie_reg, ifg_reg)
        variable idx : integer;
    begin
        case reg_sel is
            when REG_ADC12CTL0 => HRDATA <= x"0000" & ctl0_reg;
            when REG_ADC12CTL1 => HRDATA <= x"0000" & ctl1_reg;
            when REG_ADC12IE   => HRDATA <= x"0000" & ie_reg;
            when REG_ADC12IFG  => HRDATA <= x"0000" & ifg_reg;
            when others =>
                if unsigned(reg_sel) >= unsigned(REG_ADC12MEM0) and
                   unsigned(reg_sel) < unsigned(REG_ADC12MEM0) + NUM_CHANNELS then
                    idx := to_integer(unsigned(reg_sel) - unsigned(REG_ADC12MEM0));
                    HRDATA <= x"0000" & mem_reg(idx);
                elsif unsigned(reg_sel) >= unsigned(REG_ADC12MCTL0) and
                      unsigned(reg_sel) < unsigned(REG_ADC12MCTL0) + NUM_CHANNELS then
                    idx := to_integer(unsigned(reg_sel) - unsigned(REG_ADC12MCTL0));
                    HRDATA <= x"000000" & mctl_reg(idx);
                else
                    HRDATA <= (others => '0');
                end if;
        end case;
    end process reg_read;

    adc12_irq <= '1' when (ifg_reg and ie_reg) /= x"0000" else '0';

end architecture rtl;

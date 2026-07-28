-- ================================================================================
-- pic_timer : PIC Timer0/1/2 with AHB-Lite slave interface
-- ================================================================================
-- Timer0: 8-bit with prescaler. Timer1: 16-bit. Timer2: 8-bit with PR2 period.
-- Registers: OPTION_REG, TMR0, TMR1H/L, T1CON, TMR2, T2CON, PR2, PIR1, PIE1.
--
-- Register Map (HADDR[6:2]):
--   0x00: OPTION_REG  0x04: TMR0  0x08: TMR1L  0x0C: TMR1H
--   0x10: T1CON      0x14: TMR2  0x18: T2CON  0x1C: PR2
--   0x20: PIR1       0x24: PIE1
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pic_timer is
    port (
        -- AHB-Lite slave interface
        HCLK      : in  std_logic;  HRESETn   : in  std_logic;
        HSEL      : in  std_logic;  HWRITE    : in  std_logic;
        HREADY    : in  std_logic;  HTRANS    : in  std_logic_vector(1 downto 0);
        HSIZE     : in  std_logic_vector(2 downto 0);
        HADDR     : in  std_logic_vector(31 downto 0);
        HWDATA    : in  std_logic_vector(31 downto 0);
        HRDATA    : out std_logic_vector(31 downto 0);
        HRESP     : out std_logic;  HREADYOUT : out std_logic;
        -- Timer external clock inputs and output
        t0_clk        : in  std_logic;
        t1_clk        : in  std_logic;
        t2_out        : out std_logic;
        pic_timer_irq : out std_logic
    );
end entity pic_timer;

architecture rtl of pic_timer is
    constant REG_OPTION : std_logic_vector(4 downto 0) := "00000";
    constant REG_TMR0   : std_logic_vector(4 downto 0) := "00001";
    constant REG_TMR1L  : std_logic_vector(4 downto 0) := "00010";
    constant REG_TMR1H  : std_logic_vector(4 downto 0) := "00011";
    constant REG_T1CON  : std_logic_vector(4 downto 0) := "00100";
    constant REG_TMR2   : std_logic_vector(4 downto 0) := "00101";
    constant REG_T2CON  : std_logic_vector(4 downto 0) := "00110";
    constant REG_PR2    : std_logic_vector(4 downto 0) := "00111";
    constant REG_PIR1   : std_logic_vector(4 downto 0) := "01000";
    constant REG_PIE1   : std_logic_vector(4 downto 0) := "01001";

    signal option_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal tmr0_reg   : unsigned(7 downto 0) := (others => '0');
    signal tmr1l_reg  : unsigned(7 downto 0) := (others => '0');
    signal tmr1h_reg  : unsigned(7 downto 0) := (others => '0');
    signal t1con_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal tmr2_reg   : unsigned(7 downto 0) := (others => '0');
    signal t2con_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal pr2_reg    : unsigned(7 downto 0) := (others => '0');
    signal pir1_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal pie1_reg   : std_logic_vector(7 downto 0) := (others => '0');

    signal tmr0_irq, tmr1_irq, tmr2_irq : std_logic := '0';
    signal t2_out_reg : std_logic := '0';
    signal t0_prescale : unsigned(3 downto 0) := (others => '0');
    signal t1_prescale : unsigned(1 downto 0) := (others => '0');
    signal t2_prescale : unsigned(3 downto 0) := (others => '0');
    signal t0_clk_prev, t1_clk_prev : std_logic := '0';

    signal reg_sel  : std_logic_vector(4 downto 0);
    signal write_en : std_logic;
begin
    reg_sel  <= HADDR(6 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    HREADYOUT <= '1';  HRESP <= '0';

    -- Combined timer + register write process
    timer_proc : process(HCLK)
        variable ps_val : unsigned(3 downto 0);
        variable t2_ps  : unsigned(3 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                option_reg <= (others => '0');  tmr0_reg <= (others => '0');
                tmr1l_reg <= (others => '0');   tmr1h_reg <= (others => '0');
                t1con_reg <= (others => '0');   tmr2_reg <= (others => '0');
                t2con_reg <= (others => '0');   pr2_reg <= (others => '0');
                pir1_reg <= (others => '0');    pie1_reg <= (others => '0');
                t0_prescale <= (others => '0'); t1_prescale <= (others => '0');
                t2_prescale <= (others => '0'); t0_clk_prev <= '0'; t1_clk_prev <= '0';
                tmr0_irq <= '0'; tmr1_irq <= '0'; tmr2_irq <= '0'; t2_out_reg <= '0';
            else
                -- Register writes
                if write_en = '1' then
                    case reg_sel is
                        when REG_OPTION => option_reg <= HWDATA(7 downto 0);
                        when REG_TMR0   => tmr0_reg  <= unsigned(HWDATA(7 downto 0));
                        when REG_TMR1L  => tmr1l_reg <= unsigned(HWDATA(7 downto 0));
                        when REG_TMR1H  => tmr1h_reg <= unsigned(HWDATA(7 downto 0));
                        when REG_T1CON  => t1con_reg <= HWDATA(7 downto 0);
                        when REG_TMR2   => tmr2_reg  <= unsigned(HWDATA(7 downto 0));
                        when REG_T2CON  => t2con_reg <= HWDATA(7 downto 0);
                        when REG_PR2    => pr2_reg   <= unsigned(HWDATA(7 downto 0));
                        when REG_PIR1   => pir1_reg  <= pir1_reg and not HWDATA(7 downto 0);
                        when REG_PIE1   => pie1_reg  <= HWDATA(7 downto 0);
                        when others => null;
                    end case;
                end if;

                -- Timer0: 8-bit with prescaler
                ps_val := unsigned(option_reg(2 downto 0)) & '0';
                if option_reg(3) = '1' then ps_val := "0000"; end if; -- PSA=1 -> 1:1
                if option_reg(5) = '1' then -- external clock
                    if t0_clk = '1' and t0_clk_prev = '0' then
                        if t0_prescale = ps_val then
                            t0_prescale <= (others => '0');
                            if tmr0_reg = x"FF" then tmr0_reg <= (others => '0'); tmr0_irq <= '1';
                            else tmr0_reg <= tmr0_reg + 1; end if;
                        else t0_prescale <= t0_prescale + 1; end if;
                    end if;
                    t0_clk_prev <= t0_clk;
                else -- internal clock
                    if t0_prescale = ps_val then
                        t0_prescale <= (others => '0');
                        if tmr0_reg = x"FF" then tmr0_reg <= (others => '0'); tmr0_irq <= '1';
                        else tmr0_reg <= tmr0_reg + 1; end if;
                    else t0_prescale <= t0_prescale + 1; end if;
                end if;

                -- Timer1: 16-bit
                if t1con_reg(0) = '1' then -- TMR1ON
                    if t1con_reg(1) = '1' then -- external clock
                        if t1_clk = '1' and t1_clk_prev = '0' then
                            if t1_prescale = unsigned(t1con_reg(5 downto 4)) then
                                t1_prescale <= (others => '0');
                                if tmr1l_reg = x"FF" then
                                    tmr1l_reg <= (others => '0');
                                    if tmr1h_reg = x"FF" then tmr1h_reg <= (others => '0'); tmr1_irq <= '1';
                                    else tmr1h_reg <= tmr1h_reg + 1; end if;
                                else tmr1l_reg <= tmr1l_reg + 1; end if;
                            else t1_prescale <= t1_prescale + 1; end if;
                        end if;
                        t1_clk_prev <= t1_clk;
                    else -- internal clock
                        if t1_prescale = unsigned(t1con_reg(5 downto 4)) then
                            t1_prescale <= (others => '0');
                            if tmr1l_reg = x"FF" then
                                tmr1l_reg <= (others => '0');
                                if tmr1h_reg = x"FF" then tmr1h_reg <= (others => '0'); tmr1_irq <= '1';
                                else tmr1h_reg <= tmr1h_reg + 1; end if;
                            else tmr1l_reg <= tmr1l_reg + 1; end if;
                        else t1_prescale <= t1_prescale + 1; end if;
                    end if;
                end if;

                -- Timer2: 8-bit with PR2 period
                if t2con_reg(2) = '1' then -- TMR2ON
                    case t2con_reg(1 downto 0) is
                        when "00" => t2_ps := "0000";
                        when "01" => t2_ps := "0011";
                        when others => t2_ps := "1111";
                    end case;
                    if t2_prescale = t2_ps then
                        t2_prescale <= (others => '0');
                        if tmr2_reg = pr2_reg then
                            tmr2_reg <= (others => '0'); tmr2_irq <= '1';
                            t2_out_reg <= not t2_out_reg;
                        else tmr2_reg <= tmr2_reg + 1; end if;
                    else t2_prescale <= t2_prescale + 1; end if;
                end if;
            end if;
        end if;
    end process timer_proc;

    -- Register read mux
    reg_read : process(reg_sel, option_reg, tmr0_reg, tmr1l_reg, tmr1h_reg,
                       t1con_reg, tmr2_reg, t2con_reg, pr2_reg, pir1_reg, pie1_reg)
    begin
        case reg_sel is
            when REG_OPTION => HRDATA <= x"000000" & option_reg;
            when REG_TMR0   => HRDATA <= x"000000" & std_logic_vector(tmr0_reg);
            when REG_TMR1L  => HRDATA <= x"000000" & std_logic_vector(tmr1l_reg);
            when REG_TMR1H  => HRDATA <= x"000000" & std_logic_vector(tmr1h_reg);
            when REG_T1CON  => HRDATA <= x"000000" & t1con_reg;
            when REG_TMR2   => HRDATA <= x"000000" & std_logic_vector(tmr2_reg);
            when REG_T2CON  => HRDATA <= x"000000" & t2con_reg;
            when REG_PR2    => HRDATA <= x"000000" & std_logic_vector(pr2_reg);
            when REG_PIR1   => HRDATA <= x"000000" & pir1_reg;
            when REG_PIE1   => HRDATA <= x"000000" & pie1_reg;
            when others     => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    t2_out <= t2_out_reg;
    pic_timer_irq <= (tmr1_irq and pie1_reg(0)) or (tmr2_irq and pie1_reg(1));

end architecture rtl;

-- ================================================================================
-- msp430_timer_b : MSP430 Timer_B (16-bit, 7 capture/compare blocks)
-- ================================================================================
-- Similar to Timer_A but with 7 CC blocks and group latch feature.
-- Modes: Stop, Up, Continuous, Up/Down.
-- Registers: TBCTL, TBR, TBCCR0-6, TBCCTL0-6, TBIV.
--
-- Register Map (HADDR[8:2]):
--   0x00: TBCTL    - Timer B control
--   0x04: TBR      - Timer B counter (16-bit)
--   0x08: TBCCR0-6 - Capture/compare registers
--   0x24: TBCCTL0-6 - Capture/compare control registers
--   0x40: TBIV     - Timer B interrupt vector (RO)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity msp430_timer_b is
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

        -- Timer outputs
        tb_clk  : out std_logic;
        tb_out  : out std_logic_vector(6 downto 0);
        tb_irq  : out std_logic
    );
end entity msp430_timer_b;

architecture rtl of msp430_timer_b is

    constant NUM_CC : integer := 7;

    constant REG_TBCTL    : std_logic_vector(6 downto 0) := "0000000";
    constant REG_TBR      : std_logic_vector(6 downto 0) := "0000001";
    constant REG_TBCCR0   : std_logic_vector(6 downto 0) := "0000010";
    constant REG_TBCCTL0  : std_logic_vector(6 downto 0) := "0001001";

    signal tbctl_reg  : std_logic_vector(15 downto 0) := (others => '0');
    signal tbr_reg    : unsigned(15 downto 0) := (others => '0');
    type tbccr_arr  is array(0 to NUM_CC-1) of unsigned(15 downto 0);
    type tbcctl_arr is array(0 to NUM_CC-1) of std_logic_vector(15 downto 0);
    signal tbccr_reg  : tbccr_arr := (others => (others => '0'));
    signal tbcctl_reg : tbcctl_arr := (others => (others => '0'));
    signal tbiv_reg   : std_logic_vector(15 downto 0) := (others => '0');

    signal cc_irq : std_logic_vector(NUM_CC-1 downto 0) := (others => '0');
    signal tb_out_reg : std_logic_vector(NUM_CC-1 downto 0) := (others => '0');

    signal reg_sel  : std_logic_vector(6 downto 0);
    signal write_en : std_logic;
    signal timer_tick : std_logic;
    signal prescale_cnt : unsigned(7 downto 0) := (others => '0');

begin

    reg_sel  <= HADDR(8 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    prescaler : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                prescale_cnt <= (others => '0');
                timer_tick <= '0';
            else
                if prescale_cnt = 3 then
                    prescale_cnt <= (others => '0');
                    timer_tick <= '1';
                else
                    prescale_cnt <= prescale_cnt + 1;
                    timer_tick <= '0';
                end if;
            end if;
        end if;
    end process prescaler;

    timer_proc : process(HCLK)
        variable mc : std_logic_vector(1 downto 0);
        variable idx : integer;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                tbr_reg <= (others => '0');
                tbctl_reg <= (others => '0');
                tbccr_reg <= (others => (others => '0'));
                tbcctl_reg <= (others => (others => '0'));
                cc_irq <= (others => '0');
                tb_out_reg <= (others => '0');
            else
                mc := tbctl_reg(5 downto 4);
                if write_en = '1' then
                    case reg_sel is
                        when REG_TBCTL =>
                            tbctl_reg <= HWDATA(15 downto 0);
                            if HWDATA(1) = '1' then tbr_reg <= (others => '0'); end if;
                        when REG_TBR => tbr_reg <= unsigned(HWDATA(15 downto 0));
                        when others =>
                            if unsigned(reg_sel) >= unsigned(REG_TBCCR0) and
                               unsigned(reg_sel) < unsigned(REG_TBCCR0) + NUM_CC then
                                idx := to_integer(unsigned(reg_sel) - unsigned(REG_TBCCR0));
                                tbccr_reg(idx) <= unsigned(HWDATA(15 downto 0));
                            elsif unsigned(reg_sel) >= unsigned(REG_TBCCTL0) and
                                  unsigned(reg_sel) < unsigned(REG_TBCCTL0) + NUM_CC then
                                idx := to_integer(unsigned(reg_sel) - unsigned(REG_TBCCTL0));
                                tbcctl_reg(idx) <= HWDATA(15 downto 0);
                                if HWDATA(0) = '1' then cc_irq(idx) <= '0'; end if;
                            end if;
                    end case;
                end if;

                if timer_tick = '1' and mc /= "00" then
                    case mc is
                        when "01" => -- Up
                            if tbr_reg = tbccr_reg(0) then
                                tbr_reg <= (others => '0');
                                cc_irq(0) <= '1';
                            else tbr_reg <= tbr_reg + 1; end if;
                        when "10" => -- Continuous
                            if tbr_reg = x"FFFF" then
                                tbr_reg <= (others => '0');
                                cc_irq(0) <= '1';
                            else tbr_reg <= tbr_reg + 1; end if;
                        when "11" => -- Up/Down
                            if tbr_reg = tbccr_reg(0) then
                                tbr_reg <= tbr_reg - 1;
                                cc_irq(0) <= '1';
                            elsif tbr_reg = 0 then
                                tbr_reg <= tbr_reg + 1;
                            end if;
                        when others => null;
                    end case;
                    for i in 1 to NUM_CC-1 loop
                        if tbr_reg = tbccr_reg(i) then
                            cc_irq(i) <= '1';
                            if tbcctl_reg(i)(7 downto 5) = "001" then
                                tb_out_reg(i) <= not tb_out_reg(i);
                            end if;
                        end if;
                    end loop;
                end if;
            end if;
        end if;
    end process timer_proc;

    tbiv_proc : process(cc_irq)
    begin
        if cc_irq(0) = '1' then tbiv_reg <= x"0002";
        elsif cc_irq(1) = '1' then tbiv_reg <= x"0004";
        elsif cc_irq(2) = '1' then tbiv_reg <= x"0006";
        elsif cc_irq(3) = '1' then tbiv_reg <= x"0008";
        elsif cc_irq(4) = '1' then tbiv_reg <= x"000A";
        elsif cc_irq(5) = '1' then tbiv_reg <= x"000C";
        elsif cc_irq(6) = '1' then tbiv_reg <= x"000E";
        else tbiv_reg <= x"0000"; end if;
    end process tbiv_proc;

    reg_read : process(reg_sel, tbctl_reg, tbr_reg, tbccr_reg, tbcctl_reg, tbiv_reg)
        variable idx : integer;
    begin
        case reg_sel is
            when REG_TBCTL => HRDATA <= x"0000" & tbctl_reg;
            when REG_TBR   => HRDATA <= x"0000" & std_logic_vector(tbr_reg);
            when others =>
                if unsigned(reg_sel) >= unsigned(REG_TBCCR0) and
                   unsigned(reg_sel) < unsigned(REG_TBCCR0) + NUM_CC then
                    idx := to_integer(unsigned(reg_sel) - unsigned(REG_TBCCR0));
                    HRDATA <= x"0000" & std_logic_vector(tbccr_reg(idx));
                elsif unsigned(reg_sel) >= unsigned(REG_TBCCTL0) and
                      unsigned(reg_sel) < unsigned(REG_TBCCTL0) + NUM_CC then
                    idx := to_integer(unsigned(reg_sel) - unsigned(REG_TBCCTL0));
                    HRDATA <= x"0000" & tbcctl_reg(idx);
                elsif reg_sel = "1000000" then
                    HRDATA <= x"0000" & tbiv_reg;
                else
                    HRDATA <= (others => '0');
                end if;
        end case;
    end process reg_read;

    tb_clk <= HCLK;
    tb_out <= tb_out_reg;
    tb_irq <= cc_irq(0) or cc_irq(1) or cc_irq(2) or cc_irq(3) or
              cc_irq(4) or cc_irq(5) or cc_irq(6);

end architecture rtl;

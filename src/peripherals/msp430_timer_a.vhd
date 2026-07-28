-- ================================================================================
-- msp430_timer_a : MSP430 Timer_A (16-bit, 5 capture/compare blocks)
-- ================================================================================
-- Modes: Stop, Up, Continuous, Up/Down.
-- Registers: TACTL, TAR, TACCR0-4, TACCTL0-4, TAIV.
--
-- Register Map (HADDR[7:2]):
--   0x00: TACTL    - Timer A control
--   0x04: TAR      - Timer A counter (16-bit)
--   0x08: TACCR0   - Capture/compare 0
--   0x0C: TACCR1
--   0x10: TACCR2
--   0x14: TACCR3
--   0x18: TACCR4
--   0x1C: TACCTL0  - Capture/compare control 0
--   0x20: TACCTL1
--   0x24: TACCTL2
--   0x28: TACCTL3
--   0x2C: TACCTL4
--   0x30: TAIV     - Timer A interrupt vector (RO)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity msp430_timer_a is
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
        ta_clk  : out std_logic;
        ta_out  : out std_logic_vector(4 downto 0);
        ta_irq  : out std_logic
    );
end entity msp430_timer_a;

architecture rtl of msp430_timer_a is

    constant NUM_CC : integer := 5;

    constant REG_TACTL   : std_logic_vector(5 downto 0) := "000000";
    constant REG_TAR     : std_logic_vector(5 downto 0) := "000001";
    constant REG_TACCR0  : std_logic_vector(5 downto 0) := "000010";
    constant REG_TACCTL0 : std_logic_vector(5 downto 0) := "000111";

    signal tactl_reg  : std_logic_vector(15 downto 0) := (others => '0');
    signal tar_reg    : unsigned(15 downto 0) := (others => '0');
    type taccr_arr  is array(0 to NUM_CC-1) of unsigned(15 downto 0);
    type tacctl_arr is array(0 to NUM_CC-1) of std_logic_vector(15 downto 0);
    signal taccr_reg  : taccr_arr := (others => (others => '0'));
    signal tacctl_reg : tacctl_arr := (others => (others => '0'));
    signal taiv_reg   : std_logic_vector(15 downto 0) := (others => '0');

    signal cc_irq : std_logic_vector(NUM_CC-1 downto 0) := (others => '0');
    signal ta_out_reg : std_logic_vector(NUM_CC-1 downto 0) := (others => '0');

    signal reg_sel  : std_logic_vector(5 downto 0);
    signal write_en : std_logic;
    signal timer_tick : std_logic;
    signal prescale_cnt : unsigned(7 downto 0) := (others => '0');

begin

    reg_sel  <= HADDR(7 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Prescaler (simplified: divide by 4)
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

    -- Timer counting
    timer_proc : process(HCLK)
        variable mc : std_logic_vector(1 downto 0);
        variable mode : integer;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                tar_reg <= (others => '0');
                tactl_reg <= (others => '0');
                taccr_reg <= (others => (others => '0'));
                tacctl_reg <= (others => (others => '0'));
                cc_irq <= (others => '0');
                ta_out_reg <= (others => '0');
            else
                mc := tactl_reg(5 downto 4); -- MC bits
                -- Register writes
                if write_en = '1' then
                    case reg_sel is
                        when REG_TACTL =>
                            tactl_reg <= HWDATA(15 downto 0);
                            if HWDATA(1) = '1' then -- TACLR
                                tar_reg <= (others => '0');
                            end if;
                        when REG_TAR => tar_reg <= unsigned(HWDATA(15 downto 0));
                        when others =>
                            if unsigned(reg_sel) >= unsigned(REG_TACCR0) and
                               unsigned(reg_sel) < unsigned(REG_TACCR0) + NUM_CC then
                                taccr_reg(to_integer(unsigned(reg_sel) - unsigned(REG_TACCR0))) <= unsigned(HWDATA(15 downto 0));
                            elsif unsigned(reg_sel) >= unsigned(REG_TACCTL0) and
                                  unsigned(reg_sel) < unsigned(REG_TACCTL0) + NUM_CC then
                                tacctl_reg(to_integer(unsigned(reg_sel) - unsigned(REG_TACCTL0))) <= HWDATA(15 downto 0);
                            end if;
                    end case;
                end if;

                -- Timer counting
                if timer_tick = '1' and mc /= "00" then
                    case mc is
                        when "01" => -- Up mode: count to TACCR0
                            if tar_reg = taccr_reg(0) then
                                tar_reg <= (others => '0');
                                cc_irq(0) <= '1';
                            else
                                tar_reg <= tar_reg + 1;
                            end if;
                        when "10" => -- Continuous: count to 0xFFFF
                            if tar_reg = x"FFFF" then
                                tar_reg <= (others => '0');
                                cc_irq(0) <= '1'; -- TAIFG
                            else
                                tar_reg <= tar_reg + 1;
                            end if;
                        when "11" => -- Up/Down: count up to TACCR0 then down to 0
                            if tar_reg = taccr_reg(0) then
                                tar_reg <= tar_reg - 1;
                                cc_irq(0) <= '1';
                            elsif tar_reg = 0 then
                                tar_reg <= tar_reg + 1;
                            else
                                null; -- hold direction (simplified)
                            end if;
                        when others => null; -- Stop
                    end case;

                    -- Compare match for CC1-4
                    for i in 1 to NUM_CC-1 loop
                        if tar_reg = taccr_reg(i) then
                            cc_irq(i) <= '1';
                            -- Toggle output if OUTMOD = toggle
                            if tacctl_reg(i)(7 downto 5) = "001" then
                                ta_out_reg(i) <= not ta_out_reg(i);
                            end if;
                        end if;
                    end loop;
                end if;

                -- Clear IRQ flags on TACCTL write with COV=0
                if write_en = '1' and unsigned(reg_sel) >= unsigned(REG_TACCTL0) and
                   unsigned(reg_sel) < unsigned(REG_TACCTL0) + NUM_CC then
                    if HWDATA(0) = '1' then -- CCIFG cleared by write
                        cc_irq(to_integer(unsigned(reg_sel) - unsigned(REG_TACCTL0))) <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process timer_proc;

    -- TAIV: interrupt vector (priority encoded)
    taiv_proc : process(cc_irq, tactl_reg)
    begin
        if cc_irq(0) = '1' then
            taiv_reg <= x"0002";
        elsif cc_irq(1) = '1' then
            taiv_reg <= x"0004";
        elsif cc_irq(2) = '1' then
            taiv_reg <= x"0006";
        elsif cc_irq(3) = '1' then
            taiv_reg <= x"0008";
        elsif cc_irq(4) = '1' then
            taiv_reg <= x"000A";
        else
            taiv_reg <= x"0000";
        end if;
    end process taiv_proc;

    -- Register read mux
    reg_read : process(reg_sel, tactl_reg, tar_reg, taccr_reg, tacctl_reg, taiv_reg)
        variable idx : integer;
    begin
        case reg_sel is
            when REG_TACTL => HRDATA <= x"0000" & tactl_reg;
            when REG_TAR   => HRDATA <= x"0000" & std_logic_vector(tar_reg);
            when others =>
                if unsigned(reg_sel) >= unsigned(REG_TACCR0) and
                   unsigned(reg_sel) < unsigned(REG_TACCR0) + NUM_CC then
                    idx := to_integer(unsigned(reg_sel) - unsigned(REG_TACCR0));
                    HRDATA <= x"0000" & std_logic_vector(taccr_reg(idx));
                elsif unsigned(reg_sel) >= unsigned(REG_TACCTL0) and
                      unsigned(reg_sel) < unsigned(REG_TACCTL0) + NUM_CC then
                    idx := to_integer(unsigned(reg_sel) - unsigned(REG_TACCTL0));
                    HRDATA <= x"0000" & tacctl_reg(idx);
                elsif reg_sel = "001100" then
                    HRDATA <= x"0000" & taiv_reg;
                else
                    HRDATA <= (others => '0');
                end if;
        end case;
    end process reg_read;

    ta_clk <= HCLK;
    ta_out <= ta_out_reg;
    ta_irq <= cc_irq(0) or cc_irq(1) or cc_irq(2) or cc_irq(3) or cc_irq(4);

end architecture rtl;

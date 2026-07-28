-- ================================================================================
-- pic_ccp : PIC Capture/Compare/PWM module with AHB-Lite slave interface
-- ================================================================================
-- Two CCP modules (CCP1, CCP2). Capture: 16-bit timer capture. Compare: compare
-- with 16-bit timer. PWM: 10-bit PWM.
-- Registers: CCP1CON, CCPR1H/L, CCP2CON, CCPR2H/L.
--
-- Register Map (HADDR[5:2]):
--   0x00: CCP1CON - CCP1 control register
--   0x04: CCPR1L  - CCP1 compare/capture low byte
--   0x08: CCPR1H  - CCP1 compare/capture high byte
--   0x0C: CCP2CON - CCP2 control register
--   0x10: CCPR2L  - CCP2 compare/capture low byte
--   0x14: CCPR2H  - CCP2 compare/capture high byte
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pic_ccp is
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

        -- CCP pins (bidirectional: input for capture, output for compare/PWM)
        ccp1_pin : inout std_logic;
        ccp2_pin : inout std_logic;
        ccp_irq  : out std_logic
    );
end entity pic_ccp;

architecture rtl of pic_ccp is

    constant NUM_CCP : integer := 2;
    constant REG_CCP1CON : std_logic_vector(3 downto 0) := "0000";
    constant REG_CCPR1L  : std_logic_vector(3 downto 0) := "0001";
    constant REG_CCPR1H  : std_logic_vector(3 downto 0) := "0010";
    constant REG_CCP2CON : std_logic_vector(3 downto 0) := "0011";
    constant REG_CCPR2L  : std_logic_vector(3 downto 0) := "0100";
    constant REG_CCPR2H  : std_logic_vector(3 downto 0) := "0101";

    type ccpcon_arr is array(0 to NUM_CCP-1) of std_logic_vector(7 downto 0);
    type ccpr_arr  is array(0 to NUM_CCP-1) of unsigned(15 downto 0);

    signal ccpcon_reg : ccpcon_arr := (others => (others => '0'));
    signal ccpr_reg   : ccpr_arr  := (others => (others => '0'));
    signal ccp_irq_reg: std_logic_vector(NUM_CCP-1 downto 0) := (others => '0');

    -- Internal 16-bit timer (simulates TMR1 for capture/compare)
    signal timer16 : unsigned(15 downto 0) := (others => '0');
    -- PWM period counter (10-bit for PWM mode)
    signal pwm_cnt : unsigned(9 downto 0) := (others => '0');
    signal pwm_period : unsigned(9 downto 0) := (others => '0');

    -- Capture edge detection
    signal ccp_prev : std_logic_vector(NUM_CCP-1 downto 0) := (others => '0');

    -- CCP output pins
    signal ccp_out : std_logic_vector(NUM_CCP-1 downto 0) := (others => '0');

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Main CCP process
    ccp_proc : process(HCLK)
        variable mode : std_logic_vector(3 downto 0);
        variable ccp_pin_vec : std_logic_vector(1 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ccpcon_reg <= (others => (others => '0'));
                ccpr_reg   <= (others => (others => '0'));
                ccp_irq_reg <= (others => '0');
                timer16 <= (others => '0');
                pwm_cnt <= (others => '0');
                ccp_prev <= (others => '0');
                ccp_out <= (others => '0');
            else
                ccp_pin_vec := ccp2_pin & ccp1_pin;

                -- Register writes
                if write_en = '1' then
                    case reg_sel is
                        when REG_CCP1CON => ccpcon_reg(0) <= HWDATA(7 downto 0);
                        when REG_CCPR1L  => ccpr_reg(0)(7 downto 0)  <= unsigned(HWDATA(7 downto 0));
                        when REG_CCPR1H  => ccpr_reg(0)(15 downto 8) <= unsigned(HWDATA(7 downto 0));
                        when REG_CCP2CON => ccpcon_reg(1) <= HWDATA(7 downto 0);
                        when REG_CCPR2L  => ccpr_reg(1)(7 downto 0)  <= unsigned(HWDATA(7 downto 0));
                        when REG_CCPR2H  => ccpr_reg(1)(15 downto 8) <= unsigned(HWDATA(7 downto 0));
                        when others => null;
                    end case;
                end if;

                -- Free-running 16-bit timer for capture/compare
                timer16 <= timer16 + 1;
                -- PWM counter (10-bit)
                pwm_cnt <= pwm_cnt + 1;

                -- Per-CCP module logic
                for i in 0 to NUM_CCP-1 loop
                    mode := ccpcon_reg(i)(3 downto 0);
                    case mode is
                        when "0100" => -- Capture, rising edge
                            if ccp_pin_vec(i) = '1' and ccp_prev(i) = '0' then
                                ccpr_reg(i) <= timer16;
                                ccp_irq_reg(i) <= '1';
                            end if;
                        when "0101" => -- Capture, falling edge
                            if ccp_pin_vec(i) = '0' and ccp_prev(i) = '1' then
                                ccpr_reg(i) <= timer16;
                                ccp_irq_reg(i) <= '1';
                            end if;
                        when "0110" => -- Capture, 4th rising edge
                            -- Simplified: capture on rising edge
                            if ccp_pin_vec(i) = '1' and ccp_prev(i) = '0' then
                                ccpr_reg(i) <= timer16;
                                ccp_irq_reg(i) <= '1';
                            end if;
                        when "1000" | "1001" => -- Compare: set/reset output on match
                            if timer16 = ccpr_reg(i) then
                                ccp_irq_reg(i) <= '1';
                                if mode(0) = '1' then
                                    ccp_out(i) <= '1'; -- set on match
                                else
                                    ccp_out(i) <= '0'; -- clear on match
                                end if;
                            end if;
                        when "1100" | "1111" => -- PWM mode
                            -- 10-bit PWM: upper 8 bits from CCPRxL, lower 2 from CCPxCON
                            if pwm_cnt = unsigned(std_logic_vector'(std_logic_vector(ccpr_reg(i)(7 downto 0)) & ccpcon_reg(i)(5 downto 4))) then
                                ccp_out(i) <= '0';
                            elsif pwm_cnt = 0 then
                                ccp_out(i) <= '1';
                            end if;
                        when others => null;
                    end case;
                    ccp_prev(i) <= ccp_pin_vec(i);
                end loop;
            end if;
        end if;
    end process ccp_proc;

    -- Register read mux
    reg_read : process(reg_sel, ccpcon_reg, ccpr_reg)
    begin
        case reg_sel is
            when REG_CCP1CON => HRDATA <= x"000000" & ccpcon_reg(0);
            when REG_CCPR1L  => HRDATA <= x"000000" & std_logic_vector(ccpr_reg(0)(7 downto 0));
            when REG_CCPR1H  => HRDATA <= x"000000" & std_logic_vector(ccpr_reg(0)(15 downto 8));
            when REG_CCP2CON => HRDATA <= x"000000" & ccpcon_reg(1);
            when REG_CCPR2L  => HRDATA <= x"000000" & std_logic_vector(ccpr_reg(1)(7 downto 0));
            when REG_CCPR2H  => HRDATA <= x"000000" & std_logic_vector(ccpr_reg(1)(15 downto 8));
            when others      => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    -- Drive CCP pins in compare/PWM modes; high-Z in capture mode
    ccp1_pin <= ccp_out(0) when (ccpcon_reg(0)(3 downto 2) = "10" or ccpcon_reg(0)(3 downto 2) = "11") else 'Z';
    ccp2_pin <= ccp_out(1) when (ccpcon_reg(1)(3 downto 2) = "10" or ccpcon_reg(1)(3 downto 2) = "11") else 'Z';

    ccp_irq <= ccp_irq_reg(0) or ccp_irq_reg(1);

end architecture rtl;

-- ================================================================================
-- msp430_lpm : MSP430 Low-Power Modes controller with AHB-Lite slave interface
-- ================================================================================
-- Manages LPM0-LPM4 clock gating for CPU, MCLK, SMCLK, ACLK.
-- Registers: LPM_CTRL, LPM_STAT, CLK_GATE, WAKE_SRC.
--
-- Register Map:
--   0x00: LPM_CTRL  - Low-power mode control
--       bit0-2 = LPM mode (0=LPM0, 1=LPM1, ..., 4=LPM4)
--       bit3   = GIE (global interrupt enable)
--       bit4   = SCG0 (system clock generator 0)
--       bit5   = SCG1 (system clock generator 1)
--       bit6   = OSCOFF (oscillator off)
--       bit7   = CPUOFF (CPU off)
--   0x04: LPM_STAT  - LPM status (RO)
--       bit0 = in_lpm
--       bit1 = cpu_off
--       bit2 = mclk_off
--       bit3 = smclk_off
--       bit4 = aclk_off
--       bit5 = dco_off
--   0x08: CLK_GATE  - Manual clock gating override (RW)
--       bit0 = cpu_clk_en_manual
--       bit1 = mclk_en_manual
--       bit2 = smclk_en_manual
--       bit3 = aclk_en_manual
--   0x0C: WAKE_SRC  - Wake-up source enable mask (RW)
--       bit0 = wake_on_irq
--       bit1 = wake_on_timer
--       bit2 = wake_on_uart
--       bit3 = wake_on_wdt
--       bit4 = wake_on_rtc
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity msp430_lpm is
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

        -- Clock enable outputs
        cpu_clk_en : out std_logic;
        mclk_en    : out std_logic;
        smclk_en   : out std_logic;
        aclk_en    : out std_logic;
        lpm_irq    : out std_logic
    );
end entity msp430_lpm;

architecture rtl of msp430_lpm is

    constant REG_LPM_CTRL  : std_logic_vector(3 downto 0) := "0000";
    constant REG_LPM_STAT  : std_logic_vector(3 downto 0) := "0001";
    constant REG_CLK_GATE  : std_logic_vector(3 downto 0) := "0010";
    constant REG_WAKE_SRC  : std_logic_vector(3 downto 0) := "0011";

    signal lpm_ctrl_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal clk_gate_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal wake_src_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal in_lpm        : std_logic := '0';
    signal irq_pending   : std_logic := '0';

    -- LPM mode decoding
    -- LPM0: CPUOFF=1, SCG0=0, SCG1=0, OSCOFF=0 -> CPU off, MCLK off
    -- LPM1: CPUOFF=1, SCG0=1                  -> + DCO off (SMCLK from DCO)
    -- LPM2: CPUOFF=1, SCG0=1, SCG1=1          -> + SMCLK off
    -- LPM3: CPUOFF=1, SCG0=1, SCG1=1, OSCOFF=0 -> LPM3 (DCO+SMCLK off, ACLK on)
    -- LPM4: CPUOFF=1, SCG0=1, SCG1=1, OSCOFF=1 -> All clocks off

    signal cpu_off  : std_logic;
    signal mclk_off : std_logic;
    signal smclk_off: std_logic;
    signal aclk_off : std_logic;
    signal dco_off  : std_logic;

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Decode LPM mode from control bits
    cpu_off   <= lpm_ctrl_reg(7);
    dco_off   <= lpm_ctrl_reg(4);
    smclk_off <= lpm_ctrl_reg(5) or lpm_ctrl_reg(4);
    aclk_off  <= lpm_ctrl_reg(6);
    mclk_off  <= lpm_ctrl_reg(7);

    -- LPM state machine
    lpm_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                lpm_ctrl_reg <= (others => '0');
                clk_gate_reg <= (others => '0');
                wake_src_reg <= (others => '0');
                in_lpm       <= '0';
                irq_pending  <= '0';
            else
                -- Register writes
                if write_en = '1' then
                    case reg_sel is
                        when REG_LPM_CTRL => lpm_ctrl_reg <= HWDATA(7 downto 0);
                        when REG_CLK_GATE => clk_gate_reg <= HWDATA(7 downto 0);
                        when REG_WAKE_SRC => wake_src_reg <= HWDATA(7 downto 0);
                        when others => null;
                    end case;
                end if;

                -- Determine if in LPM
                if lpm_ctrl_reg(7) = '1' or lpm_ctrl_reg(6) = '1' or
                   lpm_ctrl_reg(5) = '1' or lpm_ctrl_reg(4) = '1' then
                    in_lpm <= '1';
                else
                    in_lpm <= '0';
                end if;

                -- Wake-up: writing 0 to CPUOFF exits LPM
                if write_en = '1' and reg_sel = REG_LPM_CTRL and HWDATA(7) = '0' then
                    in_lpm <= '0';
                    irq_pending <= '0';
                end if;

                -- IRQ generation when entering LPM with wake source enabled
                if in_lpm = '1' and wake_src_reg(0) = '1' then
                    irq_pending <= '1';
                end if;
            end if;
        end if;
    end process lpm_proc;

    -- Register read mux
    reg_read : process(reg_sel, lpm_ctrl_reg, clk_gate_reg, wake_src_reg,
                       in_lpm, cpu_off, mclk_off, smclk_off, aclk_off, dco_off, irq_pending)
    begin
        case reg_sel is
            when REG_LPM_CTRL => HRDATA <= x"000000" & lpm_ctrl_reg;
            when REG_LPM_STAT =>
                HRDATA <= x"000000" & "00" & dco_off & aclk_off & smclk_off & mclk_off & cpu_off & in_lpm;
            when REG_CLK_GATE => HRDATA <= x"000000" & clk_gate_reg;
            when REG_WAKE_SRC => HRDATA <= x"000000" & wake_src_reg;
            when others       => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    -- Clock enable outputs (manual override takes priority)
    cpu_clk_en <= clk_gate_reg(0) when clk_gate_reg(0) = '1' else not cpu_off;
    mclk_en    <= clk_gate_reg(1) when clk_gate_reg(1) = '1' else not mclk_off;
    smclk_en   <= clk_gate_reg(2) when clk_gate_reg(2) = '1' else not smclk_off;
    aclk_en    <= clk_gate_reg(3) when clk_gate_reg(3) = '1' else not aclk_off;

    lpm_irq <= irq_pending;

end architecture rtl;

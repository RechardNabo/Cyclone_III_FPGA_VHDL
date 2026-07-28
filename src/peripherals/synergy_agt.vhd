-- ================================================================================
-- synergy_agt : Asynchronous General Timer (16-bit, low-power)
-- ================================================================================
-- Renesas Synergy-style AGT for Cyclone III FPGA.
--
-- Features:
--   * 16-bit down-counter for low-power operation
--   * Programmable period and compare/capture
--   * One-shot and periodic modes
--   * Single output pin and interrupt
--
-- Register Map:
--   0x00: AGT_CTRL - bit0=enable, bit1=irq_en, bit2=mode(0=periodic,1=one-shot)
--   0x04: AGT_STAT - bit0=underflow flag (write-1-to-clear)
--   0x08: AGT_CNT  - current 16-bit counter value (RO)
--   0x0C: AGT_PER  - 16-bit period value
--   0x10: AGT_CC   - 16-bit compare/capture value
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_agt is
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

        -- AGT I/O
        agt_out   : out std_logic;
        agt_irq   : out std_logic
    );
end entity synergy_agt;

architecture rtl of synergy_agt is

    constant REG_AGT_CTRL : std_logic_vector(3 downto 0) := "0000";
    constant REG_AGT_STAT : std_logic_vector(3 downto 0) := "0001";
    constant REG_AGT_CNT  : std_logic_vector(3 downto 0) := "0010";
    constant REG_AGT_PER  : std_logic_vector(3 downto 0) := "0011";
    constant REG_AGT_CC   : std_logic_vector(3 downto 0) := "0100";

    signal agt_ctrl : std_logic_vector(31 downto 0) := (others => '0');
    signal agt_stat : std_logic_vector(31 downto 0) := (others => '0');
    signal agt_cnt  : unsigned(15 downto 0) := (others => '0');
    signal agt_per  : unsigned(15 downto 0) := (others => '0');
    signal agt_cc   : unsigned(15 downto 0) := (others => '0');
    signal agt_out_reg : std_logic := '0';

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                agt_ctrl <= (others => '0');
                agt_stat <= (others => '0');
                agt_per  <= (others => '0');
                agt_cc   <= (others => '0');
            elsif write_en = '1' then
                case reg_sel is
                    when REG_AGT_CTRL =>
                        agt_ctrl <= HWDATA;
                    when REG_AGT_STAT =>
                        if HWDATA(0) = '1' then
                            agt_stat(0) <= '0';
                        end if;
                    when REG_AGT_PER =>
                        agt_per <= unsigned(HWDATA(15 downto 0));
                    when REG_AGT_CC =>
                        agt_cc  <= unsigned(HWDATA(15 downto 0));
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Timer engine (16-bit down-counter)
    timer_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                agt_cnt     <= (others => '0');
                agt_out_reg <= '0';
            elsif agt_ctrl(0) = '1' then
                if agt_cnt = 0 then
                    -- Underflow
                    agt_stat(0) <= '1';
                    if agt_ctrl(2) = '1' then
                        -- One-shot: auto-disable
                        agt_ctrl(0) <= '0';
                        agt_cnt <= (others => '0');
                    else
                        -- Periodic: reload
                        agt_cnt <= agt_per;
                    end if;
                    agt_out_reg <= not agt_out_reg;
                else
                    agt_cnt <= agt_cnt - 1;
                    -- Toggle output at compare match
                    if agt_cnt = agt_cc then
                        agt_out_reg <= not agt_out_reg;
                    end if;
                end if;
            end if;
        end if;
    end process timer_proc;

    -- Register read mux
    reg_read : process(reg_sel, agt_ctrl, agt_stat, agt_cnt, agt_per, agt_cc)
    begin
        case reg_sel is
            when REG_AGT_CTRL =>
                HRDATA <= agt_ctrl;
            when REG_AGT_STAT =>
                HRDATA <= agt_stat;
            when REG_AGT_CNT =>
                HRDATA <= x"0000" & std_logic_vector(agt_cnt);
            when REG_AGT_PER =>
                HRDATA <= x"0000" & std_logic_vector(agt_per);
            when REG_AGT_CC =>
                HRDATA <= x"0000" & std_logic_vector(agt_cc);
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    agt_out <= agt_out_reg;
    agt_irq <= agt_stat(0) and agt_ctrl(1);

end architecture rtl;

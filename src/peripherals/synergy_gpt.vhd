-- ================================================================================
-- synergy_gpt : General Purpose Timer (32-bit, 6 channels)
-- ================================================================================
-- Renesas Synergy-style GPT for Cyclone III FPGA.
--
-- Features:
--   * 6 independent 32-bit timer channels
--   * Modes: one-shot, periodic, PWM, capture
--   * 2 output pins per channel (12 total)
--   * 1 input pin per channel for capture (6 total)
--   * Per-channel interrupt
--
-- Register Map:
--   0x00: GPT_CTRL  - bit[5:0]=channel enable, bit[11:6]=irq enable
--   0x04: GPT_STAT  - bit[5:0]=channel IRQ flags (write-1-to-clear)
--   Per channel (base + 0x08 + ch*0x0C):
--   0x08+ch*0x0C: GPTx_CNT - current counter value (RO)
--   0x0C+ch*0x0C: GPTx_PER - period / top value
--   0x10+ch*0x0C: GPTx_CC  - compare/capture value
--   Mode field in GPTx_CNT high bits: bits[31:30] = mode (0=oneshot,1=periodic,2=pwm,3=capture)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_gpt is
    generic (
        CLK_FREQ : integer := 50000000
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

        -- GPT I/O
        gpt_out   : out std_logic_vector(11 downto 0);  -- 2 per channel
        gpt_in    : in  std_logic_vector(5 downto 0);   -- 1 per channel
        gpt_irq   : out std_logic_vector(5 downto 0)
    );
end entity synergy_gpt;

architecture rtl of synergy_gpt is

    constant NUM_CH : integer := 6;

    constant REG_GPT_CTRL : integer := 0;
    constant REG_GPT_STAT : integer := 1;

    type ch_cnt_t  is array(0 to NUM_CH-1) of unsigned(31 downto 0);
    type ch_reg_t  is array(0 to NUM_CH-1) of std_logic_vector(31 downto 0);

    signal gpt_ctrl : std_logic_vector(31 downto 0) := (others => '0');
    signal gpt_stat : std_logic_vector(31 downto 0) := (others => '0');

    signal gpt_cnt  : ch_cnt_t := (others => (others => '0'));
    signal gpt_per  : ch_reg_t := (others => (others => '0'));
    signal gpt_cc   : ch_reg_t := (others => (others => '0'));
    signal gpt_mode : ch_reg_t := (others => (others => '0'));  -- bits[31:30]

    signal gpt_out_reg : std_logic_vector(11 downto 0) := (others => '0');

    signal reg_idx    : integer range 0 to 63;
    signal ch_idx     : integer range 0 to NUM_CH-1;
    signal ch_reg_off : integer range 0 to 2;
    signal write_en   : std_logic;

begin

    reg_idx    <= to_integer(unsigned(HADDR(7 downto 2)));
    ch_idx     <= (reg_idx - 2) / 3 when reg_idx >= 2 else 0;
    ch_reg_off <= (reg_idx - 2) mod 3 when reg_idx >= 2 else 0;

    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                gpt_ctrl <= (others => '0');
                gpt_stat <= (others => '0');
                gpt_cnt  <= (others => (others => '0'));
                gpt_per  <= (others => (others => '0'));
                gpt_cc   <= (others => (others => '0'));
                gpt_mode <= (others => (others => '0'));
            elsif write_en = '1' then
                if reg_idx = REG_GPT_CTRL then
                    gpt_ctrl <= HWDATA;
                elsif reg_idx = REG_GPT_STAT then
                    for i in 0 to NUM_CH-1 loop
                        if HWDATA(i) = '1' then
                            gpt_stat(i) <= '0';
                        end if;
                    end loop;
                elsif reg_idx >= 2 then
                    case ch_reg_off is
                        when 0 =>  -- CNT: writing sets mode in high bits, resets counter
                            gpt_mode(ch_idx) <= HWDATA;
                            gpt_cnt(ch_idx)  <= (others => '0');
                        when 1 =>  -- PER
                            gpt_per(ch_idx) <= HWDATA;
                        when 2 =>  -- CC
                            gpt_cc(ch_idx)  <= HWDATA;
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process reg_write;

    -- Timer engine
    timer_engine : process(HCLK)
        variable mode : integer range 0 to 3;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                gpt_out_reg <= (others => '0');
            else
                for i in 0 to NUM_CH-1 loop
                    if gpt_ctrl(i) = '1' then
                        mode := to_integer(unsigned(gpt_mode(i)(31 downto 30)));
                        case mode is
                            when 0 =>  -- one-shot
                                if gpt_cnt(i) < unsigned(gpt_per(i)) then
                                    gpt_cnt(i) <= gpt_cnt(i) + 1;
                                else
                                    gpt_stat(i) <= '1';
                                    gpt_ctrl(i) <= '0';  -- auto-disable
                                end if;
                            when 1 =>  -- periodic
                                if gpt_cnt(i) >= unsigned(gpt_per(i)) then
                                    gpt_cnt(i) <= (others => '0');
                                    gpt_stat(i) <= '1';
                                else
                                    gpt_cnt(i) <= gpt_cnt(i) + 1;
                                end if;
                            when 2 =>  -- PWM
                                if gpt_cnt(i) >= unsigned(gpt_per(i)) then
                                    gpt_cnt(i) <= (others => '0');
                                else
                                    gpt_cnt(i) <= gpt_cnt(i) + 1;
                                end if;
                                gpt_out_reg(i*2)   <= '1' when gpt_cnt(i) < unsigned(gpt_cc(i)) else '0';
                                gpt_out_reg(i*2+1) <= '1' when gpt_cnt(i) >= unsigned(gpt_cc(i)) else '0';
                            when 3 =>  -- capture
                                if gpt_in(i) = '1' then
                                    gpt_cc(i)   <= std_logic_vector(gpt_cnt(i));
                                    gpt_stat(i) <= '1';
                                end if;
                                gpt_cnt(i) <= gpt_cnt(i) + 1;
                            when others => null;
                        end case;
                    end if;
                end loop;
            end if;
        end if;
    end process timer_engine;

    -- Register read mux
    reg_read : process(reg_idx, gpt_ctrl, gpt_stat, gpt_cnt, gpt_per, gpt_cc, gpt_mode)
    begin
        case reg_idx is
            when REG_GPT_CTRL => HRDATA <= gpt_ctrl;
            when REG_GPT_STAT => HRDATA <= gpt_stat;
            when others =>
                if reg_idx >= 2 then
                    case ch_reg_off is
                        when 0 => HRDATA <= gpt_mode(ch_idx)(31 downto 30) & std_logic_vector(gpt_cnt(ch_idx)(29 downto 0));
                        when 1 => HRDATA <= gpt_per(ch_idx);
                        when 2 => HRDATA <= gpt_cc(ch_idx);
                        when others => HRDATA <= (others => '0');
                    end case;
                else
                    HRDATA <= (others => '0');
                end if;
        end case;
    end process reg_read;

    gpt_out <= gpt_out_reg;

    irq_gen : for i in 0 to NUM_CH-1 generate
        gpt_irq(i) <= gpt_stat(i) and gpt_ctrl(6+i);
    end generate;

end architecture rtl;

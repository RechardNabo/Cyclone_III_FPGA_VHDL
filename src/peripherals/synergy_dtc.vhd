-- ================================================================================
-- synergy_dtc : Data Transfer Controller (lightweight DMA companion)
-- ================================================================================
-- Renesas Synergy-style DTC for Cyclone III FPGA.
--
-- Features:
--   * Lightweight single-transfer controller (companion to DMAC)
--   * Vector-based transfer activation
--   * Source, destination, and length registers
--   * Transfer complete interrupt
--
-- Register Map:
--   0x00: DTC_CTRL - bit0=enable, bit1=irq_en, bit2=start
--   0x04: DTC_STAT - bit0=busy, bit1=done (write-1-to-clear)
--   0x08: DTC_VEC  - vector number that triggers transfer
--   0x0C: DTC_SRC  - source address
--   0x10: DTC_DST  - destination address
--   0x14: DTC_LEN  - transfer length in words
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_dtc is
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

        -- DTC interface
        dtc_irq   : out std_logic;
        dtc_req   : in  std_logic
    );
end entity synergy_dtc;

architecture rtl of synergy_dtc is

    constant REG_DTC_CTRL : std_logic_vector(3 downto 0) := "0000";
    constant REG_DTC_STAT : std_logic_vector(3 downto 0) := "0001";
    constant REG_DTC_VEC  : std_logic_vector(3 downto 0) := "0010";
    constant REG_DTC_SRC  : std_logic_vector(3 downto 0) := "0011";
    constant REG_DTC_DST  : std_logic_vector(3 downto 0) := "0100";
    constant REG_DTC_LEN  : std_logic_vector(3 downto 0) := "0101";

    signal dtc_ctrl : std_logic_vector(31 downto 0) := (others => '0');
    signal dtc_stat : std_logic_vector(31 downto 0) := (others => '0');
    signal dtc_vec  : std_logic_vector(31 downto 0) := (others => '0');
    signal dtc_src  : unsigned(31 downto 0) := (others => '0');
    signal dtc_dst  : unsigned(31 downto 0) := (others => '0');
    signal dtc_len  : unsigned(31 downto 0) := (others => '0');
    signal dtc_xfer : unsigned(31 downto 0) := (others => '0');

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
                dtc_ctrl <= (others => '0');
                dtc_stat <= (others => '0');
                dtc_vec  <= (others => '0');
                dtc_src  <= (others => '0');
                dtc_dst  <= (others => '0');
                dtc_len  <= (others => '0');
                dtc_xfer <= (others => '0');
            elsif write_en = '1' then
                case reg_sel is
                    when REG_DTC_CTRL =>
                        dtc_ctrl <= HWDATA;
                        if HWDATA(2) = '1' then
                            dtc_xfer <= (others => '0');
                        end if;
                    when REG_DTC_STAT =>
                        if HWDATA(1) = '1' then
                            dtc_stat(1) <= '0';
                        end if;
                    when REG_DTC_VEC =>
                        dtc_vec <= HWDATA;
                    when REG_DTC_SRC =>
                        dtc_src <= unsigned(HWDATA);
                    when REG_DTC_DST =>
                        dtc_dst <= unsigned(HWDATA);
                    when REG_DTC_LEN =>
                        dtc_len <= unsigned(HWDATA);
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Transfer engine
    xfer_engine : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                dtc_stat(0) <= '0';
            elsif dtc_ctrl(0) = '1' then
                if (dtc_ctrl(2) = '1' or dtc_req = '1') and dtc_xfer < dtc_len then
                    -- Perform single-word transfer (simulated)
                    dtc_xfer <= dtc_xfer + 1;
                    dtc_src  <= dtc_src + 4;
                    dtc_dst  <= dtc_dst + 4;
                    dtc_stat(0) <= '1';  -- busy
                    dtc_ctrl(2) <= '0';  -- clear start bit

                    if dtc_xfer + 1 = dtc_len then
                        -- Transfer complete
                        dtc_stat(0) <= '0';
                        dtc_stat(1) <= '1';
                    end if;
                else
                    dtc_stat(0) <= '0';
                end if;
            end if;
        end if;
    end process xfer_engine;

    -- Register read mux
    reg_read : process(reg_sel, dtc_ctrl, dtc_stat, dtc_vec, dtc_src, dtc_dst, dtc_len, dtc_xfer)
    begin
        case reg_sel is
            when REG_DTC_CTRL => HRDATA <= dtc_ctrl;
            when REG_DTC_STAT => HRDATA <= dtc_stat;
            when REG_DTC_VEC  => HRDATA <= dtc_vec;
            when REG_DTC_SRC  => HRDATA <= std_logic_vector(dtc_src);
            when REG_DTC_DST  => HRDATA <= std_logic_vector(dtc_dst);
            when REG_DTC_LEN  => HRDATA <= std_logic_vector(dtc_len);
            when others       => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    dtc_irq <= dtc_stat(1) and dtc_ctrl(1);

end architecture rtl;

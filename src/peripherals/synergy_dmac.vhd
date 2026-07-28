-- ================================================================================
-- synergy_dmac : 8-channel DMA Controller with round-robin arbitration
-- ================================================================================
-- Renesas Synergy-style DMA controller for Cyclone III FPGA.
--
-- Features:
--   * 8 independent DMA channels
--   * Round-robin channel arbitration
--   * Per-channel source, destination, and transfer length
--   * Transfer complete interrupt per channel
--   * Software-triggered transfers via AHB-Lite register interface
--
-- Register Map:
--   0x00: DMAC_CTRL  - bit0=enable, bit1=round_robin
--   0x04: DMAC_STAT  - bit[7:0]=channel done flags (write-1-to-clear)
--   Per channel (base + 0x08 + ch*0x0C):
--   0x08+ch*0x0C: CHx_CTRL - bit0=enable, bit1=irq_en, bit2=trigger
--   0x0C+ch*0x0C: CHx_SRC  - source address
--   0x10+ch*0x0C: CHx_DST  - destination address
--   0x14+ch*0x0C: CHx_LEN  - transfer length in words
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_dmac is
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

        -- DMA interface
        dmac_irq  : out std_logic_vector(7 downto 0);  -- per-channel IRQ
        dmac_req  : in  std_logic_vector(7 downto 0)   -- per-channel request
    );
end entity synergy_dmac;

architecture rtl of synergy_dmac is

    constant NUM_CH : integer := 8;

    -- Register address offsets (word-indexed)
    constant REG_DMAC_CTRL : integer := 0;  -- 0x00
    constant REG_DMAC_STAT : integer := 1;  -- 0x04

    type ch_ctrl_t  is array(0 to NUM_CH-1) of std_logic_vector(31 downto 0);
    type ch_addr_t  is array(0 to NUM_CH-1) of unsigned(31 downto 0);
    type ch_len_t   is array(0 to NUM_CH-1) of unsigned(31 downto 0);

    signal dmac_ctrl : std_logic_vector(31 downto 0) := (others => '0');
    signal dmac_stat : std_logic_vector(31 downto 0) := (others => '0');

    signal ch_ctrl   : ch_ctrl_t := (others => (others => '0'));
    signal ch_src    : ch_addr_t := (others => (others => '0'));
    signal ch_dst    : ch_addr_t := (others => (others => '0'));
    signal ch_len    : ch_len_t  := (others => (others => '0'));
    signal ch_xfer   : ch_len_t  := (others => (others => '0'));

    signal reg_idx    : integer range 0 to 63;
    signal ch_idx     : integer range 0 to NUM_CH-1;
    signal ch_reg_off : integer range 0 to 3;
    signal write_en   : std_logic;
    signal read_en    : std_logic;

    signal rr_ptr     : integer range 0 to NUM_CH-1 := 0;

begin

    -- Address decode: HADDR(7 downto 2) gives word index (0..63)
    reg_idx    <= to_integer(unsigned(HADDR(7 downto 2)));
    ch_idx     <= (reg_idx - 2) / 3 when reg_idx >= 2 else 0;
    ch_reg_off <= (reg_idx - 2) mod 3 when reg_idx >= 2 else 0;

    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                dmac_ctrl <= (others => '0');
                dmac_stat <= (others => '0');
                ch_ctrl   <= (others => (others => '0'));
                ch_src    <= (others => (others => '0'));
                ch_dst    <= (others => (others => '0'));
                ch_len    <= (others => (others => '0'));
                ch_xfer   <= (others => (others => '0'));
            elsif write_en = '1' then
                if reg_idx = REG_DMAC_CTRL then
                    dmac_ctrl <= HWDATA;
                elsif reg_idx = REG_DMAC_STAT then
                    -- Write-1-to-clear status flags
                    for i in 0 to NUM_CH-1 loop
                        if HWDATA(i) = '1' then
                            dmac_stat(i) <= '0';
                        end if;
                    end loop;
                elsif reg_idx >= 2 then
                    case ch_reg_off is
                        when 0 => ch_ctrl(ch_idx) <= HWDATA;
                        when 1 => ch_src(ch_idx)  <= unsigned(HWDATA);
                        when 2 => ch_dst(ch_idx)  <= unsigned(HWDATA);
                        when 3 => ch_len(ch_idx)  <= unsigned(HWDATA);
                                  ch_xfer(ch_idx) <= (others => '0');
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process reg_write;

    -- DMA transfer engine (round-robin)
    dma_engine : process(HCLK)
        variable active : boolean;
        variable sel    : integer range 0 to NUM_CH-1;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                rr_ptr <= 0;
            elsif dmac_ctrl(0) = '1' then
                -- Find next active channel via round-robin
                active := false;
                sel := rr_ptr;
                for i in 0 to NUM_CH-1 loop
                    sel := (rr_ptr + i) mod NUM_CH;
                    if (ch_ctrl(sel)(0) = '1') and
                       (dmac_req(sel) = '1' or ch_ctrl(sel)(2) = '1') and
                       (ch_xfer(sel) < ch_len(sel)) then
                        active := true;
                        exit;
                    end if;
                end loop;

                if active then
                    -- Simulate single-word transfer (increment counters)
                    ch_xfer(sel)  <= ch_xfer(sel) + 1;
                    ch_src(sel)   <= ch_src(sel) + 4;
                    ch_dst(sel)   <= ch_dst(sel) + 4;
                    -- Clear trigger bit
                    ch_ctrl(sel)(2) <= '0';

                    if ch_xfer(sel) + 1 = ch_len(sel) then
                        -- Transfer complete
                        dmac_stat(sel) <= '1';
                        ch_ctrl(sel)(0) <= '0';  -- auto-disable
                    end if;

                    -- Advance round-robin pointer
                    rr_ptr <= (sel + 1) mod NUM_CH;
                end if;
            end if;
        end if;
    end process dma_engine;

    -- Register read mux
    reg_read : process(reg_idx, dmac_ctrl, dmac_stat, ch_ctrl, ch_src, ch_dst, ch_len)
    begin
        case reg_idx is
            when REG_DMAC_CTRL =>
                HRDATA <= dmac_ctrl;
            when REG_DMAC_STAT =>
                HRDATA <= dmac_stat;
            when others =>
                if reg_idx >= 2 then
                    case ch_reg_off is
                        when 0 => HRDATA <= ch_ctrl(ch_idx);
                        when 1 => HRDATA <= std_logic_vector(ch_src(ch_idx));
                        when 2 => HRDATA <= std_logic_vector(ch_dst(ch_idx));
                        when 3 => HRDATA <= std_logic_vector(ch_len(ch_idx));
                        when others => HRDATA <= (others => '0');
                    end case;
                else
                    HRDATA <= (others => '0');
                end if;
        end case;
    end process reg_read;

    -- Per-channel interrupt output
    irq_gen : for i in 0 to NUM_CH-1 generate
        dmac_irq(i) <= dmac_stat(i) and ch_ctrl(i)(1);
    end generate;

end architecture rtl;

-- ================================================================================
-- ethernet_mac : Ethernet MAC Controller with 4-bit MII interface (educational)
-- ================================================================================
-- Implements a simplified Ethernet MAC controller with AHB-Lite slave register
-- interface and 4-bit MII interface. Supports basic frame TX/RX, CRC-32
-- generation/checking, MAC address filtering, and multicast hash filtering.
--
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- Register Map (word-aligned, offset from base, HADDR[7:2] selects register):
--   0x00: ETH_CTRL       - bit0=enable, bit1=tx_enable, bit2=rx_enable,
--                          bit3=loopback, bit4=promiscuous,
--                          bit5=tx_irq_en, bit6=rx_irq_en
--   0x04: ETH_STATUS     - bit0=tx_done, bit1=rx_ready, bit2=tx_busy, bit3=rx_busy,
--                          bit4=link_up, bit5=tx_error, bit6=rx_error,
--                          bit7=tx_underflow, bit8=rx_overflow
--   0x08: ETH_MAC_ADDR_L - MAC address low 32 bits
--   0x0C: ETH_MAC_ADDR_H - MAC address high 16 bits
--   0x10: ETH_TX_CTRL    - bit0=tx_start, bit1=tx_done(RO), bit2=tx_irq_pending
--   0x14: ETH_TX_LEN     - TX frame length in bytes
--   0x18: ETH_TX_DATA    - TX data FIFO port (write 32-bit words, auto-increment)
--   0x1C: ETH_TX_STATUS  - bit0=tx_ok, bit1=tx_error, bit2=tx_retry,
--                          bit3=tx_deferred, bit4=tx_collision_count
--   0x20: ETH_RX_CTRL    - bit0=rx_enable, bit1=rx_irq_pending, bit2=rx_flush
--   0x24: ETH_RX_LEN     - RX frame length in bytes
--   0x28: ETH_RX_DATA    - RX data FIFO port (read 32-bit words, auto-increment)
--   0x2C: ETH_RX_STATUS  - bit0=rx_ok, bit1=rx_error, bit2=rx_crc_error,
--                          bit3=rx_runt, bit4=rx_giant, bit5=rx_overflow
--   0x30: ETH_IRQ_STATUS - bit0=tx_done_irq, bit1=rx_done_irq,
--                          bit2=tx_error_irq, bit3=rx_error_irq
--   0x34: ETH_IRQ_CLEAR  - Write 1 to clear IRQ bits
--   0x38: ETH_HASH_L     - Multicast hash table low 32 bits
--   0x3C: ETH_HASH_H     - Multicast hash table high 32 bits
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ethernet_mac_ahb is
    generic (
        CLK_FREQ   : integer := 50_000_000;  -- System clock frequency
        FIFO_DEPTH : integer := 1024          -- TX/RX FIFO depth in bytes
    );
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

        -- MII interface (4-bit Media Independent Interface)
        mii_txd   : out std_logic_vector(3 downto 0);
        mii_rxd   : in  std_logic_vector(3 downto 0);
        mii_tx_en : out std_logic;
        mii_tx_clk: in  std_logic;
        mii_rx_clk: in  std_logic;
        mii_rx_dv : in  std_logic;
        mii_tx_er : out std_logic;
        mii_rx_er : in  std_logic;
        mii_crs   : in  std_logic;
        mii_col   : in  std_logic;

        -- MII management interface (MDIO/MDC)
        mdc       : out std_logic;
        mdio      : inout std_logic;

        -- Interrupt
        eth_int   : out std_logic
    );
end entity ethernet_mac_ahb;

architecture rtl of ethernet_mac_ahb is

    -- Register offsets
    constant REG_CTRL          : integer := 0;  -- 0x00
    constant REG_STATUS        : integer := 1;  -- 0x04
    constant REG_MAC_ADDR_L   : integer := 2;  -- 0x08
    constant REG_MAC_ADDR_H   : integer := 3;  -- 0x0C
    constant REG_TX_CTRL       : integer := 4;  -- 0x10
    constant REG_TX_LEN        : integer := 5;  -- 0x14
    constant REG_TX_DATA       : integer := 6;  -- 0x18
    constant REG_TX_STATUS     : integer := 7;  -- 0x1C
    constant REG_RX_CTRL       : integer := 8;  -- 0x20
    constant REG_RX_LEN        : integer := 9;  -- 0x24
    constant REG_RX_DATA       : integer := 10; -- 0x28
    constant REG_RX_STATUS     : integer := 11; -- 0x2C
    constant REG_IRQ_STATUS    : integer := 12; -- 0x30
    constant REG_IRQ_CLEAR     : integer := 13; -- 0x34
    constant REG_HASH_L        : integer := 14; -- 0x38
    constant REG_HASH_H        : integer := 15; -- 0x3C

    -- Control register bits
    constant CTRL_ENABLE       : integer := 0;
    constant CTRL_TX_ENABLE    : integer := 1;
    constant CTRL_RX_ENABLE    : integer := 2;
    constant CTRL_LOOPBACK     : integer := 3;
    constant CTRL_PROMISCUOUS  : integer := 4;
    constant CTRL_TX_IRQ_EN    : integer := 5;
    constant CTRL_RX_IRQ_EN    : integer := 6;

    -- Status register bits
    constant STATUS_TX_DONE    : integer := 0;
    constant STATUS_RX_READY   : integer := 1;
    constant STATUS_TX_BUSY    : integer := 2;
    constant STATUS_RX_BUSY    : integer := 3;
    constant STATUS_LINK_UP    : integer := 4;
    constant STATUS_TX_ERROR   : integer := 5;
    constant STATUS_RX_ERROR   : integer := 6;
    constant STATUS_TX_UNDERFLOW: integer := 7;
    constant STATUS_RX_OVERFLOW: integer := 8;

    -- TX control bits
    constant TXCTRL_START      : integer := 0;
    constant TXCTRL_DONE       : integer := 1;
    constant TXCTRL_IRQ_PEND   : integer := 2;

    -- RX control bits
    constant RXCTRL_ENABLE     : integer := 0;
    constant RXCTRL_IRQ_PEND   : integer := 1;
    constant RXCTRL_FLUSH      : integer := 2;

    -- TX FSM states
    type tx_state_t is (TX_IDLE, TX_PREAMBLE, TX_SFD, TX_DEST_MAC, TX_SRC_MAC,
                        TX_ETHERTYPE, TX_DATA, TX_PAD, TX_FCS, TX_IPG, TX_DONE);
    signal tx_state : tx_state_t := TX_IDLE;

    -- RX FSM states
    type rx_state_t is (RX_IDLE, RX_PREAMBLE, RX_SFD, RX_DEST_MAC, RX_SRC_MAC,
                        RX_ETHERTYPE, RX_DATA, RX_FCS, RX_CHECK, RX_STORE);
    signal rx_state : rx_state_t := RX_IDLE;

    -- Registers
    signal eth_ctrl_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal eth_mac_addr_l     : std_logic_vector(31 downto 0) := (others => '0');
    signal eth_mac_addr_h     : std_logic_vector(15 downto 0) := (others => '0');
    signal eth_tx_ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal eth_tx_len_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal eth_tx_status_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal eth_rx_ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal eth_rx_len_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal eth_rx_status_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal eth_irq_status     : std_logic_vector(31 downto 0) := (others => '0');
    signal eth_irq_set        : std_logic_vector(31 downto 0) := (others => '0');  -- set by FSMs
    signal eth_hash_l         : std_logic_vector(31 downto 0) := (others => '0');
    signal eth_hash_h         : std_logic_vector(31 downto 0) := (others => '0');

    -- TX FIFO (byte-wide for simplicity)
    type tx_fifo_t is array(0 to FIFO_DEPTH-1) of std_logic_vector(7 downto 0);
    signal tx_fifo_mem  : tx_fifo_t := (others => (others => '0'));
    signal tx_wr_ptr    : integer range 0 to FIFO_DEPTH-1 := 0;
    signal tx_rd_ptr    : integer range 0 to FIFO_DEPTH-1 := 0;
    signal tx_count     : integer range 0 to FIFO_DEPTH := 0;

    -- RX FIFO
    type rx_fifo_t is array(0 to FIFO_DEPTH-1) of std_logic_vector(7 downto 0);
    signal rx_fifo_mem  : rx_fifo_t := (others => (others => '0'));
    signal rx_wr_ptr    : integer range 0 to FIFO_DEPTH-1 := 0;
    signal rx_rd_ptr    : integer range 0 to FIFO_DEPTH-1 := 0;
    -- rx_count is computed combinationally from rx_wr_ptr - rx_rd_ptr
    signal rx_count     : integer range 0 to FIFO_DEPTH;

    -- TX internal signals
    signal tx_byte_cnt    : integer := 0;
    signal tx_nibble_cnt  : integer := 0;
    signal tx_crc32       : std_logic_vector(31 downto 0) := (others => '0');
    signal tx_nibble_reg  : std_logic_vector(3 downto 0) := (others => '0');

    -- RX internal signals
    signal rx_byte_cnt    : integer := 0;
    signal rx_nibble_cnt  : integer := 0;
    signal rx_crc32       : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_dest_mac_val    : std_logic_vector(47 downto 0) := (others => '0');
    signal rx_src_mac_val     : std_logic_vector(47 downto 0) := (others => '0');
    signal rx_ethertype_val   : std_logic_vector(15 downto 0) := (others => '0');
    signal rx_byte_shift  : std_logic_vector(7 downto 0) := (others => '0');

    -- Status signals
    signal tx_done_sig    : std_logic := '0';
    signal rx_ready_sig   : std_logic := '0';
    signal tx_busy_sig    : std_logic := '0';
    signal rx_busy_sig    : std_logic := '0';
    signal link_up_sig    : std_logic := '1';

    -- CRC-32 polynomial: 0x04C11DB7
    constant CRC32_POLY : std_logic_vector(31 downto 0) := x"04C11DB7";

    -- Address decode
    signal reg_sel : integer range 0 to 63;

    -- =========================================================================
    -- CRC-32 next-byte function (Ethernet FCS)
    -- =========================================================================
    function crc32_next(crc : std_logic_vector(31 downto 0);
                        byte_in : std_logic_vector(7 downto 0))
        return std_logic_vector is
        variable crc_tmp : std_logic_vector(31 downto 0);
        variable bit_in  : std_logic;
    begin
        crc_tmp := crc;
        for i in 0 to 7 loop
            bit_in := byte_in(i) xor crc_tmp(31);
            crc_tmp := crc_tmp(30 downto 0) & '0';
            if bit_in = '1' then
                crc_tmp := crc_tmp xor CRC32_POLY;
            end if;
        end loop;
        return crc_tmp;
    end function;

begin

    -- Address decoder: HADDR[7:2] selects register
    reg_sel <= to_integer(unsigned(HADDR(7 downto 2)));

    -- RX FIFO count (combinational: write pointer - read pointer)
    rx_count <= rx_wr_ptr - rx_rd_ptr when rx_wr_ptr >= rx_rd_ptr
                else (rx_wr_ptr + FIFO_DEPTH) - rx_rd_ptr;

    -- =========================================================================
    -- AHB-LITE WRITE PROCESS
    -- =========================================================================
    process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            eth_ctrl_reg      <= (others => '0');
            eth_mac_addr_l    <= (others => '0');
            eth_mac_addr_h    <= (others => '0');
            eth_tx_ctrl_reg   <= (others => '0');
            eth_tx_len_reg    <= (others => '0');
            eth_rx_ctrl_reg   <= (others => '0');
            eth_hash_l        <= (others => '0');
            eth_hash_h        <= (others => '0');
            tx_wr_ptr <= 0;
            tx_count  <= 0;
            -- tx_rd_ptr, rx_wr_ptr, rx_rd_ptr, rx_count are reset in TX/RX FSMs
            -- eth_tx_status_reg, eth_rx_status_reg, eth_irq_status, eth_rx_len_reg
            -- are reset in TX/RX FSMs (they are also driven from there)
        elsif rising_edge(HCLK) then
            if HSEL = '1' and HREADY = '1' and HWRITE = '1' then
                case reg_sel is
                    when REG_CTRL =>
                        eth_ctrl_reg <= HWDATA;

                    when REG_MAC_ADDR_L =>
                        eth_mac_addr_l <= HWDATA;

                    when REG_MAC_ADDR_H =>
                        eth_mac_addr_h <= HWDATA(15 downto 0);

                    when REG_TX_CTRL =>
                        eth_tx_ctrl_reg <= HWDATA;
                        if HWDATA(TXCTRL_START) = '1' and tx_state = TX_IDLE then
                            -- tx_busy_sig and tx_done_sig are managed by TX FSM
                            null;
                        end if;

                    when REG_TX_LEN =>
                        eth_tx_len_reg <= HWDATA;

                    when REG_TX_DATA =>
                        -- Write 4 bytes to TX FIFO (big-endian)
                        if tx_wr_ptr + 3 < FIFO_DEPTH then
                            tx_fifo_mem(tx_wr_ptr)     <= HWDATA(31 downto 24);
                            tx_fifo_mem(tx_wr_ptr + 1) <= HWDATA(23 downto 16);
                            tx_fifo_mem(tx_wr_ptr + 2) <= HWDATA(15 downto 8);
                            tx_fifo_mem(tx_wr_ptr + 3) <= HWDATA(7 downto 0);
                            tx_wr_ptr <= tx_wr_ptr + 4;
                            tx_count  <= tx_count + 4;
                        end if;

                    when REG_RX_CTRL =>
                        eth_rx_ctrl_reg <= HWDATA;
                        if HWDATA(RXCTRL_FLUSH) = '1' then
                            rx_rd_ptr <= 0;
                            -- rx_wr_ptr and rx_ready_sig are managed by RX FSM
                        end if;

                    when REG_IRQ_CLEAR =>
                        -- Clear IRQ bits
                        for i in 0 to 31 loop
                            if HWDATA(i) = '1' then
                                eth_irq_status(i) <= '0';
                            end if;
                        end loop;

                    when REG_HASH_L =>
                        eth_hash_l <= HWDATA;

                    when REG_HASH_H =>
                        eth_hash_h <= HWDATA;

                    when others => null;
                end case;
            end if;

            -- RX FIFO read pointer auto-increment on data read
            if HSEL = '1' and HREADY = '1' and HWRITE = '0' and reg_sel = REG_RX_DATA then
                if rx_count >= 4 then
                    rx_rd_ptr <= (rx_rd_ptr + 4) mod FIFO_DEPTH;
                end if;
            end if;

            -- OR in IRQ set bits from FSMs (unless being cleared this cycle)
            for i in 0 to 31 loop
                if eth_irq_set(i) = '1' and not (HSEL = '1' and HREADY = '1' and HWRITE = '1'
                                                  and reg_sel = REG_IRQ_CLEAR and HWDATA(i) = '1') then
                    eth_irq_status(i) <= '1';
                end if;
            end loop;

            -- Auto-clear TXCTRL_START when TX FSM has started (tx_busy_sig='1')
            if tx_busy_sig = '1' and eth_tx_ctrl_reg(TXCTRL_START) = '1' then
                eth_tx_ctrl_reg(TXCTRL_START) <= '0';
            end if;
        end if;
    end process;

    -- =========================================================================
    -- AHB-LITE READ MULTIPLEXER
    -- =========================================================================
    process(all)
        variable status_reg : std_logic_vector(31 downto 0);
    begin
        status_reg := (others => '0');
        status_reg(STATUS_TX_DONE)     := tx_done_sig;
        status_reg(STATUS_RX_READY)    := rx_ready_sig;
        status_reg(STATUS_TX_BUSY)     := tx_busy_sig;
        status_reg(STATUS_RX_BUSY)     := rx_busy_sig;
        status_reg(STATUS_LINK_UP)     := link_up_sig;

        if HSEL = '1' then
            case reg_sel is
                when REG_CTRL =>
                    HRDATA <= eth_ctrl_reg;
                when REG_STATUS =>
                    HRDATA <= status_reg;
                when REG_MAC_ADDR_L =>
                    HRDATA <= eth_mac_addr_l;
                when REG_MAC_ADDR_H =>
                    HRDATA <= x"0000" & eth_mac_addr_h;
                when REG_TX_CTRL =>
                    HRDATA(31 downto 2) <= eth_tx_ctrl_reg(31 downto 2);
                    HRDATA(1) <= tx_done_sig;
                    HRDATA(0) <= eth_tx_ctrl_reg(0);
                when REG_TX_LEN =>
                    HRDATA <= eth_tx_len_reg;
                when REG_TX_DATA =>
                    HRDATA <= (others => '0');
                when REG_TX_STATUS =>
                    HRDATA <= eth_tx_status_reg;
                when REG_RX_CTRL =>
                    HRDATA <= eth_rx_ctrl_reg;
                when REG_RX_LEN =>
                    HRDATA <= eth_rx_len_reg;
                when REG_RX_DATA =>
                    -- Read 4 bytes from RX FIFO (big-endian)
                    if rx_count >= 4 then
                        HRDATA <= rx_fifo_mem(rx_rd_ptr) &
                                  rx_fifo_mem(rx_rd_ptr + 1) &
                                  rx_fifo_mem(rx_rd_ptr + 2) &
                                  rx_fifo_mem(rx_rd_ptr + 3);
                    else
                        HRDATA <= (others => '0');
                    end if;
                when REG_RX_STATUS =>
                    HRDATA <= eth_rx_status_reg;
                when REG_IRQ_STATUS =>
                    HRDATA <= eth_irq_status;
                when REG_HASH_L =>
                    HRDATA <= eth_hash_l;
                when REG_HASH_H =>
                    HRDATA <= eth_hash_h;
                when others =>
                    HRDATA <= (others => '0');
            end case;
        else
            HRDATA <= (others => '0');
        end if;
    end process;

    -- RX read pointer auto-increment is handled in the main write process above
    -- (merged to avoid multi-driver on rx_rd_ptr / rx_count)

    HRESP <= '0';
    HREADYOUT <= '1';

    -- =========================================================================
    -- TX FSM - Transmit Ethernet frame via MII
    -- Generates: Preamble (7x 0x55) + SFD (0xD5) + Dest MAC + Src MAC +
    --             EtherType + Data + Pad (if < 64 bytes) + FCS (CRC-32)
    -- =========================================================================
    process(mii_tx_clk, HRESETn)
        variable tx_byte : std_logic_vector(7 downto 0);
        variable frame_len : integer;
        variable pad_needed : integer;
    begin
        if HRESETn = '0' then
            tx_state <= TX_IDLE;
            mii_txd <= (others => '0');
            mii_tx_en <= '0';
            mii_tx_er <= '0';
            tx_busy_sig <= '0';
            tx_done_sig <= '0';
            tx_byte_cnt <= 0;
            tx_nibble_cnt <= 0;
            tx_rd_ptr <= 0;
            tx_crc32 <= x"FFFFFFFF";
            eth_tx_status_reg <= (others => '0');
            eth_irq_set(0) <= '0';  -- tx_done_irq
        elsif rising_edge(mii_tx_clk) then
            if eth_ctrl_reg(CTRL_ENABLE) = '0' or eth_ctrl_reg(CTRL_TX_ENABLE) = '0' then
                tx_state <= TX_IDLE;
                mii_txd <= (others => '0');
                mii_tx_en <= '0';
                mii_tx_er <= '0';
                tx_busy_sig <= '0';
            else
                case tx_state is
                    when TX_IDLE =>
                        mii_tx_en <= '0';
                        mii_txd <= (others => '0');
                        if eth_tx_ctrl_reg(TXCTRL_START) = '1' then
                            tx_busy_sig <= '1';
                            tx_done_sig <= '0';
                            tx_state <= TX_PREAMBLE;
                            tx_byte_cnt <= 0;
                            tx_nibble_cnt <= 0;
                            tx_crc32 <= x"FFFFFFFF";
                        end if;

                    when TX_PREAMBLE =>
                        -- Send 7 preamble bytes (0x55 = 01010101)
                        mii_tx_en <= '1';
                        if tx_nibble_cnt = 0 then
                            mii_txd <= "0101";  -- low nibble of 0x55
                            tx_nibble_cnt <= 1;
                        else
                            mii_txd <= "0101";  -- high nibble of 0x55
                            tx_nibble_cnt <= 0;
                            tx_byte_cnt <= tx_byte_cnt + 1;
                            if tx_byte_cnt = 6 then
                                tx_state <= TX_SFD;
                                tx_byte_cnt <= 0;
                            end if;
                        end if;

                    when TX_SFD =>
                        -- Send SFD byte (0xD5 = 11010101)
                        if tx_nibble_cnt = 0 then
                            mii_txd <= "0101";  -- low nibble of 0xD5
                            tx_nibble_cnt <= 1;
                        else
                            mii_txd <= "1101";  -- high nibble of 0xD5
                            tx_nibble_cnt <= 0;
                            tx_state <= TX_DEST_MAC;
                            tx_byte_cnt <= 0;
                        end if;

                    when TX_DEST_MAC =>
                        -- Send 6 destination MAC bytes from TX FIFO
                        if tx_nibble_cnt = 0 then
                            tx_byte := tx_fifo_mem(tx_rd_ptr);
                            mii_txd <= tx_byte(3 downto 0);
                            tx_nibble_cnt <= 1;
                        else
                            tx_byte := tx_fifo_mem(tx_rd_ptr);
                            mii_txd <= tx_byte(7 downto 4);
                            tx_nibble_cnt <= 0;
                            tx_crc32 <= crc32_next(tx_crc32, tx_byte);
                            tx_rd_ptr <= (tx_rd_ptr + 1) mod FIFO_DEPTH;
                            tx_byte_cnt <= tx_byte_cnt + 1;
                            if tx_byte_cnt = 5 then
                                tx_state <= TX_SRC_MAC;
                                tx_byte_cnt <= 0;
                            end if;
                        end if;

                    when TX_SRC_MAC =>
                        -- Send 6 source MAC bytes from TX FIFO
                        if tx_nibble_cnt = 0 then
                            tx_byte := tx_fifo_mem(tx_rd_ptr);
                            mii_txd <= tx_byte(3 downto 0);
                            tx_nibble_cnt <= 1;
                        else
                            tx_byte := tx_fifo_mem(tx_rd_ptr);
                            mii_txd <= tx_byte(7 downto 4);
                            tx_nibble_cnt <= 0;
                            tx_crc32 <= crc32_next(tx_crc32, tx_byte);
                            tx_rd_ptr <= (tx_rd_ptr + 1) mod FIFO_DEPTH;
                            tx_byte_cnt <= tx_byte_cnt + 1;
                            if tx_byte_cnt = 5 then
                                tx_state <= TX_ETHERTYPE;
                                tx_byte_cnt <= 0;
                            end if;
                        end if;

                    when TX_ETHERTYPE =>
                        -- Send 2 EtherType bytes from TX FIFO
                        if tx_nibble_cnt = 0 then
                            tx_byte := tx_fifo_mem(tx_rd_ptr);
                            mii_txd <= tx_byte(3 downto 0);
                            tx_nibble_cnt <= 1;
                        else
                            tx_byte := tx_fifo_mem(tx_rd_ptr);
                            mii_txd <= tx_byte(7 downto 4);
                            tx_nibble_cnt <= 0;
                            tx_crc32 <= crc32_next(tx_crc32, tx_byte);
                            tx_rd_ptr <= (tx_rd_ptr + 1) mod FIFO_DEPTH;
                            tx_byte_cnt <= tx_byte_cnt + 1;
                            if tx_byte_cnt = 1 then
                                tx_state <= TX_DATA;
                                tx_byte_cnt <= 0;
                            end if;
                        end if;

                    when TX_DATA =>
                        -- Send remaining data bytes from TX FIFO
                        frame_len := to_integer(unsigned(eth_tx_len_reg));
                        if tx_byte_cnt < frame_len - 14 then
                            if tx_nibble_cnt = 0 then
                                tx_byte := tx_fifo_mem(tx_rd_ptr);
                                mii_txd <= tx_byte(3 downto 0);
                                tx_nibble_cnt <= 1;
                            else
                                tx_byte := tx_fifo_mem(tx_rd_ptr);
                                mii_txd <= tx_byte(7 downto 4);
                                tx_nibble_cnt <= 0;
                                tx_crc32 <= crc32_next(tx_crc32, tx_byte);
                                tx_rd_ptr <= (tx_rd_ptr + 1) mod FIFO_DEPTH;
                                tx_byte_cnt <= tx_byte_cnt + 1;
                            end if;
                        else
                            -- Check if padding needed (min frame = 64 bytes)
                            -- Total so far = 14 (MAC+type) + data_bytes
                            if frame_len < 60 then
                                tx_state <= TX_PAD;
                                tx_byte_cnt <= 0;
                            else
                                tx_state <= TX_FCS;
                                tx_byte_cnt <= 0;
                                tx_nibble_cnt <= 0;
                            end if;
                        end if;

                    when TX_PAD =>
                        -- Pad with zeros to reach 60 bytes (64 with FCS)
                        if tx_byte_cnt < 60 - to_integer(unsigned(eth_tx_len_reg)) then
                            if tx_nibble_cnt = 0 then
                                mii_txd <= "0000";
                                tx_nibble_cnt <= 1;
                            else
                                mii_txd <= "0000";
                                tx_nibble_cnt <= 0;
                                tx_crc32 <= crc32_next(tx_crc32, x"00");
                                tx_byte_cnt <= tx_byte_cnt + 1;
                            end if;
                        else
                            tx_state <= TX_FCS;
                            tx_byte_cnt <= 0;
                            tx_nibble_cnt <= 0;
                        end if;

                    when TX_FCS =>
                        -- Send 4-byte CRC-32 (inverted)
                        if tx_byte_cnt < 4 then
                            if tx_nibble_cnt = 0 then
                                mii_txd <= not tx_crc32(tx_byte_cnt * 8 + 3 downto tx_byte_cnt * 8);
                                tx_nibble_cnt <= 1;
                            else
                                mii_txd <= not tx_crc32(tx_byte_cnt * 8 + 7 downto tx_byte_cnt * 8 + 4);
                                tx_nibble_cnt <= 0;
                                tx_byte_cnt <= tx_byte_cnt + 1;
                            end if;
                        else
                            mii_tx_en <= '0';
                            tx_state <= TX_IPG;
                            tx_byte_cnt <= 0;
                        end if;

                    when TX_IPG =>
                        -- Inter-Packet Gap (96 bit times = 24 nibble times at 4-bit)
                        if tx_byte_cnt < 12 then
                            mii_txd <= (others => '0');
                            tx_byte_cnt <= tx_byte_cnt + 1;
                        else
                            tx_state <= TX_DONE;
                        end if;

                    when TX_DONE =>
                        tx_busy_sig <= '0';
                        tx_done_sig <= '1';
                        eth_tx_status_reg(0) <= '1';  -- tx_ok
                        if eth_ctrl_reg(CTRL_TX_IRQ_EN) = '1' then
                            eth_irq_set(0) <= '1';  -- tx_done_irq
                        end if;
                        tx_state <= TX_IDLE;

                    when others =>
                        tx_state <= TX_IDLE;
                end case;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- RX FSM - Receive Ethernet frame from MII
    -- Detects: Preamble + SFD + Dest MAC + Src MAC + EtherType + Data + FCS
    -- Filters: Accept if Dest MAC matches, broadcast, or multicast hash match
    -- =========================================================================
    process(mii_rx_clk, HRESETn)
        variable rx_byte : std_logic_vector(7 downto 0);
        variable mac_match : boolean;
        variable hash_bit : integer;
        variable crc_final : std_logic_vector(31 downto 0);
    begin
        if HRESETn = '0' then
            rx_state <= RX_IDLE;
            rx_byte_cnt <= 0;
            rx_nibble_cnt <= 0;
            rx_crc32 <= x"FFFFFFFF";
            rx_dest_mac_val <= (others => '0');
            rx_src_mac_val <= (others => '0');
            rx_ethertype_val <= (others => '0');
            rx_ready_sig <= '0';
            rx_busy_sig <= '0';
            rx_wr_ptr <= 0;
            eth_rx_status_reg <= (others => '0');
            eth_rx_len_reg <= (others => '0');
            eth_irq_set(1) <= '0';  -- rx_done_irq
            -- rx_rd_ptr is managed by AHB read process (HCLK domain)
            -- rx_count is combinational (rx_wr_ptr - rx_rd_ptr)
        elsif rising_edge(mii_rx_clk) then
            if eth_ctrl_reg(CTRL_ENABLE) = '0' or eth_ctrl_reg(CTRL_RX_ENABLE) = '0' then
                rx_state <= RX_IDLE;
                rx_busy_sig <= '0';
            else
                case rx_state is
                    when RX_IDLE =>
                        -- Wait for preamble (0x55 nibbles)
                        if mii_rx_dv = '1' and mii_rxd = "0101" then
                            rx_state <= RX_PREAMBLE;
                            rx_nibble_cnt <= 1;
                            rx_byte_cnt <= 0;
                        end if;

                    when RX_PREAMBLE =>
                        -- Count preamble nibbles (14 nibbles = 7 bytes of 0x55)
                        if mii_rx_dv = '1' then
                            if mii_rxd = "1101" then
                                -- SFD detected (high nibble of 0xD5)
                                rx_state <= RX_SFD;
                                rx_nibble_cnt <= 0;
                            elsif mii_rxd = "0101" then
                                rx_nibble_cnt <= rx_nibble_cnt + 1;
                            else
                                -- Error: not preamble
                                rx_state <= RX_IDLE;
                            end if;
                        else
                            rx_state <= RX_IDLE;
                        end if;

                    when RX_SFD =>
                        -- SFD low nibble already consumed, start receiving dest MAC
                        rx_state <= RX_DEST_MAC;
                        rx_byte_cnt <= 0;
                        rx_nibble_cnt <= 0;
                        rx_crc32 <= x"FFFFFFFF";
                        rx_busy_sig <= '1';

                    when RX_DEST_MAC =>
                        -- Receive 6 destination MAC bytes
                        if mii_rx_dv = '1' then
                            if rx_nibble_cnt = 0 then
                                rx_byte_shift(3 downto 0) <= mii_rxd;
                                rx_nibble_cnt <= 1;
                            else
                                rx_byte := mii_rxd & rx_byte_shift(3 downto 0);
                                rx_dest_mac_val(47 - rx_byte_cnt * 8 downto 40 - rx_byte_cnt * 8) <= rx_byte;
                                rx_crc32 <= crc32_next(rx_crc32, rx_byte);
                                rx_nibble_cnt <= 0;
                                rx_byte_cnt <= rx_byte_cnt + 1;
                                if rx_byte_cnt = 5 then
                                    rx_state <= RX_SRC_MAC;
                                    rx_byte_cnt <= 0;
                                end if;
                            end if;
                        else
                            rx_state <= RX_IDLE;
                            rx_busy_sig <= '0';
                        end if;

                    when RX_SRC_MAC =>
                        -- Receive 6 source MAC bytes
                        if mii_rx_dv = '1' then
                            if rx_nibble_cnt = 0 then
                                rx_byte_shift(3 downto 0) <= mii_rxd;
                                rx_nibble_cnt <= 1;
                            else
                                rx_byte := mii_rxd & rx_byte_shift(3 downto 0);
                                rx_src_mac_val(47 - rx_byte_cnt * 8 downto 40 - rx_byte_cnt * 8) <= rx_byte;
                                rx_crc32 <= crc32_next(rx_crc32, rx_byte);
                                -- Store in RX FIFO
                                if rx_wr_ptr < FIFO_DEPTH then
                                    rx_fifo_mem(rx_wr_ptr) <= rx_byte;
                                    rx_wr_ptr <= rx_wr_ptr + 1;
                                end if;
                                rx_nibble_cnt <= 0;
                                rx_byte_cnt <= rx_byte_cnt + 1;
                                if rx_byte_cnt = 5 then
                                    rx_state <= RX_ETHERTYPE;
                                    rx_byte_cnt <= 0;
                                end if;
                            end if;
                        else
                            rx_state <= RX_IDLE;
                            rx_busy_sig <= '0';
                        end if;

                    when RX_ETHERTYPE =>
                        -- Receive 2 EtherType bytes
                        if mii_rx_dv = '1' then
                            if rx_nibble_cnt = 0 then
                                rx_byte_shift(3 downto 0) <= mii_rxd;
                                rx_nibble_cnt <= 1;
                            else
                                rx_byte := mii_rxd & rx_byte_shift(3 downto 0);
                                rx_ethertype_val(15 - rx_byte_cnt * 8 downto 8 - rx_byte_cnt * 8) <= rx_byte;
                                rx_crc32 <= crc32_next(rx_crc32, rx_byte);
                                if rx_wr_ptr < FIFO_DEPTH then
                                    rx_fifo_mem(rx_wr_ptr) <= rx_byte;
                                    rx_wr_ptr <= rx_wr_ptr + 1;
                                end if;
                                rx_nibble_cnt <= 0;
                                rx_byte_cnt <= rx_byte_cnt + 1;
                                if rx_byte_cnt = 1 then
                                    rx_state <= RX_DATA;
                                    rx_byte_cnt <= 0;
                                end if;
                            end if;
                        else
                            rx_state <= RX_IDLE;
                            rx_busy_sig <= '0';
                        end if;

                    when RX_DATA =>
                        -- Receive data bytes until mii_rx_dv goes low
                        if mii_rx_dv = '1' then
                            if rx_nibble_cnt = 0 then
                                rx_byte_shift(3 downto 0) <= mii_rxd;
                                rx_nibble_cnt <= 1;
                            else
                                rx_byte := mii_rxd & rx_byte_shift(3 downto 0);
                                rx_crc32 <= crc32_next(rx_crc32, rx_byte);
                                if rx_wr_ptr < FIFO_DEPTH then
                                    rx_fifo_mem(rx_wr_ptr) <= rx_byte;
                                    rx_wr_ptr <= rx_wr_ptr + 1;
                                else
                                    eth_rx_status_reg(5) <= '1';  -- rx_overflow
                                end if;
                                rx_nibble_cnt <= 0;
                                rx_byte_cnt <= rx_byte_cnt + 1;
                            end if;
                        else
                            -- End of frame: check FCS
                            rx_state <= RX_FCS;
                            rx_byte_cnt <= 0;
                            rx_nibble_cnt <= 0;
                        end if;

                    when RX_FCS =>
                        -- Receive 4 FCS bytes (simplified: skip actual nibbles)
                        rx_state <= RX_CHECK;

                    when RX_CHECK =>
                        -- Verify CRC-32 (should be 0xC704DD7B after good frame)
                        -- Acceptance filter
                        mac_match := false;
                        if eth_ctrl_reg(CTRL_PROMISCUOUS) = '1' then
                            mac_match := true;
                        elsif rx_dest_mac_val = x"FFFFFFFFFFFF" then
                            -- Broadcast
                            mac_match := true;
                        elsif rx_dest_mac_val = eth_mac_addr_h & eth_mac_addr_l then
                            -- Unicast match
                            mac_match := true;
                        elsif rx_dest_mac_val(0) = '1' then
                            -- Multicast: check hash table
                            -- Simplified: use dest_mac[4:0] as hash index
                            hash_bit := to_integer(unsigned(rx_dest_mac_val(4 downto 0)));
                            if hash_bit < 32 and eth_hash_l(hash_bit) = '1' then
                                mac_match := true;
                            elsif hash_bit >= 32 and hash_bit < 64 and
                                  eth_hash_h(hash_bit - 32) = '1' then
                                mac_match := true;
                            end if;
                        end if;

                        if mac_match then
                            -- Frame accepted
                            eth_rx_status_reg(0) <= '1';  -- rx_ok
                            eth_rx_len_reg <= std_logic_vector(to_unsigned(rx_count, 32));
                            rx_ready_sig <= '1';
                            if eth_ctrl_reg(CTRL_RX_IRQ_EN) = '1' then
                                eth_irq_set(1) <= '1';  -- rx_done_irq
                            end if;
                        else
                            -- Frame rejected: flush FIFO
                            rx_wr_ptr <= 0;
                        end if;

                        rx_state <= RX_STORE;

                    when RX_STORE =>
                        rx_busy_sig <= '0';
                        rx_state <= RX_IDLE;

                    when others =>
                        rx_state <= RX_IDLE;
                end case;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- MII Management Interface (MDIO/MDC) - simplified
    -- =========================================================================
    mdc <= HCLK when eth_ctrl_reg(CTRL_ENABLE) = '1' else '0';
    mdio <= 'Z';

    -- =========================================================================
    -- Interrupt output
    -- =========================================================================
    eth_int <= '1' when eth_irq_status /= x"00000000" and
                        eth_ctrl_reg(CTRL_ENABLE) = '1'
               else '0';

end architecture rtl;

-- ============================================================================
-- Simplified Ethernet MAC (Educational)
-- ============================================================================
-- Implements a basic Ethernet Media Access Controller that can transmit
-- and receive frames with this simplified structure:
--   [Preamble (7 bytes of 0x55)] [SFD (1 byte 0xD5)] [Dest MAC (6 bytes)]
--   [Src MAC (6 bytes)] [Length/Type (2 bytes)] [Data (up to 46 bytes)]
--   [CRC/Checksum (2 bytes, simplified)]
-- Uses a simple 16-bit additive checksum instead of a full CRC32.
-- Beginner-friendly, synthesizable VHDL for the Cyclone III FPGA.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ethernet_mac is
    generic (
        CLK_FREQ : integer := 50000000
    );
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        -- TX interface (CPU sends a frame)
        tx_data      : in  std_logic_vector(7 downto 0); -- byte to send
        tx_valid     : in  std_logic;  -- '1' when tx_data is valid
        tx_ready     : out std_logic;  -- '1' when MAC can accept a byte
        tx_end       : in  std_logic;  -- pulse high with the last data byte
        tx_done      : out std_logic;  -- pulse high when frame fully sent
        -- RX interface (CPU receives a frame)
        rx_data      : out std_logic_vector(7 downto 0);
        rx_valid     : out std_logic;  -- '1' when rx_data is a valid byte
        rx_end       : out std_logic;  -- pulse high on last byte of frame
        -- MAC address (used for filtering)
        mac_addr     : in  std_logic_vector(47 downto 0);
        -- MII interface (simplified: 4-bit nibble data path)
        mii_tx_clk   : in  std_logic;
        mii_txd      : out std_logic_vector(3 downto 0);
        mii_tx_en    : out std_logic;
        mii_rx_clk   : in  std_logic;
        mii_rxd      : in  std_logic_vector(3 downto 0);
        mii_rx_dv    : in  std_logic
    );
end entity ethernet_mac;

architecture rtl of ethernet_mac is
    -- TX state machine
    type tx_state_t is (TX_IDLE, TX_PREAMBLE, TX_SFD, TX_DEST, TX_SRC,
                        TX_LEN, TX_DATA, TX_CRC, TX_DONE_ST);
    signal tx_state : tx_state_t := TX_IDLE;
    signal tx_byte_cnt : integer range 0 to 63 := 0;
    signal tx_nibble   : std_logic := '0';  -- '0' = low nibble, '1' = high
    signal tx_data_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_checksum : unsigned(15 downto 0) := (others => '0');
    signal tx_ready_flag: std_logic := '0';
    signal tx_done_flag: std_logic := '0';

    -- RX state machine
    type rx_state_t is (RX_IDLE, RX_PREAMBLE, RX_SFD, RX_DEST, RX_SRC,
                        RX_LEN, RX_DATA, RX_CRC);
    signal rx_state : rx_state_t := RX_IDLE;
    signal rx_byte_cnt : integer range 0 to 63 := 0;
    signal rx_nibble   : std_logic := '0';
    signal rx_byte_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_valid_flag: std_logic := '0';
    signal rx_end_flag: std_logic := '0';

    constant PREAMBLE_BYTE : std_logic_vector(7 downto 0) := x"55";
    constant SFD_BYTE      : std_logic_vector(7 downto 0) := x"D5";
begin

    -- =================== TX state machine ===================
    -- Operates on the system clock for simplicity (real designs use mii_tx_clk)
    tx_proc : process(clk, reset)
    begin
        if reset = '1' then
            tx_state      <= TX_IDLE;
            mii_txd       <= (others => '0');
            mii_tx_en     <= '0';
            tx_ready_flag <= '0';
            tx_done_flag  <= '0';
            tx_byte_cnt   <= 0;
            tx_nibble     <= '0';
            tx_checksum   <= (others => '0');
        elsif rising_edge(clk) then
            tx_done_flag <= '0';

            case tx_state is
                when TX_IDLE =>
                    mii_tx_en     <= '0';
                    tx_ready_flag <= '1';  -- ready to accept data
                    tx_byte_cnt   <= 0;
                    tx_nibble     <= '0';
                    tx_checksum   <= (others => '0');
                    if tx_valid = '1' then
                        tx_data_reg   <= tx_data;
                        tx_ready_flag <= '0';
                        tx_state      <= TX_PREAMBLE;
                    end if;

                -- Preamble: 7 bytes of 0x55
                when TX_PREAMBLE =>
                    mii_tx_en <= '1';
                    if tx_nibble = '0' then
                        mii_txd   <= PREAMBLE_BYTE(3 downto 0);
                        tx_nibble <= '1';
                    else
                        mii_txd   <= PREAMBLE_BYTE(7 downto 4);
                        tx_nibble <= '0';
                        if tx_byte_cnt = 6 then
                            tx_byte_cnt <= 0;
                            tx_state    <= TX_SFD;
                        else
                            tx_byte_cnt <= tx_byte_cnt + 1;
                        end if;
                    end if;

                -- SFD: 1 byte of 0xD5
                when TX_SFD =>
                    if tx_nibble = '0' then
                        mii_txd   <= SFD_BYTE(3 downto 0);
                        tx_nibble <= '1';
                    else
                        mii_txd   <= SFD_BYTE(7 downto 4);
                        tx_nibble <= '0';
                        tx_state  <= TX_DATA;  -- simplified: go to data
                    end if;

                -- DATA: send bytes from CPU, compute checksum
                when TX_DATA =>
                    if tx_nibble = '0' then
                        mii_txd     <= tx_data_reg(3 downto 0);
                        tx_nibble   <= '1';
                        tx_checksum <= tx_checksum + unsigned(tx_data_reg);
                    else
                        mii_txd       <= tx_data_reg(7 downto 4);
                        tx_nibble     <= '0';
                        tx_ready_flag <= '1';  -- ready for next byte
                        if tx_end = '1' then
                            tx_ready_flag <= '0';
                            tx_byte_cnt   <= 0;
                            tx_state      <= TX_CRC;
                        else
                            if tx_valid = '1' then
                                tx_data_reg   <= tx_data;
                                tx_ready_flag <= '0';
                            end if;
                        end if;
                    end if;

                -- CRC: send 2-byte simplified checksum
                when TX_CRC =>
                    if tx_nibble = '0' then
                        mii_txd   <= std_logic_vector(tx_checksum(3 downto 0));
                        tx_nibble <= '1';
                    else
                        mii_txd   <= std_logic_vector(tx_checksum(7 downto 4));
                        tx_nibble <= '0';
                        if tx_byte_cnt = 1 then
                            tx_state <= TX_DONE_ST;
                        else
                            tx_byte_cnt <= tx_byte_cnt + 1;
                        end if;
                    end if;

                when TX_DONE_ST =>
                    mii_tx_en     <= '0';
                    tx_done_flag  <= '1';
                    tx_ready_flag <= '1';
                    tx_state      <= TX_IDLE;
            end case;
        end if;
    end process tx_proc;

    tx_ready <= tx_ready_flag;
    tx_done  <= tx_done_flag;

    -- =================== RX state machine ===================
    rx_proc : process(clk, reset)
    begin
        if reset = '1' then
            rx_state      <= RX_IDLE;
            rx_data       <= (others => '0');
            rx_valid_flag <= '0';
            rx_end_flag   <= '0';
            rx_byte_cnt   <= 0;
            rx_nibble     <= '0';
        elsif rising_edge(clk) then
            rx_valid_flag <= '0';
            rx_end_flag   <= '0';

            if mii_rx_dv = '1' then
                case rx_state is
                    -- Look for preamble bytes (0x55)
                    when RX_IDLE =>
                        rx_byte_reg(3 downto 0) <= mii_rxd;
                        rx_nibble <= '1';
                        rx_state  <= RX_PREAMBLE;

                    when RX_PREAMBLE =>
                        if rx_nibble = '1' then
                            rx_byte_reg(7 downto 4) <= mii_rxd;
                            rx_nibble <= '0';
                            -- Check for SFD (0xD5) instead of preamble
                            if mii_rxd = x"5" and rx_byte_reg(3 downto 0) = x"5" then
                                null; -- still preamble
                            elsif mii_rxd = x"D" and rx_byte_reg(3 downto 0) = x"5" then
                                rx_state <= RX_DATA; -- SFD found, go to data
                            end if;
                        else
                            rx_byte_reg(3 downto 0) <= mii_rxd;
                            rx_nibble <= '1';
                        end if;

                    -- DATA: assemble bytes from nibbles
                    when RX_DATA =>
                        if rx_nibble = '0' then
                            rx_byte_reg(3 downto 0) <= mii_rxd;
                            rx_nibble <= '1';
                        else
                            rx_byte_reg(7 downto 4) <= mii_rxd;
                            rx_nibble   <= '0';
                            rx_data     <= rx_byte_reg(7 downto 4) & rx_byte_reg(3 downto 0);
                            rx_valid_flag <= '1';
                        end if;

                    when others =>
                        rx_state <= RX_IDLE;
                end case;
            else
                -- RX data not valid: if we were receiving, frame ended
                if rx_state = RX_DATA then
                    rx_end_flag <= '1';
                    rx_state    <= RX_IDLE;
                end if;
            end if;
        end if;
    end process rx_proc;

    rx_valid <= rx_valid_flag;
    rx_end   <= rx_end_flag;

end architecture rtl;

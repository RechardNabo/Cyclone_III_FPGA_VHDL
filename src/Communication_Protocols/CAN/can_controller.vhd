-- ============================================================================
-- Simplified CAN Controller (Educational)
-- ============================================================================
-- CAN (Controller Area Network) is a robust serial bus used in automotive
-- and industrial systems. This is a simplified educational version that
-- implements a basic frame structure:
--   [SOF (1 bit)] [11-bit ID] [RTR (1)] [DLC (4 bits)] [8-bit data] [CRC (8)]
--   [ACK slot (1)] [EOF (1)]
-- Not a full CAN 2.0B implementation, but teaches the frame concept.
-- Beginner-friendly, synthesizable VHDL for the Cyclone III FPGA.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity can_controller is
    generic (
        CLK_FREQ  : integer := 50000000;
        BIT_RATE  : integer := 500000    -- CAN bit rate (500 kbps)
    );
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;
        -- TX interface (CPU sends a frame)
        tx_id      : in  std_logic_vector(10 downto 0); -- 11-bit identifier
        tx_data    : in  std_logic_vector(7 downto 0);  -- 8-bit data payload
        tx_start   : in  std_logic;       -- pulse high to send a frame
        tx_done    : out std_logic;       -- pulse high when frame sent
        tx_busy    : out std_logic;
        -- RX interface (CPU receives a frame)
        rx_id      : out std_logic_vector(10 downto 0);
        rx_data    : out std_logic_vector(7 downto 0);
        rx_valid   : out std_logic;       -- pulse high when frame received
        -- CAN bus (single-bit serial, simplified: no differential pair)
        can_tx     : out std_logic;
        can_rx     : in  std_logic
    );
end entity can_controller;

architecture rtl of can_controller is
    constant CLK_PER_BIT : integer := CLK_FREQ / BIT_RATE;

    -- TX state machine
    type tx_state_t is (TX_IDLE, TX_SOF, ST_TX_ID, TX_RTR, TX_DLC, ST_TX_DATA,
                        ST_TX_CRC, TX_ACK, TX_EOF);
    signal tx_state : tx_state_t := TX_IDLE;
    signal tx_clk_cnt : integer range 0 to CLK_PER_BIT - 1 := 0;
    signal tx_bit_idx : integer range 0 to 15 := 0;
    signal tx_id_reg  : std_logic_vector(10 downto 0) := (others => '0');
    signal tx_data_reg: std_logic_vector(7 downto 0) := (others => '0');
    signal tx_crc     : unsigned(7 downto 0) := (others => '0');
    signal tx_busy_flag: std_logic := '0';
    signal tx_done_flag: std_logic := '0';

    -- RX state machine
    type rx_state_t is (RX_IDLE, RX_SOF, ST_RX_ID, RX_RTR, RX_DLC, ST_RX_DATA,
                        RX_CRC, RX_ACK, RX_EOF);
    signal rx_state : rx_state_t := RX_IDLE;
    signal rx_clk_cnt : integer range 0 to CLK_PER_BIT - 1 := 0;
    signal rx_bit_idx : integer range 0 to 15 := 0;
    signal rx_id_reg  : std_logic_vector(10 downto 0) := (others => '0');
    signal rx_data_reg: std_logic_vector(7 downto 0) := (others => '0');
    signal rx_valid_flag: std_logic := '0';
begin

    -- =================== CRC-8 (simple XOR checksum) ===================
    -- For educational simplicity we use an XOR of all bits as "CRC"
    -- =================== TX state machine ===================
    tx_proc : process(clk, reset)
    begin
        if reset = '1' then
            tx_state     <= TX_IDLE;
            can_tx       <= '1';  -- CAN bus idle is recessive (high)
            tx_busy_flag <= '0';
            tx_done_flag <= '0';
            tx_clk_cnt   <= 0;
            tx_bit_idx   <= 0;
        elsif rising_edge(clk) then
            tx_done_flag <= '0';

            case tx_state is
                when TX_IDLE =>
                    can_tx <= '1';
                    tx_busy_flag <= '0';
                    if tx_start = '1' then
                        tx_id_reg   <= tx_id;
                        tx_data_reg <= tx_data;
                        -- Simple CRC: XOR all ID and data bits
                        tx_crc <= unsigned(tx_id(7 downto 0)) xor
                                  unsigned(tx_data);
                        tx_busy_flag <= '1';
                        tx_state     <= TX_SOF;
                        tx_clk_cnt   <= 0;
                    end if;

                -- SOF: Start of Frame (1 dominant bit = 0)
                when TX_SOF =>
                    can_tx <= '0';
                    if tx_clk_cnt = CLK_PER_BIT - 1 then
                        tx_clk_cnt <= 0;
                        tx_bit_idx <= 10;
                        tx_state   <= ST_TX_ID;
                    else
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end if;

                -- ID: 11-bit identifier (MSB first)
                when ST_TX_ID =>
                    can_tx <= tx_id_reg(tx_bit_idx);
                    if tx_clk_cnt = CLK_PER_BIT - 1 then
                        tx_clk_cnt <= 0;
                        if tx_bit_idx = 0 then
                            tx_state <= TX_RTR;
                        else
                            tx_bit_idx <= tx_bit_idx - 1;
                        end if;
                    else
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end if;

                -- RTR: Remote Transmission Request (0 = data frame)
                when TX_RTR =>
                    can_tx <= '0';
                    if tx_clk_cnt = CLK_PER_BIT - 1 then
                        tx_clk_cnt <= 0;
                        tx_bit_idx <= 3;
                        tx_state   <= TX_DLC;
                    else
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end if;

                -- DLC: Data Length Code (4 bits, value = 1 for 8-bit data)
                when TX_DLC =>
                    can_tx <= '0' when tx_bit_idx = 0 else '1';
                    if tx_clk_cnt = CLK_PER_BIT - 1 then
                        tx_clk_cnt <= 0;
                        if tx_bit_idx = 0 then
                            tx_bit_idx <= 7;
                            tx_state   <= ST_TX_DATA;
                        else
                            tx_bit_idx <= tx_bit_idx - 1;
                        end if;
                    else
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end if;

                -- DATA: 8-bit payload (MSB first)
                when ST_TX_DATA =>
                    can_tx <= tx_data_reg(tx_bit_idx);
                    if tx_clk_cnt = CLK_PER_BIT - 1 then
                        tx_clk_cnt <= 0;
                        if tx_bit_idx = 0 then
                            tx_bit_idx <= 7;
                            tx_state   <= ST_TX_CRC;
                        else
                            tx_bit_idx <= tx_bit_idx - 1;
                        end if;
                    else
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end if;

                -- CRC: 8-bit checksum (MSB first)
                when ST_TX_CRC =>
                    can_tx <= tx_crc(tx_bit_idx);
                    if tx_clk_cnt = CLK_PER_BIT - 1 then
                        tx_clk_cnt <= 0;
                        if tx_bit_idx = 0 then
                            tx_state <= TX_ACK;
                        else
                            tx_bit_idx <= tx_bit_idx - 1;
                        end if;
                    else
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end if;

                -- ACK: dominant bit (sender sends recessive, receiver drives low)
                when TX_ACK =>
                    can_tx <= '1';  -- recessive, expect receiver to pull low
                    if tx_clk_cnt = CLK_PER_BIT - 1 then
                        tx_clk_cnt <= 0;
                        tx_state   <= TX_EOF;
                    else
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end if;

                -- EOF: End of Frame (1 recessive bit)
                when TX_EOF =>
                    can_tx <= '1';
                    if tx_clk_cnt = CLK_PER_BIT - 1 then
                        tx_clk_cnt   <= 0;
                        tx_done_flag <= '1';
                        tx_busy_flag <= '0';
                        tx_state     <= TX_IDLE;
                    else
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end if;
            end case;
        end if;
    end process tx_proc;

    tx_busy <= tx_busy_flag;
    tx_done <= tx_done_flag;

    -- =================== RX state machine ===================
    rx_proc : process(clk, reset)
    begin
        if reset = '1' then
            rx_state      <= RX_IDLE;
            rx_valid_flag <= '0';
            rx_clk_cnt    <= 0;
            rx_bit_idx    <= 0;
            rx_id         <= (others => '0');
            rx_data       <= (others => '0');
        elsif rising_edge(clk) then
            rx_valid_flag <= '0';

            case rx_state is
                when RX_IDLE =>
                    if can_rx = '0' then  -- SOF detected
                        rx_state   <= RX_SOF;
                        rx_clk_cnt <= 0;
                    end if;

                when RX_SOF =>
                    if rx_clk_cnt = CLK_PER_BIT - 1 then
                        rx_clk_cnt <= 0;
                        rx_bit_idx <= 10;
                        rx_state   <= ST_RX_ID;
                    else
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end if;

                when ST_RX_ID =>
                    if rx_clk_cnt = CLK_PER_BIT - 1 then
                        rx_id_reg(rx_bit_idx) <= can_rx;
                        rx_clk_cnt <= 0;
                        if rx_bit_idx = 0 then
                            rx_state <= RX_RTR;
                        else
                            rx_bit_idx <= rx_bit_idx - 1;
                        end if;
                    else
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end if;

                when RX_RTR =>
                    if rx_clk_cnt = CLK_PER_BIT - 1 then
                        rx_clk_cnt <= 0;
                        rx_bit_idx <= 3;
                        rx_state   <= RX_DLC;
                    else
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end if;

                when RX_DLC =>
                    if rx_clk_cnt = CLK_PER_BIT - 1 then
                        rx_clk_cnt <= 0;
                        if rx_bit_idx = 0 then
                            rx_bit_idx <= 7;
                            rx_state   <= ST_RX_DATA;
                        else
                            rx_bit_idx <= rx_bit_idx - 1;
                        end if;
                    else
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end if;

                when ST_RX_DATA =>
                    if rx_clk_cnt = CLK_PER_BIT - 1 then
                        rx_data_reg(rx_bit_idx) <= can_rx;
                        rx_clk_cnt <= 0;
                        if rx_bit_idx = 0 then
                            rx_bit_idx <= 7;
                            rx_state   <= RX_CRC;
                        else
                            rx_bit_idx <= rx_bit_idx - 1;
                        end if;
                    else
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end if;

                when RX_CRC =>
                    if rx_clk_cnt = CLK_PER_BIT - 1 then
                        rx_clk_cnt <= 0;
                        if rx_bit_idx = 0 then
                            rx_state <= RX_ACK;
                        else
                            rx_bit_idx <= rx_bit_idx - 1;
                        end if;
                    else
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end if;

                when RX_ACK =>
                    if rx_clk_cnt = CLK_PER_BIT - 1 then
                        rx_clk_cnt <= 0;
                        rx_state   <= RX_EOF;
                    else
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end if;

                when RX_EOF =>
                    if rx_clk_cnt = CLK_PER_BIT - 1 then
                        rx_clk_cnt    <= 0;
                        rx_id         <= rx_id_reg;
                        rx_data       <= rx_data_reg;
                        rx_valid_flag <= '1';
                        rx_state      <= RX_IDLE;
                    else
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end if;
            end case;
        end if;
    end process rx_proc;

    rx_valid <= rx_valid_flag;

end architecture rtl;

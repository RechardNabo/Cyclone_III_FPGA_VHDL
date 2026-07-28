-- ================================================================================
-- can_controller : CAN 2.0B Bus Controller (educational model)
-- ================================================================================
-- Implements a simplified CAN 2.0B controller with AHB-Lite slave register
-- interface. Supports standard (11-bit) and extended (29-bit) frame formats,
-- acceptance filtering, loopback and listen-only modes, bit timing
-- configuration, and error counters.
--
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- Register Map (word-aligned, offset from base, HADDR[7:2] selects register):
--   0x00: CAN_CTRL     - bit0=reset, bit1=loopback, bit2=listen_only,
--                        bit3=tx_irq_en, bit4=rx_irq_en, bit5=enable
--   0x04: CAN_STATUS   - bit0=rx_ready, bit1=tx_ready, bit2=bus_off,
--                        bit3=error_passive, bit4=error_warning
--   0x08: CAN_BTR      - Bit timing: [15:0]=prescaler, [19:16]=tseg1,
--                        [23:20]=tseg2, [27:24]=sjw
--   0x0C: CAN_ID       - CAN identifier (11-bit standard or 29-bit extended)
--   0x10: CAN_DLC      - Data length code (0-8 bytes)
--   0x14: CAN_DATA_L   - Data bytes 0-3 (low word)
--   0x18: CAN_DATA_H   - Data bytes 4-7 (high word)
--   0x1C: CAN_TX_CTRL  - bit0=send (write 1 to transmit),
--                        bit1=extended_frame (29-bit ID)
--   0x20: CAN_RX_CTRL  - bit0=rx_valid, bit1=extended_frame, bit2=rx_overrun
--   0x24: CAN_RX_ID    - Received CAN identifier
--   0x28: CAN_RX_DLC   - Received data length code
--   0x2C: CAN_RX_DATA_L - Received data bytes 0-3
--   0x30: CAN_RX_DATA_H - Received data bytes 4-7
--   0x34: CAN_ERR_CNT  - [7:0]=tx_err, [15:8]=rx_err
--   0x38: CAN_ACCEPT_MASK - Acceptance filter mask (0=match, 1=don't care)
--   0x3C: CAN_ACCEPT_ID   - Acceptance filter ID
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity can_controller_ahb is
    generic (
        CLK_FREQ : integer := 50_000_000;  -- System clock frequency (Hz)
        BITRATE  : integer := 500_000      -- CAN bus bitrate (bps)
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

        -- CAN physical interface
        can_tx    : out std_logic;
        can_rx    : in  std_logic;
        can_clkout: out std_logic;

        -- Interrupt
        can_int   : out std_logic
    );
end entity can_controller_ahb;

architecture rtl of can_controller_ahb is

    -- Register offsets (HADDR[7:2] = 6-bit index)
    constant REG_CTRL          : integer := 0;  -- 0x00
    constant REG_STATUS        : integer := 1;  -- 0x04
    constant REG_BTR           : integer := 2;  -- 0x08
    constant REG_ID            : integer := 3;  -- 0x0C
    constant REG_DLC           : integer := 4;  -- 0x10
    constant REG_DATA_L        : integer := 5;  -- 0x14
    constant REG_DATA_H        : integer := 6;  -- 0x18
    constant REG_TX_CTRL       : integer := 7;  -- 0x1C
    constant REG_RX_CTRL       : integer := 8;  -- 0x20
    constant REG_RX_ID         : integer := 9;  -- 0x24
    constant REG_RX_DLC        : integer := 10; -- 0x28
    constant REG_RX_DATA_L     : integer := 11; -- 0x2C
    constant REG_RX_DATA_H     : integer := 12; -- 0x30
    constant REG_ERR_CNT       : integer := 13; -- 0x34
    constant REG_ACCEPT_MASK   : integer := 14; -- 0x38
    constant REG_ACCEPT_ID     : integer := 15; -- 0x3C

    -- Control register bits
    constant CTRL_RESET        : integer := 0;
    constant CTRL_LOOPBACK     : integer := 1;
    constant CTRL_LISTEN_ONLY  : integer := 2;
    constant CTRL_TX_IRQ_EN    : integer := 3;
    constant CTRL_RX_IRQ_EN    : integer := 4;
    constant CTRL_ENABLE       : integer := 5;

    -- Status register bits
    constant STATUS_RX_READY   : integer := 0;
    constant STATUS_TX_READY   : integer := 1;
    constant STATUS_BUS_OFF    : integer := 2;
    constant STATUS_ERR_PASSIVE: integer := 3;
    constant STATUS_ERR_WARN   : integer := 4;

    -- TX control bits
    constant TX_SEND           : integer := 0;
    constant TX_EXTENDED       : integer := 1;

    -- RX control bits
    constant RX_VALID          : integer := 0;
    constant RX_EXTENDED       : integer := 1;
    constant RX_OVERRUN        : integer := 2;

    -- CAN frame FSM states
    type tx_state_t is (TX_IDLE, TX_SOF, TX_ARB, TX_CONTROL, TX_DATA, TX_CRC, TX_ACK, TX_EOF, TX_DONE);
    type rx_state_t is (RX_IDLE, RX_SOF, RX_ARB, RX_CONTROL, RX_DATA, RX_CRC, RX_ACK, RX_EOF, RX_STORE);

    signal tx_state : tx_state_t := TX_IDLE;
    signal rx_state : rx_state_t := RX_IDLE;

    -- Registers
    signal can_ctrl_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal can_btr_reg        : std_logic_vector(31 downto 0) := (others => '0');
    signal can_id_reg         : std_logic_vector(31 downto 0) := (others => '0');
    signal can_dlc_reg        : std_logic_vector(31 downto 0) := (others => '0');
    signal can_data_l_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal can_data_h_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal can_tx_ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal can_rx_ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal can_rx_id_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal can_rx_dlc_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal can_rx_data_l_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal can_rx_data_h_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal can_err_cnt_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal can_accept_mask_reg: std_logic_vector(31 downto 0) := (others => '0');
    signal can_accept_id_reg  : std_logic_vector(31 downto 0) := (others => '0');

    -- Status signals
    signal rx_ready    : std_logic := '0';
    signal tx_ready    : std_logic := '1';
    signal bus_off     : std_logic := '0';
    signal err_passive : std_logic := '0';
    signal err_warn    : std_logic := '0';

    -- IRQ signals
    signal tx_irq_pending : std_logic := '0';
    signal rx_irq_pending : std_logic := '0';

    -- Bit timing
    -- Default: derive from generics if BTR not programmed
    constant DEFAULT_BIT_PERIOD : integer := CLK_FREQ / BITRATE;
    signal bit_period    : integer := DEFAULT_BIT_PERIOD;
    signal bit_clk_cnt   : integer := 0;
    signal bit_clk       : std_logic := '0';  -- Internal bit clock

    -- TX shift registers and counters
    signal tx_bit_cnt    : integer := 0;
    signal tx_byte_cnt   : integer := 0;
    signal tx_shift      : std_logic_vector(63 downto 0) := (others => '0');
    signal tx_bit_total  : integer := 0;
    signal tx_crc_val        : std_logic_vector(14 downto 0) := (others => '0');

    -- RX shift registers and counters
    signal rx_bit_cnt    : integer := 0;
    signal rx_byte_cnt   : integer := 0;
    signal rx_shift      : std_logic_vector(63 downto 0) := (others => '0');
    signal rx_bit_total  : integer := 0;
    signal rx_crc_val        : std_logic_vector(14 downto 0) := (others => '0');
    signal rx_id_shift   : std_logic_vector(28 downto 0) := (others => '0');
    signal rx_dlc_shift  : std_logic_vector(3 downto 0) := (others => '0');
    signal rx_ext_frame : std_logic := '0';

    -- CRC-15 polynomial: x^15 + x^14 + x^10 + x^8 + x^7 + x^4 + x^3 + 1
    constant CAN_CRC_POLY : std_logic_vector(14 downto 0) := "100010110001101";

    -- Address decode
    signal reg_sel : integer range 0 to 63;

    -- =========================================================================
    -- CRC-15 calculation (next-bit combinational function)
    -- =========================================================================
    function can_crc_next(crc : std_logic_vector(14 downto 0);
                          bit_in : std_logic) return std_logic_vector is
        variable next_crc : std_logic_vector(14 downto 0);
        variable crc_nxt  : std_logic;
    begin
        crc_nxt := bit_in xor crc(14);
        next_crc(14) := crc(13) xor (crc_nxt and CAN_CRC_POLY(14));
        next_crc(13) := crc(12) xor (crc_nxt and CAN_CRC_POLY(13));
        next_crc(12) := crc(11) xor (crc_nxt and CAN_CRC_POLY(12));
        next_crc(11) := crc(10) xor (crc_nxt and CAN_CRC_POLY(11));
        next_crc(10) := crc(9)  xor (crc_nxt and CAN_CRC_POLY(10));
        next_crc(9)  := crc(8)  xor (crc_nxt and CAN_CRC_POLY(9));
        next_crc(8)  := crc(7)  xor (crc_nxt and CAN_CRC_POLY(8));
        next_crc(7)  := crc(6)  xor (crc_nxt and CAN_CRC_POLY(7));
        next_crc(6)  := crc(5)  xor (crc_nxt and CAN_CRC_POLY(6));
        next_crc(5)  := crc(4)  xor (crc_nxt and CAN_CRC_POLY(5));
        next_crc(4)  := crc(3)  xor (crc_nxt and CAN_CRC_POLY(4));
        next_crc(3)  := crc(2)  xor (crc_nxt and CAN_CRC_POLY(3));
        next_crc(2)  := crc(1)  xor (crc_nxt and CAN_CRC_POLY(2));
        next_crc(1)  := crc(0)  xor (crc_nxt and CAN_CRC_POLY(1));
        next_crc(0)  := crc_nxt;
        return next_crc;
    end function;

begin

    -- Address decoder: HADDR[7:2] selects one of 64 word registers
    reg_sel <= to_integer(unsigned(HADDR(7 downto 2)));

    -- =========================================================================
    -- Bit clock generation (simplified: no sample point / resync logic)
    -- In a real CAN controller, bit timing uses TSEG1/TSEG2/SJW from BTR.
    -- This educational model uses a simple bit-period counter.
    -- =========================================================================
    bit_period <= to_integer(unsigned(can_btr_reg(15 downto 0)))
                  when can_btr_reg(15 downto 0) /= x"0000"
                  else DEFAULT_BIT_PERIOD;

    process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            bit_clk_cnt <= 0;
            bit_clk <= '0';
        elsif rising_edge(HCLK) then
            if can_ctrl_reg(CTRL_ENABLE) = '1' then
                if bit_clk_cnt >= bit_period - 1 then
                    bit_clk_cnt <= 0;
                    bit_clk <= not bit_clk;
                else
                    bit_clk_cnt <= bit_clk_cnt + 1;
                end if;
            else
                bit_clk_cnt <= 0;
                bit_clk <= '0';
            end if;
        end if;
    end process;

    can_clkout <= bit_clk;

    -- =========================================================================
    -- MERGED SEQUENTIAL PROCESS (AHB write + TX FSM + RX FSM + error counters)
    -- All clocked logic in one process to avoid multi-driver signal issues.
    -- =========================================================================
    process(HCLK, HRESETn)
        variable tx_data_word  : std_logic_vector(63 downto 0);
        variable tx_total_bits : integer;
        variable tx_id_bits    : integer;
        variable bit_to_send   : std_logic;
    begin
        if HRESETn = '0' then
            -- Register resets
            can_ctrl_reg        <= (others => '0');
            can_btr_reg         <= (others => '0');
            can_id_reg          <= (others => '0');
            can_dlc_reg         <= (others => '0');
            can_data_l_reg      <= (others => '0');
            can_data_h_reg      <= (others => '0');
            can_tx_ctrl_reg     <= (others => '0');
            can_rx_ctrl_reg     <= (others => '0');
            can_rx_id_reg       <= (others => '0');
            can_rx_dlc_reg      <= (others => '0');
            can_rx_data_l_reg   <= (others => '0');
            can_rx_data_h_reg   <= (others => '0');
            can_err_cnt_reg     <= (others => '0');
            can_accept_mask_reg <= (others => '0');
            can_accept_id_reg   <= (others => '0');
            -- Status resets
            rx_ready       <= '0';
            tx_ready       <= '1';
            bus_off        <= '0';
            err_passive    <= '0';
            err_warn       <= '0';
            -- IRQ resets
            tx_irq_pending <= '0';
            rx_irq_pending <= '0';
            -- TX FSM resets
            tx_state    <= TX_IDLE;
            tx_bit_cnt  <= 0;
            tx_byte_cnt <= 0;
            tx_shift    <= (others => '0');
            tx_crc_val  <= (others => '0');
            can_tx      <= '1';
            -- RX FSM resets
            rx_state    <= RX_IDLE;
            rx_bit_cnt  <= 0;
            rx_byte_cnt <= 0;
            rx_shift    <= (others => '0');
            rx_crc_val  <= (others => '0');
            rx_ext_frame <= '0';
        elsif rising_edge(HCLK) then

            -- ==================================================================
            -- AHB-Lite register write access
            -- ==================================================================
            if HSEL = '1' and HREADY = '1' and HWRITE = '1' then
                case reg_sel is
                    when REG_CTRL =>
                        can_ctrl_reg <= HWDATA;
                        -- Soft reset: clear error counters when reset bit is set
                        if HWDATA(CTRL_RESET) = '1' then
                            can_err_cnt_reg <= (others => '0');
                        end if;
                    when REG_BTR         => can_btr_reg         <= HWDATA;
                    when REG_ID          => can_id_reg          <= HWDATA;
                    when REG_DLC         => can_dlc_reg         <= HWDATA;
                    when REG_DATA_L      => can_data_l_reg      <= HWDATA;
                    when REG_DATA_H      => can_data_h_reg      <= HWDATA;
                    when REG_TX_CTRL     =>
                        can_tx_ctrl_reg <= HWDATA;
                    when REG_RX_CTRL     =>
                        if HWDATA(RX_VALID) = '0' then
                            can_rx_ctrl_reg(RX_VALID) <= '0';
                            rx_ready <= '0';
                        end if;
                    when REG_ACCEPT_MASK => can_accept_mask_reg <= HWDATA;
                    when REG_ACCEPT_ID   => can_accept_id_reg   <= HWDATA;
                    when others => null;
                end case;
            end if;

            -- ==================================================================
            -- TX FSM - Transmit CAN frame
            -- ==================================================================
            if can_ctrl_reg(CTRL_ENABLE) = '0' then
                tx_state <= TX_IDLE;
                tx_ready <= '1';
                can_tx   <= '1';
            else
                case tx_state is
                    when TX_IDLE =>
                        can_tx <= '1';  -- recessive
                        if can_tx_ctrl_reg(TX_SEND) = '1' and tx_ready = '1' then
                            -- Prepare frame
                            tx_data_word := can_data_h_reg & can_data_l_reg;
                            tx_shift <= tx_data_word;
                            tx_crc_val <= (others => '0');
                            tx_bit_cnt <= 0;
                            if can_tx_ctrl_reg(TX_EXTENDED) = '1' then
                                tx_id_bits := 29;
                            else
                                tx_id_bits := 11;
                            end if;
                            tx_total_bits := 1 + tx_id_bits + 4 + 4 +
                                             (to_integer(unsigned(can_dlc_reg(3 downto 0))) * 8) +
                                             15 + 1 + 1 + 1 + 7;
                            tx_bit_total <= tx_total_bits;
                            tx_ready <= '0';
                            can_tx_ctrl_reg(TX_SEND) <= '0';  -- clear send bit
                            tx_state <= TX_SOF;
                        end if;

                    when TX_SOF =>
                        if bit_clk = '1' then
                            can_tx <= '0';  -- dominant
                            tx_state <= TX_ARB;
                            tx_bit_cnt <= 0;
                            tx_crc_val <= can_crc_next(tx_crc_val, '0');
                        end if;

                    when TX_ARB =>
                        if bit_clk = '1' then
                            if can_tx_ctrl_reg(TX_EXTENDED) = '1' then
                                if tx_bit_cnt < 29 then
                                    bit_to_send := can_id_reg(28 - tx_bit_cnt);
                                    can_tx <= bit_to_send;
                                    tx_crc_val <= can_crc_next(tx_crc_val, bit_to_send);
                                    tx_bit_cnt <= tx_bit_cnt + 1;
                                else
                                    can_tx <= '1';  -- SRR (recessive)
                                    tx_crc_val <= can_crc_next(tx_crc_val, '1');
                                    tx_bit_cnt <= 0;
                                    tx_state <= TX_CONTROL;
                                end if;
                            else
                                if tx_bit_cnt < 11 then
                                    bit_to_send := can_id_reg(10 - tx_bit_cnt);
                                    can_tx <= bit_to_send;
                                    tx_crc_val <= can_crc_next(tx_crc_val, bit_to_send);
                                    tx_bit_cnt <= tx_bit_cnt + 1;
                                else
                                    can_tx <= '0';  -- IDE=0 (standard)
                                    tx_crc_val <= can_crc_next(tx_crc_val, '0');
                                    tx_bit_cnt <= 0;
                                    tx_state <= TX_CONTROL;
                                end if;
                            end if;
                        end if;

                    when TX_CONTROL =>
                        if bit_clk = '1' then
                            if tx_bit_cnt < 4 then
                                bit_to_send := can_dlc_reg(3 - tx_bit_cnt);
                                can_tx <= bit_to_send;
                                tx_crc_val <= can_crc_next(tx_crc_val, bit_to_send);
                                tx_bit_cnt <= tx_bit_cnt + 1;
                            else
                                tx_bit_cnt <= 0;
                                tx_byte_cnt <= 0;
                                tx_state <= TX_DATA;
                            end if;
                        end if;

                    when TX_DATA =>
                        if bit_clk = '1' then
                            if tx_byte_cnt < to_integer(unsigned(can_dlc_reg(3 downto 0))) then
                                if tx_bit_cnt < 8 then
                                    bit_to_send := tx_shift(63 - (tx_byte_cnt * 8 + tx_bit_cnt));
                                    can_tx <= bit_to_send;
                                    tx_crc_val <= can_crc_next(tx_crc_val, bit_to_send);
                                    tx_bit_cnt <= tx_bit_cnt + 1;
                                else
                                    tx_bit_cnt <= 0;
                                    tx_byte_cnt <= tx_byte_cnt + 1;
                                end if;
                            else
                                tx_bit_cnt <= 0;
                                tx_state <= TX_CRC;
                            end if;
                        end if;

                    when TX_CRC =>
                        if bit_clk = '1' then
                            if tx_bit_cnt < 15 then
                                can_tx <= tx_crc_val(14 - tx_bit_cnt);
                                tx_bit_cnt <= tx_bit_cnt + 1;
                            else
                                can_tx <= '1';  -- CRC delimiter
                                tx_state <= TX_ACK;
                            end if;
                        end if;

                    when TX_ACK =>
                        if bit_clk = '1' then
                            can_tx <= '1';
                            tx_state <= TX_EOF;
                            tx_bit_cnt <= 0;
                        end if;

                    when TX_EOF =>
                        if bit_clk = '1' then
                            if tx_bit_cnt < 7 then
                                can_tx <= '1';
                                tx_bit_cnt <= tx_bit_cnt + 1;
                            else
                                tx_state <= TX_DONE;
                            end if;
                        end if;

                    when TX_DONE =>
                        can_tx <= '1';
                        tx_ready <= '1';
                        if can_ctrl_reg(CTRL_TX_IRQ_EN) = '1' then
                            tx_irq_pending <= '1';
                        end if;
                        tx_state <= TX_IDLE;
                        -- In loopback mode, copy TX to RX
                        if can_ctrl_reg(CTRL_LOOPBACK) = '1' then
                            can_rx_id_reg       <= can_id_reg;
                            can_rx_dlc_reg      <= can_dlc_reg;
                            can_rx_data_l_reg   <= can_data_l_reg;
                            can_rx_data_h_reg   <= can_data_h_reg;
                            can_rx_ctrl_reg(RX_VALID)    <= '1';
                            can_rx_ctrl_reg(RX_EXTENDED) <= can_tx_ctrl_reg(TX_EXTENDED);
                            rx_ready <= '1';
                            if can_ctrl_reg(CTRL_RX_IRQ_EN) = '1' then
                                rx_irq_pending <= '1';
                            end if;
                        end if;

                    when others =>
                        tx_state <= TX_IDLE;
                end case;
            end if;

            -- ==================================================================
            -- RX FSM - Receive CAN frame
            -- ==================================================================
            if can_ctrl_reg(CTRL_ENABLE) = '0' then
                rx_state <= RX_IDLE;
            else
                case rx_state is
                    when RX_IDLE =>
                        if can_rx = '0' and can_ctrl_reg(CTRL_LOOPBACK) = '0' then
                            rx_state <= RX_SOF;
                            rx_crc_val <= (others => '0');
                            rx_bit_cnt <= 0;
                        end if;

                    when RX_SOF =>
                        rx_state <= RX_ARB;

                    when RX_ARB =>
                        if bit_clk = '1' then
                            if rx_bit_cnt < 11 then
                                rx_id_shift(10 - rx_bit_cnt) <= can_rx;
                                rx_crc_val <= can_crc_next(rx_crc_val, can_rx);
                                rx_bit_cnt <= rx_bit_cnt + 1;
                            else
                                rx_ext_frame <= can_rx;
                                if can_rx = '0' then
                                    rx_ext_frame <= '0';
                                    rx_bit_cnt <= 0;
                                    rx_state <= RX_CONTROL;
                                else
                                    rx_bit_cnt <= 0;
                                    rx_state <= RX_CONTROL;
                                end if;
                            end if;
                        end if;

                    when RX_CONTROL =>
                        if bit_clk = '1' then
                            if rx_bit_cnt < 4 then
                                rx_dlc_shift(3 - rx_bit_cnt) <= can_rx;
                                rx_crc_val <= can_crc_next(rx_crc_val, can_rx);
                                rx_bit_cnt <= rx_bit_cnt + 1;
                            else
                                rx_bit_cnt <= 0;
                                rx_byte_cnt <= 0;
                                rx_state <= RX_DATA;
                            end if;
                        end if;

                    when RX_DATA =>
                        if bit_clk = '1' then
                            if rx_byte_cnt < to_integer(unsigned(rx_dlc_shift)) then
                                if rx_bit_cnt < 8 then
                                    rx_shift(63 - (rx_byte_cnt * 8 + rx_bit_cnt)) <= can_rx;
                                    rx_crc_val <= can_crc_next(rx_crc_val, can_rx);
                                    rx_bit_cnt <= rx_bit_cnt + 1;
                                else
                                    rx_bit_cnt <= 0;
                                    rx_byte_cnt <= rx_byte_cnt + 1;
                                end if;
                            else
                                rx_bit_cnt <= 0;
                                rx_state <= RX_CRC;
                            end if;
                        end if;

                    when RX_CRC =>
                        if bit_clk = '1' then
                            if rx_bit_cnt < 15 then
                                rx_crc_val(14 - rx_bit_cnt) <= can_rx;
                                rx_bit_cnt <= rx_bit_cnt + 1;
                            else
                                rx_state <= RX_ACK;
                            end if;
                        end if;

                    when RX_ACK =>
                        if bit_clk = '1' then
                            rx_bit_cnt <= 0;
                            rx_state <= RX_EOF;
                        end if;

                    when RX_EOF =>
                        if bit_clk = '1' then
                            if rx_bit_cnt < 7 then
                                rx_bit_cnt <= rx_bit_cnt + 1;
                            else
                                rx_state <= RX_STORE;
                            end if;
                        end if;

                    when RX_STORE =>
                        if (rx_id_shift and not can_accept_mask_reg(10 downto 0))
                           = (can_accept_id_reg(10 downto 0) and not can_accept_mask_reg(10 downto 0))
                           or can_accept_mask_reg = x"FFFFFFFF" then
                            if rx_ready = '1' then
                                can_rx_ctrl_reg(RX_OVERRUN) <= '1';
                            end if;
                            can_rx_id_reg      <= x"00000000" & rx_id_shift(10 downto 0);
                            can_rx_dlc_reg     <= x"0000000" & rx_dlc_shift;
                            can_rx_data_l_reg  <= rx_shift(31 downto 0);
                            can_rx_data_h_reg  <= rx_shift(63 downto 32);
                            can_rx_ctrl_reg(RX_VALID)    <= '1';
                            can_rx_ctrl_reg(RX_EXTENDED) <= rx_ext_frame;
                            rx_ready <= '1';
                            if can_ctrl_reg(CTRL_RX_IRQ_EN) = '1' then
                                rx_irq_pending <= '1';
                            end if;
                        end if;
                        rx_state <= RX_IDLE;

                    when others =>
                        rx_state <= RX_IDLE;
                end case;
            end if;

            -- ==================================================================
            -- Error counter logic (simplified)
            -- ==================================================================
            if to_integer(unsigned(can_err_cnt_reg(7 downto 0))) > 96 or
               to_integer(unsigned(can_err_cnt_reg(15 downto 8))) > 96 then
                err_warn <= '1';
            else
                err_warn <= '0';
            end if;
            if to_integer(unsigned(can_err_cnt_reg(7 downto 0))) > 127 or
               to_integer(unsigned(can_err_cnt_reg(15 downto 8))) > 127 then
                err_passive <= '1';
            else
                err_passive <= '0';
            end if;
            if to_integer(unsigned(can_err_cnt_reg(7 downto 0))) > 255 then
                bus_off <= '1';
            else
                bus_off <= '0';
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
        status_reg(STATUS_RX_READY)    := rx_ready;
        status_reg(STATUS_TX_READY)    := tx_ready;
        status_reg(STATUS_BUS_OFF)     := bus_off;
        status_reg(STATUS_ERR_PASSIVE) := err_passive;
        status_reg(STATUS_ERR_WARN)    := err_warn;

        if HSEL = '1' then
            case reg_sel is
                when REG_CTRL        => HRDATA <= can_ctrl_reg;
                when REG_STATUS      => HRDATA <= status_reg;
                when REG_BTR         => HRDATA <= can_btr_reg;
                when REG_ID          => HRDATA <= can_id_reg;
                when REG_DLC         => HRDATA <= can_dlc_reg;
                when REG_DATA_L      => HRDATA <= can_data_l_reg;
                when REG_DATA_H      => HRDATA <= can_data_h_reg;
                when REG_TX_CTRL     => HRDATA <= can_tx_ctrl_reg;
                when REG_RX_CTRL     => HRDATA <= can_rx_ctrl_reg;
                when REG_RX_ID       => HRDATA <= can_rx_id_reg;
                when REG_RX_DLC      => HRDATA <= can_rx_dlc_reg;
                when REG_RX_DATA_L   => HRDATA <= can_rx_data_l_reg;
                when REG_RX_DATA_H   => HRDATA <= can_rx_data_h_reg;
                when REG_ERR_CNT     => HRDATA <= can_err_cnt_reg;
                when REG_ACCEPT_MASK => HRDATA <= can_accept_mask_reg;
                when REG_ACCEPT_ID   => HRDATA <= can_accept_id_reg;
                when others          => HRDATA <= (others => '0');
            end case;
        else
            HRDATA <= (others => '0');
        end if;
    end process;

    HRESP <= '0';
    HREADYOUT <= '1';

    -- =========================================================================
    -- Interrupt output
    -- =========================================================================
    can_int <= (tx_irq_pending or rx_irq_pending) when can_ctrl_reg(CTRL_ENABLE) = '1' else '0';

end architecture rtl;

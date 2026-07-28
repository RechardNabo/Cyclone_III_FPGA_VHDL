-- ================================================================================
-- uart_ahb : UART Controller with AHB-Lite slave interface
-- ================================================================================
-- Educational UART controller for Cyclone III FPGA.
--
-- Features:
--   * Full-duplex UART with TX and RX
--   * Configurable baud rate
--   * 8 data bits, 1-2 stop bits
--   * Even/odd/no parity
--   * RX overrun and framing error detection
--   * Interrupt on TX complete and RX ready
--
-- Register Map (HADDR[7:2] selects register):
--   0x00: UART_CTRL
--       bit0    = tx_en        (RW) - TX enable
--       bit1    = rx_en        (RW) - RX enable
--       bit2    = irq_tx_en    (RW) - TX interrupt enable
--       bit3    = irq_rx_en    (RW) - RX interrupt enable
--       bit4    = parity_en    (RW) - parity enable
--       bit5    = parity_even  (RW) - 1=even, 0=odd
--       bit6    = stop2        (RW) - 1=2 stop bits, 0=1 stop bit
--   0x04: UART_BAUD - baud rate divisor (RW)
--   0x08: UART_STATUS
--       bit0 = tx_busy         (RO) - TX in progress
--       bit1 = tx_done         (RO) - TX complete
--       bit2 = rx_ready        (RO) - RX data available
--       bit3 = rx_overrun      (RO) - RX overrun
--       bit4 = framing_err     (RO) - framing error
--       bit5 = parity_err      (RO) - parity error
--   0x0C: UART_TXDATA - write to transmit (WO)
--   0x10: UART_RXDATA - read received data (RO)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_ahb is
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

        -- UART physical interface
        txd       : out std_logic;
        rxd       : in  std_logic;

        -- Interrupt
        uart_int  : out std_logic
    );
end entity uart_ahb;

architecture rtl of uart_ahb is
    constant REG_CTRL    : integer := 0;
    constant REG_BAUD    : integer := 1;
    constant REG_STATUS  : integer := 2;
    constant REG_TXDATA  : integer := 3;
    constant REG_RXDATA_C: integer := 4;

    signal ctrl_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal baud_reg   : unsigned(15 downto 0) := to_unsigned(434, 16);  -- 115200 @ 50MHz

    -- TX state machine
    type tx_state is (TX_IDLE, TX_START, TX_DATA, TX_PARITY, TX_STOP1, TX_STOP2, TX_DONE_ST);
    signal tx_st      : tx_state := TX_IDLE;
    signal tx_shift   : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_bit_cnt : integer range 0 to 7 := 0;
    signal tx_clk_cnt : unsigned(15 downto 0) := (others => '0');
    signal tx_busy    : std_logic := '0';
    signal tx_done    : std_logic := '0';
    signal txd_reg    : std_logic := '1';  -- idle high

    -- RX state machine
    type rx_state is (RX_IDLE, RX_START, RX_DATA_ST, RX_PARITY, RX_STOP1, RX_STOP2);
    signal rx_st      : rx_state := RX_IDLE;
    signal rx_shift   : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_bit_cnt : integer range 0 to 7 := 0;
    signal rx_clk_cnt : unsigned(15 downto 0) := (others => '0');
    signal rx_data_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_ready   : std_logic := '0';
    signal rx_overrun : std_logic := '0';
    signal framing_err: std_logic := '0';
    signal parity_err : std_logic := '0';
    signal rxd_sync   : std_logic := '1';

    signal write_en   : std_logic;
    signal reg_idx    : integer range 0 to 63;

    -- TX load strobe (driven only by reg_write, read by tx_proc)
    signal tx_data_buf : std_logic_vector(7 downto 0) := (others => '0');

    signal start_tx   : std_logic := '0';
    signal rx_clear   : std_logic;

begin

    reg_idx  <= to_integer(unsigned(HADDR(7 downto 2)));
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    rx_clear <= '1' when (HSEL = '1' and HWRITE = '0' and HREADY = '1' and (HTRANS(0) = '1' or HTRANS(1) = '1') and reg_idx = REG_RXDATA_C) else '0';

    HREADYOUT <= '1';
    HRESP     <= '0';

    txd <= txd_reg;

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg   <= (others => '0');
                baud_reg   <= to_unsigned(434, 16);
                start_tx   <= '0';
            elsif write_en = '1' then
                start_tx <= '0';
                case reg_idx is
                    when REG_CTRL =>
                        ctrl_reg <= HWDATA;
                    when REG_BAUD =>
                        baud_reg <= unsigned(HWDATA(15 downto 0));
                    when REG_TXDATA =>
                        if tx_busy = '0' and ctrl_reg(0) = '1' then
                            tx_data_buf <= HWDATA(7 downto 0);
                            start_tx <= '1';
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- TX state machine
    tx_proc : process(HCLK)
        variable parity_calc : std_logic;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                tx_st      <= TX_IDLE;
                txd_reg    <= '1';
                tx_busy    <= '0';
                tx_done    <= '0';
                tx_bit_cnt <= 0;
                tx_clk_cnt <= (others => '0');
            elsif ctrl_reg(0) = '1' then  -- TX enabled
                case tx_st is
                    when TX_IDLE =>
                        txd_reg <= '1';  -- idle high
                        if start_tx = '1' then
                            tx_shift   <= tx_data_buf;
                            tx_busy    <= '1';
                            tx_done    <= '0';
                            tx_bit_cnt <= 0;
                            tx_clk_cnt <= (others => '0');
                            tx_st      <= TX_START;
                        end if;

                    when TX_START =>
                        txd_reg <= '0';  -- start bit
                        if tx_clk_cnt = baud_reg - 1 then
                            tx_clk_cnt <= (others => '0');
                            tx_st <= TX_DATA;
                            tx_bit_cnt <= 0;
                        else
                            tx_clk_cnt <= tx_clk_cnt + 1;
                        end if;

                    when TX_DATA =>
                        txd_reg <= tx_shift(0);
                        if tx_clk_cnt = baud_reg - 1 then
                            tx_clk_cnt <= (others => '0');
                            if tx_bit_cnt = 7 then
                                if ctrl_reg(4) = '1' then  -- parity enabled
                                    tx_st <= TX_PARITY;
                                else
                                    tx_st <= TX_STOP1;
                                end if;
                                tx_bit_cnt <= 0;
                            else
                                tx_shift <= '0' & tx_shift(7 downto 1);
                                tx_bit_cnt <= tx_bit_cnt + 1;
                            end if;
                        else
                            tx_clk_cnt <= tx_clk_cnt + 1;
                        end if;

                    when TX_PARITY =>
                        -- Simple even/odd parity
                        parity_calc := tx_shift(0) xor tx_shift(1) xor tx_shift(2) xor tx_shift(3) xor
                                       tx_shift(4) xor tx_shift(5) xor tx_shift(6) xor tx_shift(7);
                        if ctrl_reg(5) = '1' then  -- even parity
                            txd_reg <= parity_calc;
                        else
                            txd_reg <= not parity_calc;
                        end if;
                        if tx_clk_cnt = baud_reg - 1 then
                            tx_clk_cnt <= (others => '0');
                            tx_st <= TX_STOP1;
                        else
                            tx_clk_cnt <= tx_clk_cnt + 1;
                        end if;

                    when TX_STOP1 =>
                        txd_reg <= '1';  -- stop bit
                        if tx_clk_cnt = baud_reg - 1 then
                            tx_clk_cnt <= (others => '0');
                            if ctrl_reg(6) = '1' then  -- 2 stop bits
                                tx_st <= TX_STOP2;
                            else
                                tx_st <= TX_DONE_ST;
                            end if;
                        else
                            tx_clk_cnt <= tx_clk_cnt + 1;
                        end if;

                    when TX_STOP2 =>
                        txd_reg <= '1';
                        if tx_clk_cnt = baud_reg - 1 then
                            tx_clk_cnt <= (others => '0');
                            tx_st <= TX_DONE_ST;
                        else
                            tx_clk_cnt <= tx_clk_cnt + 1;
                        end if;

                    when TX_DONE_ST =>
                        tx_done <= '1';
                        tx_busy <= '0';
                        txd_reg <= '1';
                        tx_st <= TX_IDLE;

                    when others =>
                        tx_st <= TX_IDLE;
                end case;
            end if;
        end if;
    end process tx_proc;

    -- RX state machine (with synchronizer)
    rx_proc : process(HCLK)
        variable parity_calc : std_logic;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                rx_st       <= RX_IDLE;
                rx_shift    <= (others => '0');
                rx_data_reg <= (others => '0');
                rx_ready    <= '0';
                rx_overrun  <= '0';
                framing_err <= '0';
                parity_err  <= '0';
                rx_bit_cnt  <= 0;
                rx_clk_cnt  <= (others => '0');
                rxd_sync    <= '1';
            else
                -- Synchronize rxd
                rxd_sync <= rxd;
                -- Clear rx_ready on RXDATA read
                if rx_clear = '1' then
                    rx_ready <= '0';
                end if;
                if ctrl_reg(1) = '1' then  -- RX enabled
                    case rx_st is
                        when RX_IDLE =>
                            if rxd_sync = '0' then  -- start bit detected
                                rx_st <= RX_START;
                                rx_clk_cnt <= (others => '0');
                            end if;

                        when RX_START =>
                            -- Sample at middle of bit period
                            if rx_clk_cnt = (baud_reg / 2) - 1 then
                                if rxd_sync = '0' then  -- valid start bit
                                    rx_clk_cnt <= (others => '0');
                                    rx_st <= RX_DATA_ST;
                                    rx_bit_cnt <= 0;
                                else  -- false start
                                    rx_st <= RX_IDLE;
                                end if;
                            else
                                rx_clk_cnt <= rx_clk_cnt + 1;
                            end if;

                        when RX_DATA_ST =>
                            if rx_clk_cnt = baud_reg - 1 then
                                rx_clk_cnt <= (others => '0');
                                rx_shift <= rxd_sync & rx_shift(7 downto 1);
                                if rx_bit_cnt = 7 then
                                    if ctrl_reg(4) = '1' then
                                        rx_st <= RX_PARITY;
                                    else
                                        rx_st <= RX_STOP1;
                                    end if;
                                    rx_bit_cnt <= 0;
                                else
                                    rx_bit_cnt <= rx_bit_cnt + 1;
                                end if;
                            else
                                rx_clk_cnt <= rx_clk_cnt + 1;
                            end if;

                        when RX_PARITY =>
                            if rx_clk_cnt = baud_reg - 1 then
                                rx_clk_cnt <= (others => '0');
                                parity_calc := rx_shift(0) xor rx_shift(1) xor rx_shift(2) xor rx_shift(3) xor
                                               rx_shift(4) xor rx_shift(5) xor rx_shift(6) xor rx_shift(7);
                                if ctrl_reg(5) = '1' then  -- even parity
                                    if rxd_sync /= parity_calc then
                                        parity_err <= '1';
                                    end if;
                                else  -- odd parity
                                    if rxd_sync = parity_calc then
                                        parity_err <= '1';
                                    end if;
                                end if;
                                rx_st <= RX_STOP1;
                            else
                                rx_clk_cnt <= rx_clk_cnt + 1;
                            end if;

                        when RX_STOP1 =>
                            if rx_clk_cnt = baud_reg - 1 then
                                rx_clk_cnt <= (others => '0');
                                if rxd_sync /= '1' then
                                    framing_err <= '1';
                                end if;
                                if ctrl_reg(6) = '1' then
                                    rx_st <= RX_STOP2;
                                else
                                    -- Frame complete
                                    if rx_ready = '1' then
                                        rx_overrun <= '1';
                                    end if;
                                    rx_data_reg <= rx_shift;
                                    rx_ready <= '1';
                                    rx_st <= RX_IDLE;
                                end if;
                            else
                                rx_clk_cnt <= rx_clk_cnt + 1;
                            end if;

                        when RX_STOP2 =>
                            if rx_clk_cnt = baud_reg - 1 then
                                rx_clk_cnt <= (others => '0');
                                if rx_ready = '1' then
                                    rx_overrun <= '1';
                                end if;
                                rx_data_reg <= rx_shift;
                                rx_ready <= '1';
                                rx_st <= RX_IDLE;
                            else
                                rx_clk_cnt <= rx_clk_cnt + 1;
                            end if;

                        when others =>
                            rx_st <= RX_IDLE;
                    end case;
                end if;
            end if;
        end if;
    end process rx_proc;

    -- Register read mux
    reg_read : process(reg_idx, ctrl_reg, baud_reg, rx_data_reg, tx_busy, tx_done,
                       rx_ready, rx_overrun, framing_err, parity_err)
    begin
        case reg_idx is
            when REG_CTRL =>
                HRDATA <= ctrl_reg;
            when REG_BAUD =>
                HRDATA <= x"0000" & std_logic_vector(baud_reg);
            when REG_STATUS =>
                HRDATA <= (0 => tx_busy, 1 => tx_done, 2 => rx_ready,
                           3 => rx_overrun, 4 => framing_err, 5 => parity_err,
                           others => '0');
            when REG_TXDATA =>
                HRDATA <= (others => '0');
            when REG_RXDATA_C =>
                HRDATA <= x"000000" & rx_data_reg;
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    -- Combined interrupt
    uart_int <= (tx_done and ctrl_reg(2)) or (rx_ready and ctrl_reg(3));

end architecture rtl;

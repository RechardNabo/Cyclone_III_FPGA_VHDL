-- ================================================================================
-- i2s_master_ahb : I2S Master Controller with AHB-Lite slave interface
-- ================================================================================
-- Educational I2S master controller for Cyclone III FPGA.
--
-- Features:
--   * I2S master mode (generates SCK, WS)
--   * Philips standard I2S format
--   * Left-justified format option
--   * 16/24/32-bit word sizes
--   * Configurable sample rate
--   * TX and RX support
--   * Interrupt on frame complete
--
-- Register Map (HADDR[7:2] selects register):
--   0x00: I2S_CTRL
--       bit0    = enable       (RW) - I2S enable
--       bit1    = irq_en       (RW) - interrupt enable
--       bit2    = tx_en        (RW) - TX enable
--       bit3    = rx_en        (RW) - RX enable
--       bit4    = left_just    (RW) - 1=left-justified, 0=Philips standard
--       bit5..6 = word_size    (RW) - 00=16, 01=24, 10=32
--   0x04: I2S_CLKDIV - SCK divider (RW), SCK = HCLK / CLKDIV
--   0x08: I2S_STATUS
--       bit0 = busy            (RO) - transfer in progress
--       bit1 = done            (RO) - frame complete
--       bit2 = tx_empty        (RO) - TX buffer empty
--       bit3 = rx_full         (RO) - RX buffer full
--   0x0C: I2S_TXDATA_L - left channel TX data (WO)
--   0x10: I2S_TXDATA_R - right channel TX data (WO)
--   0x14: I2S_RXDATA_L - left channel RX data (RO)
--   0x18: I2S_RXDATA_R - right channel RX data (RO)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity i2s_master_ahb is
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

        -- I2S physical interface
        sck       : out std_logic;   -- serial bit clock (BCLK)
        ws        : out std_logic;   -- word select (LRCLK)
        sd_tx     : out std_logic;   -- serial data out
        sd_rx     : in  std_logic;   -- serial data in
        mclk      : out std_logic;   -- master clock (optional)

        -- Interrupt
        i2s_int   : out std_logic
    );
end entity i2s_master_ahb;

architecture rtl of i2s_master_ahb is
    constant REG_CTRL    : integer := 0;
    constant REG_CLKDIV  : integer := 1;
    constant REG_STATUS  : integer := 2;
    constant REG_TX_L    : integer := 3;
    constant REG_TX_R    : integer := 4;
    constant REG_RX_L    : integer := 5;
    constant REG_RX_R    : integer := 6;

    signal ctrl_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal clkdiv_reg : unsigned(15 downto 0) := to_unsigned(8, 16);

    signal tx_l_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal tx_r_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_l_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_r_reg   : std_logic_vector(31 downto 0) := (others => '0');

    signal busy       : std_logic := '0';
    signal done_flag  : std_logic := '0';
    signal tx_empty   : std_logic := '1';
    signal rx_full    : std_logic := '0';

    -- I2S state machine
    type i2s_state is (IDLE, WS_SETUP, BIT_TXRX, WS_TOGGLE, FRAME_DONE);
    signal state      : i2s_state := IDLE;
    signal bit_cnt    : integer range 0 to 32 := 0;
    signal clk_cnt    : unsigned(15 downto 0) := (others => '0');
    signal ws_reg     : std_logic := '0';  -- 0=left, 1=right
    signal sck_reg    : std_logic := '0';
    signal sd_tx_reg  : std_logic := '0';
    signal mclk_reg   : std_logic := '0';
    signal shift_tx   : std_logic_vector(31 downto 0) := (others => '0');
    signal shift_rx   : std_logic_vector(31 downto 0) := (others => '0');
    signal cur_word   : integer range 16 to 32 := 16;

    signal write_en   : std_logic;
    signal reg_idx    : integer range 0 to 63;
    signal start_tx   : std_logic := '0';
    signal tx_load    : std_logic := '0';

begin

    reg_idx  <= to_integer(unsigned(HADDR(7 downto 2)));
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    sck  <= sck_reg;
    ws   <= ws_reg;
    sd_tx <= sd_tx_reg;
    mclk <= mclk_reg;

    -- Word size decode
    cur_word <= 16 when ctrl_reg(6 downto 5) = "00" else
                24 when ctrl_reg(6 downto 5) = "01" else
                32;

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg   <= (others => '0');
                clkdiv_reg <= to_unsigned(8, 16);
                tx_l_reg   <= (others => '0');
                tx_r_reg   <= (others => '0');
                start_tx   <= '0';
                tx_load    <= '0';
            elsif write_en = '1' then
                start_tx <= '0';
                tx_load  <= '0';
                start_tx  <= '0';
                case reg_idx is
                    when REG_CTRL =>
                        ctrl_reg <= HWDATA;
                    when REG_CLKDIV =>
                        clkdiv_reg <= unsigned(HWDATA(15 downto 0));
                    when REG_TX_L =>
                        tx_l_reg <= HWDATA;
                        tx_load  <= '1';
                    when REG_TX_R =>
                        tx_r_reg <= HWDATA;
                        if busy = '0' and ctrl_reg(0) = '1' and ctrl_reg(2) = '1' then
                            -- Start transmission (trigger FSM)
                            start_tx <= '1';
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- I2S state machine
    i2s_fsm : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                state     <= IDLE;
                busy      <= '0';
                sck_reg   <= '0';
                ws_reg    <= '0';
                sd_tx_reg <= '0';
                mclk_reg  <= '0';
                shift_rx  <= (others => '0');
                rx_l_reg  <= (others => '0');
                rx_r_reg  <= (others => '0');
                rx_full   <= '0';
                done_flag <= '0';
                tx_empty  <= '1';
                bit_cnt   <= 0;
                clk_cnt   <= (others => '0');
            elsif ctrl_reg(0) = '1' then  -- enabled
                mclk_reg <= not mclk_reg;  -- toggle MCLK every system clock
                if tx_load = '1' then
                    tx_empty <= '0';
                end if;

                case state is
                    when IDLE =>
                        sck_reg <= '0';
                        if start_tx = '1' then
                            busy      <= '1';
                            state     <= WS_SETUP;
                            bit_cnt   <= 0;
                            clk_cnt   <= (others => '0');
                            ws_reg    <= '0';  -- start with left
                            shift_tx  <= tx_l_reg;
                        end if;

                    when WS_SETUP =>
                        -- Set WS and prepare first bit
                        sck_reg <= '0';
                        if ctrl_reg(4) = '1' then  -- left-justified
                            sd_tx_reg <= shift_tx(cur_word - 1);
                        else  -- Philips standard: delay by 1 SCK
                            sd_tx_reg <= '0';
                        end if;
                        if clk_cnt = clkdiv_reg - 1 then
                            clk_cnt <= (others => '0');
                            state <= BIT_TXRX;
                            bit_cnt <= 0;
                            if ctrl_reg(4) = '0' then  -- Philips: first bit after WS
                                sd_tx_reg <= shift_tx(cur_word - 1);
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when BIT_TXRX =>
                        -- Toggle SCK and shift data
                        if clk_cnt = clkdiv_reg - 1 then
                            clk_cnt <= (others => '0');
                            sck_reg <= not sck_reg;
                            -- On rising edge of SCK, sample RX
                            if sck_reg = '0' then  -- about to go high
                                shift_rx <= shift_rx(30 downto 0) & sd_rx;
                                if bit_cnt = cur_word - 1 then
                                    -- Word complete
                                    if ws_reg = '0' then
                                        rx_l_reg <= shift_rx(30 downto 0) & sd_rx;
                                    else
                                        rx_r_reg <= shift_rx(30 downto 0) & sd_rx;
                                    end if;
                                    state <= WS_TOGGLE;
                                else
                                    bit_cnt <= bit_cnt + 1;
                                    -- Set next TX bit
                                    sd_tx_reg <= shift_tx(cur_word - 2 - bit_cnt);
                                end if;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when WS_TOGGLE =>
                        -- Toggle WS for next channel
                        sck_reg <= '0';
                        if ws_reg = '0' then
                            -- Switch to right channel
                            ws_reg <= '1';
                            shift_tx <= tx_r_reg;
                            state <= WS_SETUP;
                            bit_cnt <= 0;
                            clk_cnt <= (others => '0');
                        else
                            -- Both channels done
                            state <= FRAME_DONE;
                        end if;

                    when FRAME_DONE =>
                        done_flag <= '1';
                        tx_empty  <= '1';
                        rx_full   <= '1';
                        busy      <= '0';
                        ws_reg    <= '0';
                        state     <= IDLE;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process i2s_fsm;

    -- Register read mux
    reg_read : process(reg_idx, ctrl_reg, clkdiv_reg, rx_l_reg, rx_r_reg,
                       busy, done_flag, tx_empty, rx_full)
    begin
        case reg_idx is
            when REG_CTRL =>
                HRDATA <= ctrl_reg;
            when REG_CLKDIV =>
                HRDATA <= x"0000" & std_logic_vector(clkdiv_reg);
            when REG_STATUS =>
                HRDATA <= (0 => busy, 1 => done_flag, 2 => tx_empty, 3 => rx_full,
                           others => '0');
            when REG_TX_L =>
                HRDATA <= (others => '0');
            when REG_TX_R =>
                HRDATA <= (others => '0');
            when REG_RX_L =>
                HRDATA <= rx_l_reg;
            when REG_RX_R =>
                HRDATA <= rx_r_reg;
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    i2s_int <= done_flag and ctrl_reg(1);

end architecture rtl;

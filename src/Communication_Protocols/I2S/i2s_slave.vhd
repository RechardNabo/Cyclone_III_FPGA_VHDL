-- ================================================================================
-- i2s_slave : I2S (Inter-IC Sound) bus slave receiver
--
-- Receives audio data from an I2S master. The slave does NOT generate SCK or WS;
-- it only samples SD on the appropriate SCK edges.
--
-- Supports:
--   * Philips standard I2S framing
--   * 16/24/32-bit word widths
--   * RX (capture) direction
--
-- Target: Altera Cyclone III EP3C16F484C6N.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity i2s_slave is
    generic (
        WORD_WIDTH : integer := 24  -- audio word width: 16, 24, or 32
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;       -- active-high synchronous

        enable      : in  std_logic;       -- '1' = listening, '0' = idle
        rx_l_data   : out std_logic_vector(31 downto 0); -- left channel RX
        rx_r_data   : out std_logic_vector(31 downto 0); -- right channel RX
        rx_ready    : out std_logic;       -- pulse when a full L/R pair is ready
        busy        : out std_logic;       -- '1' = currently receiving

        -- I2S bus (slave receives SCK, WS, and SD)
        i2s_sck     : in  std_logic;       -- serial bit clock (from master)
        i2s_ws      : in  std_logic;       -- word select (from master)
        i2s_sd_rx   : in  std_logic        -- serial data input (from master)
    );
end entity i2s_slave;

architecture rtl of i2s_slave is

    type state_t is (S_IDLE, S_WAIT_WS, S_RX_L, S_RX_R);
    signal state : state_t := S_IDLE;

    signal bit_cnt      : integer range 0 to WORD_WIDTH + 1 := 0;
    signal rx_l_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_r_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_ready_reg : std_logic := '0';
    signal busy_reg     : std_logic := '0';

    -- Edge detection for SCK
    signal sck_prev     : std_logic := '0';

begin

    rx_ready <= rx_ready_reg;
    busy     <= busy_reg;

    slave_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state        <= S_IDLE;
                bit_cnt      <= 0;
                rx_l_reg     <= (others => '0');
                rx_r_reg     <= (others => '0');
                rx_ready_reg <= '0';
                busy_reg     <= '0';
                sck_prev     <= '0';
                rx_l_data    <= (others => '0');
                rx_r_data    <= (others => '0');
            else
                rx_ready_reg <= '0';
                sck_prev     <= i2s_sck;

                case state is
                    when S_IDLE =>
                        busy_reg <= '0';
                        if enable = '1' then
                            -- Wait for WS to go low (start of left channel)
                            if i2s_ws = '0' then
                                busy_reg <= '1';
                                bit_cnt  <= WORD_WIDTH;
                                state    <= S_RX_L;
                            end if;
                        end if;

                    when S_RX_L =>
                        -- Sample on rising edge of SCK
                        if i2s_sck = '1' and sck_prev = '0' then
                            if bit_cnt > 0 then
                                bit_cnt <= bit_cnt - 1;
                                rx_l_reg(bit_cnt - 1) <= i2s_sd_rx;
                            end if;
                            if bit_cnt = 1 then
                                -- Last bit of left channel
                                if i2s_ws = '1' then
                                    -- WS already high, switch to right
                                    bit_cnt <= WORD_WIDTH;
                                    state   <= S_RX_R;
                                end if;
                            end if;
                        end if;
                        -- Detect WS rising edge to switch to right channel
                        if i2s_ws = '1' and bit_cnt < WORD_WIDTH then
                            bit_cnt <= WORD_WIDTH;
                            state   <= S_RX_R;
                        end if;

                    when S_RX_R =>
                        -- Sample on rising edge of SCK
                        if i2s_sck = '1' and sck_prev = '0' then
                            if bit_cnt > 0 then
                                bit_cnt <= bit_cnt - 1;
                                rx_r_reg(bit_cnt - 1) <= i2s_sd_rx;
                            end if;
                            if bit_cnt = 1 then
                                -- Right channel complete
                                rx_l_data    <= rx_l_reg;
                                rx_r_data    <= rx_r_reg;
                                rx_ready_reg <= '1';
                                busy_reg     <= '0';
                                state        <= S_IDLE;
                            end if;
                        end if;
                        -- Detect WS falling edge (next frame)
                        if i2s_ws = '0' and bit_cnt < WORD_WIDTH then
                            -- Frame complete
                            rx_l_data    <= rx_l_reg;
                            rx_r_data    <= rx_r_reg;
                            rx_ready_reg <= '1';
                            busy_reg     <= '0';
                            bit_cnt      <= WORD_WIDTH;
                            state        <= S_RX_L;
                        end if;

                    when others =>
                        state <= S_IDLE;
                end case;
            end if;
        end if;
    end process slave_proc;

end architecture rtl;

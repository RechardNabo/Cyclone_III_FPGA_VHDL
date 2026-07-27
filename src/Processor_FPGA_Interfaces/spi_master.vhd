-- ============================================================================
-- SPI Master Controller
-- Target: Altera/Intel Cyclone III FPGA
-- 8-bit data, configurable clock divider, CPOL/CPHA support.
-- CPOL=0: SCK idles low. CPHA=0: sample on leading, shift on trailing edge.
-- SS is active-low; asserted at start, de-asserted at end of transfer.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi_master is
    generic (
        DATA_WIDTH     : integer   := 8;
        CPOL           : std_logic := '0';
        CPHA           : std_logic := '0';
        CLK_DIV_FACTOR : integer   := 8  -- System clocks per SCK half-period
    );
    port (
        clk_i            : in  std_logic;
        rst_i            : in  std_logic;
        start_transfer_i : in  std_logic;
        tx_data_i        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        transfer_done_o  : out std_logic;
        rx_data_o        : out std_logic_vector(DATA_WIDTH-1 downto 0);
        sck_o            : out std_logic;
        mosi_o           : out std_logic;
        miso_i           : in  std_logic;
        ss_o             : out std_logic
    );
end entity spi_master;

architecture rtl of spi_master is
    type state_t is (IDLE, TRANSFER, DONE);
    signal state     : state_t := IDLE;
    signal clk_cnt   : integer range 0 to CLK_DIV_FACTOR-1 := 0;
    signal sck_tick  : std_logic := '0';
    signal sck_int   : std_logic := CPOL;
    signal tx_shift  : std_logic_vector(DATA_WIDTH-1 downto 0) :=
        (others => '0');
    signal rx_shift  : std_logic_vector(DATA_WIDTH-1 downto 0) :=
        (others => '0');
    signal bit_cnt   : integer range 0 to DATA_WIDTH := 0;
    signal sck_prev  : std_logic := CPOL;
begin

    -- SCK clock divider: tick every CLK_DIV_FACTOR system clocks
    clk_div : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                clk_cnt <= 0; sck_tick <= '0';
            else
                sck_tick <= '0';
                if state = TRANSFER then
                    if clk_cnt = CLK_DIV_FACTOR-1 then
                        clk_cnt <= 0; sck_tick <= '1';
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;
                else
                    clk_cnt <= 0;
                end if;
            end if;
        end if;
    end process clk_div;

    -- Main SPI FSM
    spi_fsm : process(clk_i)
        variable is_leading : boolean;
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state <= IDLE; sck_int <= CPOL; sck_prev <= CPOL;
                tx_shift <= (others => '0'); rx_shift <= (others => '0');
                bit_cnt <= 0; ss_o <= '1'; mosi_o <= '0';
                transfer_done_o <= '0'; rx_data_o <= (others => '0');
            else
                transfer_done_o <= '0';
                case state is
                    when IDLE =>
                        ss_o <= '1'; sck_int <= CPOL; sck_prev <= CPOL;
                        if start_transfer_i = '1' then
                            tx_shift <= tx_data_i;
                            rx_shift <= (others => '0');
                            bit_cnt  <= 0; ss_o <= '0';
                            state    <= TRANSFER;
                            if CPHA = '0' then  -- Pre-load first MOSI bit
                                mosi_o <= tx_data_i(DATA_WIDTH-1);
                            end if;
                        end if;
                    when TRANSFER =>
                        if sck_tick = '1' then
                            sck_int  <= not sck_int;
                            sck_prev <= sck_int;
                            is_leading := (sck_int = CPOL);  -- Going away from idle
                            if CPHA = '0' then
                                if is_leading then  -- Leading: sample MISO
                                    rx_shift <= rx_shift(DATA_WIDTH-2 downto 0)
                                               & miso_i;
                                    bit_cnt  <= bit_cnt + 1;
                                else  -- Trailing: shift next MOSI bit
                                    if bit_cnt < DATA_WIDTH then
                                        tx_shift <= tx_shift(DATA_WIDTH-2 downto 0)
                                                    & '0';
                                        mosi_o   <= tx_shift(DATA_WIDTH-2);
                                    end if;
                                end if;
                            else  -- CPHA = 1
                                if is_leading then  -- Leading: shift MOSI
                                    if bit_cnt < DATA_WIDTH then
                                        mosi_o   <= tx_shift(DATA_WIDTH-1);
                                        tx_shift <= tx_shift(DATA_WIDTH-2 downto 0)
                                                    & '0';
                                    end if;
                                else  -- Trailing: sample MISO
                                    rx_shift <= rx_shift(DATA_WIDTH-2 downto 0)
                                               & miso_i;
                                    bit_cnt  <= bit_cnt + 1;
                                end if;
                            end if;
                            if bit_cnt = DATA_WIDTH then
                                state           <= DONE;
                                rx_data_o       <= rx_shift;
                                transfer_done_o <= '1';
                            end if;
                        end if;
                    when DONE =>
                        ss_o <= '1'; sck_int <= CPOL; state <= IDLE;
                end case;
            end if;
        end if;
    end process spi_fsm;

    sck_o <= sck_int;

end architecture rtl;

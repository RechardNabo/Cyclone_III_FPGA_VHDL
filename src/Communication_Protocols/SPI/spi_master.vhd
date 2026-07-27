-- ============================================================================
-- SPI Master Controller
-- ============================================================================
-- SPI (Serial Peripheral Interface) is a synchronous serial protocol.
-- The master generates the clock (SCK), selects a slave (SS), and
-- exchanges data simultaneously: MOSI (master out, slave in) and
-- MISO (master in, slave out). This module supports all 4 SPI modes
-- via CPOL (clock polarity) and CPHA (clock phase).
--   Mode 0: CPOL=0, CPHA=0  (data sampled on rising edge)
--   Mode 1: CPOL=0, CPHA=1  (data sampled on falling edge)
--   Mode 2: CPOL=1, CPHA=0
--   Mode 3: CPOL=1, CPHA=1
-- Beginner-friendly, synthesizable VHDL for the Cyclone III FPGA.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi_master is
    generic (
        CLK_DIV : integer := 8  -- SCK = system_clk / (2 * CLK_DIV)
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        -- CPU interface
        data_in  : in  std_logic_vector(7 downto 0); -- byte to send
        tx_start : in  std_logic;        -- pulse high to start transfer
        data_out : out std_logic_vector(7 downto 0); -- received byte
        ready    : out std_logic;        -- '1' when ready for new transfer
        -- SPI mode
        cpol     : in  std_logic;        -- clock polarity
        cpha     : in  std_logic;        -- clock phase
        -- SPI bus
        sck      : out std_logic;
        mosi     : out std_logic;
        miso     : in  std_logic;
        ss       : out std_logic         -- slave select (active low)
    );
end entity spi_master;

architecture rtl of spi_master is
    type state_t is (IDLE, TRANSFER, DONE);
    signal state : state_t := IDLE;

    signal clk_cnt   : integer range 0 to CLK_DIV - 1 := 0;
    signal sck_int   : std_logic := '0';
    signal bit_index : integer range 0 to 7 := 0;
    signal tx_reg    : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_reg    : std_logic_vector(7 downto 0) := (others => '0');
    signal ready_flag: std_logic := '1';
    signal cpol_reg  : std_logic := '0';
    signal cpha_reg  : std_logic := '0';
begin

    spi_proc : process(clk, reset)
        -- Determine the edge on which to sample MISO
        variable sample_edge : boolean;
    begin
        if reset = '1' then
            state      <= IDLE;
            sck_int    <= '0';
            mosi       <= '0';
            ss         <= '1';   -- slave not selected
            ready_flag <= '1';
            clk_cnt    <= 0;
            bit_index  <= 0;
            tx_reg     <= (others => '0');
            rx_reg     <= (others => '0');
            data_out   <= (others => '0');
        elsif rising_edge(clk) then
            case state is
                -- IDLE: wait for start command
                when IDLE =>
                    ss         <= '1';
                    sck_int    <= cpol;  -- idle SCK at polarity level
                    ready_flag <= '1';
                    clk_cnt    <= 0;
                    bit_index  <= 0;
                    if tx_start = '1' then
                        tx_reg    <= data_in;
                        cpol_reg  <= cpol;
                        cpha_reg  <= cpha;
                        ready_flag<= '0';
                        ss        <= '0';  -- select slave
                        state     <= TRANSFER;
                        sck_int   <= cpol; -- start at idle polarity
                    end if;

                -- TRANSFER: generate SCK, shift data out on MOSI, sample MISO
                when TRANSFER =>
                    if clk_cnt = CLK_DIV - 1 then
                        clk_cnt <= 0;
                        -- Toggle SCK
                        sck_int <= not sck_int;

                        -- For CPHA=0: sample on the edge that goes to idle polarity
                        -- For CPHA=1: sample half a cycle later
                        -- Simplified: sample MISO on the edge opposite to MOSI change
                        if cpha_reg = '0' then
                            -- Mode 0/2: data is sampled on the leading edge
                            if sck_int = cpol_reg then
                                -- This is the leading edge (just toggled to active)
                                rx_reg <= rx_reg(6 downto 0) & miso;
                                mosi   <= tx_reg(bit_index);
                                if bit_index = 7 then
                                    state <= DONE;
                                else
                                    bit_index <= bit_index + 1;
                                end if;
                            end if;
                        else
                            -- Mode 1/3: data is sampled on the trailing edge
                            if sck_int = not cpol_reg then
                                -- This is the trailing edge
                                rx_reg <= rx_reg(6 downto 0) & miso;
                                mosi   <= tx_reg(bit_index);
                                if bit_index = 7 then
                                    state <= DONE;
                                else
                                    bit_index <= bit_index + 1;
                                end if;
                            end if;
                        end if;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                -- DONE: deassert SS, output received data
                when DONE =>
                    ss         <= '1';
                    sck_int    <= cpol_reg;
                    data_out   <= rx_reg;
                    ready_flag <= '1';
                    state      <= IDLE;
            end case;
        end if;
    end process spi_proc;

    sck   <= sck_int;
    ready <= ready_flag;

end architecture rtl;

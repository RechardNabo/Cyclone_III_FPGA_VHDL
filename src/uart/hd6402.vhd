-- ============================================================================
-- HD6402 Compatible UART Controller
-- ============================================================================
-- Inspired by the Intel 8251 / Signetics 2662 / HD6402 UART chip.
-- Provides both transmit and receive paths with status flags:
--   TX_READY  : transmitter can accept a new byte
--   RX_READY  : a received byte is available
--   FRAMING_ERROR : stop bit was not '1'
--   PARITY_ERROR  : parity check failed (even parity used here)
-- Beginner-friendly, synthesizable VHDL for the Cyclone III FPGA.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity hd6402 is
    generic (
        BAUD_RATE : integer := 9600;
        CLK_FREQ  : integer := 50000000
    );
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;
        -- CPU interface (parallel side)
        data_in       : in  std_logic_vector(7 downto 0); -- byte to transmit
        tx_load       : in  std_logic;  -- pulse high to load data_in for TX
        rx_read       : in  std_logic;  -- pulse high to read received byte
        data_out      : out std_logic_vector(7 downto 0); -- received byte
        -- Status flags
        tx_ready      : out std_logic;
        rx_ready      : out std_logic;
        framing_error : out std_logic;
        parity_error  : out std_logic;
        -- Serial side
        serial_in     : in  std_logic;
        serial_out    : out std_logic
    );
end entity hd6402;

architecture rtl of hd6402 is
    constant CLK_PER_BIT : integer := CLK_FREQ / BAUD_RATE;

    -- ---- TX state machine ----
    type tx_state_t is (TX_IDLE, TX_START, TX_DATA, ST_TX_PARITY, TX_STOP);
    signal tx_state : tx_state_t := TX_IDLE;
    signal tx_clk_count : integer range 0 to CLK_PER_BIT - 1 := 0;
    signal tx_bit_index : integer range 0 to 7 := 0;
    signal tx_data_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_parity    : std_logic := '0';
    signal tx_rdy       : std_logic := '1';

    -- ---- RX state machine ----
    type rx_state_t is (RX_IDLE, RX_START, RX_DATA, ST_RX_PARITY, RX_STOP);
    signal rx_state : rx_state_t := RX_IDLE;
    signal rx_clk_count : integer range 0 to CLK_PER_BIT - 1 := 0;
    signal rx_bit_index : integer range 0 to 7 := 0;
    signal rx_data_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_parity    : std_logic := '0';
    signal rx_rdy       : std_logic := '0';
    signal rx_ferr      : std_logic := '0';
    signal rx_perr      : std_logic := '0';
begin

    -- =================== Transmitter ===================
    tx_proc : process(clk, reset)
    begin
        if reset = '1' then
            tx_state     <= TX_IDLE;
            serial_out   <= '1';
            tx_rdy       <= '1';
            tx_clk_count <= 0;
            tx_bit_index <= 0;
            tx_data_reg  <= (others => '0');
            tx_parity    <= '0';
        elsif rising_edge(clk) then
            case tx_state is
                when TX_IDLE =>
                    serial_out <= '1';
                    tx_rdy     <= '1';
                    if tx_load = '1' then
                        tx_data_reg <= data_in;
                        -- Compute even parity (XOR of all data bits)
                        tx_parity   <= data_in(0) xor data_in(1) xor data_in(2) xor
                                       data_in(3) xor data_in(4) xor data_in(5) xor
                                       data_in(6) xor data_in(7);
                        tx_rdy      <= '0';
                        tx_state    <= TX_START;
                        tx_clk_count<= 0;
                    end if;

                when TX_START =>
                    serial_out <= '0';  -- start bit
                    if tx_clk_count = CLK_PER_BIT - 1 then
                        tx_clk_count <= 0;
                        tx_bit_index <= 0;
                        tx_state     <= TX_DATA;
                    else
                        tx_clk_count <= tx_clk_count + 1;
                    end if;

                when TX_DATA =>
                    serial_out <= tx_data_reg(tx_bit_index);
                    if tx_clk_count = CLK_PER_BIT - 1 then
                        tx_clk_count <= 0;
                        if tx_bit_index = 7 then
                            tx_state <= ST_TX_PARITY;
                        else
                            tx_bit_index <= tx_bit_index + 1;
                        end if;
                    else
                        tx_clk_count <= tx_clk_count + 1;
                    end if;

                when ST_TX_PARITY =>
                    serial_out <= tx_parity;
                    if tx_clk_count = CLK_PER_BIT - 1 then
                        tx_clk_count <= 0;
                        tx_state     <= TX_STOP;
                    else
                        tx_clk_count <= tx_clk_count + 1;
                    end if;

                when TX_STOP =>
                    serial_out <= '1';  -- stop bit
                    if tx_clk_count = CLK_PER_BIT - 1 then
                        tx_clk_count <= 0;
                        tx_rdy       <= '1';
                        tx_state     <= TX_IDLE;
                    else
                        tx_clk_count <= tx_clk_count + 1;
                    end if;
            end case;
        end if;
    end process tx_proc;

    tx_ready <= tx_rdy;

    -- =================== Receiver ===================
    rx_proc : process(clk, reset)
    begin
        if reset = '1' then
            rx_state     <= RX_IDLE;
            rx_rdy       <= '0';
            rx_ferr      <= '0';
            rx_perr      <= '0';
            rx_clk_count <= 0;
            rx_bit_index <= 0;
            rx_data_reg  <= (others => '0');
            rx_parity    <= '0';
            data_out     <= (others => '0');
        elsif rising_edge(clk) then
            if rx_read = '1' then
                rx_rdy <= '0';  -- CPU read the byte, clear ready
            end if;

            case rx_state is
                when RX_IDLE =>
                    if serial_in = '0' then  -- start bit
                        rx_state     <= RX_START;
                        rx_clk_count <= 0;
                    end if;

                when RX_START =>
                    -- Verify start bit at the middle
                    if rx_clk_count = (CLK_PER_BIT / 2) - 1 then
                        if serial_in = '0' then
                            rx_clk_count <= 0;
                            rx_bit_index <= 0;
                            rx_parity    <= '0';
                            rx_state     <= RX_DATA;
                        else
                            rx_state <= RX_IDLE;  -- false start
                        end if;
                    else
                        rx_clk_count <= rx_clk_count + 1;
                    end if;

                when RX_DATA =>
                    if rx_clk_count = CLK_PER_BIT - 1 then
                        rx_clk_count <= 0;
                        rx_data_reg(rx_bit_index) <= serial_in;
                        rx_parity <= rx_parity xor serial_in;
                        if rx_bit_index = 7 then
                            rx_state <= ST_RX_PARITY;
                        else
                            rx_bit_index <= rx_bit_index + 1;
                        end if;
                    else
                        rx_clk_count <= rx_clk_count + 1;
                    end if;

                when ST_RX_PARITY =>
                    if rx_clk_count = CLK_PER_BIT - 1 then
                        rx_clk_count <= 0;
                        -- Even parity: XOR of all bits + parity bit = 0
                        if (rx_parity xor serial_in) = '0' then
                            rx_perr <= '0';
                        else
                            rx_perr <= '1';
                        end if;
                        rx_state <= RX_STOP;
                    else
                        rx_clk_count <= rx_clk_count + 1;
                    end if;

                when RX_STOP =>
                    if rx_clk_count = CLK_PER_BIT - 1 then
                        rx_clk_count <= 0;
                        if serial_in = '1' then
                            rx_ferr <= '0';  -- valid stop bit
                        else
                            rx_ferr <= '1';  -- framing error
                        end if;
                        data_out <= rx_data_reg;
                        rx_rdy   <= '1';
                        rx_state <= RX_IDLE;
                    else
                        rx_clk_count <= rx_clk_count + 1;
                    end if;
            end case;
        end if;
    end process rx_proc;

    rx_ready      <= rx_rdy;
    framing_error <= rx_ferr;
    parity_error  <= rx_perr;

end architecture rtl;

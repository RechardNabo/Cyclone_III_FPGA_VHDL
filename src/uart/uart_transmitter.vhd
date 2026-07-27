-- ============================================================================
-- UART Transmitter (TX)
-- ============================================================================
-- Sends one byte at a time over a serial line using the standard UART frame:
--   [Start bit (0)] [8 data bits, LSB first] [Stop bit (1)]
-- The baud rate is derived from the system clock using a simple counter.
-- Beginner-friendly, synthesizable VHDL for the Cyclone III FPGA.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_transmitter is
    generic (
        BAUD_RATE : integer := 9600;   -- Target baud rate (bits per second)
        CLK_FREQ  : integer := 50000000 -- System clock frequency in Hz
    );
    port (
        clk     : in  std_logic;        -- System clock
        reset   : in  std_logic;        -- Asynchronous reset (active high)
        tx_data : in  std_logic_vector(7 downto 0); -- Byte to send
        tx_start: in  std_logic;        -- Pulse high to begin transmission
        tx_serial: out std_logic;       -- Serial output line
        tx_busy : out std_logic;        -- '1' while transmitting
        tx_done : out std_logic         -- Pulse high for one clock when done
    );
end entity uart_transmitter;

architecture rtl of uart_transmitter is
    -- Number of clock cycles per bit (e.g. 50 MHz / 9600 = 5208)
    constant CLK_PER_BIT : integer := CLK_FREQ / BAUD_RATE;

    -- Simple state machine: IDLE -> START -> DATA -> STOP -> IDLE
    type state_t is (IDLE, START, DATA, STOP);
    signal state : state_t := IDLE;

    signal clk_count : integer range 0 to CLK_PER_BIT - 1 := 0;
    signal bit_index : integer range 0 to 7 := 0;          -- which data bit (0..7)
    signal data_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal done_flag : std_logic := '0';
begin

    tx_proc : process(clk, reset)
    begin
        if reset = '1' then
            state      <= IDLE;
            tx_serial  <= '1';   -- Idle line is high
            tx_busy    <= '0';
            done_flag  <= '0';
            clk_count  <= 0;
            bit_index  <= 0;
            data_reg   <= (others => '0');
        elsif rising_edge(clk) then
            done_flag <= '0';    -- default: clear done pulse

            case state is
                -- IDLE: wait for tx_start, then latch data and begin
                when IDLE =>
                    tx_serial <= '1';  -- keep line high when idle
                    tx_busy   <= '0';
                    clk_count <= 0;
                    bit_index <= 0;
                    if tx_start = '1' then
                        data_reg <= tx_data;  -- grab the byte
                        state    <= START;
                        tx_busy  <= '1';
                    end if;

                -- START: drive the line low for one bit period
                when START =>
                    tx_serial <= '0';  -- start bit is always 0
                    if clk_count = CLK_PER_BIT - 1 then
                        clk_count <= 0;
                        state     <= DATA;
                    else
                        clk_count <= clk_count + 1;
                    end if;

                -- DATA: send 8 bits, least-significant bit first
                when DATA =>
                    tx_serial <= data_reg(bit_index);  -- output current bit
                    if clk_count = CLK_PER_BIT - 1 then
                        clk_count <= 0;
                        if bit_index = 7 then
                            state <= STOP;             -- all 8 bits sent
                        else
                            bit_index <= bit_index + 1; -- next bit
                        end if;
                    else
                        clk_count <= clk_count + 1;
                    end if;

                -- STOP: drive line high for one bit period, then finish
                when STOP =>
                    tx_serial <= '1';  -- stop bit is always 1
                    if clk_count = CLK_PER_BIT - 1 then
                        clk_count <= 0;
                        done_flag <= '1';  -- signal completion
                        tx_busy   <= '0';
                        state     <= IDLE;
                    else
                        clk_count <= clk_count + 1;
                    end if;
            end case;
        end if;
    end process tx_proc;

    tx_done <= done_flag;

end architecture rtl;

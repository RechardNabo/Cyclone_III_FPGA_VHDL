-- ============================================================================
-- UART Receiver (RX)
-- ============================================================================
-- Receives one byte at a time from a serial line using the standard UART frame:
--   [Start bit (0)] [8 data bits, LSB first] [Stop bit (1)]
-- Uses 16x oversampling: the line is sampled 16 times per bit so that the
-- sample point sits in the middle of each bit, giving noise immunity.
-- Beginner-friendly, synthesizable VHDL for the Cyclone III FPGA.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_receiver is
    generic (
        BAUD_RATE : integer := 9600;    -- Target baud rate (bits per second)
        CLK_FREQ  : integer := 50000000 -- System clock frequency in Hz
    );
    port (
        clk       : in  std_logic;      -- System clock
        reset     : in  std_logic;      -- Asynchronous reset (active high)
        rx_serial : in  std_logic;      -- Serial input line
        rx_data   : out std_logic_vector(7 downto 0); -- Received byte
        rx_valid  : out std_logic;      -- Pulse high for one clock when byte ready
        rx_busy   : out std_logic       -- '1' while receiving
    );
end entity uart_receiver;

architecture rtl of uart_receiver is
    -- Clock cycles per bit, divided by 16 for oversampling
    constant CLK_PER_BIT : integer := CLK_FREQ / BAUD_RATE;
    constant OVERSAMPLE  : integer := 16;
    constant SAMPLES_PER_BIT : integer := CLK_PER_BIT / OVERSAMPLE;

    -- State machine: IDLE -> START -> DATA -> STOP -> IDLE
    type state_t is (IDLE, START, DATA, STOP);
    signal state : state_t := IDLE;

    signal sample_count : integer range 0 to SAMPLES_PER_BIT - 1 := 0;
    signal oversample_count : integer range 0 to OVERSAMPLE - 1 := 0;
    signal bit_index : integer range 0 to 7 := 0;
    signal data_reg  : std_logic_vector(7 downto 0) := (others => '0');
begin

    rx_proc : process(clk, reset)
    begin
        if reset = '1' then
            state            <= IDLE;
            rx_valid         <= '0';
            rx_busy          <= '0';
            rx_data          <= (others => '0');
            sample_count     <= 0;
            oversample_count <= 0;
            bit_index        <= 0;
            data_reg         <= (others => '0');
        elsif rising_edge(clk) then
            rx_valid <= '0';  -- default: no valid pulse

            case state is
                -- IDLE: wait for the line to go low (start bit falling edge)
                when IDLE =>
                    rx_busy <= '0';
                    if rx_serial = '0' then  -- start bit detected
                        state            <= START;
                        sample_count     <= 0;
                        oversample_count <= 0;
                        rx_busy          <= '1';
                    end if;

                -- START: verify the start bit at the middle of the bit period
                when START =>
                    if sample_count = SAMPLES_PER_BIT - 1 then
                        sample_count <= 0;
                        if oversample_count = OVERSAMPLE / 2 - 1 then
                            -- Check the middle of the start bit
                            if rx_serial = '0' then
                                oversample_count <= 0;
                                bit_index        <= 0;
                                state            <= DATA;
                            else
                                -- False start, go back to idle
                                state    <= IDLE;
                                rx_busy  <= '0';
                            end if;
                        else
                            oversample_count <= oversample_count + 1;
                        end if;
                    else
                        sample_count <= sample_count + 1;
                    end if;

                -- DATA: sample each bit in the middle, LSB first
                when DATA =>
                    if sample_count = SAMPLES_PER_BIT - 1 then
                        sample_count <= 0;
                        if oversample_count = OVERSAMPLE / 2 - 1 then
                            -- Sample in the middle of the bit
                            data_reg(bit_index) <= rx_serial;
                            if bit_index = 7 then
                                state <= STOP;
                            else
                                bit_index <= bit_index + 1;
                            end if;
                            oversample_count <= 0;
                        else
                            oversample_count <= oversample_count + 1;
                        end if;
                    else
                        sample_count <= sample_count + 1;
                    end if;

                -- STOP: verify stop bit is high, then output the byte
                when STOP =>
                    if sample_count = SAMPLES_PER_BIT - 1 then
                        sample_count <= 0;
                        if oversample_count = OVERSAMPLE / 2 - 1 then
                            rx_data  <= data_reg;
                            rx_valid <= '1';
                            rx_busy  <= '0';
                            state    <= IDLE;
                        else
                            oversample_count <= oversample_count + 1;
                        end if;
                    else
                        sample_count <= sample_count + 1;
                    end if;
            end case;
        end if;
    end process rx_proc;

end architecture rtl;

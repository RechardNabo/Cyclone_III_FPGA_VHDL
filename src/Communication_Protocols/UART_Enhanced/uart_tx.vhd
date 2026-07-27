-- ============================================================================
-- Enhanced UART Transmitter with FIFO Buffer
-- ============================================================================
-- Adds a 16-deep FIFO so the CPU can queue multiple bytes without waiting.
-- Supports optional parity (even) and configurable baud rate.
-- Frame: [Start (0)] [8 data bits, LSB first] [Parity (if enabled)] [Stop (1)]
-- Beginner-friendly, synthesizable VHDL for the Cyclone III FPGA.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_tx is
    generic (
        BAUD_RATE    : integer := 9600;
        CLK_FREQ     : integer := 50000000;
        PARITY_ENABLE: boolean  := false;  -- set true to add a parity bit
        FIFO_DEPTH   : integer  := 16      -- number of bytes the FIFO holds
    );
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;
        -- CPU write interface
        tx_data    : in  std_logic_vector(7 downto 0);
        tx_wr      : in  std_logic;        -- pulse high to push byte into FIFO
        -- Serial output
        tx_serial  : out std_logic;
        -- Status
        tx_ready   : out std_logic;        -- '1' when FIFO not full
        tx_empty   : out std_logic;        -- '1' when FIFO is empty
        tx_busy    : out std_logic         -- '1' while sending a frame
    );
end entity uart_tx;

architecture rtl of uart_tx is
    constant CLK_PER_BIT : integer := CLK_FREQ / BAUD_RATE;

    -- ---- Simple FIFO (depth = FIFO_DEPTH, width = 8) ----
    type fifo_array is array (0 to FIFO_DEPTH - 1) of std_logic_vector(7 downto 0);
    signal fifo_mem  : fifo_array := (others => (others => '0'));
    signal wr_ptr    : integer range 0 to FIFO_DEPTH - 1 := 0;
    signal rd_ptr    : integer range 0 to FIFO_DEPTH - 1 := 0;
    signal fifo_cnt  : integer range 0 to FIFO_DEPTH := 0;
    signal fifo_empty: std_logic := '1';
    signal fifo_full : std_logic := '0';
    signal fifo_data : std_logic_vector(7 downto 0) := (others => '0');

    -- ---- TX state machine ----
    type state_t is (IDLE, START, DATA, PARITY, STOP);
    signal state      : state_t := IDLE;
    signal clk_count  : integer range 0 to CLK_PER_BIT - 1 := 0;
    signal bit_index  : integer range 0 to 7 := 0;
    signal data_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal parity_bit : std_logic := '0';
    signal busy_flag  : std_logic := '0';
begin

    -- =================== FIFO management ===================
    fifo_proc : process(clk, reset)
    begin
        if reset = '1' then
            wr_ptr     <= 0;
            rd_ptr     <= 0;
            fifo_cnt   <= 0;
            fifo_empty <= '1';
            fifo_full  <= '0';
        elsif rising_edge(clk) then
            -- Write into FIFO
            if tx_wr = '1' and fifo_full = '0' and busy_flag = '0' then
                fifo_mem(wr_ptr) <= tx_data;
                if wr_ptr = FIFO_DEPTH - 1 then
                    wr_ptr <= 0;
                else
                    wr_ptr <= wr_ptr + 1;
                end if;
                fifo_cnt <= fifo_cnt + 1;
            end if;

            -- Read from FIFO (when TX state machine consumes a byte)
            if state = IDLE and fifo_empty = '0' and busy_flag = '0' then
                fifo_data <= fifo_mem(rd_ptr);
                if rd_ptr = FIFO_DEPTH - 1 then
                    rd_ptr <= 0;
                else
                    rd_ptr <= rd_ptr + 1;
                end if;
                fifo_cnt <= fifo_cnt - 1;
            end if;

            -- Update flags
            if fifo_cnt = 0 then
                fifo_empty <= '1';
            else
                fifo_empty <= '0';
            end if;
            if fifo_cnt >= FIFO_DEPTH then
                fifo_full <= '1';
            else
                fifo_full <= '0';
            end if;
        end if;
    end process fifo_proc;

    tx_ready <= not fifo_full;
    tx_empty <= fifo_empty;

    -- =================== TX state machine ===================
    tx_proc : process(clk, reset)
    begin
        if reset = '1' then
            state      <= IDLE;
            serial_out <= '1';
            busy_flag  <= '0';
            clk_count  <= 0;
            bit_index  <= 0;
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    serial_out <= '1';
                    busy_flag  <= '0';
                    if fifo_empty = '0' then
                        data_reg   <= fifo_data;
                        -- Compute even parity
                        parity_bit <= fifo_data(0) xor fifo_data(1) xor
                                      fifo_data(2) xor fifo_data(3) xor
                                      fifo_data(4) xor fifo_data(5) xor
                                      fifo_data(6) xor fifo_data(7);
                        busy_flag  <= '1';
                        state      <= START;
                        clk_count  <= 0;
                    end if;

                when START =>
                    serial_out <= '0';
                    if clk_count = CLK_PER_BIT - 1 then
                        clk_count <= 0;
                        bit_index <= 0;
                        state     <= DATA;
                    else
                        clk_count <= clk_count + 1;
                    end if;

                when DATA =>
                    serial_out <= data_reg(bit_index);
                    if clk_count = CLK_PER_BIT - 1 then
                        clk_count <= 0;
                        if bit_index = 7 then
                            if PARITY_ENABLE then
                                state <= PARITY;
                            else
                                state <= STOP;
                            end if;
                        else
                            bit_index <= bit_index + 1;
                        end if;
                    else
                        clk_count <= clk_count + 1;
                    end if;

                when PARITY =>
                    serial_out <= parity_bit;
                    if clk_count = CLK_PER_BIT - 1 then
                        clk_count <= 0;
                        state     <= STOP;
                    else
                        clk_count <= clk_count + 1;
                    end if;

                when STOP =>
                    serial_out <= '1';
                    if clk_count = CLK_PER_BIT - 1 then
                        clk_count <= 0;
                        busy_flag <= '0';
                        state     <= IDLE;
                    else
                        clk_count <= clk_count + 1;
                    end if;
            end case;
        end if;
    end process tx_proc;

    tx_serial <= serial_out;
    tx_busy   <= busy_flag;

end architecture rtl;

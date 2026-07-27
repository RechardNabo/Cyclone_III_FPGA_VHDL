-- ============================================================================
-- Enhanced UART Receiver with FIFO Buffer
-- ============================================================================
-- Receives UART frames and stores bytes in a 16-deep FIFO.
-- Supports optional parity checking (even) and break detection
-- (line held low longer than a full frame).
-- Frame: [Start (0)] [8 data bits, LSB first] [Parity (if enabled)] [Stop (1)]
-- Beginner-friendly, synthesizable VHDL for the Cyclone III FPGA.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_rx is
    generic (
        BAUD_RATE    : integer := 9600;
        CLK_FREQ     : integer := 50000000;
        PARITY_ENABLE: boolean  := false;
        FIFO_DEPTH   : integer  := 16
    );
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;
        -- Serial input
        rx_serial  : in  std_logic;
        -- CPU read interface
        rx_data    : out std_logic_vector(7 downto 0);
        rx_rd      : in  std_logic;       -- pulse high to pop a byte from FIFO
        -- Status
        rx_ready   : out std_logic;       -- '1' when a byte is available
        rx_full    : out std_logic;       -- '1' when FIFO is full
        parity_err : out std_logic;       -- pulse high on parity mismatch
        break_detect: out std_logic       -- '1' when a break is detected
    );
end entity uart_rx;

architecture rtl of uart_rx is
    constant CLK_PER_BIT : integer := CLK_FREQ / BAUD_RATE;

    -- ---- FIFO ----
    type fifo_array is array (0 to FIFO_DEPTH - 1) of std_logic_vector(7 downto 0);
    signal fifo_mem  : fifo_array := (others => (others => '0'));
    signal wr_ptr    : integer range 0 to FIFO_DEPTH - 1 := 0;
    signal rd_ptr    : integer range 0 to FIFO_DEPTH - 1 := 0;
    signal fifo_cnt  : integer range 0 to FIFO_DEPTH := 0;

    -- ---- RX state machine ----
    type state_t is (IDLE, START, DATA, PARITY, STOP);
    signal state      : state_t := IDLE;
    signal clk_count  : integer range 0 to CLK_PER_BIT - 1 := 0;
    signal bit_index  : integer range 0 to 7 := 0;
    signal data_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal parity_calc: std_logic := '0';
    signal parity_rx  : std_logic := '0';
    signal low_count  : integer range 0 to CLK_PER_BIT * 12 := 0; -- for break detect
begin

    -- =================== RX state machine ===================
    rx_proc : process(clk, reset)
    begin
        if reset = '1' then
            state       <= IDLE;
            clk_count   <= 0;
            bit_index   <= 0;
            data_reg    <= (others => '0');
            parity_calc <= '0';
            parity_rx   <= '0';
            low_count   <= 0;
            parity_err  <= '0';
            break_detect<= '0';
        elsif rising_edge(clk) then
            parity_err   <= '0';
            break_detect <= '0';

            -- Break detection: line low for more than ~10 bit periods
            if rx_serial = '0' then
                if low_count < CLK_PER_BIT * 12 then
                    low_count <= low_count + 1;
                end if;
                if low_count = CLK_PER_BIT * 10 then
                    break_detect <= '1';
                end if;
            else
                low_count <= 0;
            end if;

            case state is
                when IDLE =>
                    if rx_serial = '0' then  -- falling edge = start bit
                        state     <= START;
                        clk_count <= 0;
                    end if;

                when START =>
                    -- Check middle of start bit
                    if clk_count = (CLK_PER_BIT / 2) - 1 then
                        if rx_serial = '0' then
                            clk_count   <= 0;
                            bit_index   <= 0;
                            parity_calc <= '0';
                            state       <= DATA;
                        else
                            state <= IDLE;  -- false start
                        end if;
                    else
                        clk_count <= clk_count + 1;
                    end if;

                when DATA =>
                    if clk_count = CLK_PER_BIT - 1 then
                        clk_count <= 0;
                        data_reg(bit_index) <= rx_serial;
                        parity_calc <= parity_calc xor rx_serial;
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
                    if clk_count = CLK_PER_BIT - 1 then
                        clk_count <= 0;
                        parity_rx <= rx_serial;
                        -- Even parity: calc XOR received parity should be 0
                        if (parity_calc xor rx_serial) /= '0' then
                            parity_err <= '1';
                        end if;
                        state <= STOP;
                    else
                        clk_count <= clk_count + 1;
                    end if;

                when STOP =>
                    if clk_count = CLK_PER_BIT - 1 then
                        clk_count <= 0;
                        -- Push byte into FIFO if not full
                        if fifo_cnt < FIFO_DEPTH then
                            fifo_mem(wr_ptr) <= data_reg;
                            if wr_ptr = FIFO_DEPTH - 1 then
                                wr_ptr <= 0;
                            else
                                wr_ptr <= wr_ptr + 1;
                            end if;
                            fifo_cnt <= fifo_cnt + 1;
                        end if;
                        state <= IDLE;
                    else
                        clk_count <= clk_count + 1;
                    end if;
            end case;
        end if;
    end process rx_proc;

    -- =================== FIFO read side ===================
    fifo_rd_proc : process(clk, reset)
    begin
        if reset = '1' then
            rd_ptr   <= 0;
            rx_data  <= (others => '0');
        elsif rising_edge(clk) then
            if rx_rd = '1' and fifo_cnt > 0 then
                rx_data <= fifo_mem(rd_ptr);
                if rd_ptr = FIFO_DEPTH - 1 then
                    rd_ptr <= 0;
                else
                    rd_ptr <= rd_ptr + 1;
                end if;
                fifo_cnt <= fifo_cnt - 1;
            end if;
        end if;
    end process fifo_rd_proc;

    rx_ready <= '1' when fifo_cnt > 0 else '0';
    rx_full  <= '1' when fifo_cnt = FIFO_DEPTH else '0';

end architecture rtl;

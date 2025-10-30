-- ============================================================================
-- Project: FPGA-Optimized SPI Master Controller
--
-- Description:
-- This VHDL module implements a Serial Peripheral Interface (SPI) master controller,
-- optimized for FPGA synthesis. SPI is a synchronous serial data protocol widely
-- used for short-distance communication, primarily in embedded systems, to interface
-- with various peripherals such as ADCs, DACs, EEPROMs, sensors, and other microcontrollers.
-- This master controller is designed to initiate and control data transfers,
-- supporting configurable clock polarity (CPOL) and clock phase (CPHA) modes.
--
-- Learning Objectives:
-- 1. Understand the SPI protocol fundamentals, including master/slave roles, clock,
--    data lines (MOSI, MISO), and slave select (SS).
-- 2. Learn how to implement an SPI master controller in VHDL.
-- 3. Understand the impact of CPOL and CPHA on SPI communication and how to configure them.
-- 4. Develop a state machine to manage SPI transaction phases (idle, start, data transfer, end).
-- 5. Gain experience in designing a flexible and efficient serial communication interface for FPGAs.
-- 6. Learn how to handle data transmission and reception synchronously.
--
-- Implementation Guidance:
-- 1. **SPI Protocol**: Review the SPI protocol specification, paying close attention
--    to the four modes defined by CPOL and CPHA. The master generates the clock (SCK)
--    and controls the slave select (SS) line.
-- 2. **State Machine**: A finite state machine (FSM) is crucial for managing the SPI
--    transaction. States typically include: IDLE, START_TRANSFER, SHIFT_DATA, END_TRANSFER.
-- 3. **Clock Generation**: The master must generate the serial clock (SCK). This can be
--    derived from the system clock using a clock divider to achieve the desired SPI baud rate.
-- 4. **Data Shifting**: Implement shift registers for both MOSI (Master Out Slave In)
--    and MISO (Master In Slave Out) data. Data is typically shifted out on one clock edge
--    and sampled on the opposite edge, depending on CPHA.
-- 5. **Slave Select (SS)**: The master controls the SS line (active low) to select
--    the target slave device. It should be asserted low at the beginning of a transaction
--    and de-asserted high at the end.
-- 6. **Configurable Modes**: Use generics to allow configuration of CPOL and CPHA,
--    making the SPI master adaptable to different slave devices.
-- 7. **Transaction Control**: Provide input signals to initiate a transfer (e.g., `start_transfer_i`),
--    input data (`tx_data_i`), and output signals for received data (`rx_data_o`) and
--    transfer completion (`transfer_done_o`).
-- 8. **Testbench Development**: Create a comprehensive testbench that simulates communication
--    with a dummy SPI slave, verifying data integrity and correct protocol adherence for
--    all supported CPOL/CPHA modes.
--
-- ----------------------------------------------------------------------------
-- Architecture:
-- An SPI master controller typically consists of:
-- - Clock Divider: To generate the SCK signal.
-- - State Machine: To control the transaction flow.
-- - Shift Registers: For MOSI and MISO data handling.
-- - Control Logic: For SS, CPOL, CPHA, and transaction initiation/completion.
--
-- This VHDL template provides a basic structure for an SPI master controller.
-- The FSM logic and data shifting will need to be detailed based on the desired
-- SPI mode and specific application requirements.
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is
    generic (
        DATA_WIDTH      : natural := 8;    -- Number of bits per SPI transfer
        CPOL            : std_logic := '0'; -- Clock Polarity (0: SCK low when idle, 1: SCK high when idle)
        CPHA            : std_logic := '0'; -- Clock Phase (0: sample on leading edge, 1: sample on trailing edge)
        CLK_DIV_FACTOR  : natural := 10    -- Clock division factor for SCK (e.g., system_clk / CLK_DIV_FACTOR)
    );
    port (
        -- Global Signals
        clk_i           : in  std_logic;
        rst_i           : in  std_logic;

        -- Master Control
        start_transfer_i : in  std_logic; -- Start a new SPI transfer
        tx_data_i       : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- Data to transmit
        transfer_done_o : out std_logic; -- Indicates transfer is complete
        rx_data_o       : out std_logic_vector(DATA_WIDTH-1 downto 0); -- Received data

        -- SPI Interface Signals
        sck_o           : out std_logic; -- Serial Clock
        mosi_o          : out std_logic; -- Master Out Slave In
        miso_i          : in  std_logic; -- Master In Slave Out
        ss_o            : out std_logic  -- Slave Select (active low)
    );
end entity spi_master;

architecture rtl of spi_master is

    -- State machine for SPI transfer
    type spi_state_type is (IDLE, START_TRANSFER, SHIFT_DATA, END_TRANSFER);
    signal current_state : spi_state_type;
    signal next_state    : spi_state_type;

    -- Internal signals for clock generation
    signal clk_div_cnt   : natural range 0 to CLK_DIV_FACTOR-1;
    signal sck_int       : std_logic;

    -- Internal signals for data shifting
    signal tx_shift_reg  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal rx_shift_reg  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal bit_cnt       : natural range 0 to DATA_WIDTH;

begin

    -- SCK Generation
    process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            clk_div_cnt <= 0;
            sck_int <= CPOL;
        elsif rising_edge(clk_i) then
            if clk_div_cnt = CLK_DIV_FACTOR/2 - 1 then
                sck_int <= not sck_int;
                clk_div_cnt <= 0;
            else
                clk_div_cnt <= clk_div_cnt + 1;
            end if;
        end if;
    end process;
    sck_o <= sck_int;

    -- SPI State Machine
    process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            current_state <= IDLE;
        elsif rising_edge(clk_i) then
            current_state <= next_state;
        end if;
    end process;

    process (current_state, start_transfer_i, bit_cnt, tx_data_i, tx_shift_reg, miso_i, sck_int, CPOL, CPHA)
    begin
        next_state <= current_state;
        transfer_done_o <= '0';
        ss_o <= '1'; -- Default to inactive
        mosi_o <= '0'; -- Default MOSI to low
        rx_data_o <= (others => '0');

        case current_state is
            when IDLE =>
                ss_o <= '1';
                if start_transfer_i = '1' then
                    next_state <= START_TRANSFER;
                    tx_shift_reg <= tx_data_i;
                    bit_cnt <= 0;
                end if;

            when START_TRANSFER =>
                ss_o <= '0'; -- Assert SS
                if CPHA = '0' then -- Sample on leading edge
                    if sck_int = CPOL then -- Leading edge
                        mosi_o <= tx_shift_reg(DATA_WIDTH-1);
                        next_state <= SHIFT_DATA;
                    end if;
                else -- Sample on trailing edge
                    if sck_int /= CPOL then -- Trailing edge
                        mosi_o <= tx_shift_reg(DATA_WIDTH-1);
                        next_state <= SHIFT_DATA;
                    end if;
                end if;

            when SHIFT_DATA =>
                ss_o <= '0';
                if CPHA = '0' then -- Sample on leading edge
                    if sck_int = CPOL then -- Leading edge
                        tx_shift_reg <= tx_shift_reg(DATA_WIDTH-2 downto 0) & '0'; -- Shift out MSB
                        rx_shift_reg <= rx_shift_reg(DATA_WIDTH-2 downto 0) & miso_i; -- Shift in MISO
                        bit_cnt <= bit_cnt + 1;
                        if bit_cnt = DATA_WIDTH-1 then
                            next_state <= END_TRANSFER;
                        end if;
                    end if;
                else -- Sample on trailing edge
                    if sck_int /= CPOL then -- Trailing edge
                        tx_shift_reg <= tx_shift_reg(DATA_WIDTH-2 downto 0) & '0'; -- Shift out MSB
                        rx_shift_reg <= rx_shift_reg(DATA_WIDTH-2 downto 0) & miso_i; -- Shift in MISO
                        bit_cnt <= bit_cnt + 1;
                        if bit_cnt = DATA_WIDTH-1 then
                            next_state <= END_TRANSFER;
                        end if;
                    end if;
                end if;
                mosi_o <= tx_shift_reg(DATA_WIDTH-1);

            when END_TRANSFER =>
                ss_o <= '1'; -- De-assert SS
                transfer_done_o <= '1';
                rx_data_o <= rx_shift_reg;
                next_state <= IDLE;

        end case;
    end process;

end architecture rtl;
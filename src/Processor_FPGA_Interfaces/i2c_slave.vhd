-- ============================================================================
-- Project: FPGA-Optimized I2C Slave Controller
--
-- Description:
-- This VHDL module implements an Inter-Integrated Circuit (I2C) slave controller,
-- optimized for FPGA synthesis. I2C is a popular two-wire serial bus used for
-- connecting low-speed peripherals to microcontrollers and FPGAs. This slave
-- controller is designed to respond to a master device, allowing it to read from
-- and write to internal registers or memory within the FPGA. It supports standard
-- and fast-mode I2C communication.
--
-- Learning Objectives:
-- 1. Understand the I2C protocol fundamentals, including start/stop conditions,
--    addressing, data transfer, and acknowledge (ACK)/not-acknowledge (NACK).
-- 2. Learn how to implement an I2C slave controller in VHDL.
-- 3. Develop a state machine to manage the I2C transaction phases (idle, address match,
--    data read, data write, stop).
-- 4. Gain experience in designing a robust and efficient two-wire serial communication
--    interface for FPGAs.
-- 5. Learn how to handle clock stretching and arbitration (though arbitration is primarily
--    a master concern, slave should be aware of clock stretching).
--
-- Implementation Guidance:
-- 1. **I2C Protocol**: Review the I2C bus specification, paying close attention to
--    the timing requirements for start/stop conditions, data setup/hold times, and
--    the acknowledge mechanism.
-- 2. **State Machine**: A finite state machine (FSM) is essential for managing the I2C
--    transaction. States typically include: IDLE, START_DETECTED, ADDRESS_MATCH,
--    DATA_RECEIVE, DATA_TRANSMIT, STOP_DETECTED.
-- 3. **SCL and SDA Handling**: The I2C bus uses two lines: SCL (Serial Clock) and SDA
--    (Serial Data). Both are open-drain, requiring external pull-up resistors. The slave
--    must correctly sample SDA on the rising edge of SCL and drive SDA on the falling edge.
-- 4. **Address Recognition**: Implement logic to recognize the slave's unique 7-bit
--    or 10-bit address. The R/W bit in the address byte determines if the master wants
--    to read from or write to the slave.
-- 5. **Data Transfer**: Implement shift registers for both transmitting and receiving data.
--    The slave must generate an ACK after receiving each byte (including the address byte)
--    if it successfully processed the data.
-- 6. **Clock Stretching**: The slave can hold SCL low to slow down the master if it needs
--    more time to process data. This is an advanced feature and might not be necessary
--    for a basic implementation.
-- 7. **Internal Registers/Memory**: The slave will typically interface with internal
--    registers or a small memory block. The I2C master will read from or write to these
--    locations.
-- 8. **Testbench Development**: Create a comprehensive testbench that simulates I2C master
--    transactions (addressing, single byte read/write, multi-byte read/write) to verify
--    the slave's correct behavior and compliance with the protocol.
--
-- ----------------------------------------------------------------------------
-- Architecture:
-- An I2C slave controller typically consists of:
-- - SCL/SDA Synchronization and Edge Detection: To correctly sample and drive the bus.
-- - State Machine: To control the transaction flow.
-- - Address Comparator: To recognize the slave's address.
-- - Shift Registers: For data transmission and reception.
-- - Internal Register File/Memory: The data storage accessible via I2C.
-- - ACK/NACK Generation Logic.
--
-- This VHDL template provides a basic structure for an I2C slave controller.
-- The FSM logic, address decoding, and internal register access will need to be
-- detailed based on the specific application requirements.
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_slave is
    generic (
        SLAVE_ADDRESS   : std_logic_vector(6 downto 0) := "0101001" -- Example 7-bit slave address
    );
    port (
        -- Global Signals
        clk_i           : in  std_logic;
        rst_i           : in  std_logic;

        -- I2C Bus Signals (Open-drain, requires external pull-ups)
        scl_io          : inout std_logic; -- Serial Clock
        sda_io          : inout std_logic; -- Serial Data

        -- Internal Interface (to/from FPGA logic)
        read_data_o     : out std_logic_vector(7 downto 0); -- Data read by master
        write_data_i    : in  std_logic_vector(7 downto 0); -- Data written by master
        data_valid_o    : out std_logic; -- Indicates new data written by master
        data_request_i  : in  std_logic; -- Request to send data to master
        ack_error_o     : out std_logic  -- Indicates an error during ACK/NACK
    );
end entity i2c_slave;

architecture rtl of i2c_slave is

    -- Internal signals for I2C bus control
    signal scl_i_sync       : std_logic; -- Synchronized SCL input
    signal sda_i_sync       : std_logic; -- Synchronized SDA input
    signal sda_o_reg        : std_logic; -- SDA output register
    signal sda_oe           : std_logic; -- SDA output enable

    -- State machine for I2C transaction
    type i2c_state_type is (IDLE, START_DETECTED, ADDRESS_PHASE, DATA_PHASE_WRITE, DATA_PHASE_READ, ACK_PHASE, STOP_DETECTED);
    signal current_state    : i2c_state_type;
    signal next_state       : i2c_state_type;

    -- Internal registers for data handling
    signal shift_reg        : std_logic_vector(7 downto 0);
    signal bit_count        : natural range 0 to 8;
    signal rw_bit           : std_logic;
    signal address_match    : std_logic;

begin

    -- Bidirectional SDA control
    sda_io <= '0' when sda_oe = '1' else 'Z';

    -- Synchronize SCL and SDA inputs (simple synchronizer, more robust needed for real designs)
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            scl_i_sync <= scl_io;
            sda_i_sync <= sda_io;
        end if;
    end process;

    -- I2C State Machine
    process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            current_state <= IDLE;
            sda_oe <= '0';
            shift_reg <= (others => '0');
            bit_count <= 0;
            rw_bit <= '0';
            address_match <= '0';
            data_valid_o <= '0';
            read_data_o <= (others => '0');
            ack_error_o <= '0';
        elsif rising_edge(clk_i) then
            current_state <= next_state;

            -- State-dependent logic
            case current_state is
                when IDLE =>
                    sda_oe <= '0';
                    data_valid_o <= '0';
                    ack_error_o <= '0';
                    if scl_i_sync = '1' and sda_i_sync = '0' then -- Start condition
                        next_state <= START_DETECTED;
                    end if;

                when START_DETECTED =>
                    bit_count <= 0;
                    shift_reg <= (others => '0');
                    next_state <= ADDRESS_PHASE;

                when ADDRESS_PHASE =>
                    if scl_i_sync = '1' and scl_i_sync'event and scl_i_sync = '0' then -- Falling edge of SCL
                        shift_reg(7-bit_count) <= sda_i_sync;
                        bit_count <= bit_count + 1;
                        if bit_count = 6 then -- Last bit of address + R/W bit
                            rw_bit <= sda_i_sync;
                            if shift_reg(6 downto 0) = SLAVE_ADDRESS then
                                address_match <= '1';
                            else
                                address_match <= '0';
                            end if;
                            next_state <= ACK_PHASE;
                        end if;
                    end if;

                when ACK_PHASE =>
                    if scl_i_sync = '0' and scl_i_sync'event and scl_i_sync = '1' then -- Rising edge of SCL
                        if address_match = '1' then
                            sda_oe <= '1'; -- Drive SDA low for ACK
                            sda_o_reg <= '0';
                            ack_error_o <= '0';
                            if rw_bit = '0' then -- Master wants to write
                                next_state <= DATA_PHASE_WRITE;
                            else -- Master wants to read
                                next_state <= DATA_PHASE_READ;
                            end if;
                        else
                            sda_oe <= '1'; -- Drive SDA high for NACK (or let it float high)
                            sda_o_reg <= '1';
                            ack_error_o <= '1';
                            next_state <= IDLE; -- Go back to idle if no address match
                        end if;
                    end if;

                when DATA_PHASE_WRITE =>
                    sda_oe <= '0'; -- Release SDA
                    if scl_i_sync = '1' and scl_i_sync'event and scl_i_sync = '0' then -- Falling edge of SCL
                        shift_reg(7-bit_count) <= sda_i_sync;
                        bit_count <= bit_count + 1;
                        if bit_count = 7 then -- Last data bit
                            data_valid_o <= '1';
                            -- Store received data (e.g., to an internal register)
                            -- For this template, we just output it
                            read_data_o <= shift_reg;
                            next_state <= ACK_PHASE; -- Send ACK for data byte
                        end if;
                    end if;

                when DATA_PHASE_READ =>
                    sda_oe <= '1'; -- Drive SDA
                    if scl_i_sync = '1' and scl_i_sync'event and scl_i_sync = '0' then -- Falling edge of SCL
                        -- Drive SDA with data_request_i or internal data
                        sda_o_reg <= write_data_i(7-bit_count); -- Example: send data from write_data_i
                        bit_count <= bit_count + 1;
                        if bit_count = 7 then -- Last data bit
                            next_state <= ACK_PHASE; -- Wait for ACK from master
                        end if;
                    end if;

                when STOP_DETECTED =>
                    sda_oe <= '0';
                    next_state <= IDLE;

            end case;

            -- Detect Stop condition (SDA goes high while SCL is high)
            if scl_i_sync = '1' and sda_i_sync = '1' and sda_i_sync'event and sda_i_sync = '1' then
                next_state <= STOP_DETECTED;
            end if;

        end if;
    end process;

end architecture rtl;
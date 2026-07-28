-- ============================================================================
-- I2C Slave Controller
-- ============================================================================
-- Listens on the I2C bus for transactions addressed to this slave.
-- Supports 7-bit address matching, 8-bit register read/write.
-- When the master writes, data is stored in an internal register.
-- When the master reads, the stored data is sent back on SDA.
-- Beginner-friendly, synthesizable VHDL for the Cyclone III FPGA.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity i2c_slave is
    generic (
        SLAVE_ADDR : std_logic_vector(6 downto 0) := "1010000" -- 7-bit address
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        -- I2C bus
        sda       : inout std_logic;
        scl       : in  std_logic;
        -- Register interface
        reg_data  : in  std_logic_vector(7 downto 0); -- data to send on read
        reg_wr    : out std_logic;       -- pulse high when master wrote a byte
        reg_dout  : out std_logic_vector(7 downto 0) -- received data byte
    );
end entity i2c_slave;

architecture rtl of i2c_slave is
    type state_t is (IDLE, ADDR, ADDR_ACK, WR_DATA, WR_ACK, RD_DATA, RD_ACK);
    signal state : state_t := IDLE;

    signal sda_prev : std_logic := '1';
    signal scl_prev : std_logic := '1';
    signal bit_index: integer range 0 to 7 := 0;
    signal addr_reg : std_logic_vector(6 downto 0) := (others => '0');
    signal rw_bit   : std_logic := '0';
    signal data_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal sda_out  : std_logic := '1';
    signal wr_pulse : std_logic := '0';
begin

    -- Open-drain SDA: drive '0' or release ('Z' = pull-up to '1')
    sda <= '0' when sda_out = '0' else 'Z';

    i2c_slave_proc : process(clk, reset)
    begin
        if reset = '1' then
            state      <= IDLE;
            sda_out    <= '1';
            sda_prev   <= '1';
            scl_prev   <= '1';
            bit_index  <= 0;
            addr_reg   <= (others => '0');
            rw_bit     <= '0';
            data_reg   <= (others => '0');
            reg_dout   <= (others => '0');
            wr_pulse   <= '0';
        elsif rising_edge(clk) then
            wr_pulse <= '0';

            -- Detect START: SDA falls while SCL is high
            -- Detect STOP:  SDA rises while SCL is high
            if scl = '1' and scl_prev = '1' then
                if sda = '0' and sda_prev = '1' then
                    state     <= ADDR;   -- START detected
                    bit_index <= 7;
                    sda_out   <= '1';
                elsif sda = '1' and sda_prev = '0' then
                    state     <= IDLE;   -- STOP detected
                    sda_out   <= '1';
                end if;
            end if;
            sda_prev <= sda;
            scl_prev <= scl;

            case state is
                -- Receive 7-bit address + R/W bit
                when ADDR =>
                    if scl = '1' and scl_prev = '0' then
                        -- Sample SDA on rising edge of SCL
                        if bit_index > 0 then
                            addr_reg(bit_index - 1) <= sda;
                        else
                            rw_bit <= sda;
                        end if;
                        if bit_index = 0 then
                            -- Check if address matches
                            if addr_reg = SLAVE_ADDR then
                                state <= ADDR_ACK;
                            else
                                state <= IDLE;  -- not for us
                            end if;
                        else
                            bit_index <= bit_index - 1;
                        end if;
                    end if;

                -- Send ACK (pull SDA low for one SCL cycle)
                when ADDR_ACK =>
                    sda_out <= '0';  -- ACK
                    if scl = '1' and scl_prev = '0' then
                        sda_out   <= '1';  -- release after ACK
                        bit_index <= 7;
                        if rw_bit = '0' then
                            state <= WR_DATA;  -- master wants to write
                        else
                            state <= RD_DATA;  -- master wants to read
                        end if;
                    end if;

                -- Master writes: receive 8 data bits
                when WR_DATA =>
                    if scl = '1' and scl_prev = '0' then
                        data_reg(bit_index) <= sda;
                        if bit_index = 0 then
                            state <= WR_ACK;
                        else
                            bit_index <= bit_index - 1;
                        end if;
                    end if;

                -- Send ACK after receiving data
                when WR_ACK =>
                    sda_out <= '0';  -- ACK
                    if scl = '1' and scl_prev = '0' then
                        sda_out   <= '1';
                        reg_dout  <= data_reg;
                        wr_pulse  <= '1';
                        state     <= IDLE;  -- wait for STOP or next byte
                    end if;

                -- Master reads: send 8 data bits (MSB first)
                when RD_DATA =>
                    sda_out <= reg_data(bit_index);
                    if scl = '1' and scl_prev = '0' then
                        if bit_index = 0 then
                            state <= RD_ACK;
                        else
                            bit_index <= bit_index - 1;
                        end if;
                    end if;

                -- Wait for master ACK/NACK
                when RD_ACK =>
                    if scl = '1' and scl_prev = '0' then
                        if sda = '0' then
                            -- Master ACKed: send next byte (simplified: stop here)
                            state <= IDLE;
                        else
                            -- Master NACKed: end of read
                            state <= IDLE;
                        end if;
                    end if;

                when IDLE =>
                    sda_out <= '1';  -- release SDA when idle
            end case;
        end if;
    end process i2c_slave_proc;

    reg_wr <= wr_pulse;

end architecture rtl;

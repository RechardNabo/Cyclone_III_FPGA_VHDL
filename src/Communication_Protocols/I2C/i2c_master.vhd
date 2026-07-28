-- ============================================================================
-- I2C Master Controller
-- ============================================================================
-- I2C (Inter-Integrated Circuit) is a 2-wire serial bus: SDA (data) and
-- SCL (clock). The master controls the clock and initiates transactions.
-- This module performs a single read or write to a 7-bit addressed slave:
--   START -> [7-bit addr + R/W] -> ACK -> [8-bit data] -> ACK -> STOP
-- Beginner-friendly, synthesizable VHDL for the Cyclone III FPGA.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity i2c_master is
    generic (
        CLK_FREQ  : integer := 50000000;  -- system clock in Hz
        I2C_FREQ  : integer := 100000     -- I2C bus speed in Hz (100 kHz standard)
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        -- Control interface
        start_cmd : in  std_logic;       -- pulse high to begin a transaction
        rw        : in  std_logic;       -- '0' = write, '1' = read
        addr      : in  std_logic_vector(6 downto 0); -- 7-bit slave address
        data_in   : in  std_logic_vector(7 downto 0); -- data to write
        data_out  : out std_logic_vector(7 downto 0); -- data read from slave
        done      : out std_logic;       -- pulse high when transaction finished
        ack_error : out std_logic;       -- '1' if slave did not ACK
        -- I2C bus (open-drain: '0' drives low, '1' releases)
        sda       : inout std_logic;
        scl       : inout std_logic
    );
end entity i2c_master;

architecture rtl of i2c_master is
    -- Clock divider: system clocks per I2C quarter-period (for SDA/SCL edges)
    constant DIV : integer := CLK_FREQ / (I2C_FREQ * 4);

    type state_t is (IDLE, START, ST_ADDR, ADDR_ACK, DATA, DATA_ACK, STOP);
    signal state : state_t := IDLE;

    signal clk_cnt   : integer range 0 to DIV - 1 := 0;
    signal bit_index : integer range 0 to 7 := 0;
    signal addr_byte : std_logic_vector(7 downto 0) := (others => '0');
    signal data_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal sda_out   : std_logic := '1';
    signal scl_out   : std_logic := '1';
    signal done_flag : std_logic := '0';
    signal err_flag  : std_logic := '0';
begin

    -- Open-drain: output '0' drives the line low; output '1' releases (pull-up)
    sda <= '0' when sda_out = '0' else 'Z';
    scl <= '0' when scl_out = '0' else 'Z';

    i2c_proc : process(clk, reset)
    begin
        if reset = '1' then
            state      <= IDLE;
            sda_out    <= '1';
            scl_out    <= '1';
            done_flag  <= '0';
            err_flag   <= '0';
            data_out   <= (others => '0');
            clk_cnt    <= 0;
            bit_index  <= 0;
        elsif rising_edge(clk) then
            done_flag <= '0';

            case state is
                when IDLE =>
                    sda_out <= '1';
                    scl_out <= '1';
                    if start_cmd = '1' then
                        addr_byte <= addr & rw;  -- 7-bit addr + R/W bit
                        data_reg  <= data_in;
                        state     <= START;
                        clk_cnt   <= 0;
                    end if;

                -- START condition: SDA goes low while SCL is high
                when START =>
                    if clk_cnt = DIV - 1 then
                        clk_cnt <= 0;
                        sda_out <= '0';       -- pull SDA low
                        state   <= ST_ADDR;
                        bit_index <= 7;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                -- Send 7-bit address + R/W bit (MSB first)
                when ST_ADDR =>
                    if clk_cnt = DIV - 1 then
                        clk_cnt <= 0;
                        scl_out <= '0';  -- pull SCL low to change SDA
                        sda_out <= addr_byte(bit_index);
                        -- Now raise SCL so slave samples SDA
                        if clk_cnt = 0 then
                            scl_out <= '1';
                        end if;
                        if bit_index = 0 then
                            state <= ADDR_ACK;
                        else
                            bit_index <= bit_index - 1;
                        end if;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                -- Read ACK from slave (SDA should be low)
                when ADDR_ACK =>
                    if clk_cnt = DIV - 1 then
                        clk_cnt <= 0;
                        scl_out <= '1';   -- raise SCL for ACK
                        if sda /= '0' then
                            err_flag <= '1';  -- no ACK from slave
                        end if;
                        scl_out   <= '0';
                        state     <= DATA;
                        bit_index <= 7;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                -- Send or receive 8 data bits
                when DATA =>
                    if clk_cnt = DIV - 1 then
                        clk_cnt <= 0;
                        if rw = '0' then
                            -- Write: master drives SDA
                            sda_out <= data_reg(bit_index);
                        else
                            -- Read: master releases SDA, samples it
                            sda_out <= '1';
                            data_reg(bit_index) <= sda;
                        end if;
                        scl_out <= '1';  -- clock pulse
                        scl_out <= '0';
                        if bit_index = 0 then
                            state <= DATA_ACK;
                        else
                            bit_index <= bit_index - 1;
                        end if;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                -- ACK/NACK phase
                when DATA_ACK =>
                    if clk_cnt = DIV - 1 then
                        clk_cnt <= 0;
                        if rw = '0' then
                            -- Master writes: read slave ACK
                            sda_out <= '1';  -- release SDA
                            if sda /= '0' then
                                err_flag <= '1';
                            end if;
                        else
                            -- Master reads: send NACK (high) to end read
                            sda_out <= '1';
                        end if;
                        data_out  <= data_reg;
                        state     <= STOP;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                -- STOP condition: SDA goes high while SCL is high
                when STOP =>
                    if clk_cnt = DIV - 1 then
                        clk_cnt  <= 0;
                        scl_out  <= '1';
                        sda_out  <= '1';  -- SDA rises while SCL high = STOP
                        done_flag<= '1';
                        state    <= IDLE;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;
            end case;
        end if;
    end process i2c_proc;

    done      <= done_flag;
    ack_error <= err_flag;

end architecture rtl;

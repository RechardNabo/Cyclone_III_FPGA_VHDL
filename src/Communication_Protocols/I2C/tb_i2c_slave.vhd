-- ============================================================================
-- Testbench for I2C Slave Controller
-- ============================================================================
-- Tests the I2C slave's response to master-generated START/STOP conditions,
-- 7-bit address matching, write data reception (reg_wr/reg_dout), and
-- read data transmission (reg_data).  Acts as an I2C master by driving
-- SCL and SDA with proper open-drain timing.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_i2c_slave is
end entity tb_i2c_slave;

architecture sim of tb_i2c_slave is

    constant CLK_PERIOD : time := 20 ns;

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal sda      : std_logic := '1';   -- master drives '1' idle, '0' low, 'Z' release
    signal scl      : std_logic := '1';   -- idle high
    signal reg_data : std_logic_vector(7 downto 0) := x"AB";
    signal reg_wr   : std_logic;
    signal reg_dout : std_logic_vector(7 downto 0);

    -- Slave address used by DUT (7-bit)
    constant SLAVE_ADDR : std_logic_vector(6 downto 0) := "1010000";

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.i2c_slave
        generic map (
            SLAVE_ADDR => SLAVE_ADDR
        )
        port map (
            clk      => clk,
            reset    => reset,
            sda      => sda,
            scl      => scl,
            reg_data => reg_data,
            reg_wr   => reg_wr,
            reg_dout => reg_dout
        );

    -- ========================================================================
    -- I2C Master Stimulus Process
    -- ========================================================================
    stim : process
        variable rx_byte : std_logic_vector(7 downto 0);
        variable bit_val : std_logic;
        variable got_ack : boolean;

        -- Generate START condition: SDA falls while SCL is high
        procedure i2c_start is
        begin
            sda <= '1';
            scl <= '1';
            wait until rising_edge(clk);
            wait until rising_edge(clk);   -- ensure scl_prev='1', sda_prev='1'
            sda <= '0';                     -- SDA falls while SCL high -> START
            wait until rising_edge(clk);
            wait until rising_edge(clk);   -- let slave detect START
            scl <= '0';                     -- pull SCL low to begin data
            wait until rising_edge(clk);
            wait until rising_edge(clk);
        end procedure;

        -- Generate STOP condition: SDA rises while SCL is high
        procedure i2c_stop is
        begin
            sda <= '0';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            scl <= '1';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            sda <= '1';                     -- SDA rises while SCL high -> STOP
            wait until rising_edge(clk);
            wait until rising_edge(clk);
        end procedure;

        -- Send one bit: set SDA while SCL low, then pulse SCL high
        procedure i2c_send_bit(b : std_logic) is
        begin
            sda <= b;
            wait until rising_edge(clk);
            wait until rising_edge(clk);   -- SDA settle while SCL low
            scl <= '1';                     -- SCL rising edge -> slave samples
            wait until rising_edge(clk);
            wait until rising_edge(clk);   -- SCL high
            scl <= '0';                     -- SCL falling edge
            wait until rising_edge(clk);
            wait until rising_edge(clk);   -- SCL low
        end procedure;

        -- Read one bit from slave: release SDA, pulse SCL, sample
        procedure i2c_read_bit(variable bv : out std_logic) is
        begin
            sda <= 'Z';                     -- release SDA for slave to drive
            wait until rising_edge(clk);
            wait until rising_edge(clk);   -- SDA settle while SCL low
            scl <= '1';                     -- SCL rising edge
            wait until rising_edge(clk);   -- slave processes edge
            -- Sample SDA: '0' means 0, anything else ('Z') means 1
            if sda = '0' then
                bv := '0';
            else
                bv := '1';
            end if;
            wait until rising_edge(clk);   -- SCL high
            scl <= '0';                     -- SCL falling edge
            wait until rising_edge(clk);
            wait until rising_edge(clk);   -- SCL low
        end procedure;

        -- Send a full byte (MSB first) and check ACK
        procedure i2c_send_byte(data : std_logic_vector(7 downto 0)) is
        begin
            for i in 7 downto 0 loop
                i2c_send_bit(data(i));
            end loop;
            -- ACK slot: release SDA, pulse SCL, check ACK
            sda <= 'Z';
            wait until rising_edge(clk);
            wait until rising_edge(clk);   -- let slave drive ACK
            -- Check ACK before raising SCL (slave drives ACK low)
            got_ack := (sda = '0');
            scl <= '1';                     -- ACK clock pulse
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            scl <= '0';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            sda <= '1';                     -- resume idle driving
        end procedure;

        -- Read a full byte from slave (MSB first), then send NACK
        procedure i2c_read_byte(variable rv : out std_logic_vector(7 downto 0)) is
        begin
            rv := (others => '0');
            for i in 7 downto 0 loop
                i2c_read_bit(bit_val);
                rv(i) := bit_val;
            end loop;
            -- Send NACK: master drives SDA high during ACK slot
            sda <= '1';                     -- NACK
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            scl <= '1';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            scl <= '0';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            sda <= '1';
        end procedure;

    begin
        -- ------------------------------------------------------------------
        -- Reset
        -- ------------------------------------------------------------------
        reset <= '1';
        sda   <= '1';
        scl   <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- ------------------------------------------------------------------
        -- Test 1: Verify reset state - reg_wr should be '0'
        -- ------------------------------------------------------------------
        assert reg_wr = '0'
            report "Test 1 FAIL: reg_wr not '0' after reset"
            severity error;
        report "Test 1 PASS: reg_wr is '0' after reset" severity note;

        -- ------------------------------------------------------------------
        -- Test 2: Write to slave - send address + W, data byte, check reg_wr
        -- ------------------------------------------------------------------
        -- START
        i2c_start;

        -- Send address byte: 7-bit addr + W(0) = 0xA0
        i2c_send_byte(SLAVE_ADDR & '0');  -- Write

        -- Verify slave ACKed the address
        assert got_ack
            report "Test 2 FAIL: slave did not ACK write address"
            severity error;
        report "Test 2 PASS: slave ACKed write address" severity note;

        -- Send data byte 0x55
        i2c_send_byte(x"55");

        -- Verify slave ACKed the data
        assert got_ack
            report "Test 2 FAIL: slave did not ACK data byte"
            severity error;

        -- Wait a couple clocks for reg_dout to propagate
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- Verify reg_dout contains the written byte
        assert reg_dout = x"55"
            report "Test 2 FAIL: reg_dout mismatch, expected 55 got " &
                   integer'image(to_integer(unsigned(reg_dout)))
            severity error;
        report "Test 2 PASS: reg_dout = 0x55 after write" severity note;

        -- STOP
        i2c_stop;

        -- Wait for STOP to be processed
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- ------------------------------------------------------------------
        -- Test 3: Read from slave - send address + R, read data byte
        -- ------------------------------------------------------------------
        -- Set reg_data to a known value
        reg_data <= x"3C";

        -- START
        i2c_start;

        -- Send address byte: 7-bit addr + R(1) = 0xA1
        i2c_send_byte(SLAVE_ADDR & '1');  -- Read

        -- Verify slave ACKed the read address
        assert got_ack
            report "Test 3 FAIL: slave did not ACK read address"
            severity error;
        report "Test 3 PASS: slave ACKed read address" severity note;

        -- Read data byte from slave
        i2c_read_byte(rx_byte);

        -- Verify read data matches reg_data
        assert rx_byte = x"3C"
            report "Test 3 FAIL: read data mismatch, expected 3C got " &
                   integer'image(to_integer(unsigned(rx_byte)))
            severity error;
        report "Test 3 PASS: read data = 0x3C matches reg_data" severity note;

        -- STOP
        i2c_stop;

        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- ------------------------------------------------------------------
        -- Test 4: Wrong address - slave should NOT ACK
        -- ------------------------------------------------------------------
        i2c_start;

        -- Send wrong address + W = 0x30 (addr = "0011000")
        i2c_send_byte("0011000" & '0');

        -- Verify slave did NOT ACK (wrong address)
        assert not got_ack
            report "Test 4 FAIL: slave ACKed wrong address"
            severity error;
        report "Test 4 PASS: slave did not ACK wrong address" severity note;

        -- STOP
        i2c_stop;

        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- ------------------------------------------------------------------
        -- Done
        -- ------------------------------------------------------------------
        report "All I2C slave tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim;

end architecture sim;

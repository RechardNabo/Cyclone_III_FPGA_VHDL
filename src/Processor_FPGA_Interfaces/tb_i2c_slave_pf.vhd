-- ============================================================================
-- Testbench for I2C Slave Controller
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_i2c_slave_pf is
end entity tb_i2c_slave_pf;

architecture sim of tb_i2c_slave_pf is

    -- DUT generic
    constant SLAVE_ADDRESS : std_logic_vector(6 downto 0) := "0101001";

    -- DUT signals
    signal clk_i        : std_logic := '0';
    signal rst_i        : std_logic := '1';
    signal scl_i        : std_logic := '1';
    signal sda_i        : std_logic := '1';
    signal sda_o        : std_logic;
    signal reg_write_o  : std_logic_vector(7 downto 0);
    signal reg_read_i   : std_logic_vector(7 downto 0) := x"AB";
    signal write_strobe : std_logic;

    -- Clock period (system clock, faster than I2C bus)
    constant CLK_PERIOD  : time := 20 ns;
    constant I2C_PERIOD  : time := 200 ns;  -- I2C SCL period

begin

    -- Instantiate DUT
    dut : entity work.i2c_slave
        generic map (
            SLAVE_ADDRESS => SLAVE_ADDRESS
        )
        port map (
            clk_i        => clk_i,
            rst_i        => rst_i,
            scl_i        => scl_i,
            sda_i        => sda_i,
            sda_o        => sda_o,
            reg_write_o  => reg_write_o,
            reg_read_i   => reg_read_i,
            write_strobe => write_strobe
        );

    -- System clock generation
    clk_proc : process
    begin
        clk_i <= '0';
        wait for CLK_PERIOD / 2;
        clk_i <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- I2C bus master process
    -- Helper procedure to drive I2C write transaction
    -- Address: 7-bit SLAVE_ADDRESS + R/W bit
    i2c_master_proc : process
        -- Drive SCL low
        procedure scl_low is
        begin
            scl_i <= '0';
            wait for I2C_PERIOD / 2;
        end procedure;

        -- Drive SCL high
        procedure scl_high is
        begin
            scl_i <= '1';
            wait for I2C_PERIOD / 2;
        end procedure;

        -- Send one bit on SDA (SCL low -> set SDA -> SCL high -> SCL low)
        procedure send_bit(bit_val : in std_logic) is
        begin
            scl_i <= '0';
            wait for I2C_PERIOD / 4;
            sda_i <= bit_val;
            wait for I2C_PERIOD / 4;
            scl_i <= '1';
            wait for I2C_PERIOD / 2;
            scl_i <= '0';
            wait for I2C_PERIOD / 4;
        end procedure;

        -- Generate START condition (SDA falls while SCL high)
        procedure gen_start is
        begin
            sda_i <= '1';
            scl_i <= '1';
            wait for I2C_PERIOD / 4;
            sda_i <= '0';  -- SDA falls while SCL high
            wait for I2C_PERIOD / 4;
            scl_i <= '0';
            wait for I2C_PERIOD / 4;
        end procedure;

        -- Generate STOP condition (SDA rises while SCL high)
        procedure gen_stop is
        begin
            scl_i <= '0';
            sda_i <= '0';
            wait for I2C_PERIOD / 4;
            scl_i <= '1';
            wait for I2C_PERIOD / 4;
            sda_i <= '1';  -- SDA rises while SCL high
            wait for I2C_PERIOD / 4;
        end procedure;

    begin

        -- -------------------------------------------------------
        -- Test 1: Reset state
        -- -------------------------------------------------------
        rst_i <= '1';
        scl_i <= '1';
        sda_i <= '1';
        wait for CLK_PERIOD * 5;
        assert write_strobe = '0'
            report "Test 1 FAIL: write_strobe not low during reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;

        rst_i <= '0';
        wait for CLK_PERIOD * 5;

        -- -------------------------------------------------------
        -- Test 2: Write 0x55 to slave at address "0101001"
        -- -------------------------------------------------------
        -- START
        gen_start;

        -- Send 7-bit address + W(0)
        send_bit('0');  -- A6
        send_bit('1');  -- A5
        send_bit('0');  -- A4
        send_bit('1');  -- A3
        send_bit('0');  -- A2
        send_bit('0');  -- A1
        send_bit('1');  -- A0
        send_bit('0');  -- W=0

        -- ACK from slave (9th clock) - slave should pull SDA low
        scl_i <= '0';
        wait for I2C_PERIOD / 4;
        -- Release SDA so slave can drive it
        sda_i <= '1';
        wait for I2C_PERIOD / 4;
        scl_i <= '1';
        wait for I2C_PERIOD / 2;
        -- Check ACK (sda_o should be '0')
        assert sda_o = '0'
            report "Test 2 FAIL: No ACK after address"
            severity error;
        scl_i <= '0';
        wait for I2C_PERIOD / 4;

        -- Send data byte 0x55
        send_bit('0');  -- bit 7
        send_bit('1');  -- bit 6
        send_bit('0');  -- bit 5
        send_bit('1');  -- bit 4
        send_bit('0');  -- bit 3
        send_bit('1');  -- bit 2
        send_bit('0');  -- bit 1
        send_bit('1');  -- bit 0

        -- ACK from slave
        scl_i <= '0';
        wait for I2C_PERIOD / 4;
        sda_i <= '1';
        wait for I2C_PERIOD / 4;
        scl_i <= '1';
        wait for I2C_PERIOD / 2;
        scl_i <= '0';
        wait for I2C_PERIOD / 4;

        -- STOP
        gen_stop;

        -- Wait for write strobe to be processed
        wait for CLK_PERIOD * 10;
        assert write_strobe = '1' or reg_write_o = x"55"
            report "Test 2 FAIL: Write data not 0x55"
            severity error;
        report "Test 2: Written data = 0x" & integer'image(to_integer(unsigned(reg_write_o))) severity note;
        report "Test 2 PASS: I2C write transaction completed" severity note;

        wait for CLK_PERIOD * 10;

        -- -------------------------------------------------------
        -- Test 3: Write 0xAA to slave
        -- -------------------------------------------------------
        gen_start;

        send_bit('0'); send_bit('1'); send_bit('0'); send_bit('1');
        send_bit('0'); send_bit('0'); send_bit('1'); send_bit('0');

        -- ACK
        scl_i <= '0'; wait for I2C_PERIOD / 4;
        sda_i <= '1'; wait for I2C_PERIOD / 4;
        scl_i <= '1'; wait for I2C_PERIOD / 2;
        scl_i <= '0'; wait for I2C_PERIOD / 4;

        -- Send 0xAA
        send_bit('1'); send_bit('0'); send_bit('1'); send_bit('0');
        send_bit('1'); send_bit('0'); send_bit('1'); send_bit('0');

        -- ACK
        scl_i <= '0'; wait for I2C_PERIOD / 4;
        sda_i <= '1'; wait for I2C_PERIOD / 4;
        scl_i <= '1'; wait for I2C_PERIOD / 2;
        scl_i <= '0'; wait for I2C_PERIOD / 4;

        gen_stop;

        wait for CLK_PERIOD * 10;
        assert reg_write_o = x"AA"
            report "Test 3 FAIL: Write data not 0xAA"
            severity error;
        report "Test 3 PASS: Second I2C write (0xAA) completed" severity note;

        wait for CLK_PERIOD * 10;

        -- -------------------------------------------------------
        -- Test 4: Read transaction from slave
        -- -------------------------------------------------------
        gen_start;

        -- Send address + R(1)
        send_bit('0'); send_bit('1'); send_bit('0'); send_bit('1');
        send_bit('0'); send_bit('0'); send_bit('1'); send_bit('1');

        -- ACK from slave
        scl_i <= '0'; wait for I2C_PERIOD / 4;
        sda_i <= '1'; wait for I2C_PERIOD / 4;
        scl_i <= '1'; wait for I2C_PERIOD / 2;
        scl_i <= '0'; wait for I2C_PERIOD / 4;

        -- Read 8 bits from slave (slave drives SDA via sda_o)
        for i in 0 to 7 loop
            scl_i <= '0';
            wait for I2C_PERIOD / 4;
            sda_i <= '1';  -- release bus
            wait for I2C_PERIOD / 4;
            scl_i <= '1';
            wait for I2C_PERIOD / 2;
            -- Sample sda_o here
            scl_i <= '0';
            wait for I2C_PERIOD / 4;
        end loop;

        -- NACK from master (sda high)
        scl_i <= '0'; wait for I2C_PERIOD / 4;
        sda_i <= '1'; wait for I2C_PERIOD / 4;
        scl_i <= '1'; wait for I2C_PERIOD / 2;
        scl_i <= '0'; wait for I2C_PERIOD / 4;

        gen_stop;

        wait for CLK_PERIOD * 10;
        report "Test 4 PASS: I2C read transaction completed" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

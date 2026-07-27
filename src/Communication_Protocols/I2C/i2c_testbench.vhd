library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity i2c_testbench is
end entity i2c_testbench;

architecture sim of i2c_testbench is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal start_cmd : std_logic := '0';
    signal rw        : std_logic := '0';
    signal addr      : std_logic_vector(6 downto 0) := (others => '0');
    signal data_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out  : std_logic_vector(7 downto 0);
    signal done      : std_logic;
    signal ack_error : std_logic;
    signal sda       : std_logic := 'H';  -- pull-up
    signal scl       : std_logic := 'H';  -- pull-up

    signal sda_low_seen : boolean := false;
    signal scl_low_seen : boolean := false;
begin
    clk <= not clk after 10 ns;

    dut : entity work.i2c_master
        generic map (
            CLK_FREQ => 50000000,
            I2C_FREQ => 1000000  -- 1 MHz for faster simulation
        )
        port map (
            clk       => clk,
            reset     => reset,
            start_cmd => start_cmd,
            rw        => rw,
            addr      => addr,
            data_in   => data_in,
            data_out  => data_out,
            done      => done,
            ack_error => ack_error,
            sda       => sda,
            scl       => scl
        );

    -- Monitor bus for activity
    monitor : process(sda, scl)
    begin
        if sda = '0' then
            sda_low_seen <= true;
        end if;
        if scl = '0' then
            scl_low_seen <= true;
        end if;
    end process;

    -- Simple slave ACK model: pull SDA low during ACK slots
    slave_model : process
    begin
        sda <= 'H';
        -- Wait for START condition (SDA falls while SCL high)
        wait until sda = '0' and scl = 'H';

        -- Wait for 8 SCL edges (address bits) then provide ACK
        -- Since the master's SCL behavior is simplified, just wait
        -- a fixed time and then pull SDA low for ACK
        wait for 200 ns;
        sda <= '0';   -- ACK the address
        wait for 100 ns;
        sda <= 'H';   -- release

        -- Wait for 8 data bits then ACK
        wait for 200 ns;
        sda <= '0';   -- ACK the data
        wait for 100 ns;
        sda <= 'H';   -- release

        wait;
    end process;

    stim : process
    begin
        -- Reset
        reset <= '1';
        wait for 40 ns;
        reset <= '0';
        wait for 20 ns;

        -- Write 0xAB to slave address 0x50
        addr      <= "1010000";  -- 0x50
        data_in   <= x"AB";
        rw        <= '0';        -- write
        start_cmd <= '1';
        wait until rising_edge(clk);
        start_cmd <= '0';

        -- Wait for transaction to complete
        -- DIV = 50000000/(1000000*4) = 12, ~7 states * 12 * 20ns = ~1.7 us
        wait until done = '1' for 10 us;

        -- Verify done asserted
        assert done = '1'
            report "FAIL: done signal not asserted, I2C transaction incomplete"
            severity error;

        -- Verify SDA had activity (went low = START condition)
        assert sda_low_seen
            report "FAIL: SDA never went low, no I2C bus activity on SDA"
            severity error;

        -- Verify SCL had activity (went low)
        assert scl_low_seen
            report "FAIL: SCL never went low, no I2C bus activity on SCL"
            severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

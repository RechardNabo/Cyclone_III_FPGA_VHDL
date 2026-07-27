library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_testbench is
end entity uart_testbench;

architecture sim of uart_testbench is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal tx_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_wr     : std_logic := '0';
    signal tx_serial : std_logic;
    signal tx_ready  : std_logic;
    signal tx_empty  : std_logic;
    signal tx_busy   : std_logic;

    -- Use a high baud rate for faster simulation
    -- CLK_FREQ=50000000, BAUD_RATE=1000000 -> 50 clocks per bit
    constant CLK_PER_BIT : integer := 50;

    signal start_bit_seen : boolean := false;
    signal data_bits      : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_idx        : integer := 0;
begin
    clk <= not clk after 10 ns;

    dut : entity work.uart_tx
        generic map (
            BAUD_RATE     => 1000000,
            CLK_FREQ      => 50000000,
            PARITY_ENABLE => false,
            FIFO_DEPTH    => 16
        )
        port map (
            clk       => clk,
            reset     => reset,
            tx_data   => tx_data,
            tx_wr     => tx_wr,
            tx_serial => tx_serial,
            tx_ready  => tx_ready,
            tx_empty  => tx_empty,
            tx_busy   => tx_busy
        );

    -- Monitor serial output to capture frame bits
    monitor : process(tx_serial)
    begin
        -- Detect start bit (falling edge from idle '1' to '0')
        if falling_edge(tx_serial) then
            if not start_bit_seen then
                start_bit_seen <= true;
            end if;
        end if;
    end process;

    stim : process
        variable captured : std_logic_vector(7 downto 0) := (others => '0');
    begin
        -- Reset
        reset <= '1';
        wait for 40 ns;
        reset <= '0';
        wait until rising_edge(clk);

        -- Verify idle state: serial line should be high
        assert tx_serial = '1'
            report "FAIL: tx_serial not idle high after reset"
            severity error;

        -- Verify tx_ready is high (FIFO not full)
        assert tx_ready = '1'
            report "FAIL: tx_ready not high after reset"
            severity error;

        -- Write 0x55 (01010101) to FIFO
        tx_data <= x"55";
        tx_wr   <= '1';
        wait until rising_edge(clk);
        tx_wr <= '0';

        -- Wait for tx_busy to assert (transmission starts)
        wait until tx_busy = '1' for 1 us;
        assert tx_busy = '1'
            report "FAIL: tx_busy not asserted after tx_wr"
            severity error;

        -- Wait for start bit (serial goes low)
        wait until tx_serial = '0' for 1 us;
        assert tx_serial = '0'
            report "FAIL: start bit not detected on tx_serial"
            severity error;

        -- Wait for start bit duration
        wait for CLK_PER_BIT * 20 ns;

        -- Sample 8 data bits (LSB first for 0x55 = 1,0,1,0,1,0,1,0)
        for i in 0 to 7 loop
            -- Sample at middle of bit period
            wait for (CLK_PER_BIT / 2) * 20 ns;
            captured(i) := tx_serial;
            wait for (CLK_PER_BIT / 2) * 20 ns;
        end loop;

        -- Verify captured data matches 0x55
        assert captured = x"55"
            report "FAIL: UART data mismatch, expected 55 got " &
                   integer'image(to_integer(unsigned(captured)))
            severity error;

        -- Wait for stop bit (serial should go high)
        wait for CLK_PER_BIT * 20 ns;
        assert tx_serial = '1'
            report "FAIL: stop bit not high"
            severity error;

        -- Wait for tx_busy to de-assert
        wait until tx_busy = '0' for 1 us;
        assert tx_busy = '0'
            report "FAIL: tx_busy not de-asserted after transmission"
            severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

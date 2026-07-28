library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Case 3: Start bit glitch - brief low pulse that is not a real start bit
entity tb_uart_rx_case3 is
end entity tb_uart_rx_case3;

architecture sim of tb_uart_rx_case3 is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '0';
    signal rx_serial : std_logic := '1';
    signal rx_data   : std_logic_vector(7 downto 0);
    signal rx_valid  : std_logic;
    signal rx_busy   : std_logic;

    constant CLK_PER_BIT : integer := 16;
    signal rx_valid_seen : boolean := false;
begin
    clk <= not clk after 10 ns;

    dut : entity work.uart_receiver
        generic map (BAUD_RATE => 10, CLK_FREQ => 160)
        port map (clk => clk, reset => reset, rx_serial => rx_serial,
                  rx_data => rx_data, rx_valid => rx_valid, rx_busy => rx_busy);

    -- Capture rx_valid pulse
    monitor : process(clk)
    begin
        if rising_edge(clk) then
            if rx_valid = '1' then
                rx_valid_seen <= true;
            end if;
        end if;
    end process;

    stim : process
    begin
        reset <= '1';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);

        -- Send a brief glitch (low for only 2 cycles, much less than half a bit)
        rx_serial <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        -- Bring back high before the middle sampling point
        rx_serial <= '1';

        -- Wait for the receiver to process the false start
        -- The receiver checks at the middle of the start bit (oversample_count = 7)
        -- Since we brought the line high before that, it should detect a false start
        for i in 0 to CLK_PER_BIT loop wait until rising_edge(clk); end loop;

        -- Receiver should be back in IDLE, not busy
        assert rx_busy = '0' report "FAIL: rx_busy should be 0 after glitch" severity error;
        assert rx_valid = '0' report "FAIL: rx_valid should be 0 after glitch" severity error;

        -- Now send a valid frame to confirm receiver works after glitch
        rx_serial <= '0';
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;

        -- Data 0x0F = 00001111, LSB first: 1,1,1,1,0,0,0,0
        rx_serial <= '1'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '1'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '1'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '1'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '0'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '0'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '0'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '0'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;

        -- Stop bit
        rx_serial <= '1';
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        for i in 0 to 5 loop wait until rising_edge(clk); end loop;

        assert rx_valid_seen report "FAIL: rx_valid after valid frame" severity error;
        assert rx_data = x"0F" report "FAIL: rx_data should be 0x0F" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

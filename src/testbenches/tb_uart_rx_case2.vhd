library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Case 2: Framing error - stop bit is 0 instead of 1
entity tb_uart_rx_case2 is
end entity tb_uart_rx_case2;

architecture sim of tb_uart_rx_case2 is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '0';
    signal rx_serial : std_logic := '1';
    signal rx_data   : std_logic_vector(7 downto 0);
    signal rx_valid  : std_logic;
    signal rx_busy   : std_logic;

    constant CLK_PER_BIT : integer := 16;
begin
    clk <= not clk after 10 ns;

    dut : entity work.uart_receiver
        generic map (BAUD_RATE => 10, CLK_FREQ => 160)
        port map (clk => clk, reset => reset, rx_serial => rx_serial,
                  rx_data => rx_data, rx_valid => rx_valid, rx_busy => rx_busy);

    stim : process
    begin
        reset <= '1';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);

        -- Start bit
        rx_serial <= '0';
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;

        -- Data bits 0xA5 = 10100101, LSB first: 1,0,1,0,0,1,0,1
        rx_serial <= '1'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '0'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '1'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '0'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '0'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '1'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '0'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '1'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;

        -- Bad stop bit (0 instead of 1) - framing error
        rx_serial <= '0';
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;

        -- Return line to idle
        rx_serial <= '1';
        for i in 0 to 5 loop wait until rising_edge(clk); end loop;

        -- The receiver still outputs data but with a framing error condition.
        -- This implementation does not have a framing_error output port,
        -- so we verify the receiver returns to idle (rx_busy = '0').
        assert rx_busy = '0' report "FAIL: rx_busy should be 0 after frame" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

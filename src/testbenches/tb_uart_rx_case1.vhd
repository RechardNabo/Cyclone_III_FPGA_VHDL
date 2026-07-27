library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Case 1: Normal reception of byte 0x55
entity tb_uart_rx_case1 is
end entity tb_uart_rx_case1;

architecture sim of tb_uart_rx_case1 is
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

        -- Data bits 0x55 = 01010101, LSB first: 1,0,1,0,1,0,1,0
        rx_serial <= '1'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '0'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '1'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '0'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '1'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '0'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '1'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        rx_serial <= '0'; for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;

        -- Stop bit
        rx_serial <= '1';
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;

        -- Wait a few extra cycles for rx_valid
        for i in 0 to 5 loop wait until rising_edge(clk); end loop;

        assert rx_valid = '1' report "FAIL: rx_valid not asserted" severity error;
        assert rx_data = x"55" report "FAIL: rx_data should be 0x55" severity error;
        assert rx_busy = '0' report "FAIL: rx_busy should be 0 after reception" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

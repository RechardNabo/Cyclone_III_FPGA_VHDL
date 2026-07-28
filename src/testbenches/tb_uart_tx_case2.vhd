library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Case 2: Transmit byte 0xAA
entity tb_uart_tx_case2 is
end entity tb_uart_tx_case2;

architecture sim of tb_uart_tx_case2 is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '0';
    signal tx_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start  : std_logic := '0';
    signal tx_serial : std_logic;
    signal tx_busy   : std_logic;
    signal tx_done   : std_logic;

    constant CLK_PER_BIT : integer := 16;
begin
    clk <= not clk after 10 ns;

    dut : entity work.uart_transmitter
        generic map (BAUD_RATE => 10, CLK_FREQ => 160)
        port map (clk => clk, reset => reset, tx_data => tx_data,
                  tx_start => tx_start, tx_serial => tx_serial,
                  tx_busy => tx_busy, tx_done => tx_done);

    stim : process
        variable bit_val : std_logic;
        variable int_val : integer;
    begin
        reset <= '1';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);

        assert tx_serial = '1' report "FAIL: idle line should be high" severity error;

        -- Start transmission of 0xAA
        tx_data <= x"AA";
        tx_start <= '1';
        wait until rising_edge(clk);
        tx_start <= '0';

        -- Wait for start bit
        wait until tx_serial = '0';
        assert tx_busy = '1' report "FAIL: tx_busy should be 1 during TX" severity error;

        -- Verify start bit duration
        for i in 0 to CLK_PER_BIT - 1 loop
            assert tx_serial = '0' report "FAIL: start bit not held" severity error;
            wait until rising_edge(clk);
        end loop;

        -- Verify 8 data bits: 0xAA = 10101010, LSB first: 0,1,0,1,0,1,0,1
        for i in 0 to 7 loop
            int_val := to_integer(unsigned'(x"AA"));
            if (int_val / (2**i)) rem 2 = 1 then
                bit_val := '1';
            else
                bit_val := '0';
            end if;
            for j in 0 to CLK_PER_BIT - 1 loop
                wait until falling_edge(clk);
                assert tx_serial = bit_val
                    report "FAIL: data bit " & integer'image(i) & " mismatch"
                    severity error;
            end loop;
        end loop;

        -- Verify stop bit
        for i in 0 to CLK_PER_BIT - 1 loop
            wait until falling_edge(clk);
            assert tx_serial = '1' report "FAIL: stop bit not high" severity error;
        end loop;

        -- Check done and busy (done pulses at end of STOP)
        assert tx_done = '1' report "FAIL: tx_done should pulse" severity error;
        assert tx_busy = '0' report "FAIL: tx_busy should be 0 after TX" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

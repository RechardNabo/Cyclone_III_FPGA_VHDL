library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_hd6402 is
end entity tb_hd6402;

architecture sim of tb_hd6402 is
    signal clk           : std_logic := '0';
    signal reset         : std_logic := '0';
    signal data_in       : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_load       : std_logic := '0';
    signal rx_read       : std_logic := '0';
    signal data_out      : std_logic_vector(7 downto 0);
    signal tx_ready      : std_logic;
    signal rx_ready      : std_logic;
    signal framing_error : std_logic;
    signal parity_error  : std_logic;
    signal serial_in     : std_logic := '1';
    signal serial_out    : std_logic;

    constant CLK_PER_BIT : integer := 10;
begin
    clk <= not clk after 5 ns;

    dut : entity work.hd6402
        generic map (BAUD_RATE => 10, CLK_FREQ => 100)
        port map (
            clk => clk, reset => reset,
            data_in => data_in, tx_load => tx_load, rx_read => rx_read,
            data_out => data_out,
            tx_ready => tx_ready, rx_ready => rx_ready,
            framing_error => framing_error, parity_error => parity_error,
            serial_in => serial_in, serial_out => serial_out
        );

    -- TX test: load byte and verify serial output
    tx_stim : process
    begin
        reset <= '1';
        wait for 20 ns;
        reset <= '0';
        wait until rising_edge(clk);

        -- Wait for tx_ready
        wait until tx_ready = '1' and rising_edge(clk);

        -- Load 0x55 for transmission
        data_in <= x"55";
        tx_load <= '1';
        wait until rising_edge(clk);
        tx_load <= '0';

        -- Wait for start bit (serial_out goes low)
        wait until serial_out = '0';
        assert tx_ready = '0' report "FAIL: tx_ready should be 0 during TX" severity error;

        -- Wait for full frame to complete (start + 8 data + parity + stop = 11 bits)
        for i in 0 to (CLK_PER_BIT * 11) + 5 loop
            wait until rising_edge(clk);
        end loop;

        assert tx_ready = '1' report "FAIL: tx_ready should be 1 after TX" severity error;
        assert serial_out = '1' report "FAIL: serial_out should be high after TX" severity error;

        report "TX TEST PASSED" severity note;
        wait;
    end process;

    -- RX test: feed a serial frame into serial_in
    rx_stim : process
    begin
        -- Keep serial_in high until TX test is well underway
        serial_in <= '1';
        wait for 200 ns;

        -- Send start bit
        serial_in <= '0';
        for i in 0 to CLK_PER_BIT - 1 loop
            wait until rising_edge(clk);
        end loop;

        -- Send 8 data bits for 0xA5 (LSB first: 1,0,1,0,0,1,0,1)
        serial_in <= '1';  -- bit 0
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        serial_in <= '0';  -- bit 1
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        serial_in <= '1';  -- bit 2
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        serial_in <= '0';  -- bit 3
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        serial_in <= '0';  -- bit 4
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        serial_in <= '1';  -- bit 5
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        serial_in <= '0';  -- bit 6
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;
        serial_in <= '1';  -- bit 7
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;

        -- Send parity bit (even parity for 0xA5: XOR=0)
        serial_in <= '0';
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;

        -- Send stop bit
        serial_in <= '1';
        for i in 0 to CLK_PER_BIT - 1 loop wait until rising_edge(clk); end loop;

        -- Wait for rx_ready
        wait for 100 ns;
        assert rx_ready = '1' report "FAIL: rx_ready should be 1 after RX" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

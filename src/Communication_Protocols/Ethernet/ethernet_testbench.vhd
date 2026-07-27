library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ethernet_testbench is
end entity ethernet_testbench;

architecture sim of ethernet_testbench is
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '1';
    signal tx_data      : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_valid     : std_logic := '0';
    signal tx_ready     : std_logic;
    signal tx_end       : std_logic := '0';
    signal tx_done      : std_logic;
    signal rx_data      : std_logic_vector(7 downto 0);
    signal rx_valid     : std_logic;
    signal rx_end       : std_logic;
    signal mac_addr     : std_logic_vector(47 downto 0) := x"DEADBEEFCAFE";
    signal mii_tx_clk   : std_logic := '0';
    signal mii_txd      : std_logic_vector(3 downto 0);
    signal mii_tx_en    : std_logic;
    signal mii_rx_clk   : std_logic := '0';
    signal mii_rxd      : std_logic_vector(3 downto 0) := (others => '0');
    signal mii_rx_dv    : std_logic := '0';

    signal tx_en_seen   : boolean := false;
    signal txd_activity : boolean := false;
begin
    clk        <= not clk after 10 ns;
    mii_tx_clk <= not mii_tx_clk after 40 ns;  -- 12.5 MHz MII TX clock
    mii_rx_clk <= not mii_rx_clk after 40 ns;

    dut : entity work.ethernet_mac
        generic map (
            CLK_FREQ => 50000000
        )
        port map (
            clk        => clk,
            reset      => reset,
            tx_data    => tx_data,
            tx_valid   => tx_valid,
            tx_ready   => tx_ready,
            tx_end     => tx_end,
            tx_done    => tx_done,
            rx_data    => rx_data,
            rx_valid   => rx_valid,
            rx_end     => rx_end,
            mac_addr   => mac_addr,
            mii_tx_clk => mii_tx_clk,
            mii_txd    => mii_txd,
            mii_tx_en  => mii_tx_en,
            mii_rx_clk => mii_rx_clk,
            mii_rxd    => mii_rxd,
            mii_rx_dv  => mii_rx_dv
        );

    -- Monitor MII TX for activity
    monitor : process(mii_tx_en, mii_txd)
    begin
        if mii_tx_en = '1' then
            tx_en_seen <= true;
        end if;
        if mii_txd /= "0000" then
            txd_activity <= true;
        end if;
    end process;

    stim : process
    begin
        -- Reset
        reset <= '1';
        wait for 40 ns;
        reset <= '0';
        wait until rising_edge(clk);

        -- Wait for tx_ready
        wait until tx_ready = '1' for 1 us;
        assert tx_ready = '1'
            report "FAIL: tx_ready not asserted after reset"
            severity error;

        -- Send a short frame: 4 data bytes
        -- Byte 1
        wait until rising_edge(clk);
        tx_data  <= x"AA";
        tx_valid <= '1';
        wait until rising_edge(clk);

        -- Byte 2
        tx_data  <= x"BB";
        wait until rising_edge(clk);

        -- Byte 3
        tx_data  <= x"CC";
        wait until rising_edge(clk);

        -- Byte 4 (last byte, assert tx_end)
        tx_data <= x"DD";
        tx_end  <= '1';
        wait until rising_edge(clk);
        tx_valid <= '0';
        tx_end   <= '0';

        -- Wait for frame transmission to complete
        -- Preamble(7) + SFD(1) + Data(4) + CRC(2) = 14 bytes = 28 nibbles
        wait until tx_done = '1' for 10 us;

        -- Verify tx_done asserted
        assert tx_done = '1'
            report "FAIL: tx_done not asserted, Ethernet frame not sent"
            severity error;

        -- Verify MII TX enable asserted during transmission
        assert tx_en_seen
            report "FAIL: mii_tx_en never asserted, no TX activity"
            severity error;

        -- Verify MII TXD had non-zero data
        assert txd_activity
            report "FAIL: mii_txd never had non-zero data"
            severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

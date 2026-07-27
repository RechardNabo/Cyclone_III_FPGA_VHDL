library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity can_testbench is
end entity can_testbench;

architecture sim of can_testbench is
    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal tx_id    : std_logic_vector(10 downto 0) := (others => '0');
    signal tx_data  : std_logic_vector(7 downto 0)  := (others => '0');
    signal tx_start : std_logic := '0';
    signal tx_done  : std_logic;
    signal tx_busy  : std_logic;
    signal rx_id    : std_logic_vector(10 downto 0);
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;
    signal can_tx   : std_logic;
    signal can_rx   : std_logic := '1';  -- bus idle (recessive)

    signal tx_activity : boolean := false;
begin
    clk <= not clk after 10 ns;

    dut : entity work.can_controller
        generic map (
            CLK_FREQ => 50000000,
            BIT_RATE => 500000
        )
        port map (
            clk      => clk,
            reset    => reset,
            tx_id    => tx_id,
            tx_data  => tx_data,
            tx_start => tx_start,
            tx_done  => tx_done,
            tx_busy  => tx_busy,
            rx_id    => rx_id,
            rx_data  => rx_data,
            rx_valid => rx_valid,
            can_tx   => can_tx,
            can_rx   => can_rx
        );

    -- Monitor CAN TX line for activity
    monitor : process(can_tx)
    begin
        if can_tx = '0' then
            tx_activity <= true;
        end if;
    end process;

    stim : process
    begin
        -- Reset
        reset <= '1';
        wait for 40 ns;
        reset <= '0';
        wait for 20 ns;

        -- Send a frame: ID=0x123, Data=0xAB
        tx_id    <= "10010000011";  -- 0x123
        tx_data  <= x"AB";
        tx_start <= '1';
        wait until rising_edge(clk);
        tx_start <= '0';

        -- Wait for tx_busy to assert
        wait until tx_busy = '1' for 1 us;
        assert tx_busy = '1'
            report "FAIL: tx_busy not asserted after tx_start"
            severity error;

        -- Wait for frame to complete (500 kbps, ~28 bits, ~56 us)
        wait until tx_done = '1' for 200 us;

        -- Verify tx_done asserted
        assert tx_done = '1'
            report "FAIL: tx_done not asserted, frame transmission incomplete"
            severity error;

        -- Verify CAN TX line had activity (went dominant/low)
        assert tx_activity
            report "FAIL: can_tx never went low, no TX activity detected"
            severity error;

        -- Verify tx_busy de-asserted after done
        wait until rising_edge(clk);
        assert tx_busy = '0'
            report "FAIL: tx_busy still high after tx_done"
            severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

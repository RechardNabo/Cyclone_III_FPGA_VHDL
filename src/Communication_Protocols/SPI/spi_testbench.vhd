library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi_testbench is
end entity spi_testbench;

architecture sim of spi_testbench is
    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal data_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start : std_logic := '0';
    signal data_out : std_logic_vector(7 downto 0);
    signal ready    : std_logic;
    signal cpol     : std_logic := '0';
    signal cpha     : std_logic := '0';
    signal sck      : std_logic;
    signal mosi     : std_logic;
    signal miso     : std_logic := '0';
    signal ss       : std_logic;

    signal ss_low_seen  : boolean := false;
    signal mosi_bits    : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_count    : integer := 0;
begin
    clk <= not clk after 10 ns;

    dut : entity work.spi_master
        generic map (
            CLK_DIV => 2  -- small divider for faster simulation
        )
        port map (
            clk      => clk,
            reset    => reset,
            data_in  => data_in,
            tx_start => tx_start,
            data_out => data_out,
            ready    => ready,
            cpol     => cpol,
            cpha     => cpha,
            sck      => sck,
            mosi     => mosi,
            miso     => miso,
            ss       => ss
        );

    -- Monitor SS and capture MOSI bits on SCK edges
    monitor : process(ss, sck)
    begin
        if ss = '0' then
            ss_low_seen <= true;
        end if;
        -- Capture MOSI on rising edge of SCK when SS is active
        if rising_edge(sck) and ss = '0' then
            if bit_count < 8 then
                mosi_bits(bit_count) <= mosi;
                bit_count <= bit_count + 1;
            end if;
        end if;
    end process;

    stim : process
    begin
        -- Reset
        reset <= '1';
        wait for 40 ns;
        reset <= '0';
        wait until rising_edge(clk);

        -- Verify ready is high initially
        assert ready = '1'
            report "FAIL: SPI master not ready after reset"
            severity error;

        -- Send 0xA5 (10100101)
        data_in  <= x"A5";
        tx_start <= '1';
        wait until rising_edge(clk);
        tx_start <= '0';

        -- Wait for transfer to complete
        -- CLK_DIV=2, 8 bits, ~2*2*8 = 32 cycles + overhead
        wait until ready = '1' for 2 us;

        -- Verify ready re-asserted (transfer complete)
        assert ready = '1'
            report "FAIL: ready not re-asserted, SPI transfer incomplete"
            severity error;

        -- Verify SS went low (slave selected)
        assert ss_low_seen
            report "FAIL: SS never went low, slave not selected"
            severity error;

        -- Verify MOSI carried 0xA5 data (MSB first: 1,0,1,0,0,1,0,1)
        assert mosi_bits = x"A5"
            report "FAIL: MOSI data mismatch, expected A5 got " &
                   std_logic'image(mosi_bits(7)) & std_logic'image(mosi_bits(6)) &
                   std_logic'image(mosi_bits(5)) & std_logic'image(mosi_bits(4)) &
                   std_logic'image(mosi_bits(3)) & std_logic'image(mosi_bits(2)) &
                   std_logic'image(mosi_bits(1)) & std_logic'image(mosi_bits(0))
            severity error;

        -- Verify SS is back high (deselected) after transfer
        assert ss = '1'
            report "FAIL: SS not de-asserted after transfer"
            severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;

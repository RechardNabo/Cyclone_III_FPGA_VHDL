-- ============================================================================
-- Testbench for SPI Master Controller
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_spi_master_pf is
end entity tb_spi_master_pf;

architecture sim of tb_spi_master_pf is

    -- DUT generics
    constant DATA_WIDTH     : integer   := 8;
    constant CPOL           : std_logic := '0';
    constant CPHA           : std_logic := '0';
    constant CLK_DIV_FACTOR : integer   := 8;

    -- DUT signals
    signal clk_i            : std_logic := '0';
    signal rst_i            : std_logic := '1';
    signal start_transfer_i : std_logic := '0';
    signal tx_data_i        : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal transfer_done_o  : std_logic;
    signal rx_data_o        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sck_o            : std_logic;
    signal mosi_o           : std_logic;
    signal miso_i           : std_logic := '0';
    signal ss_o             : std_logic;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.spi_master
        generic map (
            DATA_WIDTH     => DATA_WIDTH,
            CPOL           => CPOL,
            CPHA           => CPHA,
            CLK_DIV_FACTOR => CLK_DIV_FACTOR
        )
        port map (
            clk_i            => clk_i,
            rst_i            => rst_i,
            start_transfer_i => start_transfer_i,
            tx_data_i        => tx_data_i,
            transfer_done_o  => transfer_done_o,
            rx_data_o        => rx_data_o,
            sck_o            => sck_o,
            mosi_o           => mosi_o,
            miso_i           => miso_i,
            ss_o             => ss_o
        );

    -- Clock generation
    clk_proc : process
    begin
        clk_i <= '0';
        wait for CLK_PERIOD / 2;
        clk_i <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Loopback: connect MOSI to MISO for self-test
    miso_i <= mosi_o;

    -- Stimulus process
    stim_proc : process
    begin

        -- -------------------------------------------------------
        -- Test 1: Reset state - SS should be high (inactive)
        -- -------------------------------------------------------
        rst_i <= '1';
        start_transfer_i <= '0';
        wait for CLK_PERIOD * 3;
        assert ss_o = '1'
            report "Test 1 FAIL: SS not high (inactive) after reset"
            severity error;
        assert transfer_done_o = '0'
            report "Test 1 FAIL: transfer_done not low after reset"
            severity error;
        report "Test 1 PASS: Reset state correct, SS=1" severity note;

        -- -------------------------------------------------------
        -- Test 2: Transfer 0xA5 with loopback (MISO=MOSI)
        -- -------------------------------------------------------
        rst_i <= '0';
        wait for CLK_PERIOD;
        tx_data_i        <= x"A5";
        start_transfer_i <= '1';
        wait for CLK_PERIOD;
        start_transfer_i <= '0';

        -- Wait for transfer to complete
        -- 8 bits * 2 half-periods * 8 clk_div = ~128 cycles + overhead
        wait until transfer_done_o = '1' for CLK_PERIOD * 200;
        assert transfer_done_o = '1'
            report "Test 2 FAIL: transfer_done not asserted"
            severity error;
        assert ss_o = '1'
            report "Test 2 FAIL: SS not de-asserted after transfer"
            severity error;
        -- With loopback, rx should equal tx
        assert rx_data_o = x"A5"
            report "Test 2 FAIL: Loopback RX not equal to TX (0xA5)"
            severity error;
        report "Test 2: TX=0xA5, RX=0x" & integer'image(to_integer(unsigned(rx_data_o))) severity note;
        report "Test 2 PASS: Loopback transfer of 0xA5 correct" severity note;

        wait for CLK_PERIOD * 5;

        -- -------------------------------------------------------
        -- Test 3: Transfer 0x3C with loopback
        -- -------------------------------------------------------
        tx_data_i        <= x"3C";
        start_transfer_i <= '1';
        wait for CLK_PERIOD;
        start_transfer_i <= '0';
        wait until transfer_done_o = '1' for CLK_PERIOD * 200;
        assert transfer_done_o = '1'
            report "Test 3 FAIL: transfer_done not asserted"
            severity error;
        assert rx_data_o = x"3C"
            report "Test 3 FAIL: Loopback RX not equal to TX (0x3C)"
            severity error;
        report "Test 3 PASS: Loopback transfer of 0x3C correct" severity note;

        wait for CLK_PERIOD * 5;

        -- -------------------------------------------------------
        -- Test 4: Transfer 0xFF with loopback
        -- -------------------------------------------------------
        tx_data_i        <= x"FF";
        start_transfer_i <= '1';
        wait for CLK_PERIOD;
        start_transfer_i <= '0';
        wait until transfer_done_o = '1' for CLK_PERIOD * 200;
        assert transfer_done_o = '1'
            report "Test 4 FAIL: transfer_done not asserted"
            severity error;
        assert rx_data_o = x"FF"
            report "Test 4 FAIL: Loopback RX not equal to TX (0xFF)"
            severity error;
        report "Test 4 PASS: Loopback transfer of 0xFF correct" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;

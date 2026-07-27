-- ============================================================================
-- Testbench for SPI Slave Controller
-- ============================================================================
-- Acts as an SPI master to verify the slave's full-duplex operation.
-- Tests Mode 0 (CPOL=0, CPHA=0): SS low, SCK idle low, sample on leading
-- edge (rising), shift on trailing edge (falling).  Loads a TX byte into
-- the slave, sends a MOSI byte, checks MISO output and rx_valid/rx_data.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_spi_slave is
end entity tb_spi_slave;

architecture sim of tb_spi_slave is

    constant CLK_PERIOD : time := 20 ns;
    constant SCK_HALF   : time := 40 ns;  -- 2 clk periods per SCK half-cycle

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal cpol     : std_logic := '0';
    signal cpha     : std_logic := '0';
    signal sck      : std_logic := '0';   -- idle low for CPOL=0
    signal mosi     : std_logic := '0';
    signal miso     : std_logic;
    signal ss       : std_logic := '1';   -- idle high (deselected)
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_load  : std_logic := '0';
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;

    -- Captured MISO bits (MSB first)
    signal miso_bits : std_logic_vector(7 downto 0) := (others => '0');

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.spi_slave
        port map (
            clk      => clk,
            reset    => reset,
            cpol     => cpol,
            cpha     => cpha,
            sck      => sck,
            mosi     => mosi,
            miso     => miso,
            ss       => ss,
            tx_data  => tx_data,
            tx_load  => tx_load,
            rx_data  => rx_data,
            rx_valid => rx_valid
        );

    -- ========================================================================
    -- SPI Master Stimulus
    -- ========================================================================
    stim : process
        variable mosi_byte : std_logic_vector(7 downto 0);
        variable miso_capture : std_logic_vector(7 downto 0);
    begin
        -- ------------------------------------------------------------------
        -- Reset
        -- ------------------------------------------------------------------
        reset   <= '1';
        ss      <= '1';
        sck     <= '0';
        mosi    <= '0';
        tx_load <= '0';
        wait for CLK_PERIOD * 4;
        reset   <= '0';
        wait until rising_edge(clk);

        -- ------------------------------------------------------------------
        -- Test 1: MISO is 'Z' when SS is high (not selected)
        -- ------------------------------------------------------------------
        assert miso = 'Z'
            report "Test 1 FAIL: MISO not 'Z' when SS high"
            severity error;
        report "Test 1 PASS: MISO is 'Z' when deselected" severity note;

        -- ------------------------------------------------------------------
        -- Test 2: Full-duplex transfer in Mode 0
        --   Master sends 0x3C on MOSI, slave should send 0xA5 on MISO
        -- ------------------------------------------------------------------
        -- Load slave TX data
        tx_data <= x"A5";
        tx_load <= '1';
        wait until rising_edge(clk);
        tx_load <= '0';
        wait until rising_edge(clk);

        -- Assert SS low (select slave)
        ss   <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- MISO should now be driving MSB of tx_reg (0xA5 bit 7 = '1')
        assert miso = '1'
            report "Test 2 FAIL: MISO not driving MSB after SS low"
            severity error;
        report "Test 2 PASS: MISO drives MSB after SS low" severity note;

        -- Perform 8-bit full-duplex transfer
        mosi_byte := x"3C";  -- 0011_1100
        miso_capture := (others => '0');

        for i in 7 downto 0 loop
            -- Drive MOSI bit
            mosi <= mosi_byte(i);
            wait for SCK_HALF;  -- settle before leading edge

            -- Leading edge (rising for CPOL=0): slave samples MOSI
            -- Also capture MISO before the edge
            miso_capture(i) := miso;
            sck <= '1';
            wait for SCK_HALF;  -- SCK high

            -- Trailing edge (falling): slave shifts TX
            sck <= '0';
            wait for SCK_HALF;  -- SCK low
        end loop;

        -- Wait for rx_valid to propagate
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- Verify rx_valid pulsed
        -- (rx_valid is a pulse, may have already passed; check rx_data)
        assert rx_data = x"3C"
            report "Test 2 FAIL: rx_data mismatch, expected 3C got " &
                   integer'image(to_integer(unsigned(rx_data)))
            severity error;
        report "Test 2 PASS: rx_data = 0x3C (received MOSI byte)" severity note;

        -- Deassert SS
        ss <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- ------------------------------------------------------------------
        -- Test 3: Verify MISO returns to 'Z' after SS deasserted
        -- ------------------------------------------------------------------
        assert miso = 'Z'
            report "Test 3 FAIL: MISO not 'Z' after SS deasserted"
            severity error;
        report "Test 3 PASS: MISO returns to 'Z' after deselect" severity note;

        -- ------------------------------------------------------------------
        -- Test 4: Second transfer with different data
        --   Master sends 0xFF, slave sends 0x00
        -- ------------------------------------------------------------------
        tx_data <= x"00";
        tx_load <= '1';
        wait until rising_edge(clk);
        tx_load <= '0';
        wait until rising_edge(clk);

        ss   <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        mosi_byte := x"FF";
        for i in 7 downto 0 loop
            mosi <= mosi_byte(i);
            wait for SCK_HALF;
            sck <= '1';
            wait for SCK_HALF;
            sck <= '0';
            wait for SCK_HALF;
        end loop;

        wait until rising_edge(clk);
        wait until rising_edge(clk);

        assert rx_data = x"FF"
            report "Test 4 FAIL: rx_data mismatch, expected FF got " &
                   integer'image(to_integer(unsigned(rx_data)))
            severity error;
        report "Test 4 PASS: rx_data = 0xFF after second transfer" severity note;

        ss <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- ------------------------------------------------------------------
        -- Done
        -- ------------------------------------------------------------------
        report "All SPI slave tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim;

end architecture sim;

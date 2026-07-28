-- ================================================================================
-- tb_ethernet_mac : Testbench for Ethernet MAC controller
-- ================================================================================
-- Verifies basic register read/write functionality and TX operation.
--
-- Tests:
--   1. Write control register (enable Ethernet + TX + RX + promiscuous)
--   2. Write MAC address (low and high)
--   3. Write TX data to FIFO
--   4. Start TX and check status
--   5. Read status register
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_ethernet_mac is
end entity tb_ethernet_mac;

architecture sim of tb_ethernet_mac is

    -- Clock and reset
    signal HCLK    : std_logic := '0';
    signal HRESETn : std_logic := '0';

    -- AHB-Lite slave signals
    signal HSEL      : std_logic                    := '0';
    signal HWRITE    : std_logic                    := '0';
    signal HREADY    : std_logic                    := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "010";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;

    -- MII interface
    signal mii_txd    : std_logic_vector(3 downto 0);
    signal mii_rxd    : std_logic_vector(3 downto 0) := (others => '0');
    signal mii_tx_en  : std_logic;
    signal mii_tx_clk : std_logic := '0';
    signal mii_rx_clk : std_logic := '0';
    signal mii_rx_dv  : std_logic := '0';
    signal mii_tx_er  : std_logic;
    signal mii_rx_er  : std_logic := '0';
    signal mii_crs    : std_logic := '0';
    signal mii_col    : std_logic := '0';

    -- MDIO interface
    signal mdc  : std_logic;
    signal mdio : std_logic := 'Z';

    -- Interrupt
    signal eth_int : std_logic;

    -- Clock periods
    constant CLK_PERIOD    : time := 20 ns;  -- 50 MHz HCLK
    constant MII_CLK_PERIOD : time := 40 ns;  -- 25 MHz MII

begin

    -- Clock generation
    HCLK       <= not HCLK after CLK_PERIOD / 2;
    mii_tx_clk <= not mii_tx_clk after MII_CLK_PERIOD / 2;
    mii_rx_clk <= not mii_rx_clk after MII_CLK_PERIOD / 2;

    -- MII loopback: RX receives what TX sends
    mii_rxd   <= mii_txd;
    mii_rx_dv <= mii_tx_en;

    -- DUT instantiation
    dut : entity work.ethernet_mac_ahb
        generic map (
            CLK_FREQ   => 50_000_000,
            FIFO_DEPTH => 1024
        )
        port map (
            HCLK       => HCLK,
            HRESETn    => HRESETn,
            HSEL       => HSEL,
            HWRITE     => HWRITE,
            HREADY     => HREADY,
            HTRANS     => HTRANS,
            HSIZE      => HSIZE,
            HADDR      => HADDR,
            HWDATA     => HWDATA,
            HRDATA     => HRDATA,
            HRESP      => HRESP,
            HREADYOUT  => HREADYOUT,
            mii_txd    => mii_txd,
            mii_rxd    => mii_rxd,
            mii_tx_en  => mii_tx_en,
            mii_tx_clk => mii_tx_clk,
            mii_rx_clk => mii_rx_clk,
            mii_rx_dv  => mii_rx_dv,
            mii_tx_er  => mii_tx_er,
            mii_rx_er  => mii_rx_er,
            mii_crs    => mii_crs,
            mii_col    => mii_col,
            mdc        => mdc,
            mdio       => mdio,
            eth_int    => eth_int
        );

    -- Stimulus process
    stim : process
        -- AHB write procedure
        procedure ahb_write(addr : in std_logic_vector(31 downto 0);
                            data : in std_logic_vector(31 downto 0)) is
        begin
            HSEL   <= '1';
            HWRITE <= '1';
            HTRANS <= "10";
            HADDR  <= addr;
            HWDATA <= data;
            wait until rising_edge(HCLK);
            HSEL   <= '0';
            HWRITE <= '0';
            HTRANS <= "00";
        end procedure;

        -- AHB read procedure
        procedure ahb_read(addr : in std_logic_vector(31 downto 0);
                           data : out std_logic_vector(31 downto 0)) is
        begin
            HSEL   <= '1';
            HWRITE <= '0';
            HTRANS <= "10";
            HADDR  <= addr;
            wait until rising_edge(HCLK);
            data := HRDATA;
            HSEL   <= '0';
            HTRANS <= "00";
        end procedure;

        variable rdata     : std_logic_vector(31 downto 0);
        variable test_pass : boolean := true;
    begin
        -- Reset sequence
        HRESETn <= '0';
        wait for 100 ns;
        HRESETn <= '1';
        wait until rising_edge(HCLK);

        -- ==================================================================
        -- Test 1: Write control register (enable Ethernet + TX + RX + promiscuous)
        -- ==================================================================
        report "Test 1: Write control register (enable Ethernet)";
        -- bit0=enable, bit1=tx_enable, bit2=rx_enable, bit4=promiscuous => 0x17
        ahb_write(x"00000000", x"00000017");
        ahb_read(x"00000000", rdata);
        assert rdata(0) = '1'
            report "Test 1 FAILED: CTRL enable bit not set" severity error;
        assert rdata(1) = '1'
            report "Test 1 FAILED: CTRL tx_enable bit not set" severity error;
        assert rdata(2) = '1'
            report "Test 1 FAILED: CTRL rx_enable bit not set" severity error;
        if rdata(0) = '1' and rdata(1) = '1' and rdata(2) = '1' then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 2: Write MAC address (low and high)
        -- ==================================================================
        report "Test 2: Write MAC address";
        ahb_write(x"00000008", x"AABBCCDD");  -- MAC_ADDR_L
        ahb_write(x"0000000C", x"0000EEFF");  -- MAC_ADDR_H (16-bit in [15:0])

        ahb_read(x"00000008", rdata);
        assert rdata = x"AABBCCDD"
            report "Test 2 FAILED: MAC_ADDR_L mismatch" severity error;
        if rdata /= x"AABBCCDD" then test_pass := false; end if;

        ahb_read(x"0000000C", rdata);
        assert rdata(15 downto 0) = x"EEFF"
            report "Test 2 FAILED: MAC_ADDR_H mismatch" severity error;
        if rdata(15 downto 0) = x"EEFF" then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 3: Write TX data to FIFO
        -- ==================================================================
        report "Test 3: Write TX data to FIFO";
        -- Write 4 words (16 bytes) to TX FIFO
        ahb_write(x"00000018", x"FFFFFFFF");  -- TX_DATA word 0
        ahb_write(x"00000018", x"FFFF0000");  -- TX_DATA word 1
        ahb_write(x"00000018", x"00000000");  -- TX_DATA word 2
        ahb_write(x"00000018", x"08004500");  -- TX_DATA word 3

        -- Set TX length
        ahb_write(x"00000014", x"00000040");  -- TX_LEN = 64 bytes

        -- Verify TX_LEN
        ahb_read(x"00000014", rdata);
        assert rdata = x"00000040"
            report "Test 3 FAILED: TX_LEN mismatch" severity error;
        if rdata = x"00000040" then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 4: Start TX and check status
        -- ==================================================================
        report "Test 4: Start TX and check status";
        -- Write TX_CTRL with start bit (bit0=1)
        ahb_write(x"00000010", x"00000001");

        -- Wait a few MII clock cycles for TX to start
        wait for 200 ns;

        -- Check status: tx_busy should be set (bit2)
        ahb_read(x"00000004", rdata);
        assert rdata(2) = '1'
            report "Test 4 FAILED: tx_busy not set during transmission" severity error;
        if rdata(2) = '1' then
            report "Test 4 PASSED (tx_busy observed)" severity note;
        else
            -- tx_busy might have already cleared if frame is short; check tx_done
            ahb_read(x"00000004", rdata);
            if rdata(0) = '1' then
                report "Test 4 PASSED (tx_done observed instead)" severity note;
            else
                report "Test 4 FAILED: neither tx_busy nor tx_done set" severity error;
                test_pass := false;
            end if;
        end if;

        -- ==================================================================
        -- Test 5: Read status register after TX completes
        -- ==================================================================
        report "Test 5: Read status register after TX";
        -- Wait for TX to complete (64 bytes at 25 MHz MII ~ 5 us)
        wait for 10 us;

        ahb_read(x"00000004", rdata);
        -- bit0=tx_done, bit2=tx_busy
        assert rdata(0) = '1'
            report "Test 5 FAILED: tx_done not set after transmission" severity error;
        assert rdata(2) = '0'
            report "Test 5 FAILED: tx_busy still set after transmission" severity error;
        if rdata(0) = '1' and rdata(2) = '0' then
            report "Test 5 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Final report
        -- ==================================================================
        if test_pass then
            report "=== ALL ETHERNET MAC TESTS PASSED ===" severity note;
        else
            report "=== ETHERNET MAC TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;

end architecture sim;

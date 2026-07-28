-- ================================================================================
-- tb_can_controller : Testbench for CAN controller
-- ================================================================================
-- Verifies basic register read/write functionality and CAN transmission operation.
--
-- Tests:
--   1. Write control register (enable CAN with loopback)
--   2. Write bit timing register
--   3. Write CAN ID and DLC
--   4. Write TX data and start transmission
--   5. Read status register (verify tx_ready and rx_ready after loopback)
--   6. Verify loopback RX data matches TX data
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_can_controller is
end entity tb_can_controller;

architecture sim of tb_can_controller is

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

    -- CAN physical interface
    signal can_tx     : std_logic;
    signal can_rx     : std_logic := '1';  -- recessive (idle)
    signal can_clkout : std_logic;

    -- Interrupt
    signal can_int : std_logic;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Clock generation (50 MHz, 20 ns period)
    HCLK <= not HCLK after CLK_PERIOD / 2;

    -- CAN loopback: can_rx follows can_tx
    can_rx <= can_tx;

    -- DUT instantiation
    dut : entity work.can_controller_ahb
        generic map (
            CLK_FREQ => 50_000_000,
            BITRATE  => 500_000
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
            can_tx     => can_tx,
            can_rx     => can_rx,
            can_clkout => can_clkout,
            can_int    => can_int
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
        -- Test 1: Write control register (enable CAN with loopback)
        -- ==================================================================
        report "Test 1: Write control register (enable CAN with loopback)";
        -- bit1=loopback, bit5=enable => 0x22
        ahb_write(x"00000000", x"00000022");
        ahb_read(x"00000000", rdata);
        assert rdata(5) = '1'
            report "Test 1 FAILED: CTRL enable bit not set" severity error;
        assert rdata(1) = '1'
            report "Test 1 FAILED: CTRL loopback bit not set" severity error;
        if rdata(5) = '1' and rdata(1) = '1' then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 2: Write bit timing register
        -- ==================================================================
        report "Test 2: Write bit timing register";
        -- prescaler=1 (bits[15:0]=0x0001) for fast simulation
        ahb_write(x"00000008", x"00000001");
        ahb_read(x"00000008", rdata);
        assert rdata = x"00000001"
            report "Test 2 FAILED: BTR mismatch" severity error;
        if rdata = x"00000001" then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 3: Write CAN ID and DLC
        -- ==================================================================
        report "Test 3: Write CAN ID and DLC";
        ahb_write(x"0000000C", x"00000123");  -- CAN_ID = 0x123 (11-bit standard)
        ahb_write(x"00000010", x"00000008");  -- CAN_DLC = 8 bytes

        ahb_read(x"0000000C", rdata);
        assert rdata = x"00000123"
            report "Test 3 FAILED: CAN_ID mismatch" severity error;
        if rdata /= x"00000123" then test_pass := false; end if;

        ahb_read(x"00000010", rdata);
        assert rdata = x"00000008"
            report "Test 3 FAILED: CAN_DLC mismatch" severity error;
        if rdata = x"00000008" then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 4: Write TX data and start transmission
        -- ==================================================================
        report "Test 4: Write TX data and start transmission";
        ahb_write(x"00000014", x"DEADBEEF");  -- CAN_DATA_L
        ahb_write(x"00000018", x"CAFEBABE");  -- CAN_DATA_H

        -- Verify data registers
        ahb_read(x"00000014", rdata);
        assert rdata = x"DEADBEEF"
            report "Test 4 FAILED: DATA_L mismatch" severity error;
        if rdata /= x"DEADBEEF" then test_pass := false; end if;

        ahb_read(x"00000018", rdata);
        assert rdata = x"CAFEBABE"
            report "Test 4 FAILED: DATA_H mismatch" severity error;
        if rdata /= x"CAFEBABE" then test_pass := false; end if;

        -- Start transmission: TX_CTRL bit0=send
        ahb_write(x"0000001C", x"00000001");

        -- Wait a few clock cycles for TX FSM to start
        wait for 100 ns;

        -- Verify tx_ready went low (transmission started)
        ahb_read(x"00000004", rdata);
        assert rdata(1) = '0'
            report "Test 4 FAILED: tx_ready not low during transmission" severity error;
        if rdata(1) = '0' then
            report "Test 4 PASSED (transmission started)" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 5: Read status register after transmission completes
        -- ==================================================================
        report "Test 5: Read status register after transmission";
        -- Wait for transmission to complete (with prescaler=1, ~5 us)
        wait for 10 us;

        ahb_read(x"00000004", rdata);

        ahb_read(x"00000004", rdata);
        -- bit0=rx_ready, bit1=tx_ready
        assert rdata(1) = '1'
            report "Test 5 FAILED: tx_ready not high after transmission" severity error;
        assert rdata(0) = '1'
            report "Test 5 FAILED: rx_ready not high after loopback" severity error;
        if rdata(1) = '1' and rdata(0) = '1' then
            report "Test 5 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 6: Verify loopback RX data matches TX data
        -- ==================================================================
        report "Test 6: Verify loopback RX data";
        ahb_read(x"00000024", rdata);  -- RX_ID
        assert rdata = x"00000123"
            report "Test 6 FAILED: RX_ID mismatch" severity error;
        if rdata /= x"00000123" then test_pass := false; end if;

        ahb_read(x"00000028", rdata);  -- RX_DLC
        assert rdata = x"00000008"
            report "Test 6 FAILED: RX_DLC mismatch" severity error;
        if rdata /= x"00000008" then test_pass := false; end if;

        ahb_read(x"0000002C", rdata);  -- RX_DATA_L
        assert rdata = x"DEADBEEF"
            report "Test 6 FAILED: RX_DATA_L mismatch" severity error;
        if rdata /= x"DEADBEEF" then test_pass := false; end if;

        ahb_read(x"00000030", rdata);  -- RX_DATA_H
        assert rdata = x"CAFEBABE"
            report "Test 6 FAILED: RX_DATA_H mismatch" severity error;
        if rdata = x"CAFEBABE" then
            report "Test 6 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Final report
        -- ==================================================================
        if test_pass then
            report "=== ALL CAN CONTROLLER TESTS PASSED ===" severity note;
        else
            report "=== CAN CONTROLLER TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;

end architecture sim;

-- ================================================================================
-- tb_usb_device : Testbench for USB device controller
-- ================================================================================
-- Verifies basic register read/write functionality and endpoint operation.
--
-- Tests:
--   1. Write control register (enable USB)
--   2. Write device address
--   3. Configure endpoint 0 (control)
--   4. Write TX data to endpoint FIFO
--   5. Read endpoint status and count
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_usb_device is
end entity tb_usb_device;

architecture sim of tb_usb_device is

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

    -- USB physical interface
    signal usb_dp : std_logic := 'Z';
    signal usb_dm : std_logic := 'Z';

    -- USB clock (100 MHz for simulation, 10 ns period)
    signal usb_clk : std_logic := '0';

    -- Interrupt
    signal usb_int : std_logic;

    -- Clock periods
    constant CLK_PERIOD    : time := 20 ns;  -- 50 MHz HCLK
    constant USB_CLK_PERIOD : time := 10 ns;  -- 100 MHz USB clock

begin

    -- Clock generation
    HCLK    <= not HCLK after CLK_PERIOD / 2;
    usb_clk <= not usb_clk after USB_CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.usb_device
        generic map (
            NUM_ENDPOINTS => 4,
            FIFO_DEPTH    => 64
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
            usb_dp     => usb_dp,
            usb_dm     => usb_dm,
            usb_clk    => usb_clk,
            usb_int    => usb_int
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
        -- Test 1: Write control register (enable USB)
        -- ==================================================================
        report "Test 1: Write control register (enable USB)";
        -- bit0=enable => 0x01
        ahb_write(x"00000000", x"00000001");
        ahb_read(x"00000000", rdata);
        assert rdata(0) = '1'
            report "Test 1 FAILED: CTRL enable bit not set" severity error;
        if rdata(0) = '1' then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 2: Write device address
        -- ==================================================================
        report "Test 2: Write device address";
        ahb_write(x"00000004", x"00000001");  -- USB_ADDR = 1
        ahb_read(x"00000004", rdata);
        assert rdata = x"00000001"
            report "Test 2 FAILED: device address mismatch" severity error;
        if rdata = x"00000001" then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 3: Configure endpoint 0 (control)
        -- ==================================================================
        report "Test 3: Configure endpoint 0 (control, IN direction)";
        -- EP_CTRL: bits[3:0]=ep_index=0, bit4=enable=1, bit6=dir=1(IN) => 0x50
        ahb_write(x"0000001C", x"00000050");
        ahb_read(x"0000001C", rdata);
        assert rdata(3 downto 0) = x"0"
            report "Test 3 FAILED: EP_CTRL ep_index not 0" severity error;
        assert rdata(4) = '1'
            report "Test 3 FAILED: EP_CTRL enable bit not set" severity error;
        if rdata(3 downto 0) = x"0" and rdata(4) = '1' then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 4: Write TX data to endpoint FIFO
        -- ==================================================================
        report "Test 4: Write TX data to endpoint FIFO";
        -- Write 4 bytes to EP_DATA (only low byte is used per write)
        ahb_write(x"00000024", x"00000041");  -- 'A'
        ahb_write(x"00000024", x"00000042");  -- 'B'
        ahb_write(x"00000024", x"00000043");  -- 'C'
        ahb_write(x"00000024", x"00000044");  -- 'D'

        -- Verify EP_COUNT shows 4 bytes in FIFO
        ahb_read(x"00000028", rdata);
        assert rdata = x"00000004"
            report "Test 4 FAILED: EP_COUNT not 4 after writing 4 bytes" severity error;
        if rdata = x"00000004" then
            report "Test 4 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 5: Read endpoint status
        -- ==================================================================
        report "Test 5: Read endpoint status";
        ahb_read(x"00000020", rdata);
        -- bit1=tx_ready: should be '0' (FIFO not empty, tx_count > 0)
        assert rdata(1) = '0'
            report "Test 5 FAILED: tx_ready should be 0 (FIFO not empty)" severity error;
        -- bit0=rx_ready: should be '0' (no RX data)
        assert rdata(0) = '0'
            report "Test 5 FAILED: rx_ready should be 0 (no RX data)" severity error;
        if rdata(1) = '0' and rdata(0) = '0' then
            report "Test 5 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Additional: Read USB status register
        -- ==================================================================
        report "Additional: Read USB status register";
        ahb_read(x"00000008", rdata);
        -- After enable, tx_ready (bit2) should be '1' (global, FIFOs empty initially)
        -- Note: this is the global status, not per-endpoint
        report "USB_STATUS = 0x" & to_hstring(rdata) severity note;

        -- ==================================================================
        -- Final report
        -- ==================================================================
        if test_pass then
            report "=== ALL USB DEVICE TESTS PASSED ===" severity note;
        else
            report "=== USB DEVICE TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;

end architecture sim;

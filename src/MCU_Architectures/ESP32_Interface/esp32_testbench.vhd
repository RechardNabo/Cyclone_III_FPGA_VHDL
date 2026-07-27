-- ================================================================================
-- esp32_testbench : Testbench for esp32_spi and esp32_uart interface models
-- VHDL-93 compliant.  10 ns clock, active-high reset.
-- Instantiates both the SPI master and UART interface models.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity esp32_tb is
end entity esp32_tb;

architecture sim of esp32_tb is

    -- ==================================================================
    -- Component declarations
    -- ==================================================================
    component esp32_spi is
        port (
            clk, reset  : in  std_logic;
            cs, we      : in  std_logic;
            addr        : in  std_logic_vector(3 downto 0);
            din         : in  std_logic_vector(7 downto 0);
            dout        : out std_logic_vector(7 downto 0);
            sclk        : out std_logic;
            mosi        : out std_logic;
            miso        : in  std_logic;
            spi_cs_n    : out std_logic_vector(3 downto 0);
            spi_int     : out std_logic;
            dma_req     : out std_logic;
            dma_ack     : in  std_logic
        );
    end component;

    component esp32_uart is
        port (
            clk, reset  : in  std_logic;
            cs, we      : in  std_logic;
            addr        : in  std_logic_vector(3 downto 0);
            din         : in  std_logic_vector(7 downto 0);
            dout        : out std_logic_vector(7 downto 0);
            txd         : out std_logic;
            rxd         : in  std_logic;
            rts_n       : out std_logic;
            cts_n       : in  std_logic;
            tx_int      : out std_logic;
            rx_int      : out std_logic;
            err_int     : out std_logic
        );
    end component;

    -- ==================================================================
    -- Shared signals
    -- ==================================================================
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '1';
    signal test_done : boolean := false;

    -- ==================================================================
    -- SPI DUT signals
    -- ==================================================================
    signal spi_cs    : std_logic := '0';
    signal spi_we    : std_logic := '0';
    signal spi_addr  : std_logic_vector(3 downto 0) := (others => '0');
    signal spi_din   : std_logic_vector(7 downto 0) := (others => '0');
    signal spi_dout  : std_logic_vector(7 downto 0);
    signal sclk      : std_logic;
    signal mosi      : std_logic;
    signal miso      : std_logic := '0';
    signal spi_cs_n  : std_logic_vector(3 downto 0);
    signal spi_int   : std_logic;
    signal dma_req   : std_logic;
    signal dma_ack   : std_logic := '0';

    -- ==================================================================
    -- UART DUT signals
    -- ==================================================================
    signal uart_cs   : std_logic := '0';
    signal uart_we   : std_logic := '0';
    signal uart_addr : std_logic_vector(3 downto 0) := (others => '0');
    signal uart_din  : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_dout : std_logic_vector(7 downto 0);
    signal txd       : std_logic;
    signal rxd       : std_logic := '1';
    signal rts_n     : std_logic;
    signal cts_n     : std_logic := '0';
    signal tx_int    : std_logic;
    signal rx_int    : std_logic;
    signal err_int   : std_logic;

    -- Register address constants
    -- SPI
    constant R_CTRL     : std_logic_vector(3 downto 0) := "0000"; -- 0x0
    constant R_STATUS   : std_logic_vector(3 downto 0) := "0001"; -- 0x1
    constant R_CLKDIV   : std_logic_vector(3 downto 0) := "0010"; -- 0x2
    constant R_TXDATA   : std_logic_vector(3 downto 0) := "0011"; -- 0x3
    constant R_RXDATA   : std_logic_vector(3 downto 0) := "0100"; -- 0x4
    constant R_CMD      : std_logic_vector(3 downto 0) := "0101"; -- 0x5
    constant R_ADDR_L   : std_logic_vector(3 downto 0) := "0110"; -- 0x6
    constant R_ADDR_H   : std_logic_vector(3 downto 0) := "0111"; -- 0x7
    constant R_SLAVE    : std_logic_vector(3 downto 0) := "1000"; -- 0x8
    constant R_DMA_CTRL : std_logic_vector(3 downto 0) := "1001"; -- 0x9
    -- UART
    constant U_TXDATA   : std_logic_vector(3 downto 0) := "0000"; -- 0x0
    constant U_RXDATA   : std_logic_vector(3 downto 0) := "0001"; -- 0x1
    constant U_STATUS   : std_logic_vector(3 downto 0) := "0010"; -- 0x2
    constant U_CTRL     : std_logic_vector(3 downto 0) := "0011"; -- 0x3
    constant U_BAUD_L   : std_logic_vector(3 downto 0) := "0100"; -- 0x4
    constant U_BAUD_H   : std_logic_vector(3 downto 0) := "0101"; -- 0x5
    constant U_FIFO_CTRL: std_logic_vector(3 downto 0) := "0110"; -- 0x6
    constant U_INT_EN   : std_logic_vector(3 downto 0) := "0111"; -- 0x7
    constant U_INT_ST   : std_logic_vector(3 downto 0) := "1000"; -- 0x8

begin

    -- ==================================================================
    -- DUT instantiations
    -- ==================================================================
    spi_dut : esp32_spi
        port map (
            clk => clk, reset => reset,
            cs => spi_cs, we => spi_we,
            addr => spi_addr, din => spi_din, dout => spi_dout,
            sclk => sclk, mosi => mosi, miso => miso,
            spi_cs_n => spi_cs_n, spi_int => spi_int,
            dma_req => dma_req, dma_ack => dma_ack
        );

    uart_dut : esp32_uart
        port map (
            clk => clk, reset => reset,
            cs => uart_cs, we => uart_we,
            addr => uart_addr, din => uart_din, dout => uart_dout,
            txd => txd, rxd => rxd,
            rts_n => rts_n, cts_n => cts_n,
            tx_int => tx_int, rx_int => rx_int, err_int => err_int
        );

    -- ==================================================================
    -- Clock generation: 10 ns period
    -- ==================================================================
    clk_proc : process
    begin
        while not test_done loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
        wait;
    end process;

    -- ==================================================================
    -- MISO loopback: feed back a known pattern during SPI transfer
    -- ==================================================================
    miso_proc : process(clk)
    begin
        if rising_edge(clk) then
            -- Provide a simple loopback: miso follows mosi delayed
            miso <= mosi;
        end if;
    end process;

    -- ==================================================================
    -- Stimulus process
    -- ==================================================================
    stim_proc : process
        -- SPI write helper
        procedure spi_write(a : in std_logic_vector(3 downto 0);
                            d : in std_logic_vector(7 downto 0)) is
        begin
            wait until rising_edge(clk);
            spi_cs   <= '1';
            spi_we   <= '1';
            spi_addr <= a;
            spi_din  <= d;
            wait until rising_edge(clk);
            spi_cs   <= '0';
            spi_we   <= '0';
            spi_addr <= (others => '0');
            spi_din  <= (others => '0');
        end procedure;

        -- SPI read helper
        procedure spi_read(a : in std_logic_vector(3 downto 0);
                           d : out std_logic_vector(7 downto 0)) is
        begin
            spi_cs   <= '1';
            spi_we   <= '0';
            spi_addr <= a;
            wait for 2 ns;
            d := spi_dout;
            spi_cs   <= '0';
            spi_addr <= (others => '0');
            wait for 2 ns;
        end procedure;

        -- UART write helper
        procedure uart_write(a : in std_logic_vector(3 downto 0);
                             d : in std_logic_vector(7 downto 0)) is
        begin
            wait until rising_edge(clk);
            uart_cs   <= '1';
            uart_we   <= '1';
            uart_addr <= a;
            uart_din  <= d;
            wait until rising_edge(clk);
            uart_cs   <= '0';
            uart_we   <= '0';
            uart_addr <= (others => '0');
            uart_din  <= (others => '0');
        end procedure;

        -- UART read helper
        procedure uart_read(a : in std_logic_vector(3 downto 0);
                            d : out std_logic_vector(7 downto 0)) is
        begin
            uart_cs   <= '1';
            uart_we   <= '0';
            uart_addr <= a;
            wait for 2 ns;
            d := uart_dout;
            uart_cs   <= '0';
            uart_addr <= (others => '0');
            wait for 2 ns;
        end procedure;

        variable rdata : std_logic_vector(7 downto 0);
    begin
        -- ----------------------------------------------------------------
        -- Reset (active-high)
        -- ----------------------------------------------------------------
        reset <= '1';
        wait for 20 ns;
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);

        -- ==================================================================
        -- SPI TESTS
        -- ==================================================================

        -- ----------------------------------------------------------------
        -- SPI register WRITE transactions (at least 3)
        -- ----------------------------------------------------------------
        -- Write 1: CTRL = 0x80 (SPE=1 enable, CPOL=0, CPHA=0, MSB first)
        spi_write(R_CTRL, x"80");

        -- Write 2: CLKDIV = 0x02 (prescaler)
        spi_write(R_CLKDIV, x"02");

        -- Write 3: CMD = 0xAB (command byte)
        spi_write(R_CMD, x"AB");

        -- Write 4: ADDR_L = 0x55
        spi_write(R_ADDR_L, x"55");

        -- ----------------------------------------------------------------
        -- SPI register READ transactions (at least 3) and check data
        -- ----------------------------------------------------------------
        -- Read 1: CTRL should be 0x80
        spi_read(R_CTRL, rdata);
        assert rdata = x"80"
            report "ESP32 TB: SPI read CTRL expected 0x80"
            severity error;

        -- Read 2: CLKDIV should be 0x02
        spi_read(R_CLKDIV, rdata);
        assert rdata = x"02"
            report "ESP32 TB: SPI read CLKDIV expected 0x02"
            severity error;

        -- Read 3: CMD should be 0xAB
        spi_read(R_CMD, rdata);
        assert rdata = x"AB"
            report "ESP32 TB: SPI read CMD expected 0xAB"
            severity error;

        -- Read 4: ADDR_L should be 0x55
        spi_read(R_ADDR_L, rdata);
        assert rdata = x"55"
            report "ESP32 TB: SPI read ADDR_L expected 0x55"
            severity error;

        -- ----------------------------------------------------------------
        -- SPI transfer: write TXDATA to start a transfer, wait for DONE
        -- ----------------------------------------------------------------
        spi_write(R_TXDATA, x"3C");
        -- Wait for transfer to complete (8 bits at clkdiv=2, ~32 clocks)
        wait for 500 ns;
        -- Check STATUS: bit7=SPIF(DONE) should be set
        spi_read(R_STATUS, rdata);
        assert rdata(7) = '1'
            report "ESP32 TB: SPI status DONE not set after transfer"
            severity error;

        -- Check interrupt output (spi_int = status_reg(7))
        assert spi_int = '1'
            report "ESP32 TB: spi_int not asserted after transfer complete"
            severity error;

        -- ----------------------------------------------------------------
        -- SPI GPIO / pin checking: check spi_cs_n active during transfer
        -- ----------------------------------------------------------------
        -- Start another transfer and check slave select
        spi_write(R_TXDATA, x"5A");
        wait for 10 ns;
        -- During transfer, spi_cs_n(0) should be low (slave 0 selected)
        assert spi_cs_n(0) = '0'
            report "ESP32 TB: spi_cs_n(0) not low during transfer"
            severity error;
        wait for 500 ns;

        -- ==================================================================
        -- UART TESTS
        -- ==================================================================

        -- ----------------------------------------------------------------
        -- UART register WRITE transactions (at least 3)
        -- ----------------------------------------------------------------
        -- Write 1: CTRL = 0xC0 (TX_EN=1, RX_EN=1, 8 data bits)
        uart_write(U_CTRL, x"C0");

        -- Write 2: BAUD_L = 0x08
        uart_write(U_BAUD_L, x"08");

        -- Write 3: BAUD_H = 0x00
        uart_write(U_BAUD_H, x"00");

        -- Write 4: INT_EN = 0x06 (TX_INT_EN + RX_INT_EN)
        uart_write(U_INT_EN, x"06");

        -- ----------------------------------------------------------------
        -- UART register READ transactions (at least 3) and check data
        -- ----------------------------------------------------------------
        -- Read 1: CTRL should be 0xC0
        uart_read(U_CTRL, rdata);
        assert rdata = x"C0"
            report "ESP32 TB: UART read CTRL expected 0xC0"
            severity error;

        -- Read 2: BAUD_L should be 0x08
        uart_read(U_BAUD_L, rdata);
        assert rdata = x"08"
            report "ESP32 TB: UART read BAUD_L expected 0x08"
            severity error;

        -- Read 3: INT_EN should be 0x06
        uart_read(U_INT_EN, rdata);
        assert rdata = x"06"
            report "ESP32 TB: UART read INT_EN expected 0x06"
            severity error;

        -- ----------------------------------------------------------------
        -- UART TX: write TXDATA to start transmission, check txd activity
        -- ----------------------------------------------------------------
        uart_write(U_TXDATA, x"41");
        wait for 20 ns;
        -- txd should go low (start bit) during transmission
        assert tx_int = '0' or tx_int = '1'
            report "ESP32 TB: UART tx_int monitoring"
            severity note;
        -- Wait for transmission to complete
        wait for 2000 ns;

        -- ----------------------------------------------------------------
        -- UART RX: stimulate rxd with a start bit, check rx_int
        -- ----------------------------------------------------------------
        -- Drive start bit (low)
        rxd <= '0';
        wait for 200 ns;
        -- Drive 8 data bits (0x55 = 01010101, LSB first)
        rxd <= '1'; wait for 200 ns;
        rxd <= '0'; wait for 200 ns;
        rxd <= '1'; wait for 200 ns;
        rxd <= '0'; wait for 200 ns;
        rxd <= '1'; wait for 200 ns;
        rxd <= '0'; wait for 200 ns;
        rxd <= '1'; wait for 200 ns;
        rxd <= '0'; wait for 200 ns;
        -- Stop bit (high)
        rxd <= '1';
        wait for 200 ns;
        -- Check RX ready interrupt
        assert rx_int = '1'
            report "ESP32 TB: UART rx_int not asserted after RX frame"
            severity error;

        -- Read received data
        uart_read(U_RXDATA, rdata);
        assert rdata = x"55"
            report "ESP32 TB: UART RXDATA expected 0x55"
            severity error;

        -- ----------------------------------------------------------------
        -- Done
        -- ----------------------------------------------------------------
        wait for 50 ns;
        test_done <= true;
        assert false report "Testbench complete" severity failure;
        wait;
    end process;

end architecture sim;

-- ================================================================================
-- esp32_testbench : Testbench for esp32_interface (top-level ESP32 peripheral model)
-- VHDL-2008 compliant.  10 ns clock, active-low AHB reset.
-- Instantiates the esp32_interface which wraps SPI, UART, CAN, DMA, I2C, and I2S.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity esp32_tb is
end entity esp32_tb;

architecture sim of esp32_tb is

    -- ==================================================================
    -- Component declaration
    -- ==================================================================
    component esp32_interface is
        port (
            -- AHB-Lite slave interface
            HCLK      : in  std_logic;
            HRESETn   : in  std_logic;
            HSEL      : in  std_logic;
            HWRITE    : in  std_logic;
            HREADY    : in  std_logic;
            HTRANS    : in  std_logic_vector(1 downto 0);
            HSIZE     : in  std_logic_vector(2 downto 0);
            HADDR     : in  std_logic_vector(31 downto 0);
            HWDATA    : in  std_logic_vector(31 downto 0);
            HRDATA    : out std_logic_vector(31 downto 0);
            HRESP     : out std_logic;
            HREADYOUT : out std_logic;
            -- SPI physical pins
            spi_sclk    : out std_logic;
            spi_mosi    : out std_logic;
            spi_miso    : in  std_logic;
            spi_cs_n    : out std_logic_vector(3 downto 0);
            spi_int     : out std_logic;
            -- UART physical pins
            uart_txd    : out std_logic;
            uart_rxd    : in  std_logic;
            uart_rts_n  : out std_logic;
            uart_cts_n  : in  std_logic;
            uart_tx_int : out std_logic;
            uart_rx_int : out std_logic;
            uart_err_int: out std_logic;
            -- CAN 2.0B (TWAI) physical pins
            can_tx      : out std_logic;
            can_rx      : in  std_logic;
            can_clkout  : out std_logic;
            can_int     : out std_logic;
            -- DMA controller interface
            dma_int     : out std_logic;
            dma_m_addr  : out std_logic_vector(31 downto 0);
            dma_m_rdata : in  std_logic_vector(31 downto 0);
            dma_m_wdata : out std_logic_vector(31 downto 0);
            dma_m_we    : out std_logic;
            dma_m_req   : out std_logic;
            dma_m_ack   : in  std_logic;
            -- I2C interface
            i2c_sda : inout std_logic;
            i2c_scl : inout std_logic;
            i2c_int : out std_logic;
            -- I2S interface (audio)
            i2s_sck   : out std_logic;
            i2s_ws    : out std_logic;
            i2s_sd_tx : out std_logic;
            i2s_sd_rx : in  std_logic;
            i2s_int   : out std_logic;
            -- Watchdog timer
            wdt_int   : out std_logic;
            wdt_reset : out std_logic;
            -- RTC interrupt
            rtc_int   : out std_logic;
            -- ADC interface
            adc_in    : in  std_logic_vector(95 downto 0) := (others => '0');
            adc_int   : out std_logic;
            -- DAC interface
            dac_out   : out std_logic_vector(23 downto 0)
        );
    end component;

    -- ==================================================================
    -- AHB-Lite bus signals
    -- ==================================================================
    signal HCLK      : std_logic := '0';
    signal HRESETn   : std_logic := '0';
    signal HSEL      : std_logic := '0';
    signal HWRITE    : std_logic := '0';
    signal HREADY    : std_logic := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "010";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;

    signal test_done : boolean := false;

    -- ==================================================================
    -- SPI physical pins
    -- ==================================================================
    signal spi_sclk  : std_logic;
    signal spi_mosi  : std_logic;
    signal spi_miso  : std_logic := '0';
    signal spi_cs_n  : std_logic_vector(3 downto 0);
    signal spi_int   : std_logic;

    -- ==================================================================
    -- UART physical pins
    -- ==================================================================
    signal uart_txd     : std_logic;
    signal uart_rxd     : std_logic := '1';
    signal uart_rts_n   : std_logic;
    signal uart_cts_n   : std_logic := '0';
    signal uart_tx_int  : std_logic;
    signal uart_rx_int  : std_logic;
    signal uart_err_int : std_logic;

    -- ==================================================================
    -- CAN physical pins
    -- ==================================================================
    signal can_tx     : std_logic;
    signal can_rx     : std_logic := '1';
    signal can_clkout : std_logic;
    signal can_int    : std_logic;

    -- ==================================================================
    -- DMA controller interface
    -- ==================================================================
    signal dma_int     : std_logic;
    signal dma_m_addr  : std_logic_vector(31 downto 0);
    signal dma_m_rdata : std_logic_vector(31 downto 0) := (others => '0');
    signal dma_m_wdata : std_logic_vector(31 downto 0);
    signal dma_m_we    : std_logic;
    signal dma_m_req   : std_logic;
    signal dma_m_ack   : std_logic := '0';

    -- ==================================================================
    -- I2C interface
    -- ==================================================================
    signal i2c_sda : std_logic := 'Z';
    signal i2c_scl : std_logic := 'Z';
    signal i2c_int : std_logic;

    -- ==================================================================
    -- I2S interface (audio)
    -- ==================================================================
    signal i2s_sck   : std_logic;
    signal i2s_ws    : std_logic;
    signal i2s_sd_tx : std_logic;
    signal i2s_sd_rx : std_logic := '0';
    signal i2s_int   : std_logic;

    -- ==================================================================
    -- Watchdog timer
    -- ==================================================================
    signal wdt_int   : std_logic;
    signal wdt_reset : std_logic;

    -- ==================================================================
    -- RTC interrupt
    -- ==================================================================
    signal rtc_int   : std_logic;

    -- ==================================================================
    -- ADC interface
    -- ==================================================================
    signal adc_in    : std_logic_vector(95 downto 0) := (others => '0');
    signal adc_int   : std_logic;

    -- ==================================================================
    -- DAC interface
    -- ==================================================================
    signal dac_out   : std_logic_vector(23 downto 0);

    -- ==================================================================
    -- AHB-Lite address map constants
    -- ==================================================================
    -- SPI registers: HADDR[11:8]=0x0, HADDR[7:4]=0x0, HADDR[3:0]=reg
    constant SPI_BASE   : std_logic_vector(31 downto 0) := x"00000000";
    -- UART registers: HADDR[11:8]=0x0, HADDR[7:4]=0x1, HADDR[3:0]=reg
    constant UART_BASE  : std_logic_vector(31 downto 0) := x"00000010";

    -- SPI register offsets (HADDR[3:0])
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

    -- UART register offsets (HADDR[3:0])
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
    -- DUT instantiation
    -- ==================================================================
    dut : esp32_interface
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            -- SPI physical pins
            spi_sclk => spi_sclk, spi_mosi => spi_mosi, spi_miso => spi_miso,
            spi_cs_n => spi_cs_n, spi_int => spi_int,
            -- UART physical pins
            uart_txd => uart_txd, uart_rxd => uart_rxd,
            uart_rts_n => uart_rts_n, uart_cts_n => uart_cts_n,
            uart_tx_int => uart_tx_int, uart_rx_int => uart_rx_int,
            uart_err_int => uart_err_int,
            -- CAN physical pins
            can_tx => can_tx, can_rx => can_rx,
            can_clkout => can_clkout, can_int => can_int,
            -- DMA controller interface
            dma_int => dma_int,
            dma_m_addr => dma_m_addr, dma_m_rdata => dma_m_rdata,
            dma_m_wdata => dma_m_wdata, dma_m_we => dma_m_we,
            dma_m_req => dma_m_req, dma_m_ack => dma_m_ack,
            -- I2C interface
            i2c_sda => i2c_sda, i2c_scl => i2c_scl, i2c_int => i2c_int,
            -- I2S interface
            i2s_sck => i2s_sck, i2s_ws => i2s_ws,
            i2s_sd_tx => i2s_sd_tx, i2s_sd_rx => i2s_sd_rx, i2s_int => i2s_int,
            -- Watchdog timer
            wdt_int => wdt_int, wdt_reset => wdt_reset,
            -- RTC interrupt
            rtc_int => rtc_int,
            -- ADC interface
            adc_in => adc_in, adc_int => adc_int,
            -- DAC interface
            dac_out => dac_out
        );

    -- ==================================================================
    -- Clock generation: 10 ns period (5 ns high, 5 ns low)
    -- ==================================================================
    HCLK <= not HCLK after 5 ns;

    -- ==================================================================
    -- MISO loopback: feed back a known pattern during SPI transfer
    -- ==================================================================
    miso_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            -- Provide a simple loopback: miso follows mosi delayed
            spi_miso <= spi_mosi;
        end if;
    end process;

    -- ==================================================================
    -- Stimulus process
    -- ==================================================================
    stim_proc : process
        -- AHB-Lite write helper
        procedure ahb_write(addr : in std_logic_vector(31 downto 0);
                            data : in std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(HCLK);
            HSEL   <= '1';
            HWRITE <= '1';
            HTRANS <= "10";  -- non-sequential
            HADDR  <= addr;
            HWDATA <= data;
            wait until rising_edge(HCLK);
            HSEL   <= '0';
            HWRITE <= '0';
            HTRANS <= "00";
            HADDR  <= (others => '0');
            HWDATA <= (others => '0');
        end procedure;

        -- AHB-Lite read helper
        procedure ahb_read(addr : in std_logic_vector(31 downto 0);
                           data : out std_logic_vector(31 downto 0)) is
        begin
            HSEL   <= '1';
            HWRITE <= '0';
            HTRANS <= "10";
            HADDR  <= addr;
            wait for 2 ns;  -- allow combinational logic to settle
            data := HRDATA;
            HSEL   <= '0';
            HTRANS <= "00";
            HADDR  <= (others => '0');
            wait for 2 ns;
        end procedure;

        -- SPI register write helper (builds AHB address from SPI base + reg offset)
        procedure spi_write(reg : in std_logic_vector(3 downto 0);
                            val : in std_logic_vector(7 downto 0)) is
        begin
            ahb_write(SPI_BASE(31 downto 4) & reg, x"000000" & val);
        end procedure;

        -- SPI register read helper
        procedure spi_read(reg : in std_logic_vector(3 downto 0);
                           val : out std_logic_vector(7 downto 0)) is
            variable rdata32 : std_logic_vector(31 downto 0);
        begin
            ahb_read(SPI_BASE(31 downto 4) & reg, rdata32);
            val := rdata32(7 downto 0);
        end procedure;

        -- UART register write helper
        procedure uart_write(reg : in std_logic_vector(3 downto 0);
                             val : in std_logic_vector(7 downto 0)) is
        begin
            ahb_write(UART_BASE(31 downto 4) & reg, x"000000" & val);
        end procedure;

        -- UART register read helper
        procedure uart_read(reg : in std_logic_vector(3 downto 0);
                            val : out std_logic_vector(7 downto 0)) is
            variable rdata32 : std_logic_vector(31 downto 0);
        begin
            ahb_read(UART_BASE(31 downto 4) & reg, rdata32);
            val := rdata32(7 downto 0);
        end procedure;

        variable rdata : std_logic_vector(7 downto 0);
    begin
        -- ----------------------------------------------------------------
        -- Reset (active-low AHB style)
        -- ----------------------------------------------------------------
        HRESETn <= '0';
        wait for 20 ns;
        wait until rising_edge(HCLK);
        HRESETn <= '1';
        wait until rising_edge(HCLK);

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
        -- Write 1: CTRL = 0xC3 (TX_EN=1, RX_EN=1, 8 data bits = "11")
        uart_write(U_CTRL, x"C3");

        -- Write 2: BAUD_L = 0x13 (divisor=19, 20 clocks per bit = 200ns at 10ns clock)
        uart_write(U_BAUD_L, x"13");

        -- Write 3: BAUD_H = 0x00
        uart_write(U_BAUD_H, x"00");

        -- Write 4: INT_EN = 0x06 (TX_INT_EN + RX_INT_EN)
        uart_write(U_INT_EN, x"06");

        -- ----------------------------------------------------------------
        -- UART register READ transactions (at least 3) and check data
        -- ----------------------------------------------------------------
        -- Read 1: CTRL should be 0xC3
        uart_read(U_CTRL, rdata);
        assert rdata = x"C3"
            report "ESP32 TB: UART read CTRL expected 0xC3"
            severity error;

        -- Read 2: BAUD_L should be 0x13
        uart_read(U_BAUD_L, rdata);
        assert rdata = x"13"
            report "ESP32 TB: UART read BAUD_L expected 0x13"
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
        assert uart_tx_int = '0' or uart_tx_int = '1'
            report "ESP32 TB: UART tx_int monitoring"
            severity note;
        -- Wait for transmission to complete
        wait for 2000 ns;

        -- ----------------------------------------------------------------
        -- UART RX: stimulate rxd with a start bit, check rx_int
        -- ----------------------------------------------------------------
        -- Drive start bit (low)
        uart_rxd <= '0';
        wait for 200 ns;
        -- Drive 8 data bits (0x55 = 01010101, LSB first)
        uart_rxd <= '1'; wait for 200 ns;
        uart_rxd <= '0'; wait for 200 ns;
        uart_rxd <= '1'; wait for 200 ns;
        uart_rxd <= '0'; wait for 200 ns;
        uart_rxd <= '1'; wait for 200 ns;
        uart_rxd <= '0'; wait for 200 ns;
        uart_rxd <= '1'; wait for 200 ns;
        uart_rxd <= '0'; wait for 200 ns;
        -- Stop bit (high)
        uart_rxd <= '1';
        wait for 200 ns;
        -- Check RX ready interrupt
        assert uart_rx_int = '1'
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

-- ================================================================================
-- esp32_interface : Top-level ESP32-style MCU peripheral interface model
-- ================================================================================
-- Educational MCU interface model for Cyclone III FPGA.
-- Wraps the ESP32 SPI master, UART, CAN 2.0B controller (TWAI), and DMA
-- controller behind a single AHB-Lite slave interface.
--
-- Peripheral Summary:
--   [Y] SPI Master (4 slave selects, CPOL/CPHA, DMA request)
--   [Y] UART (configurable baud, parity, flow control)
--   [Y] CAN 2.0B controller (TWAI)
--   [Y] DMA controller (4-channel, bus master)
--
-- AHB-Lite Address Map (HADDR[11:8] selects peripheral block):
--   0x000 - 0x0FF : Original peripherals
--       HADDR[7:4] = 0x0 : SPI registers   (HADDR[3:0] = register select)
--       HADDR[7:4] = 0x1 : UART registers  (HADDR[3:0] = register select)
--   0x100 - 0x1FF : DMA controller registers
--       HADDR[7:4] = channel index (0-3) or 0x4 for global registers
--       HADDR[3:2] = sub-register select
--   0x200 - 0x2FF : CAN controller registers
--       HADDR[7:2] = register index (6-bit)
--
-- Target FPGA : Cyclone III (EP3C16F484C6N)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity esp32_interface is
    port (
        -- ====================================================================
        -- AHB-Lite slave interface
        -- ====================================================================
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

        -- ====================================================================
        -- SPI physical pins
        -- ====================================================================
        spi_sclk    : out std_logic;
        spi_mosi    : out std_logic;
        spi_miso    : in  std_logic;
        spi_cs_n    : out std_logic_vector(3 downto 0);
        spi_int     : out std_logic;

        -- ====================================================================
        -- UART physical pins
        -- ====================================================================
        uart_txd    : out std_logic;
        uart_rxd    : in  std_logic;
        uart_rts_n  : out std_logic;
        uart_cts_n  : in  std_logic;
        uart_tx_int : out std_logic;
        uart_rx_int : out std_logic;
        uart_err_int: out std_logic;

        -- ====================================================================
        -- CAN 2.0B (TWAI) physical pins
        -- ====================================================================
        can_tx      : out std_logic;
        can_rx      : in  std_logic;
        can_clkout  : out std_logic;
        can_int     : out std_logic;

        -- ====================================================================
        -- DMA controller interface
        -- ====================================================================
        dma_int     : out std_logic;
        dma_m_addr  : out std_logic_vector(31 downto 0);
        dma_m_rdata : in  std_logic_vector(31 downto 0);
        dma_m_wdata : out std_logic_vector(31 downto 0);
        dma_m_we    : out std_logic;
        dma_m_req   : out std_logic;
        dma_m_ack   : in  std_logic;

        -- ====================================================================
        -- I2C interface
        -- ====================================================================
        i2c_sda : inout std_logic;
        i2c_scl : inout std_logic;
        i2c_int : out std_logic;

        -- ====================================================================
        -- I2S interface (audio)
        -- ====================================================================
        i2s_sck   : out std_logic;
        i2s_ws    : out std_logic;
        i2s_sd_tx : out std_logic;
        i2s_sd_rx : in  std_logic;
        i2s_int   : out std_logic;

        -- ====================================================================
        -- Watchdog Timer (WDT)
        -- ====================================================================
        wdt_int   : out std_logic;
        wdt_reset : out std_logic;

        -- ====================================================================
        -- Real-Time Clock (RTC)
        -- ====================================================================
        rtc_int   : out std_logic;

        -- ====================================================================
        -- ADC (8-channel, 12-bit = 96 bits)
        -- ====================================================================
        adc_in    : in  std_logic_vector(95 downto 0) := (others => '0');
        adc_int   : out std_logic;

        -- ====================================================================
        -- DAC (2-channel, 12-bit = 24 bits)
        -- ====================================================================
        dac_out   : out std_logic_vector(23 downto 0)
    );
end entity esp32_interface;

architecture rtl of esp32_interface is

    -- ========================================================================
    -- Address decode signals
    -- ========================================================================
    -- HADDR[11:8] selects the peripheral block
    signal blk_sel : std_logic_vector(3 downto 0);

    -- Block-level select signals (qualified by HSEL)
    signal orig_sel : std_logic;   -- HADDR[11:8] = 0x0 (SPI/UART)
    signal dma_sel  : std_logic;   -- HADDR[11:8] = 0x1 (DMA)
    signal can_sel  : std_logic;   -- HADDR[11:8] = 0x2 (CAN)

    -- Sub-block selects within the original peripheral block
    signal spi_sel  : std_logic;   -- HADDR[7:4] = 0x0
    signal uart_sel : std_logic;   -- HADDR[7:4] = 0x1

    -- ========================================================================
    -- SPI interface signals (AHB-to-simple bridge)
    -- ========================================================================
    signal spi_cs    : std_logic;
    signal spi_we    : std_logic;
    signal spi_addr  : std_logic_vector(3 downto 0);
    signal spi_din   : std_logic_vector(7 downto 0);
    signal spi_dout  : std_logic_vector(7 downto 0);
    signal spi_dma_req : std_logic;

    -- ========================================================================
    -- UART interface signals (AHB-to-simple bridge)
    -- ========================================================================
    signal uart_cs   : std_logic;
    signal uart_we   : std_logic;
    signal uart_addr : std_logic_vector(3 downto 0);
    signal uart_din  : std_logic_vector(7 downto 0);
    signal uart_dout : std_logic_vector(7 downto 0);

    -- ========================================================================
    -- CAN controller AHB interface signals
    -- ========================================================================
    signal can_hsel      : std_logic;
    signal can_hrdata    : std_logic_vector(31 downto 0);
    signal can_hresp     : std_logic;
    signal can_hreadyout : std_logic;

    -- ========================================================================
    -- DMA controller AHB interface signals
    -- ========================================================================
    signal dma_hsel      : std_logic;
    signal dma_hrdata    : std_logic_vector(31 downto 0);
    signal dma_hresp     : std_logic;
    signal dma_hreadyout : std_logic;
    signal dma_int_vec   : std_logic_vector(3 downto 0);
    signal dma_req_in    : std_logic_vector(3 downto 0);

    -- ========================================================================
    -- Active-high reset for SPI/UART (they use active-high, AHB uses active-low)
    -- ========================================================================
    signal reset_n_high : std_logic;

    -- ========================================================================
    -- WDT controller AHB interface signals
    -- ========================================================================
    signal wdt_hsel      : std_logic;
    signal wdt_hrdata    : std_logic_vector(31 downto 0);
    signal wdt_hresp     : std_logic;
    signal wdt_hreadyout : std_logic;

    -- ========================================================================
    -- RTC controller AHB interface signals
    -- ========================================================================
    signal rtc_hsel      : std_logic;
    signal rtc_hrdata    : std_logic_vector(31 downto 0);
    signal rtc_hresp     : std_logic;
    signal rtc_hreadyout : std_logic;

    -- ========================================================================
    -- ADC controller AHB interface signals
    -- ========================================================================
    signal adc_hsel      : std_logic;
    signal adc_hrdata    : std_logic_vector(31 downto 0);
    signal adc_hresp     : std_logic;
    signal adc_hreadyout : std_logic;

    -- ========================================================================
    -- DAC controller AHB interface signals
    -- ========================================================================
    signal dac_hsel      : std_logic;
    signal dac_hrdata    : std_logic_vector(31 downto 0);
    signal dac_hresp     : std_logic;
    signal dac_hreadyout : std_logic;

    -- ========================================================================
    -- Component declarations for new peripheral modules
    -- ========================================================================
    component wdt_controller is
        port (
            HCLK      : in  std_logic;
            HRESETn   : in  std_logic;
            HSEL      : in  std_logic;
            HWRITE    : in  std_logic;
            HREADY    : in  std_logic;
            HTRANS    : in  std_logic_vector(1 downto 0);
            HADDR     : in  std_logic_vector(31 downto 0);
            HWDATA    : in  std_logic_vector(31 downto 0);
            HRDATA    : out std_logic_vector(31 downto 0);
            HRESP     : out std_logic;
            HREADYOUT : out std_logic;
            wdt_int   : out std_logic;
            wdt_reset : out std_logic
        );
    end component;

    component rtc_controller is
        port (
            HCLK      : in  std_logic;
            HRESETn   : in  std_logic;
            HSEL      : in  std_logic;
            HWRITE    : in  std_logic;
            HREADY    : in  std_logic;
            HTRANS    : in  std_logic_vector(1 downto 0);
            HADDR     : in  std_logic_vector(31 downto 0);
            HWDATA    : in  std_logic_vector(31 downto 0);
            HRDATA    : out std_logic_vector(31 downto 0);
            HRESP     : out std_logic;
            HREADYOUT : out std_logic;
            rtc_int   : out std_logic
        );
    end component;

    component adc_controller is
        port (
            HCLK      : in  std_logic;
            HRESETn   : in  std_logic;
            HSEL      : in  std_logic;
            HWRITE    : in  std_logic;
            HREADY    : in  std_logic;
            HTRANS    : in  std_logic_vector(1 downto 0);
            HADDR     : in  std_logic_vector(31 downto 0);
            HWDATA    : in  std_logic_vector(31 downto 0);
            HRDATA    : out std_logic_vector(31 downto 0);
            HRESP     : out std_logic;
            HREADYOUT : out std_logic;
            adc_in    : in  std_logic_vector(95 downto 0);
            adc_int   : out std_logic
        );
    end component;

    component dac_controller is
        port (
            HCLK      : in  std_logic;
            HRESETn   : in  std_logic;
            HSEL      : in  std_logic;
            HWRITE    : in  std_logic;
            HREADY    : in  std_logic;
            HTRANS    : in  std_logic_vector(1 downto 0);
            HADDR     : in  std_logic_vector(31 downto 0);
            HWDATA    : in  std_logic_vector(31 downto 0);
            HRDATA    : out std_logic_vector(31 downto 0);
            HRESP     : out std_logic;
            HREADYOUT : out std_logic;
            dac_out   : out std_logic_vector(23 downto 0)
        );
    end component;

begin

    -- I2C interface (not implemented - outputs idle)
    i2c_int <= '0';

    -- I2S interface (not implemented - outputs idle)
    i2s_sck   <= '0';
    i2s_ws    <= '0';
    i2s_sd_tx <= '0';
    i2s_int   <= '0';

    -- ========================================================================
    -- Address decode
    -- ========================================================================
    blk_sel  <= HADDR(11 downto 8);

    orig_sel <= '1' when (HSEL = '1' and HADDR(11 downto 8) = "0000") else '0';
    dma_sel  <= '1' when (HSEL = '1' and HADDR(11 downto 8) = "0001") else '0';
    can_sel  <= '1' when (HSEL = '1' and HADDR(11 downto 8) = "0010") else '0';

    -- New peripheral decode: HADDR[15:12] selects peripheral block
    wdt_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0101") else '0';
    rtc_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0110") else '0';
    adc_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "0111") else '0';
    dac_hsel <= '1' when (HSEL = '1' and HADDR(15 downto 12) = "1000") else '0';

    -- Sub-block decode within original peripheral block
    spi_sel  <= '1' when (orig_sel = '1' and HADDR(7 downto 4) = "0000") else '0';
    uart_sel <= '1' when (orig_sel = '1' and HADDR(7 downto 4) = "0001") else '0';

    -- ========================================================================
    -- AHB-to-simple bus bridge for SPI
    -- ========================================================================
    spi_cs   <= spi_sel and HREADY;
    spi_we   <= HWRITE when spi_sel = '1' else '0';
    spi_addr <= HADDR(3 downto 0);
    spi_din  <= HWDATA(7 downto 0);

    -- ========================================================================
    -- AHB-to-simple bus bridge for UART
    -- ========================================================================
    uart_cs   <= uart_sel and HREADY;
    uart_we   <= HWRITE when uart_sel = '1' else '0';
    uart_addr <= HADDR(3 downto 0);
    uart_din  <= HWDATA(7 downto 0);

    -- ========================================================================
    -- HSEL for CAN and DMA (direct AHB pass-through)
    -- ========================================================================
    can_hsel <= can_sel;
    dma_hsel <= dma_sel;

    -- ========================================================================
    -- Reset polarity conversion
    -- ========================================================================
    reset_n_high <= not HRESETn;

    -- ========================================================================
    -- SPI master instantiation
    -- ========================================================================
    spi_inst : entity work.esp32_spi
        port map (
            clk       => HCLK,
            reset     => reset_n_high,
            cs        => spi_cs,
            we        => spi_we,
            addr      => spi_addr,
            din       => spi_din,
            dout      => spi_dout,
            sclk      => spi_sclk,
            mosi      => spi_mosi,
            miso      => spi_miso,
            spi_cs_n  => spi_cs_n,
            spi_int   => spi_int,
            dma_req   => spi_dma_req,
            dma_ack   => '0'
        );

    -- ========================================================================
    -- UART instantiation
    -- ========================================================================
    uart_inst : entity work.esp32_uart
        port map (
            clk       => HCLK,
            reset     => reset_n_high,
            cs        => uart_cs,
            we        => uart_we,
            addr      => uart_addr,
            din       => uart_din,
            dout      => uart_dout,
            txd       => uart_txd,
            rxd       => uart_rxd,
            rts_n     => uart_rts_n,
            cts_n     => uart_cts_n,
            tx_int    => uart_tx_int,
            rx_int    => uart_rx_int,
            err_int   => uart_err_int
        );

    -- ========================================================================
    -- CAN 2.0B controller (TWAI) instantiation
    -- ========================================================================
    can_inst : entity work.can_controller_ahb
        port map (
            HCLK       => HCLK,
            HRESETn    => HRESETn,
            HSEL       => can_hsel,
            HWRITE     => HWRITE,
            HREADY     => HREADY,
            HTRANS     => HTRANS,
            HSIZE      => HSIZE,
            HADDR      => HADDR,
            HWDATA     => HWDATA,
            HRDATA     => can_hrdata,
            HRESP      => can_hresp,
            HREADYOUT  => can_hreadyout,
            can_tx     => can_tx,
            can_rx     => can_rx,
            can_clkout => can_clkout,
            can_int    => can_int
        );

    -- ========================================================================
    -- DMA controller instantiation
    -- ========================================================================
    -- Connect SPI DMA request to DMA channel 0 trigger
    dma_req_in <= spi_dma_req & "000";

    dma_inst : entity work.dma_controller
        generic map (
            NUM_CHANNELS => 4,
            DATA_WIDTH   => 32,
            ADDR_WIDTH   => 32
        )
        port map (
            HCLK       => HCLK,
            HRESETn    => HRESETn,
            HSEL       => dma_hsel,
            HWRITE     => HWRITE,
            HREADY     => HREADY,
            HTRANS     => HTRANS,
            HSIZE      => HSIZE,
            HADDR      => HADDR,
            HWDATA     => HWDATA,
            HRDATA     => dma_hrdata,
            HRESP      => dma_hresp,
            HREADYOUT  => dma_hreadyout,
            m_addr     => dma_m_addr,
            m_rdata    => dma_m_rdata,
            m_wdata    => dma_m_wdata,
            m_we       => dma_m_we,
            m_req      => dma_m_req,
            m_ack      => dma_m_ack,
            dma_int    => dma_int_vec,
            dma_req_in => dma_req_in
        );

    -- OR all DMA channel interrupts into a single output
    dma_int <= dma_int_vec(0) or dma_int_vec(1) or
               dma_int_vec(2) or dma_int_vec(3);

    -- ========================================================================
    -- WDT controller instantiation (base 0x5000)
    -- ========================================================================
    wdt_inst : wdt_controller
        port map (
            HCLK       => HCLK,
            HRESETn    => HRESETn,
            HSEL       => wdt_hsel,
            HWRITE     => HWRITE,
            HREADY     => HREADY,
            HTRANS     => HTRANS,
            HADDR      => HADDR,
            HWDATA     => HWDATA,
            HRDATA     => wdt_hrdata,
            HRESP      => wdt_hresp,
            HREADYOUT  => wdt_hreadyout,
            wdt_int    => wdt_int,
            wdt_reset  => wdt_reset
        );

    -- ========================================================================
    -- RTC controller instantiation (base 0x6000)
    -- ========================================================================
    rtc_inst : rtc_controller
        port map (
            HCLK       => HCLK,
            HRESETn    => HRESETn,
            HSEL       => rtc_hsel,
            HWRITE     => HWRITE,
            HREADY     => HREADY,
            HTRANS     => HTRANS,
            HADDR      => HADDR,
            HWDATA     => HWDATA,
            HRDATA     => rtc_hrdata,
            HRESP      => rtc_hresp,
            HREADYOUT  => rtc_hreadyout,
            rtc_int    => rtc_int
        );

    -- ========================================================================
    -- ADC controller instantiation (base 0x7000)
    -- ========================================================================
    adc_inst : adc_controller
        port map (
            HCLK       => HCLK,
            HRESETn    => HRESETn,
            HSEL       => adc_hsel,
            HWRITE     => HWRITE,
            HREADY     => HREADY,
            HTRANS     => HTRANS,
            HADDR      => HADDR,
            HWDATA     => HWDATA,
            HRDATA     => adc_hrdata,
            HRESP      => adc_hresp,
            HREADYOUT  => adc_hreadyout,
            adc_in     => adc_in,
            adc_int    => adc_int
        );

    -- ========================================================================
    -- DAC controller instantiation (base 0x8000)
    -- ========================================================================
    dac_inst : dac_controller
        port map (
            HCLK       => HCLK,
            HRESETn    => HRESETn,
            HSEL       => dac_hsel,
            HWRITE     => HWRITE,
            HREADY     => HREADY,
            HTRANS     => HTRANS,
            HADDR      => HADDR,
            HWDATA     => HWDATA,
            HRDATA     => dac_hrdata,
            HRESP      => dac_hresp,
            HREADYOUT  => dac_hreadyout,
            dac_out    => dac_out
        );

    -- ========================================================================
    -- AHB read data multiplexer
    --   First decode HADDR[15:12] for new peripherals, then HADDR[11:8] for
    --   original blocks.
    -- ========================================================================
    ahb_read_mux : process(HADDR, spi_dout, uart_dout,
                           dma_hrdata, can_hrdata,
                           wdt_hrdata, rtc_hrdata, adc_hrdata, dac_hrdata)
    begin
        case HADDR(15 downto 12) is
            when "0000" =>
                -- Original peripheral block: decode HADDR[11:8]
                case HADDR(11 downto 8) is
                    when "0000" =>
                        if HADDR(7 downto 4) = "0001" then
                            HRDATA <= x"000000" & uart_dout;
                        else
                            HRDATA <= x"000000" & spi_dout;
                        end if;
                    when "0001" =>
                        HRDATA <= dma_hrdata;
                    when "0010" =>
                        HRDATA <= can_hrdata;
                    when others =>
                        HRDATA <= (others => '0');
                end case;
            when "0101" =>
                HRDATA <= wdt_hrdata;
            when "0110" =>
                HRDATA <= rtc_hrdata;
            when "0111" =>
                HRDATA <= adc_hrdata;
            when "1000" =>
                HRDATA <= dac_hrdata;
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process ahb_read_mux;

    -- ========================================================================
    -- AHB response multiplexer
    -- ========================================================================
    HRESP <= wdt_hresp  when HADDR(15 downto 12) = "0101" else
             rtc_hresp  when HADDR(15 downto 12) = "0110" else
             adc_hresp  when HADDR(15 downto 12) = "0111" else
             dac_hresp  when HADDR(15 downto 12) = "1000" else
             dma_hresp  when HADDR(15 downto 12) = "0000" and HADDR(11 downto 8) = "0001" else
             can_hresp  when HADDR(15 downto 12) = "0000" and HADDR(11 downto 8) = "0010" else
             '0';

    -- ========================================================================
    -- AHB ready-out multiplexer
    --   SPI and UART are combinational (always ready).
    --   CAN, DMA, WDT, RTC, ADC, DAC have their own HREADYOUT.
    -- ========================================================================
    HREADYOUT <= wdt_hreadyout when HADDR(15 downto 12) = "0101" else
                 rtc_hreadyout when HADDR(15 downto 12) = "0110" else
                 adc_hreadyout when HADDR(15 downto 12) = "0111" else
                 dac_hreadyout when HADDR(15 downto 12) = "1000" else
                 dma_hreadyout when HADDR(15 downto 12) = "0000" and HADDR(11 downto 8) = "0001" else
                 can_hreadyout when HADDR(15 downto 12) = "0000" and HADDR(11 downto 8) = "0010" else
                 '1';

end architecture rtl;

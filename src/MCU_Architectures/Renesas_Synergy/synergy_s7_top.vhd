-- ================================================================================
-- synergy_s7_top : Top-level Renesas Synergy S7 SoC integration
-- ================================================================================
-- Integrates Synergy S7 CPU (Cortex-M23 + TrustZone) with DMAC, GPT, AGT,
-- ELC, DTC, SDHI, and GLCD peripherals via AHB-Lite bus matrix.
-- Address Map (HADDR[31:16]): 0x4000 s7_if | 0x4001 dmac | 0x4002 gpt
--   0x4003 agt | 0x4004 elc | 0x4005 dtc | 0x4006 sdhi | 0x4007 glcd
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_s7_top is
    generic ( CLK_FREQ : integer := 50000000 );
    port (
        -- AHB-Lite master port (external bus access)
        HCLK, HRESETn, HSEL, HWRITE, HREADY, HMASTLOCK : in std_logic;
        HTRANS : in std_logic_vector(1 downto 0);
        HSIZE  : in std_logic_vector(2 downto 0);
        HPROT  : in std_logic_vector(3 downto 0);
        HADDR  : in std_logic_vector(31 downto 0);
        HWDATA : in std_logic_vector(31 downto 0);
        HRDATA : out std_logic_vector(31 downto 0);
        HRESP  : out std_logic;
        HREADYOUT : out std_logic;
        -- GPIO
        gpio_in  : in  std_logic_vector(31 downto 0) := (others => '0');
        gpio_out : out std_logic_vector(31 downto 0);
        gpio_dir : out std_logic_vector(31 downto 0);
        -- UART
        uart_txd : out std_logic;  uart_rxd : in std_logic := '0';
        -- SPI
        spi_sclk : out std_logic;  spi_mosi : out std_logic;
        spi_miso : in std_logic := '0';
        -- I2C
        i2c_sda  : inout std_logic;  i2c_scl : inout std_logic;
        -- ADC (12-bit single channel on S7)
        adc_in   : in std_logic_vector(11 downto 0) := (others => '0');
        -- GPT I/O (6-ch, 2 outputs + 1 input per channel)
        gpt_out  : out std_logic_vector(11 downto 0);
        gpt_in   : in  std_logic_vector(5 downto 0) := (others => '0');
        -- AGT I/O
        agt_out  : out std_logic;
        -- SD bus
        sd_clk   : out std_logic;  sd_cmd : inout std_logic;
        sd_dat   : inout std_logic_vector(3 downto 0);
        sd_cd    : in std_logic := '1';
        -- LCD (GLCD)
        lcd_hsync, lcd_vsync, lcd_de, lcd_clk : out std_logic;
        lcd_r    : out std_logic_vector(5 downto 0);
        lcd_g    : out std_logic_vector(5 downto 0);
        lcd_b    : out std_logic_vector(5 downto 0);
        -- Security
        trng_valid  : out std_logic;
        secure_boot : out std_logic;
        -- Combined interrupt
        global_irq  : out std_logic
    );
end entity synergy_s7_top;

architecture rtl of synergy_s7_top is
    type rdata_arr_t is array(0 to 7) of std_logic_vector(31 downto 0);
    type resp_arr_t  is array(0 to 7) of std_logic;
    signal rdata  : rdata_arr_t := (others => (others => '0'));
    signal resp   : resp_arr_t  := (others => '0');
    signal rdy    : resp_arr_t  := (others => '1');
    signal sel    : resp_arr_t;
    signal sel_idx: integer range 0 to 7;
    -- Interrupt wires
    signal timer_int_s, uart_int_s, spi_int_s, i2c_int_s, adc_int_s : std_logic;
    signal dmac_irq_s : std_logic_vector(7 downto 0);
    signal gpt_irq_s : std_logic_vector(5 downto 0);
    signal agt_irq_s, dtc_irq_s, sdhi_irq_s : std_logic;
    signal dma_irq_s, can_int_s, eth_int_s, usb_int_s, i2s_int_s : std_logic;
    signal wdt_int_s, rtc_int_s : std_logic;
    -- DMA master tie-off
    signal dma_req_s, dma_done_s : std_logic;
    -- ELC event bus
    signal elc_event_out : std_logic_vector(31 downto 0);

    -- Component declaration for synergy_s7_interface (compiled in separate directory)
    component synergy_s7_interface is
        generic (
            GPIO_WIDTH : integer := 32
        );
        port (
            HCLK, HRESETn, HSEL, HWRITE, HREADY, HMASTLOCK : in std_logic;
            HTRANS : in std_logic_vector(1 downto 0);
            HSIZE  : in std_logic_vector(2 downto 0);
            HPROT  : in std_logic_vector(3 downto 0);
            HADDR  : in std_logic_vector(31 downto 0);
            HWDATA : in std_logic_vector(31 downto 0);
            HRDATA : out std_logic_vector(31 downto 0);
            HRESP  : out std_logic;
            HREADYOUT : out std_logic;
            gpio_in  : in  std_logic_vector(31 downto 0);
            gpio_out : out std_logic_vector(31 downto 0);
            gpio_dir : out std_logic_vector(31 downto 0);
            timer_int : out std_logic;
            uart_txd : out std_logic;  uart_rxd : in std_logic;  uart_int : out std_logic;
            spi_sclk, spi_mosi : out std_logic;  spi_miso : in std_logic;  spi_int : out std_logic;
            i2c_sda : inout std_logic;  i2c_scl : inout std_logic;  i2c_int : out std_logic;
            adc_in  : in  std_logic_vector(11 downto 0);  adc_int : out std_logic;
            dma_req    : out std_logic;
            dma_done   : in  std_logic;
            dma_m_addr : out std_logic_vector(31 downto 0);
            dma_m_rdata: in  std_logic_vector(31 downto 0);
            dma_m_wdata: out std_logic_vector(31 downto 0);
            dma_m_we   : out std_logic;
            dma_irq    : out std_logic;
            can_tx : out std_logic;  can_rx : in std_logic;  can_int : out std_logic;
            eth_txd : out std_logic_vector(3 downto 0);  eth_rxd : in std_logic_vector(3 downto 0);
            eth_int : out std_logic;
            mii_tx_en  : out std_logic;
            mii_tx_clk : in  std_logic;
            mii_rx_clk : in  std_logic;
            mii_rx_dv  : in  std_logic;
            mii_tx_er  : out std_logic;
            mii_rx_er  : in  std_logic;
            mii_crs    : in  std_logic;
            mii_col    : in  std_logic;
            mdc        : out std_logic;
            mdio       : inout std_logic;
            usb_dp, usb_dm : inout std_logic;  usb_int : out std_logic;
            usb_clk   : in  std_logic;
            lcd_data : out std_logic_vector(15 downto 0);
            lcd_hsync, lcd_vsync, lcd_clk : out std_logic;
            trng_valid  : out std_logic;
            secure_boot : out std_logic;
            wdt_int   : out std_logic;
            wdt_reset : out std_logic;
            rtc_int   : out std_logic;
            dac_out   : out std_logic_vector(23 downto 0);
            i2s_sck   : out std_logic;
            i2s_ws    : out std_logic;
            i2s_sd_tx : out std_logic;
            i2s_sd_rx : in  std_logic;
            i2s_int   : out std_logic
        );
    end component synergy_s7_interface;

begin

    -- Address decode
    sel(0) <= '1' when HADDR(31 downto 16) = x"4000" else '0';
    sel(1) <= '1' when HADDR(31 downto 16) = x"4001" else '0';
    sel(2) <= '1' when HADDR(31 downto 16) = x"4002" else '0';
    sel(3) <= '1' when HADDR(31 downto 16) = x"4003" else '0';
    sel(4) <= '1' when HADDR(31 downto 16) = x"4004" else '0';
    sel(5) <= '1' when HADDR(31 downto 16) = x"4005" else '0';
    sel(6) <= '1' when HADDR(31 downto 16) = x"4006" else '0';
    sel(7) <= '1' when HADDR(31 downto 16) = x"4007" else '0';

    sel_idx <= 0 when sel(0)='1' else 1 when sel(1)='1' else 2 when sel(2)='1'
            else 3 when sel(3)='1' else 4 when sel(4)='1' else 5 when sel(5)='1'
            else 6 when sel(6)='1' else 7 when sel(7)='1' else 0;

    HRDATA <= rdata(sel_idx);  HRESP <= resp(sel_idx);  HREADYOUT <= rdy(sel_idx);

    -- DMA master tie-off (loopback ack)
    dma_done_s <= dma_req_s;

    -- ========================================================================
    -- Synergy S7 CPU interface
    -- ========================================================================
    u_s7 : synergy_s7_interface port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(0), HWRITE=>HWRITE, HREADY=>HREADY,
        HMASTLOCK=>HMASTLOCK, HTRANS=>HTRANS, HSIZE=>HSIZE, HPROT=>HPROT,
        HADDR=>HADDR, HWDATA=>HWDATA, HRDATA=>rdata(0), HRESP=>resp(0), HREADYOUT=>rdy(0),
        gpio_in=>gpio_in, gpio_out=>gpio_out, gpio_dir=>gpio_dir,
        timer_int=>timer_int_s,
        uart_txd=>uart_txd, uart_rxd=>uart_rxd, uart_int=>uart_int_s,
        spi_sclk=>spi_sclk, spi_mosi=>spi_mosi, spi_miso=>spi_miso, spi_int=>spi_int_s,
        i2c_sda=>i2c_sda, i2c_scl=>i2c_scl, i2c_int=>i2c_int_s,
        adc_in=>adc_in, adc_int=>adc_int_s,
        dma_req=>dma_req_s, dma_done=>dma_done_s,
        dma_m_addr=>open, dma_m_rdata=>(others=>'0'), dma_m_wdata=>open,
        dma_m_we=>open, dma_irq=>dma_irq_s,
        can_tx=>open, can_rx=>'1', can_int=>can_int_s,
        eth_txd=>open, eth_rxd=>(others=>'0'), eth_int=>eth_int_s,
        mii_tx_en=>open, mii_tx_clk=>'0', mii_rx_clk=>'0', mii_rx_dv=>'0',
        mii_tx_er=>open, mii_rx_er=>'0', mii_crs=>'0', mii_col=>'0',
        mdc=>open, mdio=>open,
        usb_dp=>open, usb_dm=>open, usb_clk=>'0', usb_int=>usb_int_s,
        lcd_data=>open, lcd_hsync=>open, lcd_vsync=>open, lcd_clk=>open,
        trng_valid=>trng_valid, secure_boot=>secure_boot,
        wdt_int=>wdt_int_s, wdt_reset=>open, rtc_int=>rtc_int_s, dac_out=>open,
        i2s_sck=>open, i2s_ws=>open, i2s_sd_tx=>open, i2s_sd_rx=>'0', i2s_int=>i2s_int_s );

    -- DMAC (8-channel DMA)
    u_dmac : entity work.synergy_dmac port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(1), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(1), HRESP=>resp(1), HREADYOUT=>rdy(1),
        dmac_irq=>dmac_irq_s, dmac_req=>(others=>'0') );

    -- GPT (6-channel general purpose timer)
    u_gpt : entity work.synergy_gpt generic map ( CLK_FREQ=>CLK_FREQ ) port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(2), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(2), HRESP=>resp(2), HREADYOUT=>rdy(2),
        gpt_out=>gpt_out, gpt_in=>gpt_in, gpt_irq=>gpt_irq_s );

    -- AGT (asynchronous general timer)
    u_agt : entity work.synergy_agt port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(3), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(3), HRESP=>resp(3), HREADYOUT=>rdy(3),
        agt_out=>agt_out, agt_irq=>agt_irq_s );

    -- ELC (event link controller)
    u_elc : entity work.synergy_elc port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(4), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(4), HRESP=>resp(4), HREADYOUT=>rdy(4),
        elc_event_in=>(others=>'0'), elc_event_out=>elc_event_out );

    -- DTC (data transfer controller)
    u_dtc : entity work.synergy_dtc port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(5), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(5), HRESP=>resp(5), HREADYOUT=>rdy(5),
        dtc_irq=>dtc_irq_s, dtc_req=>'0' );

    -- SDHI (SD host interface)
    u_sdhi : entity work.synergy_sdhi port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(6), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(6), HRESP=>resp(6), HREADYOUT=>rdy(6),
        sd_clk=>sd_clk, sd_cmd=>sd_cmd, sd_dat=>sd_dat, sd_cd=>sd_cd, sd_irq=>sdhi_irq_s );

    -- GLCD (graphics LCD controller)
    u_glcd : entity work.synergy_glcd port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(7), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(7), HRESP=>resp(7), HREADYOUT=>rdy(7),
        lcd_hsync=>lcd_hsync, lcd_vsync=>lcd_vsync, lcd_de=>lcd_de, lcd_clk=>lcd_clk,
        lcd_r=>lcd_r, lcd_g=>lcd_g, lcd_b=>lcd_b );

    global_irq <= timer_int_s or uart_int_s or spi_int_s or i2c_int_s or adc_int_s
                  or dma_irq_s or (or dmac_irq_s) or (or gpt_irq_s) or agt_irq_s or dtc_irq_s
                  or sdhi_irq_s or can_int_s or eth_int_s or usb_int_s or i2s_int_s
                  or wdt_int_s or rtc_int_s;

end architecture rtl;

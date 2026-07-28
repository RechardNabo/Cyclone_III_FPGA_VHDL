-- ================================================================================
-- cortex_m4_top : Top-level Cortex-M4 SoC integration
-- ================================================================================
-- Integrates Cortex-M4 CPU core with all peripherals via AHB-Lite bus matrix.
-- Address Map (HADDR[31:16]): 0x4000 cortex_m4 | 0x4001 mpu | 0x4002 dsp
--   0x4003 fpu | 0x4004 dwt | 0x4005 itm | 0x4006 nvic | 0x4007 crc
--   0x4008 aes | 0x4009 sha | 0x400A trng | 0x400B exti | 0x400C nmi
--   0x400D cmu | 0x400E psc | 0x400F uart | 0x4010 spi | 0x4011 i2c
--   0x4012 adc | 0x4013 wdt | 0x4014 rtc | 0x4015 dma
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cortex_m4_top is
    generic ( CLK_FREQ : integer := 50000000 );
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
        gpio_in  : in  std_logic_vector(31 downto 0) := (others => '0');
        gpio_out : out std_logic_vector(31 downto 0);
        gpio_dir : out std_logic_vector(31 downto 0);
        uart_txd : out std_logic;  uart_rxd : in std_logic := '0';
        spi_sclk : out std_logic;  spi_mosi : out std_logic;
        spi_miso : in std_logic := '0';  spi_ss_n : out std_logic_vector(3 downto 0);
        i2c_sda  : inout std_logic;  i2c_scl : inout std_logic;
        adc_in   : in std_logic_vector(95 downto 0) := (others => '0');
        tck, tms, tdi : in std_logic := '0';  tdo : out std_logic;
        swclk    : in std_logic := '0';  swdio : inout std_logic;
        exti_lines : in std_logic_vector(31 downto 0) := (others => '0');
        nmi_src    : in std_logic_vector(7 downto 0) := (others => '0');
        irq_inputs : in std_logic_vector(31 downto 0) := (others => '0');
        clk_in   : in std_logic_vector(3 downto 0) := (others => '0');
        clk_out  : out std_logic_vector(7 downto 0);
        pll_locked : out std_logic;
        global_irq : out std_logic
    );
end entity cortex_m4_top;

architecture rtl of cortex_m4_top is
    type rdata_arr_t is array(0 to 21) of std_logic_vector(31 downto 0);
    type resp_arr_t  is array(0 to 21) of std_logic;
    signal rdata  : rdata_arr_t := (others => (others => '0'));
    signal resp   : resp_arr_t  := (others => '0');
    signal rdy    : resp_arr_t  := (others => '1');
    signal sel    : resp_arr_t;
    signal sel_idx: integer range 0 to 21;
    signal nmi_out_sig, nvic_irq, mpu_irq, dsp_irq, fpu_irq, dwt_irq, itm_irq : std_logic;
    signal crc_irq, aes_irq, sha_irq, trng_irq, cmu_irq, psc_irq : std_logic;
    signal uart_int, spi_int, i2c_int, adc_int, wdt_int, rtc_int : std_logic;

    -- Component declaration for cortex_m4_interface (compiled in separate directory)
    component cortex_m4_interface is
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
            irq_inputs : in std_logic_vector(31 downto 0);
            nmi        : in std_logic;
            irq_out    : out std_logic;
            irq_num    : out std_logic_vector(8 downto 0);
            mclk        : in std_logic;
            systick_int : out std_logic;
            gpio_in   : in  std_logic_vector(31 downto 0);
            gpio_out  : out std_logic_vector(31 downto 0);
            gpio_dir  : out std_logic_vector(31 downto 0);
            mpu_region_violation : out std_logic;
            tck, tms, tdi : in std_logic;
            tdo : out std_logic;
            swclk : in std_logic;
            swdio : inout std_logic;
            hardfault, busfault, memfault, usagefault : out std_logic;
            fpu_enable : out std_logic;
            fpu_int    : out std_logic;
            fpscr      : out std_logic_vector(31 downto 0);
            dwt_cmp0_addr  : in  std_logic_vector(31 downto 0);
            dwt_cmp0_match : out std_logic;
            dwt_cmp1_addr  : in  std_logic_vector(31 downto 0);
            dwt_cmp1_match : out std_logic;
            itm_stim0 : in std_logic_vector(31 downto 0);
            itm_stim1 : in std_logic_vector(31 downto 0);
            itm_atb   : out std_logic;
            dma_int    : out std_logic;
            dma_req_in : in  std_logic_vector(3 downto 0);
            m_addr     : out std_logic_vector(31 downto 0);
            m_rdata    : in  std_logic_vector(31 downto 0);
            m_wdata    : out std_logic_vector(31 downto 0);
            m_we       : out std_logic;
            m_req      : out std_logic;
            m_ack      : in  std_logic;
            can_tx     : out std_logic;
            can_rx     : in  std_logic;
            can_clkout : out std_logic;
            can_int    : out std_logic;
            mii_txd    : out std_logic_vector(3 downto 0);
            mii_rxd    : in  std_logic_vector(3 downto 0);
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
            eth_int    : out std_logic;
            usb_dp     : inout std_logic;
            usb_dm     : inout std_logic;
            usb_clk    : in  std_logic;
            usb_int    : out std_logic;
            i2c_sda : inout std_logic;
            i2c_scl : inout std_logic;
            i2c_int : out std_logic;
            uart_txd : out std_logic;
            uart_rxd : in  std_logic;
            uart_int : out std_logic;
            i2s_sck   : out std_logic;
            i2s_ws    : out std_logic;
            i2s_sd_tx : out std_logic;
            i2s_sd_rx : in  std_logic;
            i2s_int   : out std_logic;
            sleep_out  : out std_logic;
            sleep_on_exit : out std_logic;
            event_on   : out std_logic;
            wdt_int   : out std_logic;
            wdt_reset : out std_logic;
            rtc_int   : out std_logic;
            adc_in    : in  std_logic_vector(95 downto 0) := (others => '0');
            adc_int   : out std_logic;
            dac_out   : out std_logic_vector(23 downto 0)
        );
    end component cortex_m4_interface;

begin

    -- Address decode
    sel(0)  <= '1' when HADDR(31 downto 16) = x"4000" else '0';
    sel(1)  <= '1' when HADDR(31 downto 16) = x"4001" else '0';
    sel(2)  <= '1' when HADDR(31 downto 16) = x"4002" else '0';
    sel(3)  <= '1' when HADDR(31 downto 16) = x"4003" else '0';
    sel(4)  <= '1' when HADDR(31 downto 16) = x"4004" else '0';
    sel(5)  <= '1' when HADDR(31 downto 16) = x"4005" else '0';
    sel(6)  <= '1' when HADDR(31 downto 16) = x"4006" else '0';
    sel(7)  <= '1' when HADDR(31 downto 16) = x"4007" else '0';
    sel(8)  <= '1' when HADDR(31 downto 16) = x"4008" else '0';
    sel(9)  <= '1' when HADDR(31 downto 16) = x"4009" else '0';
    sel(10) <= '1' when HADDR(31 downto 16) = x"400A" else '0';
    sel(11) <= '1' when HADDR(31 downto 16) = x"400B" else '0';
    sel(12) <= '1' when HADDR(31 downto 16) = x"400C" else '0';
    sel(13) <= '1' when HADDR(31 downto 16) = x"400D" else '0';
    sel(14) <= '1' when HADDR(31 downto 16) = x"400E" else '0';
    sel(15) <= '1' when HADDR(31 downto 16) = x"400F" else '0';
    sel(16) <= '1' when HADDR(31 downto 16) = x"4010" else '0';
    sel(17) <= '1' when HADDR(31 downto 16) = x"4011" else '0';
    sel(18) <= '1' when HADDR(31 downto 16) = x"4012" else '0';
    sel(19) <= '1' when HADDR(31 downto 16) = x"4013" else '0';
    sel(20) <= '1' when HADDR(31 downto 16) = x"4014" else '0';
    sel(21) <= '1' when HADDR(31 downto 16) = x"4015" else '0';

    sel_idx <=  0 when sel(0)='1' else  1 when sel(1)='1' else  2 when sel(2)='1'
            else  3 when sel(3)='1' else  4 when sel(4)='1' else  5 when sel(5)='1'
            else  6 when sel(6)='1' else  7 when sel(7)='1' else  8 when sel(8)='1'
            else  9 when sel(9)='1' else 10 when sel(10)='1' else 11 when sel(11)='1'
            else 12 when sel(12)='1' else 13 when sel(13)='1' else 14 when sel(14)='1'
            else 15 when sel(15)='1' else 16 when sel(16)='1' else 17 when sel(17)='1'
            else 18 when sel(18)='1' else 19 when sel(19)='1' else 20 when sel(20)='1'
            else 21 when sel(21)='1' else 0;

    HRDATA <= rdata(sel_idx);  HRESP <= resp(sel_idx);  HREADYOUT <= rdy(sel_idx);

    -- Cortex-M4 CPU core
    u_m4 : cortex_m4_interface port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(0), HWRITE=>HWRITE, HREADY=>HREADY,
        HMASTLOCK=>HMASTLOCK, HTRANS=>HTRANS, HSIZE=>HSIZE, HPROT=>HPROT,
        HADDR=>HADDR, HWDATA=>HWDATA, HRDATA=>rdata(0), HRESP=>resp(0), HREADYOUT=>rdy(0),
        irq_inputs=>irq_inputs, nmi=>nmi_out_sig, irq_out=>nvic_irq, irq_num=>open,
        mclk=>HCLK, systick_int=>open, gpio_in=>gpio_in, gpio_out=>gpio_out, gpio_dir=>gpio_dir,
        mpu_region_violation=>open, tck=>tck, tms=>tms, tdi=>tdi, tdo=>tdo, swclk=>swclk, swdio=>swdio,
        hardfault=>open, busfault=>open, memfault=>open, usagefault=>open,
        fpu_enable=>open, fpu_int=>open, fpscr=>open,
        dwt_cmp0_addr=>(others=>'0'), dwt_cmp0_match=>open,
        dwt_cmp1_addr=>(others=>'0'), dwt_cmp1_match=>open,
        itm_stim0=>(others=>'0'), itm_stim1=>(others=>'0'), itm_atb=>open,
        dma_int=>open, dma_req_in=>(others=>'0'),
        m_addr=>open, m_rdata=>(others=>'0'), m_wdata=>open, m_we=>open, m_req=>open, m_ack=>'0',
        can_tx=>open, can_rx=>'1', can_clkout=>open, can_int=>open,
        mii_txd=>open, mii_rxd=>(others=>'0'), mii_tx_en=>open, mii_tx_clk=>'0',
        mii_rx_clk=>'0', mii_rx_dv=>'0', mii_tx_er=>open, mii_rx_er=>'0',
        mii_crs=>'0', mii_col=>'0', mdc=>open, mdio=>open, eth_int=>open,
        usb_dp=>open, usb_dm=>open, usb_clk=>'0', usb_int=>open,
        i2c_sda=>open, i2c_scl=>open, i2c_int=>open,
        uart_txd=>open, uart_rxd=>'1', uart_int=>open,
        i2s_sck=>open, i2s_ws=>open, i2s_sd_tx=>open, i2s_sd_rx=>'0', i2s_int=>open,
        sleep_out=>open, sleep_on_exit=>open, event_on=>open,
        wdt_int=>open, wdt_reset=>open, rtc_int=>open,
        adc_in=>adc_in, adc_int=>open, dac_out=>open );

    u_mpu : entity work.mpu_controller port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(1), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA, HRDATA=>rdata(1), HRESP=>resp(1), HREADYOUT=>rdy(1),
        cpu_addr=>HADDR, cpu_priv=>'1', cpu_write=>HWRITE, region_fault=>open, mpu_irq=>mpu_irq );

    u_dsp : entity work.dsp_extensions port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(2), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA, HRDATA=>rdata(2), HRESP=>resp(2), HREADYOUT=>rdy(2),
        dsp_irq=>dsp_irq );

    u_fpu : entity work.fpu_single port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(3), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(3), HRESP=>resp(3), HREADYOUT=>rdy(3), fpu_irq=>fpu_irq );

    u_dwt : entity work.dwt_controller port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(4), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA, HRDATA=>rdata(4), HRESP=>resp(4), HREADYOUT=>rdy(4),
        cpu_daddr=>(others=>'0'), cpu_dwrite=>'0', dwt_cmp=>open, dwt_irq=>dwt_irq );

    u_itm : entity work.itm_controller port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(5), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA, HRDATA=>rdata(5), HRESP=>resp(5), HREADYOUT=>rdy(5),
        itm_swv=>open, itm_irq=>itm_irq );

    u_nvic : entity work.nvic_tailchain port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(6), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA, HRDATA=>rdata(6), HRESP=>resp(6), HREADYOUT=>rdy(6),
        irq_in=>irq_inputs, exception_return=>'0', cpu_pri=>"000",
        irq_out=>open, irq_num=>open, exception_active=>open );

    u_crc : entity work.crc_accelerator port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(7), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(7), HRESP=>resp(7), HREADYOUT=>rdy(7), crc_irq=>crc_irq );

    u_aes : entity work.aes_accelerator port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(8), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(8), HRESP=>resp(8), HREADYOUT=>rdy(8), aes_irq=>aes_irq );

    u_sha : entity work.sha256_accelerator port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(9), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(9), HRESP=>resp(9), HREADYOUT=>rdy(9), sha_irq=>sha_irq );

    u_trng : entity work.trng_controller port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(10), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(10), HRESP=>resp(10), HREADYOUT=>rdy(10), trng_irq=>trng_irq );

    u_exti : entity work.exti_controller port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(11), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(11), HRESP=>resp(11), HREADYOUT=>rdy(11),
        exti_lines=>exti_lines, exti_irq=>open );

    u_nmi : entity work.nmi_controller port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(12), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(12), HRESP=>resp(12), HREADYOUT=>rdy(12),
        nmi_out=>nmi_out_sig, nmi_src=>nmi_src );

    u_cmu : entity work.cmu_controller port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(13), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(13), HRESP=>resp(13), HREADYOUT=>rdy(13),
        clk_in=>clk_in, clk_out=>clk_out, pll_locked=>pll_locked, cmu_irq=>cmu_irq );

    u_psc : entity work.psc_controller port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(14), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(14), HRESP=>resp(14), HREADYOUT=>rdy(14),
        wake_req=>'0', sleep_out=>open, deep_sleep_out=>open, peri_clk_en=>open, psc_irq=>psc_irq );

    u_uart : entity work.uart_ahb port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(15), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(15), HRESP=>resp(15), HREADYOUT=>rdy(15),
        txd=>uart_txd, rxd=>uart_rxd, uart_int=>uart_int );

    u_spi : entity work.spi_master_ahb port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(16), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(16), HRESP=>resp(16), HREADYOUT=>rdy(16),
        sclk=>spi_sclk, mosi=>spi_mosi, miso=>spi_miso, ss_n=>spi_ss_n, spi_int=>spi_int );

    u_i2c : entity work.i2c_master_ahb port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(17), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(17), HRESP=>resp(17), HREADYOUT=>rdy(17),
        sda=>i2c_sda, scl=>i2c_scl, i2c_int=>i2c_int );

    u_adc : entity work.adc_controller generic map ( NUM_CHANNELS=>8, CONV_CYCLES=>16 ) port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(18), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA, HRDATA=>rdata(18), HRESP=>resp(18), HREADYOUT=>rdy(18),
        adc_in=>adc_in, adc_int=>adc_int );

    u_wdt : entity work.wdt_controller generic map ( CLK_FREQ=>CLK_FREQ, DEFAULT_LOAD=>CLK_FREQ ) port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(19), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA, HRDATA=>rdata(19), HRESP=>resp(19), HREADYOUT=>rdy(19),
        wdt_int=>wdt_int, wdt_reset=>open );

    u_rtc : entity work.rtc_controller generic map ( CLK_FREQ=>CLK_FREQ ) port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(20), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HADDR=>HADDR, HWDATA=>HWDATA, HRDATA=>rdata(20), HRESP=>resp(20), HREADYOUT=>rdy(20),
        rtc_int=>rtc_int );

    u_dma : entity work.dma_controller generic map ( NUM_CHANNELS=>4, DATA_WIDTH=>32, ADDR_WIDTH=>32 ) port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(21), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(21), HRESP=>resp(21), HREADYOUT=>rdy(21),
        m_addr=>open, m_rdata=>(others=>'0'), m_wdata=>open, m_we=>open, m_req=>open, m_ack=>'0',
        dma_int=>open, dma_req_in=>(others=>'0') );

    global_irq <= nvic_irq or mpu_irq or dsp_irq or fpu_irq or dwt_irq or itm_irq
                  or crc_irq or aes_irq or sha_irq or trng_irq or cmu_irq or psc_irq
                  or uart_int or spi_int or i2c_int or adc_int or wdt_int or rtc_int;

end architecture rtl;

-- ================================================================================
-- soc_top : Unified multi-core SoC top-level
-- ================================================================================
-- Bus matrix with 4 masters (Cortex-M4, RISC-V, RP2040, Synergy S7) accessing
-- shared peripherals (ext_sram_controller, bootloader_rom) and each CPU subsystem.
--
-- Address Map (HADDR[31:28]):
--   0x0  ext_sram_controller   0x1  bootloader_rom
--   0x4  cortex_m4_top         0x5  riscv_top
--   0x6  synergy_s7_top
--
-- Arbitration: Priority-based (M0 > M1 > M2 > M3)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity soc_top is
    generic ( CLK_FREQ : integer := 50000000 );
    port (
        HCLK, HRESETn : in std_logic;

        -- 4 AHB-Lite master ports (packed: 4 masters, signals grouped)
        m_HSEL    : in  std_logic_vector(3 downto 0);
        m_HWRITE  : in  std_logic_vector(3 downto 0);
        m_HREADY  : in  std_logic_vector(3 downto 0);
        m_HMASTLOCK : in std_logic_vector(3 downto 0);
        m_HTRANS  : in  std_logic_vector(7 downto 0);   -- 2 bits per master
        m_HSIZE   : in  std_logic_vector(11 downto 0);  -- 3 bits per master
        m_HPROT   : in  std_logic_vector(15 downto 0);  -- 4 bits per master
        m_HADDR   : in  std_logic_vector(127 downto 0); -- 32 bits per master
        m_HWDATA  : in  std_logic_vector(127 downto 0);
        m_HRDATA  : out std_logic_vector(127 downto 0);
        m_HRESP   : out std_logic_vector(3 downto 0);
        m_HREADYOUT : out std_logic_vector(3 downto 0);

        -- RISC-V core clock/reset (separate from AHB clock)
        rv_clk, rv_reset : in std_logic;

        -- External SRAM interface (from ext_sram_controller)
        sram_addr  : out std_logic_vector(19 downto 0);
        sram_data  : inout std_logic_vector(31 downto 0);
        sram_oe_n  : out std_logic;
        sram_we_n  : out std_logic;
        sram_cs_n  : out std_logic;
        sram_bls_n : out std_logic_vector(3 downto 0);

        -- RP2040 (not on AHB bus, instantiated standalone)
        rp_clk     : in std_logic;
        rp_nRESET  : in std_logic;
        rp_irq_out : out std_logic;

        -- Combined interrupt from all cores
        global_irq : out std_logic
    );
end entity soc_top;

architecture rtl of soc_top is

    -- Bus matrix arbitration
    signal grant : integer range 0 to 3;

    -- Selected master signals (routed to shared bus)
    signal sel_HSEL, sel_HWRITE, sel_HREADY, sel_HMASTLOCK : std_logic;
    signal sel_HTRANS : std_logic_vector(1 downto 0);
    signal sel_HSIZE  : std_logic_vector(2 downto 0);
    signal sel_HPROT  : std_logic_vector(3 downto 0);
    signal sel_HADDR  : std_logic_vector(31 downto 0);
    signal sel_HWDATA : std_logic_vector(31 downto 0);
    signal sel_HRDATA : std_logic_vector(31 downto 0);
    signal sel_HRESP  : std_logic;
    signal sel_HREADYOUT : std_logic;

    -- Slave select and response (5 slaves: sram, boot, cm4, rv, synergy)
    signal sel_sram, sel_boot, sel_cm4, sel_rv, sel_synergy : std_logic;
    signal hsel_sram, hsel_boot, hsel_cm4, hsel_rv, hsel_synergy : std_logic;
    signal slave_idx : integer range 0 to 4;

    type sl_rdata_t is array(0 to 4) of std_logic_vector(31 downto 0);
    signal sl_rdata : sl_rdata_t;
    signal sl_resp  : std_logic_vector(4 downto 0);
    signal sl_rdy   : std_logic_vector(4 downto 0);

    -- Interrupt wires
    signal cm4_irq, rv_irq, synergy_irq : std_logic;

    -- Extract master signals from packed vectors
    type trans_arr_t is array(0 to 3) of std_logic_vector(1 downto 0);
    type size_arr_t  is array(0 to 3) of std_logic_vector(2 downto 0);
    type prot_arr_t  is array(0 to 3) of std_logic_vector(3 downto 0);
    type addr_arr_t  is array(0 to 3) of std_logic_vector(31 downto 0);
    signal m_trans : trans_arr_t;
    signal m_size  : size_arr_t;
    signal m_prot  : prot_arr_t;
    signal m_addr  : addr_arr_t;
    signal m_wdata : addr_arr_t;

begin

    -- Unpack master vectors
    gen_unpack: for i in 0 to 3 generate
        m_trans(i) <= m_HTRANS(i*2+1 downto i*2);
        m_size(i)  <= m_HSIZE(i*3+2 downto i*3);
        m_prot(i)  <= m_HPROT(i*4+3 downto i*4);
        m_addr(i)  <= m_HADDR(i*32+31 downto i*32);
        m_wdata(i) <= m_HWDATA(i*32+31 downto i*32);
    end generate;

    -- ========================================================================
    -- Bus matrix arbitration (priority: M0 > M1 > M2 > M3)
    -- ========================================================================
    grant <= 0 when (m_HSEL(0) = '1' and (m_trans(0)(1) = '1' or m_trans(0)(0) = '1')) else
             1 when (m_HSEL(1) = '1' and (m_trans(1)(1) = '1' or m_trans(1)(0) = '1')) else
             2 when (m_HSEL(2) = '1' and (m_trans(2)(1) = '1' or m_trans(2)(0) = '1')) else
             3 when (m_HSEL(3) = '1' and (m_trans(3)(1) = '1' or m_trans(3)(0) = '1')) else 0;

    -- Route selected master to shared bus
    sel_HSEL      <= m_HSEL(grant);
    sel_HWRITE    <= m_HWRITE(grant);
    sel_HREADY    <= m_HREADY(grant);
    sel_HMASTLOCK <= m_HMASTLOCK(grant);
    sel_HTRANS    <= m_trans(grant);
    sel_HSIZE     <= m_size(grant);
    sel_HPROT     <= m_prot(grant);
    sel_HADDR     <= m_addr(grant);
    sel_HWDATA    <= m_wdata(grant);

    -- Route shared bus response back to selected master
    gen_resp: for i in 0 to 3 generate
        m_HRDATA(i*32+31 downto i*32) <= sel_HRDATA when grant = i else (others => '0');
        m_HRESP(i)  <= sel_HRESP when grant = i else '0';
        m_HREADYOUT(i) <= sel_HREADYOUT when grant = i else '1';
    end generate;

    -- ========================================================================
    -- Shared bus address decode (HADDR[31:28])
    -- ========================================================================
    sel_sram    <= '1' when sel_HADDR(31 downto 28) = x"0" else '0';
    sel_boot    <= '1' when sel_HADDR(31 downto 28) = x"1" else '0';
    sel_cm4     <= '1' when sel_HADDR(31 downto 28) = x"4" else '0';
    sel_rv      <= '1' when sel_HADDR(31 downto 28) = x"5" else '0';
    sel_synergy <= '1' when sel_HADDR(31 downto 28) = x"6" else '0';

    hsel_sram    <= sel_sram    and sel_HSEL;
    hsel_boot    <= sel_boot    and sel_HSEL;
    hsel_cm4     <= sel_cm4     and sel_HSEL;
    hsel_rv      <= sel_rv      and sel_HSEL;
    hsel_synergy <= sel_synergy and sel_HSEL;

    -- Slave index for response mux
    slave_idx <= 0 when sel_sram = '1' else
                 1 when sel_boot = '1' else
                 2 when sel_cm4 = '1' else
                 3 when sel_rv = '1' else
                 4 when sel_synergy = '1' else 0;

    -- Response mux from selected slave
    sel_HRDATA    <= sl_rdata(slave_idx);
    sel_HRESP     <= sl_resp(slave_idx);
    sel_HREADYOUT <= sl_rdy(slave_idx);

    -- ========================================================================
    -- Shared peripherals
    -- ========================================================================
    u_ext_sram : entity work.ext_sram_controller port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>hsel_sram, HWRITE=>sel_HWRITE, HREADY=>sel_HREADY,
        HTRANS=>sel_HTRANS, HSIZE=>sel_HSIZE, HADDR=>sel_HADDR, HWDATA=>sel_HWDATA,
        HRDATA=>sl_rdata(0), HRESP=>sl_resp(0), HREADYOUT=>sl_rdy(0),
        sram_addr=>sram_addr, sram_data=>sram_data, sram_oe_n=>sram_oe_n,
        sram_we_n=>sram_we_n, sram_cs_n=>sram_cs_n, sram_bls_n=>sram_bls_n );

    u_bootloader : entity work.bootloader_rom port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>hsel_boot, HWRITE=>sel_HWRITE, HREADY=>sel_HREADY,
        HTRANS=>sel_HTRANS, HSIZE=>sel_HSIZE, HADDR=>sel_HADDR, HWDATA=>sel_HWDATA,
        HRDATA=>sl_rdata(1), HRESP=>sl_resp(1), HREADYOUT=>sl_rdy(1), boot_irq=>open );

    -- ========================================================================
    -- CPU subsystems (accessible via bus matrix)
    -- ========================================================================
    u_cortex_m4 : entity work.cortex_m4_top generic map ( CLK_FREQ=>CLK_FREQ ) port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>hsel_cm4, HWRITE=>sel_HWRITE, HREADY=>sel_HREADY,
        HMASTLOCK=>sel_HMASTLOCK, HTRANS=>sel_HTRANS, HSIZE=>sel_HSIZE, HPROT=>sel_HPROT,
        HADDR=>sel_HADDR, HWDATA=>sel_HWDATA, HRDATA=>sl_rdata(2), HRESP=>sl_resp(2), HREADYOUT=>sl_rdy(2),
        gpio_in=>(others=>'0'), gpio_out=>open, gpio_dir=>open,
        uart_txd=>open, uart_rxd=>'1', spi_sclk=>open, spi_mosi=>open, spi_miso=>'0',
        spi_ss_n=>open, i2c_sda=>open, i2c_scl=>open, adc_in=>(others=>'0'),
        tck=>'0', tms=>'0', tdi=>'0', tdo=>open, swclk=>'0', swdio=>open,
        exti_lines=>(others=>'0'), nmi_src=>(others=>'0'), irq_inputs=>(others=>'0'),
        clk_in=>(others=>'0'), clk_out=>open, pll_locked=>open, global_irq=>cm4_irq );

    u_riscv : entity work.riscv_top generic map ( CLK_FREQ=>CLK_FREQ ) port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>hsel_rv, HWRITE=>sel_HWRITE, HREADY=>sel_HREADY,
        HTRANS=>sel_HTRANS, HSIZE=>sel_HSIZE, HADDR=>sel_HADDR, HWDATA=>sel_HWDATA,
        HRDATA=>sl_rdata(3), HRESP=>sl_resp(3), HREADYOUT=>sl_rdy(3),
        clk=>rv_clk, reset=>rv_reset,
        core_uart_txd=>open, core_uart_rxd=>'1',
        core_spi_sclk=>open, core_spi_mosi=>open, core_spi_miso=>'0',
        core_i2c_sda=>open, core_i2c_scl=>open, core_adc_in=>(others=>'0'),
        uart_txd=>open, uart_rxd=>'1', spi_sclk=>open, spi_mosi=>open, spi_miso=>'0',
        spi_ss_n=>open, i2c_sda=>open, i2c_scl=>open,
        ext_irq_src=>(others=>'0'), global_irq=>rv_irq );

    u_synergy : entity work.synergy_s7_top generic map ( CLK_FREQ=>CLK_FREQ ) port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>hsel_synergy, HWRITE=>sel_HWRITE, HREADY=>sel_HREADY,
        HMASTLOCK=>sel_HMASTLOCK, HTRANS=>sel_HTRANS, HSIZE=>sel_HSIZE, HPROT=>sel_HPROT,
        HADDR=>sel_HADDR, HWDATA=>sel_HWDATA, HRDATA=>sl_rdata(4), HRESP=>sl_resp(4), HREADYOUT=>sl_rdy(4),
        gpio_in=>(others=>'0'), gpio_out=>open, gpio_dir=>open,
        uart_txd=>open, uart_rxd=>'1', spi_sclk=>open, spi_mosi=>open, spi_miso=>'0',
        i2c_sda=>open, i2c_scl=>open, adc_in=>(others=>'0'),
        gpt_out=>open, gpt_in=>(others=>'0'), agt_out=>open,
        sd_clk=>open, sd_cmd=>open, sd_dat=>open, sd_cd=>'1',
        lcd_hsync=>open, lcd_vsync=>open, lcd_de=>open, lcd_clk=>open,
        lcd_r=>open, lcd_g=>open, lcd_b=>open,
        trng_valid=>open, secure_boot=>open, global_irq=>synergy_irq );

    -- RP2040 (standalone, not on AHB bus matrix)
    u_rp2040 : entity work.rp2040_top port map (
        CLK=>rp_clk, nRESET=>rp_nRESET,
        qspi_clk=>open, qspi_cs_n=>open, qspi_dq=>open,
        gpio=>open, uart0_tx=>open, uart0_rx=>'1',
        uart1_tx=>open, uart1_rx=>'1',
        spi0_clk=>open, spi0_mosi=>open, spi0_miso=>'0', spi0_cs_n=>open,
        spi1_clk=>open, spi1_mosi=>open, spi1_miso=>'0', spi1_cs_n=>open,
        i2c0_sda=>open, i2c0_scl=>open, i2c1_sda=>open, i2c1_scl=>open,
        usb_dp=>open, usb_dm=>open, adc_in=>(others=>'0'),
        swclk0=>'0', swdio0=>open, swclk1=>'0', swdio1=>open, irq_out=>rp_irq_out );

    global_irq <= cm4_irq or rv_irq or synergy_irq or rp_irq_out;

end architecture rtl;

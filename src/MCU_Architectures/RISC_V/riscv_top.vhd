-- ================================================================================
-- riscv_top : Top-level RISC-V SoC integration
-- ================================================================================
-- Integrates RV32I core with CSR, CLINT, PLIC, PMP, M/A/C extensions, and
-- AHB-Lite peripherals (CRC, TRNG, UART, SPI, I2C) via bus matrix.
-- Address Map (HADDR[31:16]): 0x4000 csr | 0x4001 clint | 0x4002 plic
--   0x4003 pmp | 0x4004 m_ext | 0x4005 a_ext | 0x4006 c_ext
--   0x4007 crc | 0x4008 trng | 0x4009 uart | 0x400A spi | 0x400B i2c
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity riscv_top is
    generic ( CLK_FREQ : integer := 50000000 );
    port (
        -- AHB-Lite master port (external bus access)
        HCLK, HRESETn, HSEL, HWRITE, HREADY : in std_logic;
        HTRANS : in std_logic_vector(1 downto 0);
        HSIZE  : in std_logic_vector(2 downto 0);
        HADDR  : in std_logic_vector(31 downto 0);
        HWDATA : in std_logic_vector(31 downto 0);
        HRDATA : out std_logic_vector(31 downto 0);
        HRESP  : out std_logic;
        HREADYOUT : out std_logic;
        -- System
        clk, reset : in std_logic;
        -- RISC-V core I/O (built-in peripherals)
        core_uart_txd : out std_logic;  core_uart_rxd : in std_logic := '0';
        core_spi_sclk : out std_logic;  core_spi_mosi : out std_logic;
        core_spi_miso : in std_logic := '0';
        core_i2c_sda  : inout std_logic;  core_i2c_scl : inout std_logic;
        core_adc_in   : in std_logic_vector(95 downto 0) := (others => '0');
        -- External AHB peripherals I/O
        uart_txd : out std_logic;  uart_rxd : in std_logic := '0';
        spi_sclk : out std_logic;  spi_mosi : out std_logic;
        spi_miso : in std_logic := '0';  spi_ss_n : out std_logic_vector(3 downto 0);
        i2c_sda  : inout std_logic;  i2c_scl : inout std_logic;
        -- External interrupt sources to PLIC
        ext_irq_src : in std_logic_vector(31 downto 0) := (others => '0');
        -- Combined interrupt output
        global_irq  : out std_logic
    );
end entity riscv_top;

architecture rtl of riscv_top is
    type rdata_arr_t is array(0 to 11) of std_logic_vector(31 downto 0);
    type resp_arr_t  is array(0 to 11) of std_logic;
    signal rdata  : rdata_arr_t := (others => (others => '0'));
    signal resp   : resp_arr_t  := (others => '0');
    signal rdy    : resp_arr_t  := (others => '1');
    signal sel    : resp_arr_t;
    signal sel_idx: integer range 0 to 11;
    -- Interrupt wires
    signal clint_timer_irq, clint_sw_irq, plic_ext_irq : std_logic;
    signal plic_irq_id : std_logic_vector(5 downto 0);
    signal crc_irq_s, trng_irq_s, uart_int_s, spi_int_s, i2c_int_s : std_logic;
    signal mul_irq_s, amo_irq_s : std_logic;
    signal pmp_fault_s : std_logic;
    signal core_irq_out : std_logic;
    -- Core mem interface
    signal imem_addr, dmem_addr, dmem_wdata : std_logic_vector(31 downto 0);
    signal dmem_rdata : std_logic_vector(31 downto 0) := (others => '0');
    signal dmem_we, dmem_re : std_logic;
    -- Combined external interrupts for core
    signal core_ext_irq : std_logic_vector(31 downto 0);
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

    sel_idx <=  0 when sel(0)='1' else  1 when sel(1)='1' else  2 when sel(2)='1'
            else  3 when sel(3)='1' else  4 when sel(4)='1' else  5 when sel(5)='1'
            else  6 when sel(6)='1' else  7 when sel(7)='1' else  8 when sel(8)='1'
            else  9 when sel(9)='1' else 10 when sel(10)='1' else 11 when sel(11)='1' else 0;

    HRDATA <= rdata(sel_idx);  HRESP <= resp(sel_idx);  HREADYOUT <= rdy(sel_idx);

    -- Combine external interrupts for PLIC input
    core_ext_irq <= ext_irq_src or (0 => plic_ext_irq, 1 to 31 => '0');

    -- ========================================================================
    -- RISC-V CPU core
    -- ========================================================================
    u_core : entity work.riscv_core port map (
        clk => clk, reset => reset,
        imem_addr => imem_addr, imem_data => (others => '0'),
        dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
        dmem_rdata => dmem_rdata, dmem_we => dmem_we, dmem_re => dmem_re,
        timer_int => clint_timer_irq, software_int => clint_sw_irq,
        external_int => core_ext_irq, irq_out => core_irq_out,
        mepc_out => open, mcause_out => open,
        i2c_sda => core_i2c_sda, i2c_scl => core_i2c_scl, i2c_int => open,
        spi_sclk => core_spi_sclk, spi_mosi => core_spi_mosi,
        spi_miso => core_spi_miso, spi_int => open,
        uart_txd => core_uart_txd, uart_rxd => core_uart_rxd, uart_int => open,
        i2s_sck => open, i2s_ws => open, i2s_sd_tx => open, i2s_sd_rx => '0', i2s_int => open,
        wdt_int => open, wdt_reset => open, rtc_int => open,
        adc_in => core_adc_in, adc_int => open, dac_out => open );

    -- Simple data memory (echo back zeros for unimplemented memory)
    dmem_rdata <= (others => '0');

    -- ========================================================================
    -- RISC-V CSR
    -- ========================================================================
    u_csr : entity work.riscv_csr port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(0), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(0), HRESP=>resp(0), HREADYOUT=>rdy(0),
        hart_id=>x"0", exception_in=>'0', cause_in=>"00000",
        epc_in=>(others=>'0'), irq_timer=>clint_timer_irq,
        irq_software=>clint_sw_irq, irq_external=>plic_ext_irq );

    -- CLINT (timer + software interrupts)
    u_clint : entity work.riscv_clint port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(1), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(1), HRESP=>resp(1), HREADYOUT=>rdy(1),
        timer_irq=>clint_timer_irq, sw_irq=>clint_sw_irq );

    -- PLIC (external interrupt controller)
    u_plic : entity work.riscv_plic port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(2), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(2), HRESP=>resp(2), HREADYOUT=>rdy(2),
        ext_irq_in=>ext_irq_src, ext_irq_out=>plic_ext_irq, ext_irq_id=>plic_irq_id );

    -- PMP (physical memory protection)
    u_pmp : entity work.riscv_pmp port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(3), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(3), HRESP=>resp(3), HREADYOUT=>rdy(3),
        vaddr=>dmem_addr, access_type=>(dmem_we & dmem_re), pmp_fault=>pmp_fault_s );

    -- M extension (multiply/divide)
    u_m_ext : entity work.riscv_m_ext port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(4), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(4), HRESP=>resp(4), HREADYOUT=>rdy(4), mul_irq=>mul_irq_s );

    -- A extension (atomics)
    u_a_ext : entity work.riscv_a_ext port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(5), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(5), HRESP=>resp(5), HREADYOUT=>rdy(5), amo_irq=>amo_irq_s );

    -- C extension (compressed decoder)
    u_c_ext : entity work.riscv_c_ext port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(6), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(6), HRESP=>resp(6), HREADYOUT=>rdy(6),
        instr_16=>(others=>'0'), instr_32=>open, is_compressed=>open );

    -- CRC accelerator
    u_crc : entity work.crc_accelerator port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(7), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(7), HRESP=>resp(7), HREADYOUT=>rdy(7), crc_irq=>crc_irq_s );

    -- TRNG controller
    u_trng : entity work.trng_controller port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(8), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(8), HRESP=>resp(8), HREADYOUT=>rdy(8), trng_irq=>trng_irq_s );

    -- UART (AHB)
    u_uart : entity work.uart_ahb port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(9), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(9), HRESP=>resp(9), HREADYOUT=>rdy(9),
        txd=>uart_txd, rxd=>uart_rxd, uart_int=>uart_int_s );

    -- SPI master (AHB)
    u_spi : entity work.spi_master_ahb port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(10), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(10), HRESP=>resp(10), HREADYOUT=>rdy(10),
        sclk=>spi_sclk, mosi=>spi_mosi, miso=>spi_miso, ss_n=>spi_ss_n, spi_int=>spi_int_s );

    -- I2C master (AHB)
    u_i2c : entity work.i2c_master_ahb port map (
        HCLK=>HCLK, HRESETn=>HRESETn, HSEL=>sel(11), HWRITE=>HWRITE, HREADY=>HREADY,
        HTRANS=>HTRANS, HSIZE=>HSIZE, HADDR=>HADDR, HWDATA=>HWDATA,
        HRDATA=>rdata(11), HRESP=>resp(11), HREADYOUT=>rdy(11),
        sda=>i2c_sda, scl=>i2c_scl, i2c_int=>i2c_int_s );

    global_irq <= core_irq_out or plic_ext_irq or clint_timer_irq or clint_sw_irq
                  or crc_irq_s or trng_irq_s or uart_int_s or spi_int_s or i2c_int_s
                  or mul_irq_s or amo_irq_s or pmp_fault_s;

end architecture rtl;

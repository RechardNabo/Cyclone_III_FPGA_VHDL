-- ================================================================================
-- synergy_s2_tb : Testbench for synergy_s2_interface (Cortex-M0+ ultra-low-power)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_s2_tb is
end entity synergy_s2_tb;

architecture sim of synergy_s2_tb is

    component synergy_s2_interface is
        generic ( GPIO_WIDTH : integer := 16 );
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
            uart_txd : out std_logic;
            uart_rxd : in  std_logic;
            uart_int : out std_logic;
            spi_sclk : out std_logic;
            spi_mosi : out std_logic;
            spi_miso : in  std_logic;
            spi_int  : out std_logic;
            i2c_sda : inout std_logic;
            i2c_scl : inout std_logic;
            i2c_int : out std_logic;
            adc_in  : in  std_logic_vector(11 downto 0);
            adc_int : out std_logic;
            dma_req : out std_logic;
            dma_done: in  std_logic;
            can_tx  : out std_logic;
            can_rx  : in  std_logic;
            can_int : out std_logic;
            eth_txd : out std_logic_vector(3 downto 0);
            eth_rxd : in  std_logic_vector(3 downto 0);
            eth_int : out std_logic;
            usb_dp  : inout std_logic;
            usb_dm  : inout std_logic;
            usb_int : out std_logic;
            lcd_data : out std_logic_vector(15 downto 0);
            lcd_hsync: out std_logic;
            lcd_vsync: out std_logic;
            lcd_clk  : out std_logic;
            trng_valid  : out std_logic;
            secure_boot : out std_logic
        );
    end component;

    signal HCLK, HRESETn, HSEL, HWRITE, HREADY, HMASTLOCK : std_logic := '0';
    signal HTRANS : std_logic_vector(1 downto 0) := "00";
    signal HSIZE  : std_logic_vector(2 downto 0) := "010";
    signal HPROT  : std_logic_vector(3 downto 0) := (others => '0');
    signal HADDR  : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA : std_logic_vector(31 downto 0);
    signal HRESP  : std_logic;
    signal HREADYOUT : std_logic;
    signal gpio_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_out : std_logic_vector(31 downto 0);
    signal gpio_dir : std_logic_vector(31 downto 0);
    signal timer_int : std_logic;
    signal uart_txd : std_logic;
    signal uart_rxd : std_logic := '1';
    signal uart_int : std_logic;
    signal spi_sclk, spi_mosi, spi_int : std_logic;
    signal spi_miso : std_logic := '0';
    signal i2c_sda, i2c_scl : std_logic := 'Z';
    signal i2c_int : std_logic;
    signal adc_in  : std_logic_vector(11 downto 0) := (others => '0');
    signal adc_int : std_logic;
    signal dma_req : std_logic;
    signal dma_done: std_logic := '0';
    signal can_tx, can_rx, can_int : std_logic := '0';
    signal eth_txd : std_logic_vector(3 downto 0);
    signal eth_rxd : std_logic_vector(3 downto 0) := (others => '0');
    signal eth_int : std_logic;
    signal usb_dp, usb_dm : std_logic := 'Z';
    signal usb_int : std_logic;
    signal lcd_data : std_logic_vector(15 downto 0);
    signal lcd_hsync, lcd_vsync, lcd_clk : std_logic;
    signal trng_valid, secure_boot : std_logic;

    -- AHB-Lite transaction procedure
    procedure ahb_write(
        signal clk : in std_logic;
        constant addr : in std_logic_vector(31 downto 0);
        constant data : in std_logic_vector(31 downto 0);
        signal sel : out std_logic;
        signal wri : out std_logic;
        signal rdy : out std_logic;
        signal trans : out std_logic_vector(1 downto 0);
        signal a : out std_logic_vector(31 downto 0);
        signal d : out std_logic_vector(31 downto 0)
    ) is
    begin
        sel <= '1'; wri <= '1'; rdy <= '1'; trans <= "10";
        a <= addr; d <= data;
        wait until rising_edge(clk);
        sel <= '0'; wri <= '0'; trans <= "00";
    end procedure;

    procedure ahb_read(
        signal clk : in std_logic;
        constant addr : in std_logic_vector(31 downto 0);
        signal sel : out std_logic;
        signal wri : out std_logic;
        signal rdy : out std_logic;
        signal trans : out std_logic_vector(1 downto 0);
        signal a : out std_logic_vector(31 downto 0)
    ) is
    begin
        sel <= '1'; wri <= '0'; rdy <= '1'; trans <= "10";
        a <= addr;
        wait until rising_edge(clk);
        sel <= '0'; trans <= "00";
    end procedure;

begin

    HCLK <= not HCLK after 5 ns;

    dut : synergy_s2_interface
        generic map ( GPIO_WIDTH => 24 )
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HMASTLOCK => HMASTLOCK, HTRANS => HTRANS,
            HSIZE => HSIZE, HPROT => HPROT, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            gpio_in => gpio_in, gpio_out => gpio_out, gpio_dir => gpio_dir,
            timer_int => timer_int,
            uart_txd => uart_txd, uart_rxd => uart_rxd, uart_int => uart_int,
            spi_sclk => spi_sclk, spi_mosi => spi_mosi, spi_miso => spi_miso, spi_int => spi_int,
            i2c_sda => i2c_sda, i2c_scl => i2c_scl, i2c_int => i2c_int,
            adc_in => adc_in, adc_int => adc_int,
            dma_req => dma_req, dma_done => dma_done,
            can_tx => can_tx, can_rx => can_rx, can_int => can_int,
            eth_txd => eth_txd, eth_rxd => eth_rxd, eth_int => eth_int,
            usb_dp => usb_dp, usb_dm => usb_dm, usb_int => usb_int,
            lcd_data => lcd_data, lcd_hsync => lcd_hsync, lcd_vsync => lcd_vsync, lcd_clk => lcd_clk,
            trng_valid => trng_valid, secure_boot => secure_boot
        );

    stim : process
    begin
        -- Reset
        HRESETn <= '0';
        wait for 20 ns;
        HRESETn <= '1';
        wait for 10 ns;

        -- Write GPIO_DIR (offset 0x04)
        ahb_write(HCLK, x"40000004", x"0000FFFF", HSEL, HWRITE, HREADY, HTRANS, HADDR, HWDATA);
        wait for 10 ns;

        -- Write GPIO_DATA (offset 0x00)
        ahb_write(HCLK, x"40000000", x"0000AAAA", HSEL, HWRITE, HREADY, HTRANS, HADDR, HWDATA);
        wait for 10 ns;

        -- Read GPIO_DIR back
        ahb_read(HCLK, x"40000004", HSEL, HWRITE, HREADY, HTRANS, HADDR);
        wait for 10 ns;
        assert HRDATA = x"0000FFFF" report "S2: GPIO_DIR readback mismatch" severity error;

        -- Read GPIO_DATA back
        ahb_read(HCLK, x"40000000", HSEL, HWRITE, HREADY, HTRANS, HADDR);
        wait for 10 ns;
        assert HRDATA = x"0000AAAA" report "S2: GPIO_DATA readback mismatch" severity error;

        -- Write TIMER_CTRL (offset 0x08): enable + interrupt enable
        ahb_write(HCLK, x"40000008", x"00000003", HSEL, HWRITE, HREADY, HTRANS, HADDR, HWDATA);
        wait for 10 ns;

        -- Write TIMER_LOAD (offset 0x0C)
        ahb_write(HCLK, x"4000000C", x"00000010", HSEL, HWRITE, HREADY, HTRANS, HADDR, HWDATA);
        wait for 200 ns;

        -- Stimulate GPIO inputs
        gpio_in <= x"0000F0F0";
        wait for 20 ns;

        -- Stimulate UART RX
        uart_rxd <= '0';  -- start bit
        wait for 100 ns;
        uart_rxd <= '1';

        report "Synergy S2 testbench stimulus complete" severity note;
        assert false report "Testbench complete" severity failure;
        wait;
    end process stim;

end architecture sim;

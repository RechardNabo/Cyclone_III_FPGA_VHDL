-- ================================================================================
-- fpga_bram_controller : Block RAM (M9K) controller
-- ================================================================================
-- Dual-port RAM controller for Cyclone III M9K blocks with AHB-Lite interface.
--
-- Features:
--   * Dual-port RAM with configurable width and depth
--   * Port A: AHB-Lite register interface (read/write)
--   * Port B: Direct hardware interface (read/write)
--   * Configurable address width for various RAM sizes
--
-- Generics:
--   RAM_WIDTH  - data width in bits (default 32)
--   RAM_DEPTH  - number of entries (default 4096)
--   ADDR_WIDTH - address width in bits (default 12)
--
-- Register Map:
--   0x00: PORTA_ADDR - Port A address
--   0x04: PORTA_DATA - Port A data (write triggers write enable)
--   0x08: PORTB_ADDR - Port B address
--   0x0C: PORTB_DATA - Port B data (write triggers write enable)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fpga_bram_controller is
    generic (
        RAM_WIDTH  : integer := 32;
        RAM_DEPTH  : integer := 4096;
        ADDR_WIDTH : integer := 12
    );
    port (
        -- AHB-Lite slave interface
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

        -- Port B direct interface
        clk       : in  std_logic;
        we_a      : out std_logic;
        we_b      : out std_logic
    );
end entity fpga_bram_controller;

architecture rtl of fpga_bram_controller is

    constant REG_PORTA_ADDR : std_logic_vector(2 downto 0) := "000";
    constant REG_PORTA_DATA : std_logic_vector(2 downto 0) := "001";
    constant REG_PORTB_ADDR : std_logic_vector(2 downto 0) := "010";
    constant REG_PORTB_DATA : std_logic_vector(2 downto 0) := "011";

    -- Dual-port RAM array
    type ram_t is array(0 to RAM_DEPTH-1) of std_logic_vector(RAM_WIDTH-1 downto 0);
    signal ram : ram_t := (others => (others => '0'));

    -- Port A registers (AHB-Lite side)
    signal porta_addr : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal porta_data : std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');
    signal porta_we   : std_logic := '0';

    -- Port B registers (hardware side)
    signal portb_addr : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal portb_data : std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');
    signal portb_we   : std_logic := '0';

    -- Read data
    signal porta_rdata : std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');
    signal portb_rdata : std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');

    signal reg_sel  : std_logic_vector(2 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(4 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                porta_addr <= (others => '0');
                porta_data <= (others => '0');
                porta_we   <= '0';
                portb_addr <= (others => '0');
                portb_data <= (others => '0');
                portb_we   <= '0';
            elsif write_en = '1' then
                case reg_sel is
                    when REG_PORTA_ADDR =>
                        porta_addr <= unsigned(HWDATA(ADDR_WIDTH-1 downto 0));
                        porta_we   <= '0';
                    when REG_PORTA_DATA =>
                        porta_data <= HWDATA(RAM_WIDTH-1 downto 0);
                        porta_we   <= '1';
                    when REG_PORTB_ADDR =>
                        portb_addr <= unsigned(HWDATA(ADDR_WIDTH-1 downto 0));
                        portb_we   <= '0';
                    when REG_PORTB_DATA =>
                        portb_data <= HWDATA(RAM_WIDTH-1 downto 0);
                        portb_we   <= '1';
                    when others =>
                        porta_we <= '0';
                        portb_we <= '0';
                end case;
            else
                porta_we <= '0';
                portb_we <= '0';
            end if;
        end if;
    end process reg_write;

    -- Dual-port RAM write (Port A on HCLK, Port B on clk)
    -- Port A write
    process(HCLK)
    begin
        if rising_edge(HCLK) then
            if porta_we = '1' then
                ram(to_integer(porta_addr)) <= porta_data;
            end if;
            porta_rdata <= ram(to_integer(porta_addr));
        end if;
    end process;

    -- Port B write (separate clock domain)
    process(clk)
    begin
        if rising_edge(clk) then
            if portb_we = '1' then
                ram(to_integer(portb_addr)) <= portb_data;
            end if;
            portb_rdata <= ram(to_integer(portb_addr));
        end if;
    end process;

    -- Register read mux
    reg_read : process(reg_sel, porta_addr, porta_rdata, portb_addr, portb_rdata)
    begin
        case reg_sel is
            when REG_PORTA_ADDR =>
                HRDATA <= std_logic_vector(resize(porta_addr, 32));
            when REG_PORTA_DATA =>
                HRDATA <= std_logic_vector(resize(unsigned(porta_rdata), 32));
            when REG_PORTB_ADDR =>
                HRDATA <= std_logic_vector(resize(portb_addr, 32));
            when REG_PORTB_DATA =>
                HRDATA <= std_logic_vector(resize(unsigned(portb_rdata), 32));
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    we_a <= porta_we;
    we_b <= portb_we;

end architecture rtl;

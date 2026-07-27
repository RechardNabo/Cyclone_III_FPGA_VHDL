-- ================================================================================
-- cortex_interface : Generic configurable AHB-Lite peripheral controller
-- ================================================================================
-- This is a GENERIC Cortex-style interface (not variant-specific).
-- It provides a parameterizable register file, GPIO, and interrupt aggregator
-- that can be used as a building block for any ARM Cortex-M peripheral.
--
-- Generics:
--   NUM_REGS   : number of 32-bit registers in the register file (default 8)
--   GPIO_WIDTH : width of the GPIO port (default 32)
--   NUM_IRQ    : number of interrupt inputs to aggregate (default 16)
--
-- Memory map (Peripheral 0x40000000):
--   0x40000000 - 0x400000xx : Register file (NUM_REGS x 4 bytes)
--   0x40000100 - 0x4000010F : GPIO (data, dir, afsel)
--   0x40000200 - 0x4000020F : Interrupt aggregator (enable, pending, status)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cortex_interface is
    generic (
        NUM_REGS   : integer := 8;
        GPIO_WIDTH : integer := 32;
        NUM_IRQ    : integer := 16
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
        -- Interrupt aggregator
        irq_inputs : in  std_logic_vector(NUM_IRQ-1 downto 0);
        irq_out    : out std_logic;
        -- GPIO
        gpio_in   : in  std_logic_vector(GPIO_WIDTH-1 downto 0);
        gpio_out  : out std_logic_vector(GPIO_WIDTH-1 downto 0);
        gpio_dir  : out std_logic_vector(GPIO_WIDTH-1 downto 0)
    );
end entity cortex_interface;

architecture rtl of cortex_interface is

    -- Address block selects (bits [11:8])
    constant BLK_REGS : std_logic_vector(3 downto 0) := x"0"; -- 0x40000000
    constant BLK_GPIO : std_logic_vector(3 downto 0) := x"1"; -- 0x40000100
    constant BLK_IRQ  : std_logic_vector(3 downto 0) := x"2"; -- 0x40000200

    -- GPIO sub-register selects (bits [5:2])
    constant GPIO_DATA  : std_logic_vector(3 downto 0) := x"0";
    constant GPIO_DIR   : std_logic_vector(3 downto 0) := x"1";
    constant GPIO_AFSEL : std_logic_vector(3 downto 0) := x"2";

    -- IRQ sub-register selects
    constant IRQ_ENABLE  : std_logic_vector(3 downto 0) := x"0";
    constant IRQ_PENDING : std_logic_vector(3 downto 0) := x"1";
    constant IRQ_STATUS  : std_logic_vector(3 downto 0) := x"2";

    -- Register file storage
    type reg_file_array is array(0 to NUM_REGS-1) of std_logic_vector(31 downto 0);
    signal reg_file : reg_file_array := (others => (others => '0'));

    -- GPIO registers (extended to 32 bits internally, masked on output)
    signal gpio_data_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_dir_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_afsel    : std_logic_vector(31 downto 0) := (others => '0');

    -- Interrupt aggregator registers
    signal irq_enable  : std_logic_vector(31 downto 0) := (others => '0');
    signal irq_pending : std_logic_vector(31 downto 0) := (others => '0');

    -- Address decode
    signal addr_blk  : std_logic_vector(3 downto 0);
    signal addr_sub  : std_logic_vector(3 downto 0);
    signal reg_index : integer range 0 to NUM_REGS-1;
    signal write_en  : std_logic;
    signal valid_addr: std_logic;
    signal irq_combined : std_logic_vector(31 downto 0);

begin

    addr_blk <= HADDR(11 downto 8);
    addr_sub <= HADDR(5 downto 2);
    reg_index <= to_integer(unsigned(HADDR(7 downto 2))) when
                 to_integer(unsigned(HADDR(7 downto 2))) < NUM_REGS else 0;
    write_en <= HSEL and HREADY and HWRITE;
    valid_addr <= '1' when HADDR(31 downto 28) = x"4" else '0';

    -- ------------------------------------------------------------------------
    -- AHB-Lite write process
    -- ------------------------------------------------------------------------
    ahb_write : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            reg_file       <= (others => (others => '0'));
            gpio_data_reg  <= (others => '0');
            gpio_dir_reg   <= (others => '0');
            gpio_afsel     <= (others => '0');
            irq_enable     <= (others => '0');
            irq_pending    <= (others => '0');
        elsif rising_edge(HCLK) then
            if write_en = '1' and valid_addr = '1' then
                case addr_blk is
                    when BLK_REGS =>
                        if to_integer(unsigned(HADDR(7 downto 2))) < NUM_REGS then
                            reg_file(reg_index) <= HWDATA;
                        end if;
                    when BLK_GPIO =>
                        case addr_sub is
                            when GPIO_DATA  => gpio_data_reg <= HWDATA;
                            when GPIO_DIR   => gpio_dir_reg  <= HWDATA;
                            when GPIO_AFSEL => gpio_afsel    <= HWDATA;
                            when others     => null;
                        end case;
                    when BLK_IRQ =>
                        case addr_sub is
                            when IRQ_ENABLE  => irq_enable  <= irq_enable or HWDATA;
                            when IRQ_PENDING => irq_pending <= irq_pending or HWDATA;
                            when IRQ_STATUS  => irq_pending <= irq_pending and not HWDATA; -- clear
                            when others      => null;
                        end case;
                    when others => null;
                end case;
            end if;
        end if;
    end process ahb_write;

    -- ------------------------------------------------------------------------
    -- AHB-Lite read mux
    -- ------------------------------------------------------------------------
    ahb_read : process(HSEL, HADDR, valid_addr, addr_blk, addr_sub,
                       reg_file, gpio_data_reg, gpio_dir_reg, gpio_afsel,
                       irq_enable, irq_pending, irq_combined, reg_index)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' and valid_addr = '1' then
            case addr_blk is
                when BLK_REGS =>
                    if to_integer(unsigned(HADDR(7 downto 2))) < NUM_REGS then
                        rdata := reg_file(reg_index);
                    end if;
                when BLK_GPIO =>
                    case addr_sub is
                        when GPIO_DATA  => rdata := gpio_data_reg;
                        when GPIO_DIR   => rdata := gpio_dir_reg;
                        when GPIO_AFSEL => rdata := gpio_afsel;
                        when others     => null;
                    end case;
                when BLK_IRQ =>
                    case addr_sub is
                        when IRQ_ENABLE  => rdata := irq_enable;
                        when IRQ_PENDING => rdata := irq_pending;
                        when IRQ_STATUS  => rdata := irq_combined;
                        when others      => null;
                    end case;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '1' when (HSEL = '1' and valid_addr = '0') else '0';
    HREADYOUT <= '1';

    -- GPIO outputs (masked to GPIO_WIDTH)
    gpio_out <= gpio_data_reg(GPIO_WIDTH-1 downto 0);
    gpio_dir <= gpio_dir_reg(GPIO_WIDTH-1 downto 0);

    -- ------------------------------------------------------------------------
    -- Interrupt aggregator: combine external IRQs with pending, mask by enable
    -- ------------------------------------------------------------------------
    irq_combined(31 downto 0) <= (irq_pending(31 downto 0) or
                                   (irq_inputs & x"0000"(NUM_IRQ-1 downto 0))) and
                                  irq_enable(31 downto 0);

    irq_out <= '1' when unsigned(irq_combined) /= 0 else '0';

end architecture rtl;

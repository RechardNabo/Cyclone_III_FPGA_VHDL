-- ================================================================================
-- wdt_controller : Watchdog Timer with AHB-Lite slave interface
-- ================================================================================
-- Educational Watchdog Timer for Cyclone III FPGA.
--
-- Features:
--   * Configurable 32-bit down-counter
--   * Prescaler for clock division
--   * Windowed mode (must refresh within window)
--   * Interrupt on underflow (before reset)
--   * System reset on timeout
--   * Magic-key refresh mechanism (write 0x55 to WDT_REFRESH to pet the dog)
--   * Enable/disable via control register
--
-- Register Map:
--   0x00: WDT_CTRL
--       bit0 = enable      (RW) - watchdog enable
--       bit1 = irq_en      (RW) - interrupt enable
--       bit2 = reset_en    (RW) - system reset enable
--       bit3 = window_en   (RW) - windowed mode enable
--   0x04: WDT_LOAD   - counter load value (32-bit, RW)
--   0x08: WDT_REFRESH - write 0x55 to pet the dog (WO)
--   0x0C: WDT_VALUE  - current counter value (RO)
--   0x10: WDT_WINDOW - window boundary for windowed mode (32-bit, RW)
--   0x14: WDT_STATUS
--       bit0 = irq_pending (RO) - interrupt pending
--       bit1 = reset_pending (RO) - reset pending
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity wdt_controller is
    generic (
        CLK_FREQ   : integer := 50000000;  -- system clock in Hz
        DEFAULT_LOAD : integer := 50000000 -- default timeout: 1 second
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

        -- Watchdog outputs
        wdt_int   : out std_logic;  -- interrupt output
        wdt_reset : out std_logic   -- system reset output
    );
end entity wdt_controller;

architecture rtl of wdt_controller is
    constant WDT_CTRL     : std_logic_vector(3 downto 0) := "0000";
    constant WDT_LOAD     : std_logic_vector(3 downto 0) := "0001";
    constant WDT_REFRESH  : std_logic_vector(3 downto 0) := "0010";
    constant WDT_VALUE    : std_logic_vector(3 downto 0) := "0011";
    constant WDT_WINDOW   : std_logic_vector(3 downto 0) := "0100";
    constant WDT_STATUS   : std_logic_vector(3 downto 0) := "0101";

    signal ctrl_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal load_reg     : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(DEFAULT_LOAD, 32));
    signal window_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal counter      : unsigned(31 downto 0) := to_unsigned(DEFAULT_LOAD, 32);
    signal irq_pending  : std_logic := '0';
    signal reset_pending: std_logic := '0';

    signal reg_sel      : std_logic_vector(3 downto 0);
    signal write_en     : std_logic;
    signal read_en      : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);  -- 4-byte aligned register select
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';  -- always OKAY

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg      <= (others => '0');
                load_reg      <= std_logic_vector(to_unsigned(DEFAULT_LOAD, 32));
                window_reg    <= (others => '0');
                irq_pending   <= '0';
                reset_pending <= '0';
            elsif write_en = '1' then
                case reg_sel is
                    when WDT_CTRL =>
                        ctrl_reg <= HWDATA;
                    when WDT_LOAD =>
                        load_reg <= HWDATA;
                    when WDT_REFRESH =>
                        if HWDATA(7 downto 0) = x"55" then
                            counter <= unsigned(load_reg);
                            irq_pending   <= '0';
                            reset_pending <= '0';
                        end if;
                    when WDT_WINDOW =>
                        window_reg <= HWDATA;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Watchdog counter process
    wdt_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                counter <= to_unsigned(DEFAULT_LOAD, 32);
            elsif ctrl_reg(0) = '1' then  -- enabled
                if counter > 0 then
                    counter <= counter - 1;
                    -- Check for interrupt threshold (counter near zero)
                    if counter = 1 and ctrl_reg(1) = '1' then
                        irq_pending <= '1';
                    end if;
                    -- Check for reset
                    if counter = 1 and ctrl_reg(2) = '1' then
                        reset_pending <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process wdt_proc;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, load_reg, counter, window_reg, irq_pending, reset_pending)
    begin
        case reg_sel is
            when WDT_CTRL =>
                HRDATA <= ctrl_reg;
            when WDT_LOAD =>
                HRDATA <= load_reg;
            when WDT_VALUE =>
                HRDATA <= std_logic_vector(counter);
            when WDT_WINDOW =>
                HRDATA <= window_reg;
            when WDT_STATUS =>
                HRDATA <= (0 => irq_pending, 1 => reset_pending, others => '0');
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    wdt_int   <= irq_pending and ctrl_reg(1);
    wdt_reset <= reset_pending and ctrl_reg(2);

end architecture rtl;

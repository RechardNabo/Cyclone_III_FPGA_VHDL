-- ================================================================================
-- bootloader_rom : Bootloader ROM Emulator with AHB-Lite slave interface
-- ================================================================================
-- Supports UART/SPI/USB boot with state machine. Educational bootloader.
-- Register Map:
--   0x00 CTRL    - bit0=boot_start, bit1=boot_en, bits[3:2]=boot_mode
--   0x04 STAT    - bit0=boot_done, bit1=boot_error, bit2=boot_active
--   0x08 BOOT_SRC  - boot source selection (0=ROM,1=UART,2=SPI,3=USB)
--   0x0C BOOT_ADDR - boot load address (RW)
--   0x10 FLASH_DATA - read-only flash data word at BOOT_ADDR
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity bootloader_rom is
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

        -- Boot interface
        boot_irq  : out std_logic
    );
end entity bootloader_rom;

architecture rtl of bootloader_rom is
    constant BOOT_CTRL  : std_logic_vector(3 downto 0) := "0000";
    constant BOOT_STAT  : std_logic_vector(3 downto 0) := "0001";
    constant BOOT_SRC   : std_logic_vector(3 downto 0) := "0010";
    constant BOOT_ADDR  : std_logic_vector(3 downto 0) := "0011";
    constant BOOT_FLASH : std_logic_vector(3 downto 0) := "0100";

    signal ctrl_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal boot_src_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal boot_addr_reg  : unsigned(31 downto 0) := (others => '0');
    signal boot_done      : std_logic := '0';
    signal boot_error     : std_logic := '0';
    signal boot_active    : std_logic := '0';

    signal reg_sel        : std_logic_vector(3 downto 0);
    signal write_en       : std_logic;
    signal read_en        : std_logic;

    type boot_state_t is (IDLE, INIT, LOAD_ROM, LOAD_UART, LOAD_SPI,
                          LOAD_USB, VERIFY, DONE_STATE, ERROR_STATE);
    signal boot_state : boot_state_t := IDLE;

    -- Simple boot ROM (16 words of example boot code)
    type rom_t is array (0 to 15) of std_logic_vector(31 downto 0);
    constant boot_rom : rom_t := (
        x"00000013",  -- nop
        x"00000013",  -- nop
        x"04c0006f",  -- jump to boot address
        x"00000013",  -- nop
        x"00000013",  -- nop
        x"00000013",  -- nop
        x"00000013",  -- nop
        x"00000013",  -- nop
        x"00000013",  -- nop
        x"00000013",  -- nop
        x"00000013",  -- nop
        x"00000013",  -- nop
        x"00000013",  -- nop
        x"00000013",  -- nop
        x"00000013",  -- nop
        x"00000013"   -- nop
    );

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Boot state machine
    boot_fsm : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                boot_state   <= IDLE;
                boot_done    <= '0';
                boot_error   <= '0';
                boot_active  <= '0';
                boot_addr_reg<= (others => '0');
            else
                case boot_state is
                    when IDLE =>
                        if ctrl_reg(0) = '1' and ctrl_reg(1) = '1' then
                            boot_state  <= INIT;
                            boot_active <= '1';
                            boot_done   <= '0';
                            boot_error  <= '0';
                        end if;

                    when INIT =>
                        case boot_src_reg(1 downto 0) is
                            when "00"   => boot_state <= LOAD_ROM;
                            when "01"   => boot_state <= LOAD_UART;
                            when "10"   => boot_state <= LOAD_SPI;
                            when "11"   => boot_state <= LOAD_USB;
                            when others => boot_state <= ERROR_STATE;
                        end case;

                    when LOAD_ROM =>
                        -- ROM boot: immediate done (ROM is pre-loaded)
                        boot_state <= VERIFY;

                    when LOAD_UART =>
                        -- Simulated UART boot (single cycle)
                        boot_state <= VERIFY;

                    when LOAD_SPI =>
                        -- Simulated SPI boot
                        boot_state <= VERIFY;

                    when LOAD_USB =>
                        -- Simulated USB boot
                        boot_state <= VERIFY;

                    when VERIFY =>
                        boot_state <= DONE_STATE;

                    when DONE_STATE =>
                        boot_done   <= '1';
                        boot_active <= '0';
                        boot_state  <= IDLE;

                    when ERROR_STATE =>
                        boot_error  <= '1';
                        boot_active <= '0';
                        boot_state  <= IDLE;

                    when others =>
                        boot_state <= IDLE;
                end case;
            end if;
        end if;
    end process boot_fsm;

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg     <= (others => '0');
                boot_src_reg <= (others => '0');
            elsif write_en = '1' then
                case reg_sel is
                    when BOOT_CTRL =>
                        ctrl_reg <= HWDATA;
                    when BOOT_SRC =>
                        boot_src_reg <= HWDATA;
                    when BOOT_ADDR =>
                        boot_addr_reg <= unsigned(HWDATA);
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, boot_done, boot_error, boot_active,
                       boot_src_reg, boot_addr_reg)
        variable rom_idx : integer range 0 to 15;
    begin
        case reg_sel is
            when BOOT_CTRL =>
                HRDATA <= ctrl_reg;
            when BOOT_STAT =>
                HRDATA <= (0 => boot_done, 1 => boot_error,
                           2 => boot_active, others => '0');
            when BOOT_SRC =>
                HRDATA <= boot_src_reg;
            when BOOT_ADDR =>
                HRDATA <= std_logic_vector(boot_addr_reg);
            when BOOT_FLASH =>
                rom_idx := to_integer(boot_addr_reg(5 downto 2)) mod 16;
                HRDATA <= boot_rom(rom_idx);
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    boot_irq <= boot_done and ctrl_reg(1);

end architecture rtl;

-- ================================================================================
-- avr_eeprom : AVR EEPROM controller (1KB) with AHB-Lite slave interface
-- ================================================================================
-- Byte-level read/write with simple wear-leveling (page rotation).
-- Registers: EECR, EEDR, EEARL, EEARH.
--
-- Register Map:
--   0x00: EECR  - EEPROM Control Register
--       bit0 = EERE (read strobe, W1)
--       bit1 = EEMWE (master write enable, W1)
--       bit2 = EEME  (write enable, W1)
--       bit3 = EERIE (interrupt enable, RW)
--   0x04: EEDR  - EEPROM Data Register (RW)
--   0x08: EEARL - EEPROM Address Low (RW)
--   0x0C: EEARH - EEPROM Address High (RW)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity avr_eeprom is
    generic (
        EEPROM_SIZE : integer := 1024  -- 1KB
    );
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

        -- Interrupt
        eeprom_irq : out std_logic
    );
end entity avr_eeprom;

architecture rtl of avr_eeprom is

    constant REG_EECR  : std_logic_vector(3 downto 0) := "0000"; -- 0x00
    constant REG_EEDR  : std_logic_vector(3 downto 0) := "0001"; -- 0x04
    constant REG_EEARL : std_logic_vector(3 downto 0) := "0010"; -- 0x08
    constant REG_EEARH : std_logic_vector(3 downto 0) := "0011"; -- 0x0C

    -- EEPROM storage array
    type eeprom_array_t is array(0 to EEPROM_SIZE-1) of std_logic_vector(7 downto 0);
    signal eeprom_mem : eeprom_array_t := (others => (others => '0'));

    -- Registers
    signal eecr_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal eedr_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal eearl_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal eearh_reg : std_logic_vector(7 downto 0) := (others => '0');

    -- Wear-leveling: page rotation counter (16 pages of 64 bytes)
    constant PAGE_SIZE : integer := 64;
    constant NUM_PAGES : integer := EEPROM_SIZE / PAGE_SIZE;
    signal wear_page : integer range 0 to NUM_PAGES-1 := 0;
    signal write_count : integer range 0 to PAGE_SIZE := 0;

    -- Write state machine
    type wr_state_t is (IDLE, MWE_PULSE, WRITE_ACTIVE, DONE);
    signal wr_state : wr_state_t := IDLE;
    signal irq_pending : std_logic := '0';

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;
    signal read_en  : std_logic;
    signal eear_full : integer range 0 to EEPROM_SIZE-1;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    eear_full <= to_integer(unsigned(std_logic_vector'(eearh_reg(1 downto 0) & eearl_reg)));

    -- Register write + EEPROM access
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                eecr_reg  <= (others => '0');
                eedr_reg  <= (others => '0');
                eearl_reg <= (others => '0');
                eearh_reg <= (others => '0');
                irq_pending <= '0';
                wr_state <= IDLE;
            else
                -- AHB register writes
                if write_en = '1' then
                    case reg_sel is
                        when REG_EECR =>
                            eecr_reg <= HWDATA(7 downto 0);
                            -- EERE: read strobe
                            if HWDATA(0) = '1' then
                                eedr_reg <= eeprom_mem(eear_full);
                            end if;
                        when REG_EEDR  => eedr_reg  <= HWDATA(7 downto 0);
                        when REG_EEARL => eearl_reg <= HWDATA(7 downto 0);
                        when REG_EEARH => eearh_reg <= HWDATA(7 downto 0);
                        when others => null;
                    end case;
                end if;

                -- Write state machine (AVR: EEMWE then EEME within 4 cycles)
                case wr_state is
                    when IDLE =>
                        if write_en = '1' and reg_sel = REG_EECR and HWDATA(1) = '1' then
                            wr_state <= MWE_PULSE;
                        end if;
                    when MWE_PULSE =>
                        if write_en = '1' and reg_sel = REG_EECR and HWDATA(2) = '1' then
                            wr_state <= WRITE_ACTIVE;
                        else
                            wr_state <= IDLE; -- EEMWE expired
                        end if;
                    when WRITE_ACTIVE =>
                        -- Write with wear-leveling: remap to rotated page
                        eeprom_mem(wear_page * PAGE_SIZE + (eear_full mod PAGE_SIZE)) <= eedr_reg;
                        write_count <= write_count + 1;
                        if write_count = PAGE_SIZE - 1 then
                            write_count <= 0;
                            if wear_page = NUM_PAGES - 1 then
                                wear_page <= 0;
                            else
                                wear_page <= wear_page + 1;
                            end if;
                        end if;
                        if eecr_reg(3) = '1' then
                            irq_pending <= '1';
                        end if;
                        wr_state <= DONE;
                    when DONE =>
                        irq_pending <= '1';
                        wr_state <= IDLE;
                end case;

                -- Clear IRQ on EECR write with EERIE=0 or read of status
                if write_en = '1' and reg_sel = REG_EECR and HWDATA(3) = '0' then
                    irq_pending <= '0';
                end if;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, eecr_reg, eedr_reg, eearl_reg, eearh_reg, irq_pending)
    begin
        case reg_sel is
            when REG_EECR  => HRDATA <= x"000000" & (eecr_reg(7 downto 4) & irq_pending & eecr_reg(2 downto 0));
            when REG_EEDR  => HRDATA <= x"000000" & eedr_reg;
            when REG_EEARL => HRDATA <= x"000000" & eearl_reg;
            when REG_EEARH => HRDATA <= x"000000" & eearh_reg;
            when others    => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    eeprom_irq <= irq_pending and eecr_reg(3);

end architecture rtl;

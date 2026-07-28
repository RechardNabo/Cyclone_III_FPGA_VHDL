-- ================================================================================
-- vtor_controller : Vector Table Remap Controller with AHB-Lite slave interface
-- ================================================================================
-- Runtime relocation of interrupt vector table. 64 interrupt vectors.
-- Register Map:
--   0x00 CTRL       - bit0=enable, bit1=lock_en
--   0x04 VTOR_ADDR  - vector table base address (RW, 512-byte aligned)
--   0x08 VTOR_LOCK  - write magic 0x564C to lock VTOR_ADDR (WO)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity vtor_controller is
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

        -- Vector table interface
        irq_num       : in  std_logic_vector(5 downto 0);  -- 0-63
        vector_addr   : out std_logic_vector(31 downto 0)
    );
end entity vtor_controller;

architecture rtl of vtor_controller is
    constant VTOR_CTRL  : std_logic_vector(3 downto 0) := "0000";
    constant VTOR_ADDR  : std_logic_vector(3 downto 0) := "0001";
    constant VTOR_LOCK  : std_logic_vector(3 downto 0) := "0010";

    constant NUM_VECTORS  : integer := 64;
    constant LOCK_MAGIC   : std_logic_vector(15 downto 0) := x"564C";

    signal ctrl_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal vtor_addr_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal vtor_locked    : std_logic := '0';

    signal reg_sel        : std_logic_vector(3 downto 0);
    signal write_en       : std_logic;
    signal read_en        : std_logic;

    -- Vector table storage (64 entries)
    type vector_table_t is array (0 to NUM_VECTORS-1) of std_logic_vector(31 downto 0);
    signal vector_table : vector_table_t := (others => (others => '0'));

    signal vector_idx     : integer range 0 to NUM_VECTORS-1 := 0;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Vector address output: base + (irq_num * 4)
    vector_addr <= std_logic_vector(unsigned(vtor_addr_reg) +
                                    unsigned(irq_num) & "00");

    -- Vector table write access via AHB (when addressing beyond registers)
    -- HADDR[7:2] selects vector index (0-63), reg_sel for control regs
    vector_idx <= to_integer(unsigned(HADDR(7 downto 2)));

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg      <= (others => '0');
                vtor_addr_reg <= (others => '0');
                vtor_locked   <= '0';
                vector_table  <= (others => (others => '0'));
            elsif write_en = '1' then
                case reg_sel is
                    when VTOR_CTRL =>
                        ctrl_reg <= HWDATA;
                    when VTOR_ADDR =>
                        if vtor_locked = '0' then
                            -- Align to 512 bytes (clear lower 9 bits)
                            vtor_addr_reg <= HWDATA(31 downto 9) & "000000000";
                        end if;
                    when VTOR_LOCK =>
                        if HWDATA(15 downto 0) = LOCK_MAGIC and
                           ctrl_reg(1) = '1' then
                            vtor_locked <= '1';
                        end if;
                    when others =>
                        -- Direct vector table write (HADDR[7:2] = vector index)
                        if HADDR(8) = '1' and vtor_locked = '0' then
                            if vector_idx < NUM_VECTORS then
                                vector_table(vector_idx) <= HWDATA;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, vtor_addr_reg, vtor_locked,
                       vector_table, HADDR, vector_idx)
    begin
        case reg_sel is
            when VTOR_CTRL =>
                HRDATA <= (0 => ctrl_reg(0), 1 => ctrl_reg(1),
                           2 => vtor_locked, others => '0');
            when VTOR_ADDR =>
                HRDATA <= vtor_addr_reg;
            when VTOR_LOCK =>
                HRDATA <= (0 => vtor_locked, others => '0');
            when others =>
                -- Direct vector table read
                if HADDR(8) = '1' and vector_idx < NUM_VECTORS then
                    HRDATA <= vector_table(vector_idx);
                else
                    HRDATA <= (others => '0');
                end if;
        end case;
    end process reg_read;

end architecture rtl;

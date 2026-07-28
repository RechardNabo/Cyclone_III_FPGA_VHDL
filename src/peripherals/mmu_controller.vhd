-- ================================================================================
-- mmu_controller : Simple Memory Management Unit with AHB-Lite slave interface
-- ================================================================================
-- Virtual-to-physical translation with 16-entry TLB.
-- Register Map:
--   0x00 CTRL       - bit0=enable, bit1=irq_en
--   0x04 TLB_ENTRY  - write VPN[31:20], PFN[31:20], flags to TLB index
--   0x08 TLB_INDEX  - TLB index (0-15) for read/write
--   0x0C FAULT_ADDR - faulting virtual address (RO)
--   0x10 FAULT_TYPE - bit0=page_fault, bit1=permission, bit2=tlb_miss
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity mmu_controller is
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

        -- MMU translation interface
        vaddr     : in  std_logic_vector(31 downto 0);
        paddr     : out std_logic_vector(31 downto 0);
        fault     : out std_logic;
        mmu_irq   : out std_logic
    );
end entity mmu_controller;

architecture rtl of mmu_controller is
    constant MMU_CTRL      : std_logic_vector(3 downto 0) := "0000";
    constant MMU_TLB_ENTRY : std_logic_vector(3 downto 0) := "0001";
    constant MMU_TLB_INDEX : std_logic_vector(3 downto 0) := "0010";
    constant MMU_FAULT_ADDR: std_logic_vector(3 downto 0) := "0011";
    constant MMU_FAULT_TYPE: std_logic_vector(3 downto 0) := "0100";

    constant TLB_ENTRIES : integer := 16;
    constant VPN_BITS    : integer := 12;  -- top 12 bits = VPN
    constant PFN_BITS    : integer := 12;

    signal ctrl_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal tlb_index_reg  : unsigned(31 downto 0) := (others => '0');

    type vpn_array_t  is array (0 to TLB_ENTRIES-1) of
        std_logic_vector(VPN_BITS-1 downto 0);
    type pfn_array_t  is array (0 to TLB_ENTRIES-1) of
        std_logic_vector(PFN_BITS-1 downto 0);
    type flags_array_t is array (0 to TLB_ENTRIES-1) of std_logic_vector(2 downto 0);
    type valid_array_t is array (0 to TLB_ENTRIES-1) of std_logic;

    signal tlb_vpn   : vpn_array_t   := (others => (others => '0'));
    signal tlb_pfn   : pfn_array_t   := (others => (others => '0'));
    signal tlb_flags : flags_array_t := (others => (others => '0'));
    signal tlb_valid : valid_array_t := (others => '0');

    signal fault_addr_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal fault_type_reg : std_logic_vector(31 downto 0) := (others => '0');

    signal reg_sel    : std_logic_vector(3 downto 0);
    signal write_en   : std_logic;
    signal read_en    : std_logic;

    signal tlb_hit    : std_logic := '0';
    signal tlb_hit_idx: integer range 0 to TLB_ENTRIES-1 := 0;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- TLB lookup (combinational)
    tlb_lookup : process(vaddr, tlb_vpn, tlb_valid, ctrl_reg)
        variable found : boolean;
    begin
        tlb_hit     <= '0';
        tlb_hit_idx <= 0;
        found := false;
        if ctrl_reg(0) = '1' then
            for i in 0 to TLB_ENTRIES-1 loop
                if tlb_valid(i) = '1' and
                   tlb_vpn(i) = vaddr(31 downto 20) and not found then
                    tlb_hit     <= '1';
                    tlb_hit_idx <= i;
                    found := true;
                end if;
            end loop;
        end if;
    end process;

    -- Translation output
    paddr <= tlb_pfn(tlb_hit_idx) & vaddr(19 downto 0) when tlb_hit = '1'
             else vaddr;
    fault <= '1' when (ctrl_reg(0) = '1' and tlb_hit = '0') else '0';

    -- Fault detection and latching
    fault_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                fault_addr_reg <= (others => '0');
                fault_type_reg <= (others => '0');
            elsif ctrl_reg(0) = '1' and tlb_hit = '0' then
                fault_addr_reg <= vaddr;
                fault_type_reg <= (2 => '1', others => '0'); -- tlb_miss
            elsif write_en = '1' and reg_sel = MMU_FAULT_TYPE then
                fault_type_reg <= (others => '0');  -- clear on write
            end if;
        end if;
    end process fault_proc;

    -- Register write process
    reg_write : process(HCLK)
        variable idx : integer range 0 to TLB_ENTRIES-1;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg      <= (others => '0');
                tlb_index_reg <= (others => '0');
                tlb_valid     <= (others => '0');
            elsif write_en = '1' then
                case reg_sel is
                    when MMU_CTRL =>
                        ctrl_reg <= HWDATA;
                    when MMU_TLB_INDEX =>
                        tlb_index_reg <= unsigned(HWDATA);
                    when MMU_TLB_ENTRY =>
                        idx := to_integer(tlb_index_reg(3 downto 0));
                        tlb_vpn(idx)   <= HWDATA(31 downto 20);
                        tlb_pfn(idx)   <= HWDATA(19 downto 8);
                        tlb_flags(idx) <= HWDATA(2 downto 0);
                        tlb_valid(idx) <= '1';
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, tlb_index_reg, fault_addr_reg,
                       fault_type_reg, tlb_vpn, tlb_pfn, tlb_flags, tlb_valid)
        variable idx : integer range 0 to TLB_ENTRIES-1;
    begin
        case reg_sel is
            when MMU_CTRL =>
                HRDATA <= ctrl_reg;
            when MMU_TLB_INDEX =>
                HRDATA <= std_logic_vector(tlb_index_reg);
            when MMU_TLB_ENTRY =>
                idx := to_integer(tlb_index_reg(3 downto 0));
                HRDATA <= tlb_vpn(idx) & tlb_pfn(idx) &
                          "00000" & tlb_flags(idx);
            when MMU_FAULT_ADDR =>
                HRDATA <= fault_addr_reg;
            when MMU_FAULT_TYPE =>
                HRDATA <= fault_type_reg;
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    mmu_irq <= fault_type_reg(2) and ctrl_reg(1);

end architecture rtl;

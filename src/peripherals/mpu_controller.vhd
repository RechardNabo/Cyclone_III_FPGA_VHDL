-- ================================================================================
-- mpu_controller : Memory Protection Unit with AHB-Lite slave interface
-- ================================================================================
-- ARM Cortex-M style MPU with 16 protection regions.
--
-- Features:
--   * 16 regions, each with base address, size, and permissions
--   * Size from 4 bytes (5) to 4 GB (31), encoded as 2^(size+1)
--   * Access permissions: privileged RO, privileged RW, all RO, all RW, none
--   * Memory attributes: cacheable, bufferable, shareable, executable
--   * Region fault detection with interrupt
--
-- Register Map:
--   0x00: CTRL    - MPU control (enable, privdefena, hfnmiena)
--   0x04: RNR     - Region number selector (0-15)
--   0x08: RBAR    - Region base address (current region)
--   0x0C: RASR    - Region size & attribute (current region)
--   0x10: RBAR_A1 - Alias 1 base address
--   0x14: RASR_A1 - Alias 1 size & attribute
--   0x18: RBAR_A2 - Alias 2 base address
--   0x1C: RASR_A2 - Alias 2 size & attribute
--   0x20: RBAR_A3 - Alias 3 base address
--   0x24: RASR_A3 - Alias 3 size & attribute
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity mpu_controller is
    port (
        -- AHB-Lite slave interface
        HCLK        : in  std_logic;
        HRESETn     : in  std_logic;
        HSEL        : in  std_logic;
        HWRITE      : in  std_logic;
        HREADY      : in  std_logic;
        HTRANS      : in  std_logic_vector(1 downto 0);
        HADDR       : in  std_logic_vector(31 downto 0);
        HWDATA      : in  std_logic_vector(31 downto 0);
        HRDATA      : out std_logic_vector(31 downto 0);
        HRESP       : out std_logic;
        HREADYOUT   : out std_logic;

        -- MPU outputs
        cpu_addr    : in  std_logic_vector(31 downto 0);
        cpu_priv    : in  std_logic;                     -- 1=privileged, 0=unprivileged
        cpu_write   : in  std_logic;
        region_fault: out std_logic;
        mpu_irq     : out std_logic
    );
end entity mpu_controller;

architecture rtl of mpu_controller is
    constant NUM_REGIONS : integer := 16;

    type addr_array_t  is array (0 to NUM_REGIONS-1) of std_logic_vector(31 downto 0);
    type attr_array_t   is array (0 to NUM_REGIONS-1) of std_logic_vector(31 downto 0);

    signal ctrl_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal rnr_reg    : unsigned(3 downto 0) := (others => '0');

    signal rbar_mem   : addr_array_t := (others => (others => '0'));
    signal rasr_mem   : attr_array_t := (others => (others => '0'));

    signal fault_reg  : std_logic := '0';

    signal reg_sel    : std_logic_vector(4 downto 0);
    signal write_en   : std_logic;
    signal read_en    : std_logic;

begin

    reg_sel  <= HADDR(6 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Register write process
    reg_write : process(HCLK)
        variable ridx : integer range 0 to NUM_REGIONS-1;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg  <= (others => '0');
                rnr_reg   <= (others => '0');
                rbar_mem  <= (others => (others => '0'));
                rasr_mem  <= (others => (others => '0'));
                fault_reg <= '0';
            elsif write_en = '1' then
                ridx := to_integer(rnr_reg);
                case reg_sel is
                    when "00000" => -- CTRL
                        ctrl_reg <= HWDATA;
                    when "00001" => -- RNR
                        rnr_reg <= unsigned(HWDATA(3 downto 0));
                    when "00010" => -- RBAR
                        rbar_mem(ridx) <= HWDATA;
                    when "00011" => -- RASR
                        rasr_mem(ridx) <= HWDATA;
                    when "00100" => -- RBAR_A1
                        rbar_mem(ridx) <= HWDATA;
                    when "00101" => -- RASR_A1
                        rasr_mem(ridx) <= HWDATA;
                    when "00110" => -- RBAR_A2
                        rbar_mem(ridx) <= HWDATA;
                    when "00111" => -- RASR_A2
                        rasr_mem(ridx) <= HWDATA;
                    when "01000" => -- RBAR_A3
                        rbar_mem(ridx) <= HWDATA;
                    when "01001" => -- RASR_A3
                        rasr_mem(ridx) <= HWDATA;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Region fault check process
    fault_proc : process(HCLK)
        variable match_found : boolean;
        variable base_addr   : unsigned(31 downto 0);
        variable region_sz   : integer;
        variable mask        : unsigned(31 downto 0);
        variable perm        : std_logic_vector(2 downto 0);
        variable allowed     : boolean;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                fault_reg <= '0';
            elsif ctrl_reg(0) = '1' then  -- MPU enabled
                match_found := false;
                allowed     := false;
                for r in 0 to NUM_REGIONS-1 loop
                    if rasr_mem(r)(0) = '1' then  -- region enabled
                        region_sz := to_integer(unsigned(rasr_mem(r)(5 downto 1)));
                        if region_sz >= 2 and region_sz <= 31 then
                            mask := (others => '0');
                            for b in 0 to region_sz loop
                                mask(b) := '1';
                            end loop;
                            base_addr := unsigned(rbar_mem(r)) and (not mask);
                            if (unsigned(cpu_addr) and (not mask)) = base_addr then
                                match_found := true;
                                perm := rasr_mem(r)(31 downto 29);
                                -- perm: 000=all RW, 001=all RO, 010=priv RW, 011=priv RO, 100=none
                                case perm is
                                    when "000" => allowed := true;
                                    when "001" => allowed := (cpu_write = '0');
                                    when "010" => allowed := (cpu_priv = '1');
                                    when "011" => allowed := (cpu_priv = '1' and cpu_write = '0');
                                    when others => allowed := false;
                                end case;
                                exit;
                            end if;
                        end if;
                    end if;
                end loop;
                -- fault if no match (unless privdefena allows default) or permission denied
                if match_found and not allowed then
                    fault_reg <= '1';
                elsif not match_found and ctrl_reg(1) = '0' and cpu_priv = '0' then
                    fault_reg <= '1';
                else
                    fault_reg <= '0';
                end if;
            else
                fault_reg <= '0';
            end if;
        end if;
    end process fault_proc;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, rnr_reg, rbar_mem, rasr_mem)
        variable ridx : integer range 0 to NUM_REGIONS-1;
    begin
        ridx := to_integer(rnr_reg);
        case reg_sel is
            when "00000" => HRDATA <= ctrl_reg;
            when "00001" => HRDATA <= x"0000000" & std_logic_vector(rnr_reg);
            when "00010" => HRDATA <= rbar_mem(ridx);
            when "00011" => HRDATA <= rasr_mem(ridx);
            when "00100" => HRDATA <= rbar_mem(ridx);
            when "00101" => HRDATA <= rasr_mem(ridx);
            when "00110" => HRDATA <= rbar_mem(ridx);
            when "00111" => HRDATA <= rasr_mem(ridx);
            when "01000" => HRDATA <= rbar_mem(ridx);
            when "01001" => HRDATA <= rasr_mem(ridx);
            when others  => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    region_fault <= fault_reg;
    mpu_irq      <= fault_reg and ctrl_reg(2);

end architecture rtl;

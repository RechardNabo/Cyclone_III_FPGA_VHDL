-- ================================================================================
-- dwt_controller : Data Watchpoint and Trace unit with AHB-Lite slave interface
-- ================================================================================
-- ARM Cortex-M DWT for cycle counting and data address watchpoints.
--
-- Features:
--   * Cycle counter (CYCCNT) for performance profiling
--   * CPI, EXC, SLEEP, LSU, FOLD event counters
--   * 4 comparators for data address watchpoints
--   * Match mask per comparator
--   * Watchpoint trigger interrupt
--
-- Register Map:
--   0x00: CTRL      - bit0=CYCCNTENA, bit[5:2]=numcomp(RO=4)
--   0x04: CYCCNT    - cycle counter (RW when enabled)
--   0x08: CPICNT    - CPI counter
--   0x0C: EXCCNT    - exception counter
--   0x10: SLEEPCNT  - sleep counter
--   0x14: LSUCNT    - LSU counter
--   0x18: FOLDCNT   - fold counter
--   0x20: COMP0     - comparator 0 address
--   0x24: MASK0     - comparator 0 mask (ignore low N bits)
--   0x28: FUNCTION0 - bit0=enable, bit[3:2]=match mode
--   0x30..0x38: COMP1/MASK1/FUNCTION1
--   0x40..0x48: COMP2/MASK2/FUNCTION2
--   0x50..0x58: COMP3/MASK3/FUNCTION3
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity dwt_controller is
    port (
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

        -- DWT monitor inputs
        cpu_daddr : in  std_logic_vector(31 downto 0);
        cpu_dwrite: in  std_logic;
        dwt_cmp   : out std_logic_vector(3 downto 0);
        dwt_irq   : out std_logic
    );
end entity dwt_controller;

architecture rtl of dwt_controller is
    constant NUM_COMP : integer := 4;

    type comp_array_t  is array (0 to NUM_COMP-1) of std_logic_vector(31 downto 0);
    type mask_array_t  is array (0 to NUM_COMP-1) of std_logic_vector(4 downto 0);
    type func_array_t  is array (0 to NUM_COMP-1) of std_logic_vector(31 downto 0);

    signal ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal cyccnt      : unsigned(31 downto 0) := (others => '0');
    signal cpicnt      : unsigned(31 downto 0) := (others => '0');
    signal exccnt      : unsigned(31 downto 0) := (others => '0');
    signal sleepcnt    : unsigned(31 downto 0) := (others => '0');
    signal lsucnt      : unsigned(31 downto 0) := (others => '0');
    signal foldcnt     : unsigned(31 downto 0) := (others => '0');

    signal comp_mem    : comp_array_t := (others => (others => '0'));
    signal mask_mem    : mask_array_t := (others => (others => '0'));
    signal func_mem    : func_array_t := (others => (others => '0'));

    signal cmp_match   : std_logic_vector(NUM_COMP-1 downto 0) := (others => '0');
    signal irq_reg     : std_logic := '0';

    signal reg_sel     : std_logic_vector(5 downto 0);
    signal write_en    : std_logic;

begin
    reg_sel  <= HADDR(7 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Counter process
    counter_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                cyccnt   <= (others => '0');
                cpicnt   <= (others => '0');
                exccnt   <= (others => '0');
                sleepcnt <= (others => '0');
                lsucnt   <= (others => '0');
                foldcnt  <= (others => '0');
            elsif ctrl_reg(0) = '1' then
                cyccnt <= cyccnt + 1;
            end if;
        end if;
    end process counter_proc;

    -- Watchpoint comparison process
    compare_proc : process(HCLK)
        variable masked_addr : unsigned(31 downto 0);
        variable masked_comp : unsigned(31 downto 0);
        variable mask_val    : integer;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                cmp_match <= (others => '0');
                irq_reg   <= '0';
            else
                for c in 0 to NUM_COMP-1 loop
                    if func_mem(c)(0) = '1' then  -- comparator enabled
                        mask_val := to_integer(unsigned(mask_mem(c)));
                        if mask_val = 0 then
                            masked_addr := unsigned(cpu_daddr);
                            masked_comp := unsigned(comp_mem(c));
                        else
                            masked_addr := unsigned(cpu_daddr) srl mask_val;
                            masked_comp := unsigned(comp_mem(c)) srl mask_val;
                        end if;
                        if masked_addr = masked_comp then
                            cmp_match(c) <= '1';
                        else
                            cmp_match(c) <= '0';
                        end if;
                    else
                        cmp_match(c) <= '0';
                    end if;
                end loop;
                irq_reg <= '0';
                for c in 0 to NUM_COMP-1 loop
                    if cmp_match(c) = '1' and func_mem(c)(0) = '1' then
                        irq_reg <= '1';
                    end if;
                end loop;
            end if;
        end if;
    end process compare_proc;

    -- Register write process
    reg_write : process(HCLK)
        variable comp_idx : integer range 0 to NUM_COMP-1;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg  <= (others => '0');
                comp_mem  <= (others => (others => '0'));
                mask_mem  <= (others => (others => '0'));
                func_mem  <= (others => (others => '0'));
            elsif write_en = '1' then
                case reg_sel is
                    when "000000" => ctrl_reg <= HWDATA;
                    when "000001" => cyccnt   <= unsigned(HWDATA);
                    when "000010" => cpicnt   <= unsigned(HWDATA);
                    when "000011" => exccnt   <= unsigned(HWDATA);
                    when "000100" => sleepcnt <= unsigned(HWDATA);
                    when "000101" => lsucnt   <= unsigned(HWDATA);
                    when "000110" => foldcnt  <= unsigned(HWDATA);
                    when others =>
                        -- Comparator registers: COMPn at 0x20+0x10*n
                        -- MASKn at 0x24+0x10*n, FUNCTIONn at 0x28+0x10*n
                        for c in 0 to NUM_COMP-1 loop
                            comp_idx := c;
                            if reg_sel = std_logic_vector(to_unsigned(8 + c*4, 6)) then
                                comp_mem(comp_idx) <= HWDATA;
                            elsif reg_sel = std_logic_vector(to_unsigned(9 + c*4, 6)) then
                                mask_mem(comp_idx) <= HWDATA(4 downto 0);
                            elsif reg_sel = std_logic_vector(to_unsigned(10 + c*4, 6)) then
                                func_mem(comp_idx) <= HWDATA;
                            end if;
                        end loop;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, cyccnt, cpicnt, exccnt, sleepcnt,
                       lsucnt, foldcnt, comp_mem, mask_mem, func_mem)
    begin
        case reg_sel is
            when "000000" => HRDATA <= ctrl_reg;
            when "000001" => HRDATA <= std_logic_vector(cyccnt);
            when "000010" => HRDATA <= std_logic_vector(cpicnt);
            when "000011" => HRDATA <= std_logic_vector(exccnt);
            when "000100" => HRDATA <= std_logic_vector(sleepcnt);
            when "000101" => HRDATA <= std_logic_vector(lsucnt);
            when "000110" => HRDATA <= std_logic_vector(foldcnt);
            when others =>
                HRDATA <= (others => '0');
                for c in 0 to NUM_COMP-1 loop
                    if reg_sel = std_logic_vector(to_unsigned(8 + c*4, 6)) then
                        HRDATA <= comp_mem(c);
                    elsif reg_sel = std_logic_vector(to_unsigned(9 + c*4, 6)) then
                        HRDATA <= x"000000" & "000" & mask_mem(c);
                    elsif reg_sel = std_logic_vector(to_unsigned(10 + c*4, 6)) then
                        HRDATA <= func_mem(c);
                    end if;
                end loop;
        end case;
    end process reg_read;

    dwt_cmp <= cmp_match;
    dwt_irq <= irq_reg;

end architecture rtl;

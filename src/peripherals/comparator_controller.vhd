-- ================================================================================
-- comparator_controller : Analog comparator with hysteresis (4 comparators)
-- ================================================================================
-- 4 independent analog comparators with configurable hysteresis.
--   * Per-comparator hysteresis setting
--   * Output register with edge detection
--   * Interrupt on output change
--
-- AHB-Lite register map:
--   0x00 : CTRL    - [0] enable, [1] irq_en, [4:7] per-comparator enable
--   0x04 : STAT    - [0:3] current output, [4:7] output changed
--   0x10-0x1C : HYST0-3 - hysteresis threshold (4-bit each)
--   0x20 : OUTPUT  - comparator output register (read-only, [3:0])
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity comparator_controller is
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

        -- Analog comparator interface
        comp_p    : in  std_logic_vector(3 downto 0) := (others => '0');
        comp_n    : in  std_logic_vector(3 downto 0) := (others => '0');
        comp_out  : out std_logic_vector(3 downto 0);
        comp_irq  : out std_logic
    );
end entity comparator_controller;

architecture rtl of comparator_controller is
    constant NUM_COMP : integer := 4;
    type hyst_arr_t is array(0 to NUM_COMP-1) of std_logic_vector(3 downto 0);

    signal ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal hyst_regs   : hyst_arr_t := (others => (others => '0'));
    signal comp_output : std_logic_vector(3 downto 0) := (others => '0');
    signal comp_prev   : std_logic_vector(3 downto 0) := (others => '0');
    signal changed     : std_logic_vector(3 downto 0) := (others => '0');
    signal irq_pending : std_logic := '0';

    signal reg_offset  : std_logic_vector(7 downto 0);
    signal write_en    : std_logic;
begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;
    comp_out   <= comp_output when ctrl_reg(0) = '1' else (others => '0');

    ahb_write : process(HCLK, HRESETn)
        variable comp_idx : integer range 0 to NUM_COMP-1;
        variable raw_cmp  : std_logic;
    begin
        if HRESETn = '0' then
            ctrl_reg    <= (others => '0');
            hyst_regs   <= (others => (others => '0'));
            comp_output <= (others => '0');
            comp_prev   <= (others => '0');
            changed     <= (others => '0');
            irq_pending <= '0';
        elsif rising_edge(HCLK) then
            irq_pending <= '0';
            if write_en = '1' then
                case to_integer(unsigned(reg_offset)) is
                    when 16#00# => ctrl_reg <= HWDATA;
                    when 16#10# to 16#1C# =>
                        comp_idx := to_integer(unsigned(reg_offset(3 downto 2)));
                        hyst_regs(comp_idx) <= HWDATA(3 downto 0);
                    when others => null;
                end case;
            end if;

            -- Comparator with hysteresis (simplified digital model)
            for i in 0 to NUM_COMP-1 loop
                if ctrl_reg(4 + i) = '1' then
                    -- Simple comparison: comp_p > comp_n means output high
                    raw_cmp := comp_p(i);
                    -- Apply hysteresis: if currently high, need comp_p to go
                    -- lower by hyst threshold to switch low (and vice versa)
                    if comp_output(i) = '1' then
                        -- Currently high: switch low if input drops
                        if comp_p(i) = '0' then
                            comp_output(i) <= '0';
                        end if;
                    else
                        -- Currently low: switch high if input rises
                        if comp_p(i) = '1' then
                            comp_output(i) <= '1';
                        end if;
                    end if;
                end if;
            end loop;

            -- Edge detection
            changed <= comp_output xor comp_prev;
            comp_prev <= comp_output;

            -- Interrupt on any change
            if (comp_output xor comp_prev) /= "0000" and ctrl_reg(1) = '1' then
                irq_pending <= '1';
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, hyst_regs, comp_output,
                       changed)
        variable rdata : std_logic_vector(31 downto 0);
        variable ridx  : integer range 0 to NUM_COMP-1;
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case to_integer(unsigned(reg_offset)) is
                when 16#00# => rdata := ctrl_reg;
                when 16#04# =>
                    rdata(3 downto 0) := comp_output;
                    rdata(7 downto 4) := changed;
                when 16#10# to 16#1C# =>
                    ridx := to_integer(unsigned(reg_offset(3 downto 2)));
                    rdata := x"0000000" & hyst_regs(ridx);
                when 16#20# => rdata := x"0000000" & comp_output;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    comp_irq  <= irq_pending;

end architecture rtl;

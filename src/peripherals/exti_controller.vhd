-- ================================================================================
-- exti_controller : External Interrupt Controller (32 lines)
-- ================================================================================
-- 32 configurable external interrupt lines with independent mask, trigger
-- selection (rising, falling, or both), pending registers, and software
-- interrupt generation. Modeled after STM32 EXTI controller.
--
-- AHB-Lite register map:
--   0x00 : IMR   - Interrupt Mask Register (1=enabled, per line)
--   0x04 : EMR   - Event Mask Register (1=enabled, per line)
--   0x08 : RTSR  - Rising Trigger Selection Register
--   0x0C : FTSR  - Falling Trigger Selection Register
--   0x10 : PR    - Pending Register (read pending, write-1-to-clear)
--   0x14 : SWIER - Software Interrupt Event Register (write-1 to trigger)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity exti_controller is
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

        -- External interrupt lines and outputs
        exti_lines : in  std_logic_vector(31 downto 0) := (others => '0');
        exti_irq   : out std_logic_vector(31 downto 0)
    );
end entity exti_controller;

architecture rtl of exti_controller is
    signal imr_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal emr_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal rtsr_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal ftsr_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal pr_reg    : std_logic_vector(31 downto 0) := (others => '0');

    signal exti_prev : std_logic_vector(31 downto 0) := (others => '0');

    signal reg_offset : std_logic_vector(7 downto 0);
    signal write_en   : std_logic;
begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;
    exti_irq   <= pr_reg and imr_reg;

    ahb_write : process(HCLK, HRESETn)
        variable edge_det : std_logic_vector(31 downto 0);
        variable rising_edges  : std_logic_vector(31 downto 0);
        variable falling_edges : std_logic_vector(31 downto 0);
    begin
        if HRESETn = '0' then
            imr_reg   <= (others => '0');
            emr_reg   <= (others => '0');
            rtsr_reg  <= (others => '0');
            ftsr_reg  <= (others => '0');
            pr_reg    <= (others => '0');
            exti_prev <= (others => '0');
        elsif rising_edge(HCLK) then
            -- Edge detection
            rising_edges  := exti_lines and (not exti_prev);
            falling_edges := (not exti_lines) and exti_prev;
            exti_prev <= exti_lines;

            -- Hardware-triggered pending
            edge_det := (rising_edges and rtsr_reg) or (falling_edges and ftsr_reg);
            pr_reg <= (pr_reg or edge_det);

            -- Software-triggered pending
            if write_en = '1' then
                case reg_offset is
                    when x"00" => imr_reg  <= HWDATA;
                    when x"04" => emr_reg  <= HWDATA;
                    when x"08" => rtsr_reg <= HWDATA;
                    when x"0C" => ftsr_reg <= HWDATA;
                    when x"10" =>  -- PR: write-1-to-clear
                        pr_reg <= pr_reg and (not HWDATA);
                    when x"14" =>  -- SWIER: set pending if masked
                        pr_reg <= pr_reg or (HWDATA and imr_reg);
                    when others => null;
                end case;
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, imr_reg, emr_reg, rtsr_reg,
                       ftsr_reg, pr_reg)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"00" => rdata := imr_reg;
                when x"04" => rdata := emr_reg;
                when x"08" => rdata := rtsr_reg;
                when x"0C" => rdata := ftsr_reg;
                when x"10" => rdata := pr_reg;
                when x"14" => rdata := (others => '0');  -- SWIER write-only
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';

end architecture rtl;

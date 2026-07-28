-- ================================================================================
-- cmu_controller : Clock Management Unit with AHB-Lite slave interface
-- ================================================================================
-- Educational Clock Management Unit for Cyclone III FPGA.
--
-- Features:
--   * PLL control with lock status
--   * Clock input multiplexer (4 inputs)
--   * 8 independent clock outputs with prescalers
--   * Per-output clock gating
--   * Interrupt on PLL lock/unlock event
--
-- Register Map:
--   0x00: PLL_CTRL
--       bit0 = pll_bypass  (RW) - bypass PLL
--       bit1 = pll_pd      (RW) - PLL power-down
--       bit2 = pll_reset   (RW) - PLL reset (pulse)
--       bit3 = irq_en      (RW) - lock-status interrupt enable
--   0x04: PLL_STAT
--       bit0 = locked      (RO) - PLL locked
--       bit1 = lock_event  (RO) - lock/unlock event latched
--   0x08: CLK_SEL
--       bits[1:0] = input clock select (RW)
--   0x10..0x2C: CLK_DIV(0..7) - prescaler value (16-bit, RW)
--   0x30: CLK_GATE
--       bits[7:0] = per-output gate enable (RW, 1=clock on)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cmu_controller is
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

        -- Clock management interface
        clk_in    : in  std_logic_vector(3 downto 0);   -- 4 input clocks
        clk_out   : out std_logic_vector(7 downto 0);   -- 8 output clocks
        pll_locked: out std_logic;                       -- PLL lock status
        cmu_irq   : out std_logic                        -- interrupt
    );
end entity cmu_controller;

architecture rtl of cmu_controller is
    constant PLL_CTRL  : std_logic_vector(3 downto 0) := "0000";
    constant PLL_STAT  : std_logic_vector(3 downto 0) := "0001";
    constant CLK_SEL   : std_logic_vector(3 downto 0) := "0010";
    constant CLK_DIV0  : std_logic_vector(3 downto 0) := "0100";
    constant CLK_GATE  : std_logic_vector(3 downto 0) := "1100";

    signal pll_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal clk_sel_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal clk_div_reg  : std_logic_vector(31 downto 0) := (others => '0');
    type div_array_t is array (0 to 7) of unsigned(15 downto 0);
    signal clk_div      : div_array_t := (others => (others => '0'));
    signal clk_gate_reg : std_logic_vector(31 downto 0) := (others => '0');

    signal pll_lock_int : std_logic := '0';
    signal lock_event   : std_logic := '0';

    signal reg_sel      : std_logic_vector(3 downto 0);
    signal write_en     : std_logic;
    signal read_en      : std_logic;

    type prescaler_t is array (0 to 7) of unsigned(15 downto 0);
    signal presc_cnt    : prescaler_t := (others => (others => '0'));
    signal presc_tick   : std_logic_vector(7 downto 0) := (others => '0');

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- PLL lock model: locked when not in reset/power-down
    pll_lock_int <= '1' when (pll_ctrl_reg(1) = '0' and pll_ctrl_reg(2) = '0')
                    else '0';
    pll_locked   <= pll_lock_int;

    -- Detect lock/unlock event
    lock_detect : process(HCLK)
        variable prev_lock : std_logic := '0';
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                lock_event <= '0';
                prev_lock  := '0';
            elsif pll_ctrl_reg(3) = '1' then
                if pll_lock_int /= prev_lock then
                    lock_event <= '1';
                end if;
                prev_lock := pll_lock_int;
            end if;
        end if;
    end process lock_detect;

    -- Prescaler counters
    prescaler_gen : for i in 0 to 7 generate
        process(HCLK)
        begin
            if rising_edge(HCLK) then
                if HRESETn = '0' then
                    presc_cnt(i) <= (others => '0');
                    presc_tick(i) <= '0';
                elsif clk_gate_reg(i) = '1' then
                    if presc_cnt(i) = clk_div(i) then
                        presc_cnt(i)  <= (others => '0');
                        presc_tick(i) <= '1';
                    else
                        presc_cnt(i)  <= presc_cnt(i) + 1;
                        presc_tick(i) <= '0';
                    end if;
                else
                    presc_tick(i) <= '0';
                end if;
            end if;
        end process;
    end generate;

    -- Clock output generation (gated + prescaled)
    clk_out_gen : for i in 0 to 7 generate
        clk_out(i) <= presc_tick(i) when clk_gate_reg(i) = '1' else '0';
    end generate;

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                pll_ctrl_reg <= (others => '0');
                clk_sel_reg  <= (others => '0');
                clk_gate_reg <= (others => '0');
                for i in 0 to 7 loop
                    clk_div(i) <= to_unsigned(1, 16);
                end loop;
            elsif write_en = '1' then
                case reg_sel is
                    when PLL_CTRL =>
                        pll_ctrl_reg <= HWDATA;
                        if HWDATA(2) = '1' then
                            lock_event <= '0';
                        end if;
                    when PLL_STAT =>
                        if HWDATA(1) = '1' then
                            lock_event <= '0';
                        end if;
                    when CLK_SEL =>
                        clk_sel_reg <= HWDATA;
                    when CLK_GATE =>
                        clk_gate_reg <= HWDATA;
                    when others =>
                        if reg_sel >= CLK_DIV0 and reg_sel <= "1011" then
                            clk_div(to_integer(unsigned(reg_sel(2 downto 0)))) <=
                                unsigned(HWDATA(15 downto 0));
                        end if;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, pll_ctrl_reg, pll_lock_int, lock_event,
                       clk_sel_reg, clk_gate_reg, clk_div)
    begin
        case reg_sel is
            when PLL_CTRL =>
                HRDATA <= pll_ctrl_reg;
            when PLL_STAT =>
                HRDATA <= (0 => pll_lock_int, 1 => lock_event, others => '0');
            when CLK_SEL =>
                HRDATA <= clk_sel_reg;
            when CLK_GATE =>
                HRDATA <= clk_gate_reg;
            when others =>
                if reg_sel >= CLK_DIV0 and reg_sel <= "1011" then
                    HRDATA <= x"0000" &
                        std_logic_vector(clk_div(to_integer(unsigned(reg_sel(2 downto 0)))));
                else
                    HRDATA <= (others => '0');
                end if;
        end case;
    end process reg_read;

    cmu_irq <= lock_event and pll_ctrl_reg(3);

end architecture rtl;

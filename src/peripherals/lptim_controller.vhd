-- ================================================================================
-- lptim_controller : Low-Power Timer (runs in low-power mode)
-- ================================================================================
-- 16-bit low-power timer with auto-reload, compare match, and counter.
-- Supports external clock input and interrupt on compare/overflow.
--   * Configurable auto-reload (ARR) and compare (CMP) values
--   * External clock or internal clock selection
--   * Interrupt on compare match and update (overflow)
--
-- AHB-Lite register map:
--   0x00 : CTRL - [0] enable, [1] irq_en, [2] ext_clk, [3] one_pulse, [4] cnt_en
--   0x04 : STAT - [0] arr_matched, [1] cmp_matched, [2] running
--   0x08 : ARR  - auto-reload value (16-bit)
--   0x0C : CMP  - compare value (16-bit)
--   0x10 : CNT  - current counter value (read-only)
--   0x14 : IER  - interrupt enable (bit0=arr, bit1=cmp)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lptim_controller is
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

        -- LPTIM interface
        lptim_ext_clk : in  std_logic := '0';
        lptim_out     : out std_logic;
        lptim_irq     : out std_logic
    );
end entity lptim_controller;

architecture rtl of lptim_controller is
    signal ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal arr_reg     : unsigned(15 downto 0) := (others => '0');
    signal cmp_reg     : unsigned(15 downto 0) := (others => '0');
    signal cnt_reg     : unsigned(15 downto 0) := (others => '0');
    signal ier_reg     : std_logic_vector(31 downto 0) := (others => '0');

    signal arr_matched : std_logic := '0';
    signal cmp_matched : std_logic := '0';
    signal irq_pending : std_logic := '0';
    signal running     : std_logic := '0';
    signal ext_clk_prev: std_logic := '0';
    signal lptim_out_reg : std_logic := '0';

    signal reg_offset  : std_logic_vector(7 downto 0);
    signal write_en    : std_logic;
begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;
    lptim_out  <= lptim_out_reg;

    ahb_write : process(HCLK, HRESETn)
        variable clk_edge : std_logic;
    begin
        if HRESETn = '0' then
            ctrl_reg      <= (others => '0');
            arr_reg       <= (others => '0');
            cmp_reg       <= (others => '0');
            cnt_reg       <= (others => '0');
            ier_reg       <= (others => '0');
            arr_matched   <= '0';
            cmp_matched   <= '0';
            irq_pending   <= '0';
            running       <= '0';
            ext_clk_prev  <= '0';
            lptim_out_reg <= '0';
        elsif rising_edge(HCLK) then
            irq_pending <= '0';
            arr_matched <= '0';
            cmp_matched <= '0';

            if write_en = '1' then
                case reg_offset is
                    when x"00" =>
                        ctrl_reg <= HWDATA;
                        if HWDATA(0) = '1' and ctrl_reg(0) = '0' then
                            cnt_reg <= (others => '0');
                            running <= '1';
                        end if;
                        if HWDATA(0) = '0' then
                            running <= '0';
                        end if;
                    when x"08" => arr_reg <= unsigned(HWDATA(15 downto 0));
                    when x"0C" => cmp_reg <= unsigned(HWDATA(15 downto 0));
                    when x"14" => ier_reg <= HWDATA;
                    when others => null;
                end case;
            end if;

            -- Timer counting
            if running = '1' and ctrl_reg(4) = '1' then
                -- Clock source selection
                clk_edge := '0';
                if ctrl_reg(2) = '1' then
                    -- External clock (rising edge detect)
                    if lptim_ext_clk = '1' and ext_clk_prev = '0' then
                        clk_edge := '1';
                    end if;
                    ext_clk_prev <= lptim_ext_clk;
                else
                    -- Internal clock (every HCLK)
                    clk_edge := '1';
                end if;

                if clk_edge = '1' then
                    cnt_reg <= cnt_reg + 1;
                    lptim_out_reg <= not lptim_out_reg;

                    -- Compare match
                    if cnt_reg = cmp_reg then
                        cmp_matched <= '1';
                        if ier_reg(1) = '1' then
                            irq_pending <= '1';
                        end if;
                    end if;

                    -- Auto-reload match
                    if cnt_reg = arr_reg then
                        cnt_reg <= (others => '0');
                        arr_matched <= '1';
                        if ier_reg(0) = '1' then
                            irq_pending <= '1';
                        end if;
                        if ctrl_reg(3) = '1' then  -- one-pulse mode
                            running <= '0';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, arr_reg, cmp_reg, cnt_reg,
                       ier_reg, arr_matched, cmp_matched, running)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"00" => rdata := ctrl_reg;
                when x"04" =>
                    rdata(0) := arr_matched;
                    rdata(1) := cmp_matched;
                    rdata(2) := running;
                when x"08" => rdata := x"0000" & std_logic_vector(arr_reg);
                when x"0C" => rdata := x"0000" & std_logic_vector(cmp_reg);
                when x"10" => rdata := x"0000" & std_logic_vector(cnt_reg);
                when x"14" => rdata := ier_reg;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    lptim_irq <= irq_pending;

end architecture rtl;

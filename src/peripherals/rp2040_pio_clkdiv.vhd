-- ================================================================================
-- rp2040_pio_clkdiv : Full PIO clock divider (AHB-Lite slave)
-- ================================================================================
-- 16.0 fixed-point divider: 8-bit integer + 8-bit fractional.
-- Generates tick pulses at the divided rate and a stall signal while waiting.
--
-- Register Map:
--   0x00: CLKDIV_INT  - integer part (8-bit, bits0..7) (RW)
--   0x04: CLKDIV_FRAC - fractional part (8-bit, bits0..7) (RW)
--   0x08: CLKDIV_CNT  - current counter value (RO)
--   0x0C: CLKDIV_STAT - bit0=running, bit1=tick, bit2=stall (RO)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rp2040_pio_clkdiv is
    port (
        -- AHB-Lite slave interface
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

        -- Clock divider interface
        clkdiv_tick  : out std_logic;
        clkdiv_stall : out std_logic
    );
end entity rp2040_pio_clkdiv;

architecture rtl of rp2040_pio_clkdiv is
    signal int_reg    : std_logic_vector(31 downto 0) := x"00000001";
    signal frac_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal cnt_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal stat_reg   : std_logic_vector(31 downto 0) := (others => '0');

    signal frac_accum : unsigned(7 downto 0) := (others => '0');
    signal int_cnt    : unsigned(7 downto 0) := (others => '0');
    signal running    : std_logic := '0';
    signal tick_pulse : std_logic := '0';
    signal stall_int  : std_logic := '0';
    signal write_en   : std_logic;

begin

    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Clock divider process
    clkdiv_proc : process(HCLK)
        variable int_val   : unsigned(7 downto 0);
        variable frac_val  : unsigned(7 downto 0);
        variable new_accum : unsigned(8 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                int_cnt    <= (others => '0');
                frac_accum <= (others => '0');
                running    <= '0';
                tick_pulse <= '0';
                stall_int  <= '0';
            else
                tick_pulse <= '0';
                int_val  := unsigned(int_reg(7 downto 0));
                frac_val := unsigned(frac_reg(7 downto 0));

                if int_val = 0 then
                    -- Divide by 1: tick every cycle
                    tick_pulse <= '1';
                    stall_int  <= '0';
                    running    <= '1';
                else
                    running <= '1';
                    -- Fractional accumulator
                    new_accum := ('0' & frac_accum) + ('0' & frac_val);
                    if new_accum(8) = '1' then
                        frac_accum <= new_accum(7 downto 0);
                        -- Fractional carry: increment integer counter by 1 extra
                        if int_cnt = int_val then
                            int_cnt    <= (others => '0');
                            tick_pulse <= '1';
                        else
                            int_cnt <= int_cnt + 1;
                        end if;
                    else
                        frac_accum <= new_accum(7 downto 0);
                        if int_cnt = int_val - 1 then
                            int_cnt    <= (others => '0');
                            tick_pulse <= '1';
                        else
                            int_cnt <= int_cnt + 1;
                        end if;
                    end if;
                    -- Stall when not ticking
                    stall_int <= not tick_pulse;
                end if;
            end if;
        end if;
    end process clkdiv_proc;

    -- Counter readback
    cnt_reg <= x"000000" & std_logic_vector(int_cnt);

    -- Status register
    stat_reg(0) <= running;
    stat_reg(1) <= tick_pulse;
    stat_reg(2) <= stall_int;

    -- Register write
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                int_reg  <= x"00000001";
                frac_reg <= (others => '0');
            elsif write_en = '1' then
                case HADDR(5 downto 2) is
                    when "0000" => int_reg  <= HWDATA;
                    when "0001" => frac_reg <= HWDATA;
                    when others => null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(HADDR, int_reg, frac_reg, cnt_reg, stat_reg)
    begin
        case HADDR(5 downto 2) is
            when "0000" => HRDATA <= int_reg;
            when "0001" => HRDATA <= frac_reg;
            when "0010" => HRDATA <= cnt_reg;
            when "0011" => HRDATA <= stat_reg;
            when others => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    -- Outputs
    clkdiv_tick  <= tick_pulse;
    clkdiv_stall <= stall_int;

end architecture rtl;

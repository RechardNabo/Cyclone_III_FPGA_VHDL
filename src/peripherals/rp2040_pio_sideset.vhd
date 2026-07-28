-- ================================================================================
-- rp2040_pio_sideset : PIO side-set pin override module (AHB-Lite slave)
-- ================================================================================
-- Allows PIO instructions to drive side-set pins independently of OUT/SET pins.
-- Configurable side-set pin count and base pin.
--
-- Register Map:
--   0x00: SIDESET_CTRL   - bit0=enable, bit1=auto_dir, bit2=override_en
--   0x04: SIDESET_COUNT  - number of side-set pins (0..5) (RW)
--   0x08: SIDESET_BASE   - base pin index for side-set (RW)
--   0x0C: SIDESET_PINDIR - per-pin direction (bit=1=output) (RW)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rp2040_pio_sideset is
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

        -- Side-set interface
        sideset_out : out std_logic_vector(7 downto 0);
        sideset_oe  : out std_logic_vector(7 downto 0);
        sideset_clk : in  std_logic
    );
end entity rp2040_pio_sideset;

architecture rtl of rp2040_pio_sideset is
    signal ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal count_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal base_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal pindir_reg  : std_logic_vector(31 downto 0) := (others => '0');

    signal side_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal write_en    : std_logic;

begin

    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg   <= (others => '0');
                count_reg  <= (others => '0');
                base_reg   <= (others => '0');
                pindir_reg <= (others => '0');
            elsif write_en = '1' then
                case HADDR(5 downto 2) is
                    when "0000" => ctrl_reg   <= HWDATA;
                    when "0001" => count_reg  <= HWDATA;
                    when "0010" => base_reg   <= HWDATA;
                    when "0011" => pindir_reg <= HWDATA;
                    when others => null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Side-set output generation on sideset_clk
    sideset_proc : process(sideset_clk)
        variable count  : integer;
        variable base   : integer;
        variable i      : integer;
    begin
        if rising_edge(sideset_clk) then
            if HRESETn = '0' or ctrl_reg(0) = '0' then
                side_data <= (others => '0');
            else
                count := to_integer(unsigned(count_reg(2 downto 0)));
                base  := to_integer(unsigned(base_reg(2 downto 0)));
                if count > 0 and base + count <= 8 then
                    for i in 0 to 7 loop
                        if i >= base and i < base + count then
                            -- Drive from HWDATA side-set field (bits 0..count-1)
                            side_data(i) <= HWDATA(i - base);
                        else
                            side_data(i) <= '0';
                        end if;
                    end loop;
                else
                    side_data <= (others => '0');
                end if;
            end if;
        end if;
    end process sideset_proc;

    -- Output mux with override
    out_mux : process(ctrl_reg, pindir_reg, side_data)
        variable base_idx : integer;
        variable count    : integer;
    begin
        sideset_out <= (others => '0');
        sideset_oe  <= (others => '0');
        if ctrl_reg(0) = '1' then
            base_idx := to_integer(unsigned(base_reg(2 downto 0)));
            count    := to_integer(unsigned(count_reg(2 downto 0)));
            for i in 0 to 7 loop
                if i >= base_idx and i < base_idx + count then
                    if ctrl_reg(2) = '1' then
                        -- Override mode: force output
                        sideset_out(i) <= side_data(i);
                        sideset_oe(i)  <= '1';
                    else
                        -- Normal: follow pindir
                        sideset_out(i) <= side_data(i);
                        sideset_oe(i)  <= pindir_reg(i);
                    end if;
                end if;
            end loop;
        end if;
    end process out_mux;

    -- Register read mux
    reg_read : process(HADDR, ctrl_reg, count_reg, base_reg, pindir_reg)
    begin
        case HADDR(5 downto 2) is
            when "0000" => HRDATA <= ctrl_reg;
            when "0001" => HRDATA <= count_reg;
            when "0010" => HRDATA <= base_reg;
            when "0011" => HRDATA <= pindir_reg;
            when others => HRDATA <= (others => '0');
        end case;
    end process reg_read;

end architecture rtl;

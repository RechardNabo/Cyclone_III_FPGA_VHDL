-- ================================================================================
-- avr_usi : AVR Universal Serial Interface (SPI/I2C) with AHB-Lite slave
-- ================================================================================
-- Combined SPI and I2C serial interface with 4-bit shift register.
-- Registers: USICR, USISR, USIDR, USIBR, USIPP.
--
-- Register Map:
--   0x00: USICR - USI Control Register
--       bit0 = USITC (toggle clock, W1)
--       bit1 = USIOE (output enable, RW)
--       bit2 = USIWM0(RW) - wire mode 0
--       bit3 = USIWM1(RW) - wire mode 1
--       bit4 = USICS0(RW) - clock select 0
--       bit5 = USICS1(RW) - clock select 1
--       bit6 = USICLK (RW) - clock strobe
--       bit7 = USIOIE (RW) - overflow interrupt enable
--   0x04: USISR - USI Status Register
--       bit0-3 = USICNT(RO) - counter
--       bit4   = USIDC  (RO) - data collision
--       bit5   = USIPF  (RC) - stop flag (I2C)
--       bit6   = USIDIF (RC) - data interrupt flag
--       bit7   = USIOIF (RC) - overflow interrupt flag
--   0x08: USIDR - USI Data Register (RW, 8-bit)
--   0x0C: USIBR - USI Buffer Register (RO, 8-bit)
--   0x10: USIPP - USI Pin Position (RW)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity avr_usi is
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

        -- USI external pins
        usi_clk : out std_logic;
        usi_do  : out std_logic;  -- data output
        usi_di  : in  std_logic;  -- data input
        usi_irq : out std_logic   -- interrupt output
    );
end entity avr_usi;

architecture rtl of avr_usi is

    constant REG_USICR : std_logic_vector(3 downto 0) := "0000";
    constant REG_USISR : std_logic_vector(3 downto 0) := "0001";
    constant REG_USIDR : std_logic_vector(3 downto 0) := "0010";
    constant REG_USIBR : std_logic_vector(3 downto 0) := "0011";
    constant REG_USIPP : std_logic_vector(3 downto 0) := "0100";

    signal usicr_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal usidr_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal usibr_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal usipp_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal usicnt    : unsigned(3 downto 0) := (others => '0');
    signal usioif    : std_logic := '0';
    signal usidif    : std_logic := '0';
    signal usipf     : std_logic := '0';
    signal usidc     : std_logic := '0';

    signal clk_out   : std_logic := '0';
    signal do_out    : std_logic := '0';

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- USI shift and clock logic
    usi_proc : process(HCLK)
        variable wire_mode : std_logic_vector(1 downto 0);
        variable clk_sel   : std_logic_vector(1 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                usicr_reg <= (others => '0');
                usidr_reg <= (others => '0');
                usibr_reg <= (others => '0');
                usipp_reg <= (others => '0');
                usicnt    <= (others => '0');
                usioif    <= '0';
                usidif    <= '0';
                usipf     <= '0';
                usidc     <= '0';
                clk_out   <= '0';
                do_out    <= '0';
            else
                wire_mode := usicr_reg(3 downto 2);
                clk_sel   := usicr_reg(5 downto 4);

                -- Register writes
                if write_en = '1' then
                    case reg_sel is
                        when REG_USICR =>
                            usicr_reg <= HWDATA(7 downto 0);
                            -- USITC: toggle clock
                            if HWDATA(0) = '1' then
                                clk_out <= not clk_out;
                            end if;
                        when REG_USIDR => usidr_reg <= HWDATA(7 downto 0);
                        when REG_USIPP => usipp_reg <= HWDATA(7 downto 0);
                        when REG_USISR =>
                            -- Clear flags by writing 1
                            if HWDATA(7) = '1' then usioif <= '0'; end if;
                            if HWDATA(6) = '1' then usidif <= '0'; end if;
                            if HWDATA(5) = '1' then usipf  <= '0'; end if;
                        when others => null;
                    end case;
                end if;

                -- Clock strobe (USICLK or external clock)
                -- Shift on clock toggle when output enabled or input mode
                if usicr_reg(0) = '1' or usicr_reg(6) = '1' then
                    -- Shift register: MSB out, LSB in from usi_di
                    do_out <= usidr_reg(7);
                    usidr_reg <= usidr_reg(6 downto 0) & usi_di;
                    usibr_reg <= usidr_reg; -- buffer captures previous
                    usicnt <= usicnt + 1;
                    if usicnt = 15 then
                        usioif <= '1';
                        usicnt <= (others => '0');
                    end if;
                    -- I2C stop detection (simplified)
                    if wire_mode = "10" and usi_di = '1' and do_out = '1' then
                        usipf <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process usi_proc;

    -- Register read mux
    reg_read : process(reg_sel, usicr_reg, usidr_reg, usibr_reg, usipp_reg,
                       usicnt, usioif, usidif, usipf, usidc)
    begin
        case reg_sel is
            when REG_USICR => HRDATA <= x"000000" & usicr_reg;
            when REG_USISR => HRDATA <= x"000000" & usioif & usidif & usipf & usidc & std_logic_vector(usicnt);
            when REG_USIDR => HRDATA <= x"000000" & usidr_reg;
            when REG_USIBR => HRDATA <= x"000000" & usibr_reg;
            when REG_USIPP => HRDATA <= x"000000" & usipp_reg;
            when others    => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    usi_clk <= clk_out;
    usi_do  <= do_out when usicr_reg(1) = '1' else 'Z';
    usi_irq <= (usioif and usicr_reg(7)) or (usidif and usicr_reg(7));

end architecture rtl;

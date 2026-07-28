-- ================================================================================
-- pic_config_fuses : PIC Configuration Word/fuses emulator with AHB-Lite slave
-- ================================================================================
-- Stores configuration bits (oscillator type, WDT enable, code protect, etc.).
-- Read-only after programming (lock bit set). Writable only when unlocked.
-- Registers: CONFIG1, CONFIG2, CONFIG3, CONFIG4.
--
-- Register Map (HADDR[5:2]):
--   0x00: CONFIG1 - Oscillator, WDT, power-up timer, MCLR
--       bit0-2 = FOSC<2:0> (oscillator select)
--       bit3   = WDTE (WDT enable)
--       bit4   = PWRTE (power-up timer enable)
--       bit5   = MCLRE (MCLR pin function)
--       bit6   = CP (code protection)
--       bit7   = DEBUG (debug mode enable)
--   0x04: CONFIG2 - Brown-out reset, LVP
--       bit0-1 = BOREN<1:0> (BOR enable)
--       bit2   = BORV (BOR voltage select)
--       bit3   = LVP (low-voltage programming)
--       bit4   = STVREN (stack overflow reset)
--       bit5-7 = WRT<2:0> (write protection)
--   0x08: CONFIG3 - CPD, WRTC, WRTB
--       bit0 = CPD (data EEPROM code protect)
--       bit1 = WRTC (config register write protect)
--       bit2 = WRTB (boot block write protect)
--       bit3 = LVP1 (alternate LVP)
--   0x0C: CONFIG4 - Lock/unlock control
--       bit0 = LOCK (read-only after programming, set to 1 to lock)
--       bit1 = UNLOCK_KEY (write 1 to allow reprogramming)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pic_config_fuses is
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
        HREADYOUT : out std_logic
    );
end entity pic_config_fuses;

architecture rtl of pic_config_fuses is

    constant REG_CONFIG1 : std_logic_vector(3 downto 0) := "0000";
    constant REG_CONFIG2 : std_logic_vector(3 downto 0) := "0001";
    constant REG_CONFIG3 : std_logic_vector(3 downto 0) := "0010";
    constant REG_CONFIG4 : std_logic_vector(3 downto 0) := "0011";

    -- Default config values (simulating factory defaults)
    -- CONFIG1: FOSC=INTOSC, WDTE=1, PWRTE=0, MCLRE=1, CP=0, DEBUG=1
    -- CONFIG2: BOREN=11, BORV=0, LVP=1, STVREN=1, WRT=000
    -- CONFIG3: CPD=0, WRTC=1, WRTB=0
    -- CONFIG4: LOCK=0 (unlocked at power-up), UNLOCK_KEY=0
    signal config1_reg : std_logic_vector(7 downto 0) := "10111001";
    signal config2_reg : std_logic_vector(7 downto 0) := "00011011";
    signal config3_reg : std_logic_vector(7 downto 0) := "00000010";
    signal config4_reg : std_logic_vector(7 downto 0) := "00000000";

    -- Lock state: when LOCK=1, all config registers become read-only
    -- unless UNLOCK_KEY is written with the magic sequence
    signal locked : std_logic := '0';
    signal unlock_seq : unsigned(1 downto 0) := "00";

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Register write process with lock protection
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                config1_reg <= "10111001";
                config2_reg <= "00011011";
                config3_reg <= "00000010";
                config4_reg <= "00000000";
                locked <= '0';
                unlock_seq <= "00";
            elsif write_en = '1' then
                -- Unlock sequence: write 0xAA then 0x55 to CONFIG4
                if reg_sel = REG_CONFIG4 then
                    if HWDATA(7 downto 0) = x"AA" then
                        unlock_seq <= "01";
                    elsif HWDATA(7 downto 0) = x"55" and unlock_seq = "01" then
                        unlock_seq <= "10"; -- unlocked
                        locked <= '0';
                    else
                        unlock_seq <= "00";
                    end if;
                end if;

                -- Write to config registers only if unlocked
                if locked = '0' then
                    case reg_sel is
                        when REG_CONFIG1 => config1_reg <= HWDATA(7 downto 0);
                        when REG_CONFIG2 => config2_reg <= HWDATA(7 downto 0);
                        when REG_CONFIG3 => config3_reg <= HWDATA(7 downto 0);
                        when REG_CONFIG4 =>
                            -- Setting LOCK bit locks all registers
                            if HWDATA(0) = '1' then
                                locked <= '1';
                                config4_reg(0) <= '1';
                            end if;
                        when others => null;
                    end case;
                else
                    -- Locked: only CONFIG4 unlock sequence allowed
                    if reg_sel = REG_CONFIG4 and unlock_seq = "10" then
                        locked <= '0';
                        config4_reg(0) <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, config1_reg, config2_reg, config3_reg, config4_reg, locked)
    begin
        case reg_sel is
            when REG_CONFIG1 => HRDATA <= x"000000" & config1_reg;
            when REG_CONFIG2 => HRDATA <= x"000000" & config2_reg;
            when REG_CONFIG3 => HRDATA <= x"000000" & config3_reg;
            when REG_CONFIG4 => HRDATA <= x"000000" & config4_reg;
            when others      => HRDATA <= (others => '0');
        end case;
    end process reg_read;

end architecture rtl;

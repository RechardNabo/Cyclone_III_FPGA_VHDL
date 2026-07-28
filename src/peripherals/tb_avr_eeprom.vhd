--------------------------------------------------------------------------------
-- tb_avr_eeprom : Testbench for AVR EEPROM write/read via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_avr_eeprom is
end entity tb_avr_eeprom;

architecture sim of tb_avr_eeprom is
    constant CLK_PERIOD : time := 20 ns;

    signal HCLK      : std_logic := '0';
    signal HRESETn   : std_logic := '0';
    signal HSEL      : std_logic := '0';
    signal HWRITE    : std_logic := '0';
    signal HREADY    : std_logic := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "000";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;
    signal eeprom_irq : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.avr_eeprom
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            eeprom_irq => eeprom_irq
        );

    stim : process
        procedure ahb_write(addr : in std_logic_vector(31 downto 0);
                            data : in std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '1'; HTRANS <= "10";
            HADDR <= addr; HWDATA <= data;
            wait for CLK_PERIOD;
            HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
            wait for CLK_PERIOD;
        end procedure;

        procedure ahb_read(addr : in std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '0'; HTRANS <= "10";
            HADDR <= addr;
            wait for CLK_PERIOD;
            HSEL <= '0'; HTRANS <= "00";
            wait for CLK_PERIOD;
        end procedure;
    begin
        HRESETn <= '0';
        wait for 100 ns;
        HRESETn <= '1';
        wait for CLK_PERIOD * 2;

        -- Set address (EEARL=0x08, EEARH=0x0C)
        ahb_write(x"00000008", x"0000002A");  -- EEARL = 0x2A
        ahb_write(x"0000000C", x"00000000");  -- EEARH = 0x00

        -- Set data (EEDR=0x04)
        ahb_write(x"00000004", x"00000055");  -- EEDR = 0x55

        -- Issue EEMWE (EECR=0x00, bit1=1)
        ahb_write(x"00000000", x"00000002");

        -- Issue EEME (EECR=0x00, bit2=1) - triggers write
        ahb_write(x"00000000", x"00000004");

        wait for CLK_PERIOD * 4;

        -- Now read back: set same address
        ahb_write(x"00000008", x"0000002A");  -- EEARL = 0x2A
        ahb_write(x"0000000C", x"00000000");  -- EEARH = 0x00

        -- Issue EERE (EECR=0x00, bit0=1) - read strobe
        ahb_write(x"00000000", x"00000001");

        wait for CLK_PERIOD * 2;

        -- Read EEDR (offset 0x04)
        ahb_read(x"00000004");
        assert HRDATA(7 downto 0) = x"55"
            report "FAIL: EEPROM readback mismatch, got 0x" &
                   integer'image(to_integer(unsigned(HRDATA(7 downto 0))))
            severity error;
        assert HRDATA(7 downto 0) = x"55"
            report "PASS: EEPROM write/read verified"
            severity note;

        report "AVR EEPROM testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

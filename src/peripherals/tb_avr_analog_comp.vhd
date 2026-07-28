--------------------------------------------------------------------------------
-- tb_avr_analog_comp : Testbench for AVR Analog Comparator via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_avr_analog_comp is
end entity tb_avr_analog_comp;

architecture sim of tb_avr_analog_comp is
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
    signal ain0      : std_logic := '0';
    signal ain1      : std_logic := '0';
    signal ac_out    : std_logic;
    signal ac_irq    : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.avr_analog_comp
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            ain0 => ain0, ain1 => ain1, ac_out => ac_out, ac_irq => ac_irq
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

        -- Configure ACSR: enable IRQ (bit4=ACIE), toggle mode (ACIS=00)
        -- ACSR at 0x00
        ahb_write(x"00000000", x"00000010");

        -- Set ain0=1, ain1=0 => comparator output should be 1
        ain0 <= '1';
        ain1 <= '0';
        wait for CLK_PERIOD * 4;

        -- Read ACSR - bit1 (ACO_sync) should be 1
        ahb_read(x"00000000");
        assert HRDATA(1) = '1'
            report "FAIL: Comparator output not high when ain0>ain1"
            severity error;
        assert HRDATA(1) = '1'
            report "PASS: Comparator output high"
            severity note;

        -- Now reverse: ain0=0, ain1=1 => comparator output should be 0
        ain0 <= '0';
        ain1 <= '1';
        wait for CLK_PERIOD * 4;

        ahb_read(x"00000000");
        assert HRDATA(1) = '0'
            report "FAIL: Comparator output not low when ain0<ain1"
            severity error;
        assert HRDATA(1) = '0'
            report "PASS: Comparator output low"
            severity note;

        -- Test DIDR1 register write/read (0x08)
        ahb_write(x"00000008", x"00000003");
        ahb_read(x"00000008");
        assert HRDATA(1 downto 0) = "11"
            report "FAIL: DIDR1 readback mismatch"
            severity error;
        assert HRDATA(1 downto 0) = "11"
            report "PASS: DIDR1 readback verified"
            severity note;

        report "AVR Analog Comparator testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

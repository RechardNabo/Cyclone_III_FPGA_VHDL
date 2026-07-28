--------------------------------------------------------------------------------
-- tb_msp430_timer_a : Testbench for MSP430 Timer_A counting via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_msp430_timer_a is
end entity tb_msp430_timer_a;

architecture sim of tb_msp430_timer_a is
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
    signal ta_clk    : std_logic;
    signal ta_out    : std_logic_vector(4 downto 0);
    signal ta_irq    : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.msp430_timer_a
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            ta_clk => ta_clk, ta_out => ta_out, ta_irq => ta_irq
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

        -- Set TACCR0 = 100 (0x08)
        ahb_write(x"00000008", x"00000064");

        -- Set TACTL: MC=01 (Up mode), TACLR=1 (bit1)
        -- TACTL at 0x00: bit5:4=MC, bit1=TACLR
        -- MC=01 => bit4=1, TACLR=1 => 0x0012
        ahb_write(x"00000000", x"00000012");
        wait for CLK_PERIOD * 2;

        -- Let timer count (prescaler /4, so ~400 cycles for 100 counts)
        wait for 10 us;

        -- Read TAR (0x04) - should be nonzero and <= 100
        ahb_read(x"00000004");
        assert HRDATA(15 downto 0) /= x"0000"
            report "FAIL: TAR did not count"
            severity error;
        assert HRDATA(15 downto 0) /= x"0000"
            report "PASS: TAR counted to 0x" & integer'image(to_integer(unsigned(HRDATA(15 downto 0))))
            severity note;

        -- Switch to continuous mode: MC=10
        ahb_write(x"00000000", x"00000022");
        wait for 10 us;

        ahb_read(x"00000004");
        assert HRDATA(15 downto 0) /= x"0000"
            report "FAIL: TAR not counting in continuous mode"
            severity error;
        assert HRDATA(15 downto 0) /= x"0000"
            report "PASS: TAR counting in continuous mode"
            severity note;

        -- Stop timer: MC=00
        ahb_write(x"00000000", x"00000002");

        report "MSP430 Timer_A testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

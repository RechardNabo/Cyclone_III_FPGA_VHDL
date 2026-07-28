--------------------------------------------------------------------------------
-- tb_msp430_timer_b : Testbench for MSP430 Timer_B counting via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_msp430_timer_b is
end entity tb_msp430_timer_b;

architecture sim of tb_msp430_timer_b is
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
    signal tb_clk    : std_logic;
    signal tb_out    : std_logic_vector(6 downto 0);
    signal tb_irq    : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.msp430_timer_b
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            tb_clk => tb_clk, tb_out => tb_out, tb_irq => tb_irq
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

        -- Set TBCCR0 = 200 (0x08)
        ahb_write(x"00000008", x"000000C8");

        -- Set TBCTL: MC=01 (Up mode), TACLR=1 (bit1)
        -- TBCTL at 0x00: bit5:4=MC, bit1=TACLR
        ahb_write(x"00000000", x"00000012");
        wait for CLK_PERIOD * 2;

        -- Let timer count (prescaler /4, ~800 cycles for 200 counts)
        wait for 20 us;

        -- Read TBR (0x04) - should be nonzero
        ahb_read(x"00000004");
        assert HRDATA(15 downto 0) /= x"0000"
            report "FAIL: TBR did not count"
            severity error;
        assert HRDATA(15 downto 0) /= x"0000"
            report "PASS: TBR counted to 0x" & integer'image(to_integer(unsigned(HRDATA(15 downto 0))))
            severity note;

        -- Switch to continuous mode: MC=10
        ahb_write(x"00000000", x"00000022");
        wait for 10 us;

        ahb_read(x"00000004");
        assert HRDATA(15 downto 0) /= x"0000"
            report "FAIL: TBR not counting in continuous mode"
            severity error;
        assert HRDATA(15 downto 0) /= x"0000"
            report "PASS: TBR counting in continuous mode"
            severity note;

        -- Read TBIV (0x40) - interrupt vector
        ahb_read(x"00000040");

        -- Stop timer: MC=00
        ahb_write(x"00000000", x"00000002");

        report "MSP430 Timer_B testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

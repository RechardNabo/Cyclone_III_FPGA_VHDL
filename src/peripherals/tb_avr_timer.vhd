--------------------------------------------------------------------------------
-- tb_avr_timer : Testbench for AVR Timer0 counting via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_avr_timer is
end entity tb_avr_timer;

architecture sim of tb_avr_timer is
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
    signal t0_oc0a   : std_logic;
    signal t0_oc0b   : std_logic;
    signal t1_oc1a   : std_logic;
    signal t1_oc1b   : std_logic;
    signal t2_oc2a   : std_logic;
    signal t2_oc2b   : std_logic;
    signal avr_timer_irq : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.avr_timer
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            t0_oc0a => t0_oc0a, t0_oc0b => t0_oc0b,
            t1_oc1a => t1_oc1a, t1_oc1b => t1_oc1b,
            t2_oc2a => t2_oc2a, t2_oc2b => t2_oc2b,
            avr_timer_irq => avr_timer_irq
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
        -- Reset
        HRESETn <= '0';
        wait for 100 ns;
        HRESETn <= '1';
        wait for CLK_PERIOD * 2;

        -- Timer0: Set TCCR0B with prescaler CS=1 (no prescaling)
        -- T0 base = 0x000, TCCR0B at offset 0x04
        ahb_write(x"00000004", x"00000001");

        -- Set TCNT0 = 0 (offset 0x08)
        ahb_write(x"00000008", x"00000000");

        -- Enable overflow interrupt (TIMSK0 at 0x18, bit0=TOIE0)
        ahb_write(x"00000018", x"00000001");

        -- Let timer count for ~200 ticks (prescaler /8 => ~1600 cycles)
        wait for 40 us;

        -- Read TCNT0 - should be nonzero
        ahb_read(x"00000008");
        assert HRDATA(7 downto 0) /= x"00"
            report "FAIL: TCNT0 did not count"
            severity error;
        assert HRDATA(7 downto 0) = x"00"
            report "PASS: TCNT0 counted to 0x" & integer'image(to_integer(unsigned(HRDATA(7 downto 0))))
            severity note;

        -- Read TIFR0 (offset 0x14) - check overflow flag may be set
        ahb_read(x"00000014");

        report "AVR Timer testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

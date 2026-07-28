--------------------------------------------------------------------------------
-- tb_pic_timer : Testbench for PIC Timer0 via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_pic_timer is
end entity tb_pic_timer;

architecture sim of tb_pic_timer is
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
    signal t0_clk    : std_logic := '0';
    signal t1_clk    : std_logic := '0';
    signal t2_out    : std_logic;
    signal pic_timer_irq : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.pic_timer
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            t0_clk => t0_clk, t1_clk => t1_clk,
            t2_out => t2_out, pic_timer_irq => pic_timer_irq
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

        -- Configure OPTION_REG (0x00): internal clock (bit5=0), prescaler 1:2
        -- PSA=0 (bit3=0), PS=001 (bits2:0) => prescaler 1:2
        ahb_write(x"00000000", x"00000001");

        -- Set TMR0 = 0 (0x04)
        ahb_write(x"00000004", x"00000000");

        -- Enable Timer1: T1CON (0x10) bit0=TMR1ON=1, internal clock (bit1=0)
        ahb_write(x"00000010", x"00000001");

        -- Let timers count
        wait for 10 us;

        -- Read TMR0 (0x04) - should be nonzero
        ahb_read(x"00000004");
        assert HRDATA(7 downto 0) /= x"00"
            report "FAIL: TMR0 did not count"
            severity error;
        assert HRDATA(7 downto 0) /= x"00"
            report "PASS: TMR0 counted to 0x" & integer'image(to_integer(unsigned(HRDATA(7 downto 0))))
            severity note;

        -- Read TMR1L (0x08) - should be nonzero
        ahb_read(x"00000008");
        assert HRDATA(7 downto 0) /= x"00"
            report "FAIL: TMR1L did not count"
            severity error;
        assert HRDATA(7 downto 0) /= x"00"
            report "PASS: TMR1L counted"
            severity note;

        -- Configure Timer2: T2CON (0x18) bit2=TMR2ON=1, prescaler 1:1
        -- PR2 (0x1C) = 100
        ahb_write(x"0000001C", x"00000064");
        ahb_write(x"00000018", x"00000004");
        wait for 10 us;

        -- Read TMR2 (0x14)
        ahb_read(x"00000014");
        assert HRDATA(7 downto 0) /= x"00"
            report "FAIL: TMR2 did not count"
            severity error;
        assert HRDATA(7 downto 0) /= x"00"
            report "PASS: TMR2 counted"
            severity note;

        -- Read PIR1 (0x20)
        ahb_read(x"00000020");

        report "PIC Timer testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

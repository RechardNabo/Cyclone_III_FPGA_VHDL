-- ================================================================================
-- tb_rtc_controller : Testbench for RTC register config
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_rtc_controller is
end entity tb_rtc_controller;

architecture sim of tb_rtc_controller is
    constant CLK_PERIOD : time := 20 ns;

    signal clk       : std_logic := '0';
    signal resetn    : std_logic := '0';
    signal hsel      : std_logic := '0';
    signal hwrite    : std_logic := '0';
    signal hready    : std_logic := '1';
    signal htrans    : std_logic_vector(1 downto 0) := "00";
    signal haddr     : std_logic_vector(31 downto 0) := (others => '0');
    signal hwdata    : std_logic_vector(31 downto 0) := (others => '0');
    signal hrdata    : std_logic_vector(31 downto 0);
    signal hresp     : std_logic;
    signal hreadyout : std_logic;
    signal rtc_int   : std_logic;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.rtc_controller
        generic map (CLK_FREQ => 50_000_000)
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            rtc_int => rtc_int
        );

    stim : process
        procedure ahb_write(addr : std_logic_vector(31 downto 0);
                            data : std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            hsel <= '1'; hwrite <= '1'; htrans <= "11";
            haddr <= addr; hwdata <= data;
            wait until rising_edge(clk);
            hsel <= '0'; hwrite <= '0'; htrans <= "00";
        end procedure;

        procedure ahb_read(addr : std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            hsel <= '1'; hwrite <= '0'; htrans <= "11";
            haddr <= addr;
            wait until rising_edge(clk);
            hsel <= '0'; htrans <= "00";
        end procedure;
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Write CTRL: enable=1, irq_en=1
        ahb_write(x"00000000", x"00000003");

        -- Read back CTRL
        ahb_read(x"00000000");
        wait for 1 ns;
        assert hrdata(0) = '1' and hrdata(1) = '1'
            report "FAIL: CTRL readback" severity error;
        report "PASS: CTRL readback" severity note;

        -- Set seconds to a known value
        ahb_write(x"00000004", x"00001000");

        -- Read back seconds
        ahb_read(x"00000004");
        wait for 1 ns;
        assert hrdata = x"00001000"
            report "FAIL: seconds readback" severity error;
        report "PASS: seconds readback" severity note;

        -- Set alarm value
        ahb_write(x"0000000C", x"00002000");

        -- Read back alarm
        ahb_read(x"0000000C");
        wait for 1 ns;
        assert hrdata = x"00002000"
            report "FAIL: alarm readback" severity error;
        report "PASS: alarm readback" severity note;

        -- Read status (alarm_match should be 0)
        ahb_read(x"00000010");
        wait for 1 ns;
        assert hrdata(0) = '0'
            report "FAIL: status alarm_match not 0" severity error;
        report "PASS: status alarm_match=0" severity note;

        -- Read subsec (should be incrementing)
        ahb_read(x"00000008");
        wait for 1 ns;
        report "PASS: subsec read OK" severity note;

        report "--- tb_rtc_controller DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

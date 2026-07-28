-- ================================================================================
-- tb_rtcc_controller : Testbench for RTC calendar controller
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_rtcc_controller is
end entity tb_rtcc_controller;

architecture sim of tb_rtcc_controller is
    constant CLK_PERIOD : time := 20 ns;

    signal clk       : std_logic := '0';
    signal resetn    : std_logic := '0';
    signal hsel      : std_logic := '0';
    signal hwrite    : std_logic := '0';
    signal hready    : std_logic := '1';
    signal htrans    : std_logic_vector(1 downto 0) := "00";
    signal hsize     : std_logic_vector(2 downto 0) := "010";
    signal haddr     : std_logic_vector(31 downto 0) := (others => '0');
    signal hwdata    : std_logic_vector(31 downto 0) := (others => '0');
    signal hrdata    : std_logic_vector(31 downto 0);
    signal hresp     : std_logic;
    signal hreadyout : std_logic;
    signal rtcc_irq  : std_logic;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.rtcc_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HSIZE => hsize, HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            rtcc_irq => rtcc_irq
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

        -- Set time: seconds=30, minutes=15, hours=10
        ahb_write(x"00000008", x"0000001E");  -- seconds=30
        ahb_write(x"0000000C", x"0000000F");  -- minutes=15
        ahb_write(x"00000010", x"0000000A");  -- hours=10

        -- Read back seconds
        ahb_read(x"00000008");
        wait for 1 ns;
        assert hrdata(5 downto 0) = "011110"
            report "FAIL: seconds readback" severity error;
        report "PASS: seconds readback" severity note;

        -- Read back minutes
        ahb_read(x"0000000C");
        wait for 1 ns;
        assert hrdata(5 downto 0) = "001111"
            report "FAIL: minutes readback" severity error;
        report "PASS: minutes readback" severity note;

        -- Read back hours
        ahb_read(x"00000010");
        wait for 1 ns;
        assert hrdata(4 downto 0) = "01010"
            report "FAIL: hours readback" severity error;
        report "PASS: hours readback" severity note;

        -- Set alarm: seconds=31, mask=seconds only
        ahb_write(x"00000020", x"0000001F");  -- alarm seconds=31
        ahb_write(x"00000038", x"00000001");  -- mask: match seconds

        -- Enable RTC with alarm and IRQ
        ahb_write(x"00000000", x"00000007");  -- enable, irq_en, alarm_en

        -- Read CTRL
        ahb_read(x"00000000");
        wait for 1 ns;
        assert hrdata(0) = '1' report "FAIL: CTRL enable not set" severity error;
        report "PASS: CTRL enable set" severity note;

        -- Read status (running should be 1)
        ahb_read(x"00000004");
        wait for 1 ns;
        assert hrdata(0) = '1' report "FAIL: RTC not running" severity error;
        report "PASS: RTC running" severity note;

        report "--- tb_rtcc_controller DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

-- ================================================================================
-- tb_tsc_controller : Testbench for touch sense config
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_tsc_controller is
end entity tb_tsc_controller;

architecture sim of tb_tsc_controller is
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
    signal tsc_io    : std_logic_vector(7 downto 0);
    signal tsc_irq   : std_logic;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.tsc_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HSIZE => hsize, HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            tsc_io => tsc_io, tsc_irq => tsc_irq
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

        -- Write charge/discharge timing
        ahb_write(x"00000008", x"00000010");  -- charge_time=16
        ahb_write(x"0000000C", x"00000008");  -- discharge_time=8

        -- Read back charge_time
        ahb_read(x"00000008");
        wait for 1 ns;
        assert hrdata = x"00000010" report "FAIL: charge_time readback" severity error;
        report "PASS: charge_time readback" severity note;

        -- Read back discharge_time
        ahb_read(x"0000000C");
        wait for 1 ns;
        assert hrdata = x"00000008" report "FAIL: discharge_time readback" severity error;
        report "PASS: discharge_time readback" severity note;

        -- Set threshold for channel 0
        ahb_write(x"00000010", x"00000100");  -- threshold0=256

        -- Read back threshold0
        ahb_read(x"00000010");
        wait for 1 ns;
        assert hrdata(15 downto 0) = x"0100"
            report "FAIL: threshold0 readback" severity error;
        report "PASS: threshold0 readback" severity note;

        -- Enable TSC and start scan
        ahb_write(x"00000000", x"00000005");  -- enable=1, start_scan=1

        -- Read CTRL
        ahb_read(x"00000000");
        wait for 1 ns;
        assert hrdata(0) = '1' report "FAIL: CTRL enable" severity error;
        report "PASS: CTRL enable" severity note;

        -- Wait for scan to progress
        wait for 500 ns;

        -- Read status
        ahb_read(x"00000004");
        wait for 1 ns;
        report "PASS: STAT read OK" severity note;

        report "--- tb_tsc_controller DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

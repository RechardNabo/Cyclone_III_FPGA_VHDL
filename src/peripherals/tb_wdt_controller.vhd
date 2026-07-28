-- ================================================================================
-- tb_wdt_controller : Testbench for watchdog config
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_wdt_controller is
end entity tb_wdt_controller;

architecture sim of tb_wdt_controller is
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
    signal wdt_int   : std_logic;
    signal wdt_reset : std_logic;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.wdt_controller
        generic map (CLK_FREQ => 50_000_000, DEFAULT_LOAD => 50_000_000)
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            wdt_int => wdt_int, wdt_reset => wdt_reset
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

        -- Write WDT_CTRL: enable=1, irq_en=1, reset_en=1
        ahb_write(x"00000000", x"00000007");

        -- Read back CTRL
        ahb_read(x"00000000");
        wait for 1 ns;
        assert hrdata(0) = '1' and hrdata(1) = '1' and hrdata(2) = '1'
            report "FAIL: CTRL readback" severity error;
        report "PASS: CTRL readback" severity note;

        -- Write WDT_LOAD: 1000
        ahb_write(x"00000004", x"000003E8");

        -- Read back LOAD
        ahb_read(x"00000004");
        wait for 1 ns;
        assert hrdata = x"000003E8" report "FAIL: LOAD readback" severity error;
        report "PASS: LOAD readback" severity note;

        -- Refresh watchdog (write 0x55)
        ahb_write(x"00000008", x"00000055");

        -- Read VALUE (should be loaded value after refresh)
        ahb_read(x"0000000C");
        wait for 1 ns;
        assert unsigned(hrdata) = 1000
            report "FAIL: VALUE not reloaded after refresh" severity error;
        report "PASS: VALUE reloaded after refresh" severity note;

        -- Write WDT_WINDOW
        ahb_write(x"00000010", x"00000100");

        -- Read back WINDOW
        ahb_read(x"00000010");
        wait for 1 ns;
        assert hrdata = x"00000100" report "FAIL: WINDOW readback" severity error;
        report "PASS: WINDOW readback" severity note;

        -- Read STATUS (should be 0)
        ahb_read(x"00000014");
        wait for 1 ns;
        assert hrdata(0) = '0' and hrdata(1) = '0'
            report "FAIL: STATUS not clear" severity error;
        report "PASS: STATUS clear" severity note;

        report "--- tb_wdt_controller DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

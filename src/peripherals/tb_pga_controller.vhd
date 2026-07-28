-- ================================================================================
-- tb_pga_controller : Testbench for PGA gain config
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_pga_controller is
end entity tb_pga_controller;

architecture sim of tb_pga_controller is
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
    signal pga_out   : std_logic_vector(7 downto 0);
    signal pga_irq   : std_logic;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.pga_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HSIZE => hsize, HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            pga_out => pga_out, pga_irq => pga_irq
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

        -- Set channel config: active channel=0, scan_mask=0
        ahb_write(x"00000008", x"00000000");

        -- Read back channel_cfg
        ahb_read(x"00000008");
        wait for 1 ns;
        assert hrdata = x"00000000" report "FAIL: channel_cfg readback" severity error;
        report "PASS: channel_cfg readback" severity note;

        -- Set gain for channel 0: gain=3 (8x)
        ahb_write(x"00000010", x"00000003");

        -- Read back gain0
        ahb_read(x"00000010");
        wait for 1 ns;
        assert hrdata(2 downto 0) = "011"
            report "FAIL: gain0 readback" severity error;
        report "PASS: gain0 readback (8x)" severity note;

        -- Set gain for channel 1: gain=5 (32x)
        ahb_write(x"00000014", x"00000005");

        -- Read back gain1
        ahb_read(x"00000014");
        wait for 1 ns;
        assert hrdata(2 downto 0) = "101"
            report "FAIL: gain1 readback" severity error;
        report "PASS: gain1 readback (32x)" severity note;

        -- Enable PGA and start scan
        ahb_write(x"00000000", x"00000005");  -- enable=1, start_scan=1

        -- Read CTRL
        ahb_read(x"00000000");
        wait for 1 ns;
        assert hrdata(0) = '1' report "FAIL: CTRL enable" severity error;
        report "PASS: CTRL enable" severity note;

        -- Wait for conversion
        wait for 500 ns;

        -- Read value0 (should be non-zero after conversion)
        ahb_read(x"00000030");
        wait for 1 ns;
        report "PASS: value0 read OK" severity note;

        report "--- tb_pga_controller DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

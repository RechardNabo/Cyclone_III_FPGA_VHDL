-- ================================================================================
-- tb_comparator_controller : Testbench for comparator hysteresis
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_comparator_controller is
end entity tb_comparator_controller;

architecture sim of tb_comparator_controller is
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
    signal comp_p    : std_logic_vector(3 downto 0) := (others => '0');
    signal comp_n    : std_logic_vector(3 downto 0) := (others => '0');
    signal comp_out  : std_logic_vector(3 downto 0);
    signal comp_irq  : std_logic;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.comparator_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HSIZE => hsize, HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            comp_p => comp_p, comp_n => comp_n,
            comp_out => comp_out, comp_irq => comp_irq
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

        -- Set hysteresis for comparator 0: hyst=5
        ahb_write(x"00000010", x"00000005");

        -- Read back hyst0
        ahb_read(x"00000010");
        wait for 1 ns;
        assert hrdata(3 downto 0) = "0101"
            report "FAIL: hyst0 readback" severity error;
        report "PASS: hyst0 readback" severity note;

        -- Set hysteresis for comparator 1: hyst=10
        ahb_write(x"00000014", x"0000000A");

        -- Read back hyst1
        ahb_read(x"00000014");
        wait for 1 ns;
        assert hrdata(3 downto 0) = "1010"
            report "FAIL: hyst1 readback" severity error;
        report "PASS: hyst1 readback" severity note;

        -- Enable comparator 0 (bit4 in CTRL) and global enable
        ahb_write(x"00000000", x"00000011");  -- enable=1, comp0_en=1

        -- Read back CTRL
        ahb_read(x"00000000");
        wait for 1 ns;
        assert hrdata(0) = '1' and hrdata(4) = '1'
            report "FAIL: CTRL readback" severity error;
        report "PASS: CTRL readback" severity note;

        -- Drive comp_p(0) high -> output should go high
        comp_p <= "0001";
        wait for 100 ns;

        -- Read output register
        ahb_read(x"00000020");
        wait for 1 ns;
        assert hrdata(0) = '1' report "FAIL: comp0 output not high" severity error;
        report "PASS: comp0 output high" severity note;

        -- Drive comp_p(0) low -> output should go low
        comp_p <= "0000";
        wait for 100 ns;

        ahb_read(x"00000020");
        wait for 1 ns;
        assert hrdata(0) = '0' report "FAIL: comp0 output not low" severity error;
        report "PASS: comp0 output low" severity note;

        report "--- tb_comparator_controller DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

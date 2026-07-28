-- ================================================================================
-- tb_lptim_controller : Testbench for low-power timer controller
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_lptim_controller is
end entity tb_lptim_controller;

architecture sim of tb_lptim_controller is
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
    signal ext_clk   : std_logic := '0';
    signal lptim_out : std_logic;
    signal lptim_irq : std_logic;

    constant CTRL_OFFSET : std_logic_vector(31 downto 0) := x"00000000";
    constant STAT_OFFSET : std_logic_vector(31 downto 0) := x"00000004";
    constant ARR_OFFSET  : std_logic_vector(31 downto 0) := x"00000008";
    constant CMP_OFFSET  : std_logic_vector(31 downto 0) := x"0000000C";
    constant CNT_OFFSET  : std_logic_vector(31 downto 0) := x"00000010";

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.lptim_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HSIZE => hsize, HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            lptim_ext_clk => ext_clk, lptim_out => lptim_out,
            lptim_irq => lptim_irq
        );

    stim : process
        procedure ahb_write(addr : std_logic_vector(31 downto 0);
                            data : std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            hsel   <= '1'; hwrite <= '1'; htrans <= "11";
            haddr  <= addr;  hwdata <= data;
            wait until rising_edge(clk);
            hsel   <= '0'; hwrite <= '0'; htrans <= "00";
        end procedure;

        procedure ahb_read(addr : std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            hsel   <= '1'; hwrite <= '0'; htrans <= "11";
            haddr  <= addr;
            wait until rising_edge(clk);
            hsel   <= '0'; htrans <= "00";
        end procedure;
    begin
        -- Reset
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Write ARR = 10, CMP = 5
        ahb_write(ARR_OFFSET, x"0000000A");
        ahb_write(CMP_OFFSET, x"00000005");

        -- Read back ARR
        ahb_read(ARR_OFFSET);
        wait for 1 ns;
        assert hrdata = x"0000000A" report "FAIL: ARR readback" severity error;
        report "PASS: ARR readback" severity note;

        -- Read back CMP
        ahb_read(CMP_OFFSET);
        wait for 1 ns;
        assert hrdata = x"00000005" report "FAIL: CMP readback" severity error;
        report "PASS: CMP readback" severity note;

        -- Enable timer: enable=1, cnt_en=1, internal clock
        ahb_write(CTRL_OFFSET, x"00000011");

        -- Let it count a few cycles
        wait for 200 ns;

        -- Read counter (should be > 0)
        ahb_read(CNT_OFFSET);
        wait for 1 ns;
        assert unsigned(hrdata(15 downto 0)) > 0
            report "FAIL: counter not counting" severity error;
        report "PASS: counter is counting" severity note;

        -- Read status (running bit should be set)
        ahb_read(STAT_OFFSET);
        wait for 1 ns;
        assert hrdata(2) = '1' report "FAIL: running bit not set" severity error;
        report "PASS: running bit set" severity note;

        -- Disable timer
        ahb_write(CTRL_OFFSET, x"00000000");
        wait for 100 ns;

        report "--- tb_lptim_controller DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

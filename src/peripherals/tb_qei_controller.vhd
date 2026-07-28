-- ================================================================================
-- tb_qei_controller : Testbench for quadrature encoder position
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_qei_controller is
end entity tb_qei_controller;

architecture sim of tb_qei_controller is
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
    signal qei_a     : std_logic := '0';
    signal qei_b     : std_logic := '0';
    signal qei_index : std_logic := '0';
    signal qei_irq   : std_logic;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.qei_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HSIZE => hsize, HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            qei_a => qei_a, qei_b => qei_b, qei_index => qei_index,
            qei_irq => qei_irq
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

        -- Set max_pos and enable
        ahb_write(x"00000014", x"00001000");  -- MAX_POS=4096
        ahb_write(x"00000000", x"00000001");  -- CTRL: enable=1

        -- Read back CTRL
        ahb_read(x"00000000");
        wait for 1 ns;
        assert hrdata(0) = '1' report "FAIL: CTRL enable" severity error;
        report "PASS: CTRL enable" severity note;

        -- Read back MAX_POS
        ahb_read(x"00000014");
        wait for 1 ns;
        assert hrdata = x"00001000" report "FAIL: MAX_POS readback" severity error;
        report "PASS: MAX_POS readback" severity note;

        -- Generate forward quadrature pulses (A leads B)
        -- A toggles first, then B toggles, repeat
        for i in 0 to 3 loop
            wait until rising_edge(clk);
            qei_a <= '1';
            wait until rising_edge(clk);
            qei_b <= '1';
            wait until rising_edge(clk);
            qei_a <= '0';
            wait until rising_edge(clk);
            qei_b <= '0';
        end loop;

        -- Read position (should be > 0)
        wait until rising_edge(clk);
        ahb_read(x"00000008");
        wait for 1 ns;
        assert unsigned(hrdata) > 0
            report "FAIL: position not incremented" severity error;
        report "PASS: position incremented" severity note;

        -- Read status (direction should be 1=forward)
        ahb_read(x"00000004");
        wait for 1 ns;
        assert hrdata(0) = '1' report "FAIL: direction not forward" severity error;
        report "PASS: direction forward" severity note;

        report "--- tb_qei_controller DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

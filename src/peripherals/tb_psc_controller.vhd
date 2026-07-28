-- ================================================================================
-- tb_psc_controller : Testbench for power/sleep config
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_psc_controller is
end entity tb_psc_controller;

architecture sim of tb_psc_controller is
    constant CLK_PERIOD : time := 20 ns;

    signal clk          : std_logic := '0';
    signal resetn       : std_logic := '0';
    signal hsel         : std_logic := '0';
    signal hwrite       : std_logic := '0';
    signal hready       : std_logic := '1';
    signal htrans       : std_logic_vector(1 downto 0) := "00";
    signal hsize        : std_logic_vector(2 downto 0) := "010";
    signal haddr        : std_logic_vector(31 downto 0) := (others => '0');
    signal hwdata       : std_logic_vector(31 downto 0) := (others => '0');
    signal hrdata       : std_logic_vector(31 downto 0);
    signal hresp        : std_logic;
    signal hreadyout    : std_logic;
    signal wake_req      : std_logic := '0';
    signal sleep_out     : std_logic;
    signal deep_sleep_out: std_logic;
    signal peri_clk_en   : std_logic_vector(31 downto 0);
    signal psc_irq       : std_logic;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.psc_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HSIZE => hsize, HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            wake_req => wake_req, sleep_out => sleep_out,
            deep_sleep_out => deep_sleep_out, peri_clk_en => peri_clk_en,
            psc_irq => psc_irq
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

        -- Write PERI_GATE: enable peripherals 0,1,2
        ahb_write(x"00000008", x"00000007");

        -- Read back PERI_GATE
        ahb_read(x"00000008");
        wait for 1 ns;
        assert hrdata = x"00000007" report "FAIL: PERI_GATE readback" severity error;
        report "PASS: PERI_GATE readback" severity note;

        -- Write SLEEP_CFG: delay=2 cycles
        ahb_write(x"0000000C", x"00000002");

        -- Read back SLEEP_CFG
        ahb_read(x"0000000C");
        wait for 1 ns;
        assert hrdata(3 downto 0) = "0010"
            report "FAIL: SLEEP_CFG readback" severity error;
        report "PASS: SLEEP_CFG readback" severity note;

        -- Write WAKE_SRC: enable wake from source 0
        ahb_write(x"00000010", x"00000001");

        -- Read back WAKE_SRC
        ahb_read(x"00000010");
        wait for 1 ns;
        assert hrdata = x"00000001" report "FAIL: WAKE_SRC readback" severity error;
        report "PASS: WAKE_SRC readback" severity note;

        -- Write CTRL: force_sleep=1, irq_en=1
        ahb_write(x"00000000", x"0000000C");

        -- Read back CTRL
        ahb_read(x"00000000");
        wait for 1 ns;
        assert hrdata(2) = '1' and hrdata(3) = '1'
            report "FAIL: CTRL readback" severity error;
        report "PASS: CTRL readback" severity note;

        -- Wait for sleep entry (delay=2 cycles)
        wait for 100 ns;

        -- Read STAT (sleeping should be 1)
        ahb_read(x"00000004");
        wait for 1 ns;
        assert hrdata(0) = '1' report "FAIL: not sleeping" severity error;
        report "PASS: entered sleep mode" severity note;

        -- Trigger wake
        wake_req <= '1';
        wait for 100 ns;
        wake_req <= '0';

        -- Read STAT (wake_event should be latched)
        ahb_read(x"00000004");
        wait for 1 ns;
        assert hrdata(2) = '1' report "FAIL: wake_event not set" severity error;
        report "PASS: wake_event set" severity note;

        report "--- tb_psc_controller DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

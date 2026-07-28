-- ================================================================================
-- tb_dac_controller : Testbench for DAC config
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_dac_controller is
end entity tb_dac_controller;

architecture sim of tb_dac_controller is
    constant CLK_PERIOD : time := 20 ns;
    constant NUM_CH     : integer := 2;

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
    signal dac_out   : std_logic_vector(NUM_CH*12-1 downto 0);

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.dac_controller
        generic map (NUM_CHANNELS => NUM_CH)
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            dac_out => dac_out
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

        -- Write DAC_CTRL: enable=1, ch0_en=1 (bit2), ch1_en=1 (bit3)
        ahb_write(x"00000000", x"0000000D");

        -- Read back CTRL
        ahb_read(x"00000000");
        wait for 1 ns;
        assert hrdata(0) = '1' and hrdata(2) = '1' and hrdata(3) = '1'
            report "FAIL: CTRL readback" severity error;
        report "PASS: CTRL readback" severity note;

        -- Write DAC_DATA0 (shadow): 0x800 (mid-scale)
        ahb_write(x"00000008", x"00000800");

        -- Read back DAC_DATA0 (shadow)
        ahb_read(x"00000008");
        wait for 1 ns;
        assert hrdata(11 downto 0) = x"800"
            report "FAIL: DAC_DATA0 readback" severity error;
        report "PASS: DAC_DATA0 readback" severity note;

        -- Write DAC_DATA1 (shadow): 0xFFF (full-scale)
        ahb_write(x"0000000C", x"00000FFF");

        -- Read back DAC_DATA1 (shadow)
        ahb_read(x"0000000C");
        wait for 1 ns;
        assert hrdata(11 downto 0) = x"FFF"
            report "FAIL: DAC_DATA1 readback" severity error;
        report "PASS: DAC_DATA1 readback" severity note;

        -- Trigger update (write to DAC_UPDATE)
        ahb_write(x"00000004", x"00000001");

        -- Wait for output to propagate
        wait for 100 ns;

        -- Check DAC output
        assert dac_out(11 downto 0) = x"800"
            report "FAIL: DAC output0 mismatch" severity error;
        report "PASS: DAC output0 matches" severity note;

        assert dac_out(23 downto 12) = x"FFF"
            report "FAIL: DAC output1 mismatch" severity error;
        report "PASS: DAC output1 matches" severity note;

        report "--- tb_dac_controller DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

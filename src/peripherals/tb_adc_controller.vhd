-- ================================================================================
-- tb_adc_controller : Testbench for ADC config
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_adc_controller is
end entity tb_adc_controller;

architecture sim of tb_adc_controller is
    constant CLK_PERIOD : time := 20 ns;
    constant NUM_CH     : integer := 8;

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
    signal adc_in    : std_logic_vector(NUM_CH*12-1 downto 0) := (others => '0');
    signal adc_int   : std_logic;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.adc_controller
        generic map (NUM_CHANNELS => NUM_CH, CONV_CYCLES => 16)
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            adc_in => adc_in, adc_int => adc_int
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

        -- Set analog input for channel 0 to 0x800 (mid-scale)
        adc_in(11 downto 0) <= x"800";

        -- Write ADC_CTRL: enable=1, irq_en=1
        ahb_write(x"00000000", x"00000003");

        -- Read back CTRL (bit4=busy is merged in, should be 0)
        ahb_read(x"00000000");
        wait for 1 ns;
        assert hrdata(0) = '1' and hrdata(1) = '1'
            report "FAIL: CTRL readback" severity error;
        report "PASS: CTRL readback" severity note;

        -- Select channel 0
        ahb_write(x"00000004", x"00000000");

        -- Read back channel select
        ahb_read(x"00000004");
        wait for 1 ns;
        assert hrdata = x"00000000" report "FAIL: chan_sel readback" severity error;
        report "PASS: chan_sel readback" severity note;

        -- Start conversion (write start bit=1)
        ahb_write(x"00000000", x"0000000B");  -- enable, irq_en, start

        -- Wait for conversion to complete (16 cycles + margin)
        wait for 500 ns;

        -- Read result register for channel 0 (offset 0x10)
        ahb_read(x"00000010");
        wait for 1 ns;
        assert hrdata(11 downto 0) = x"800"
            report "FAIL: ADC result0 mismatch" severity error;
        report "PASS: ADC result0 matches input" severity note;

        -- Read status register
        ahb_read(x"00000008");
        wait for 1 ns;
        assert hrdata(0) = '1' report "FAIL: status bit0 not set" severity error;
        report "PASS: status channel0 done" severity note;

        report "--- tb_adc_controller DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;

-- ================================================================================
-- tb_peripherals : Testbench for WDT, RTC, ADC, DAC peripheral modules
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_peripherals is
end entity tb_peripherals;

architecture sim of tb_peripherals is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    -- Shared signals
    signal clk   : std_logic := '0';
    signal resetn: std_logic := '0';

    -- WDT signals
    signal wdt_hsel   : std_logic := '0';
    signal wdt_hwrite : std_logic := '0';
    signal wdt_hready : std_logic := '1';
    signal wdt_htrans : std_logic_vector(1 downto 0) := "00";
    signal wdt_haddr  : std_logic_vector(31 downto 0) := (others => '0');
    signal wdt_hwdata : std_logic_vector(31 downto 0) := (others => '0');
    signal wdt_hrdata : std_logic_vector(31 downto 0);
    signal wdt_hresp  : std_logic;
    signal wdt_hreadyout: std_logic;
    signal wdt_int    : std_logic;
    signal wdt_reset  : std_logic;

    -- RTC signals
    signal rtc_hsel   : std_logic := '0';
    signal rtc_hwrite : std_logic := '0';
    signal rtc_htrans : std_logic_vector(1 downto 0) := "00";
    signal rtc_haddr  : std_logic_vector(31 downto 0) := (others => '0');
    signal rtc_hwdata : std_logic_vector(31 downto 0) := (others => '0');
    signal rtc_hrdata : std_logic_vector(31 downto 0);
    signal rtc_hresp  : std_logic;
    signal rtc_hreadyout: std_logic;
    signal rtc_int    : std_logic;

    -- ADC signals
    signal adc_hsel   : std_logic := '0';
    signal adc_hwrite : std_logic := '0';
    signal adc_htrans : std_logic_vector(1 downto 0) := "00";
    signal adc_haddr  : std_logic_vector(31 downto 0) := (others => '0');
    signal adc_hwdata : std_logic_vector(31 downto 0) := (others => '0');
    signal adc_hrdata : std_logic_vector(31 downto 0);
    signal adc_hresp  : std_logic;
    signal adc_hreadyout: std_logic;
    signal adc_in     : std_logic_vector(95 downto 0) := (others => '0');
    signal adc_int    : std_logic;

    -- DAC signals
    signal dac_hsel   : std_logic := '0';
    signal dac_hwrite : std_logic := '0';
    signal dac_htrans : std_logic_vector(1 downto 0) := "00";
    signal dac_haddr  : std_logic_vector(31 downto 0) := (others => '0');
    signal dac_hwdata : std_logic_vector(31 downto 0) := (others => '0');
    signal dac_hrdata : std_logic_vector(31 downto 0);
    signal dac_hresp  : std_logic;
    signal dac_hreadyout: std_logic;
    signal dac_out    : std_logic_vector(23 downto 0);

begin

    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instances
    wdt_inst : entity work.wdt_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => wdt_hsel,
            HWRITE => wdt_hwrite, HREADY => '1', HTRANS => wdt_htrans,
            HADDR => wdt_haddr, HWDATA => wdt_hwdata,
            HRDATA => wdt_hrdata, HRESP => wdt_hresp, HREADYOUT => wdt_hreadyout,
            wdt_int => wdt_int, wdt_reset => wdt_reset
        );

    rtc_inst : entity work.rtc_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => rtc_hsel,
            HWRITE => rtc_hwrite, HREADY => '1', HTRANS => rtc_htrans,
            HADDR => rtc_haddr, HWDATA => rtc_hwdata,
            HRDATA => rtc_hrdata, HRESP => rtc_hresp, HREADYOUT => rtc_hreadyout,
            rtc_int => rtc_int
        );

    adc_inst : entity work.adc_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => adc_hsel,
            HWRITE => adc_hwrite, HREADY => '1', HTRANS => adc_htrans,
            HADDR => adc_haddr, HWDATA => adc_hwdata,
            HRDATA => adc_hrdata, HRESP => adc_hresp, HREADYOUT => adc_hreadyout,
            adc_in => adc_in, adc_int => adc_int
        );

    dac_inst : entity work.dac_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => dac_hsel,
            HWRITE => dac_hwrite, HREADY => '1', HTRANS => dac_htrans,
            HADDR => dac_haddr, HWDATA => dac_hwdata,
            HRDATA => dac_hrdata, HRESP => dac_hresp, HREADYOUT => dac_hreadyout,
            dac_out => dac_out
        );

    -- AHB write helper procedure
    ahb_write : process
        procedure do_write(signal hsel: out std_logic; signal hwrite: out std_logic;
                          signal htrans: out std_logic_vector(1 downto 0);
                          signal haddr: out std_logic_vector(31 downto 0);
                          signal hwdata: out std_logic_vector(31 downto 0);
                          addr: in std_logic_vector(31 downto 0);
                          data: in std_logic_vector(31 downto 0)) is
        begin
            hsel   <= '1'; hwrite <= '1'; htrans <= "10";
            haddr  <= addr; hwdata <= data;
            wait for CLK_PERIOD;
            hsel   <= '0'; hwrite <= '0'; htrans <= "00";
            wait for CLK_PERIOD;
        end procedure;
    begin
        -- Reset
        resetn <= '0';
        wait for CLK_PERIOD * 4;
        resetn <= '1';
        wait for CLK_PERIOD * 2;

        -- === WDT Test ===
        report "WDT Test: Load and enable" severity note;
        do_write(wdt_hsel, wdt_hwrite, wdt_htrans, wdt_haddr, wdt_hwdata,
                 x"00000004", x"00000064");  -- Load value = 100
        do_write(wdt_hsel, wdt_hwrite, wdt_htrans, wdt_haddr, wdt_hwdata,
                 x"00000000", x"00000003");  -- Enable + IRQ enable

        -- Wait for counter to count down (100 cycles ~ 2us)
        wait for 5 us;
        -- Pet the dog
        do_write(wdt_hsel, wdt_hwrite, wdt_htrans, wdt_haddr, wdt_hwdata,
                 x"00000008", x"00000055");  -- Refresh
        wait for 2 us;

        -- === RTC Test ===
        report "RTC Test: Set time and read" severity note;
        do_write(rtc_hsel, rtc_hwrite, rtc_htrans, rtc_haddr, rtc_hwdata,
                 x"00000004", x"00000000");  -- Set seconds = 0
        do_write(rtc_hsel, rtc_hwrite, rtc_htrans, rtc_haddr, rtc_hwdata,
                 x"00000000", x"00000001");  -- Enable

        -- Wait a bit and read seconds (won't increment much in sim)
        wait for 2 us;

        -- === ADC Test ===
        report "ADC Test: Start conversion" severity note;
        -- Set analog input values
        adc_in <= x"000" & x"111" & x"222" & x"333" & x"444" & x"555" & x"666" & x"777";

        do_write(adc_hsel, adc_hwrite, adc_htrans, adc_haddr, adc_hwdata,
                 x"00000000", x"00000009");  -- Enable + start
        wait for 1 us;

        -- === DAC Test ===
        report "DAC Test: Write and update" severity note;
        do_write(dac_hsel, dac_hwrite, dac_htrans, dac_haddr, dac_hwdata,
                 x"00000008", x"00000AAA");  -- Channel 0 data
        do_write(dac_hsel, dac_hwrite, dac_htrans, dac_haddr, dac_hwdata,
                 x"0000000C", x"00000BBB");  -- Channel 1 data
        do_write(dac_hsel, dac_hwrite, dac_htrans, dac_haddr, dac_hwdata,
                 x"00000000", x"0000000D");  -- Enable + channel 0+1 enable (bits 0,2,3)
        do_write(dac_hsel, dac_hwrite, dac_htrans, dac_haddr, dac_hwdata,
                 x"00000004", x"00000001");  -- Update outputs
        wait for CLK_PERIOD * 2;

        -- Check DAC output
        assert dac_out(11 downto 0) = x"AAA"
            report "FAIL: DAC channel 0 output mismatch"
            severity error;
        assert dac_out(23 downto 12) = x"BBB"
            report "FAIL: DAC channel 1 output mismatch"
            severity error;

        report "Peripheral testbench complete" severity note;
        wait;
    end process ahb_write;

end architecture sim;

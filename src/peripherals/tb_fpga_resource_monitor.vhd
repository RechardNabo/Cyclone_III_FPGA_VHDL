-- ================================================================================
-- tb_fpga_resource_monitor : Testbench for FPGA Resource Monitor
-- ================================================================================
-- Tests basic AHB-Lite register read/write for resource monitoring.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_fpga_resource_monitor is
end entity tb_fpga_resource_monitor;

architecture sim of tb_fpga_resource_monitor is
    signal HCLK      : std_logic := '0';
    signal HRESETn   : std_logic := '0';
    signal HSEL      : std_logic := '0';
    signal HWRITE    : std_logic := '0';
    signal HREADY    : std_logic := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;
    signal resource_irq : std_logic;
    signal le_count_in  : unsigned(31 downto 0) := to_unsigned(1000, 32);
    signal m9k_count_in : unsigned(31 downto 0) := to_unsigned(10, 32);
    signal dsp_count_in : unsigned(31 downto 0) := to_unsigned(5, 32);
    signal pll_count_in : unsigned(31 downto 0) := to_unsigned(1, 32);

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.fpga_resource_monitor
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            resource_irq => resource_irq,
            le_count_in => le_count_in, m9k_count_in => m9k_count_in,
            dsp_count_in => dsp_count_in, pll_count_in => pll_count_in
        );

    stim : process
        procedure ahb_write(addr : std_logic_vector(31 downto 0);
                            data : std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '1'; HTRANS <= "10";
            HADDR <= addr; HWDATA <= data;
            wait until rising_edge(HCLK);
            HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
        end procedure;

        procedure ahb_read(addr : std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '0'; HTRANS <= "10";
            HADDR <= addr;
            wait until rising_edge(HCLK);
            HSEL <= '0'; HTRANS <= "00";
        end procedure;

        variable test_pass : boolean := true;
    begin
        HRESETn <= '0';
        wait for 100 ns;
        HRESETn <= '1';
        wait until rising_edge(HCLK);

        -- Test 1: Read LE_COUNT (sampled from input)
        report "Test 1: LE_COUNT read";
        wait for CLK_PERIOD * 2;  -- allow sampling
        ahb_read(x"00000000");
        if HRDATA = std_logic_vector(to_unsigned(1000, 32)) then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Read M9K_COUNT
        report "Test 2: M9K_COUNT read";
        ahb_read(x"00000004");
        if HRDATA = std_logic_vector(to_unsigned(10, 32)) then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Write and read TOTAL_LE
        report "Test 3: TOTAL_LE write/read";
        ahb_write(x"00000010", x"0000C000");  -- 49152
        ahb_read(x"00000010");
        if HRDATA = x"0000C000" then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Write and read THRESHOLD
        report "Test 4: THRESHOLD write/read";
        ahb_write(x"0000001C", x"00000050");  -- 80%
        ahb_read(x"0000001C");
        if HRDATA(7 downto 0) = x"50" then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Read DSP_COUNT
        report "Test 5: DSP_COUNT read";
        ahb_read(x"00000008");
        if HRDATA = std_logic_vector(to_unsigned(5, 32)) then
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL FPGA_RESOURCE_MONITOR TESTS PASSED ===" severity note;
        else
            report "=== FPGA_RESOURCE_MONITOR TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;

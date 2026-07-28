-- ================================================================================
-- tb_fpga_bram_controller : Testbench for FPGA BRAM Controller
-- ================================================================================
-- Tests basic AHB-Lite register read/write and BRAM data storage.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_fpga_bram_controller is
end entity tb_fpga_bram_controller;

architecture sim of tb_fpga_bram_controller is
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
    signal clk_b     : std_logic := '0';
    signal we_a      : std_logic;
    signal we_b      : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK   <= not HCLK after CLK_PERIOD / 2;
    clk_b  <= not clk_b after CLK_PERIOD / 2;

    dut : entity work.fpga_bram_controller
        generic map (
            RAM_WIDTH  => 32,
            RAM_DEPTH  => 256,
            ADDR_WIDTH => 8
        )
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            clk => clk_b, we_a => we_a, we_b => we_b
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

        -- Test 1: Set Port A address
        report "Test 1: PORTA_ADDR write/read";
        ahb_write(x"00000000", x"00000010");  -- addr=16
        ahb_read(x"00000000");
        if HRDATA = x"00000010" then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Write data to Port A (triggers write enable)
        report "Test 2: PORTA_DATA write";
        ahb_write(x"00000004", x"DEADBEEF");
        wait until rising_edge(HCLK);
        if we_a = '1' then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL: we_a not asserted" severity error;
            test_pass := false;
        end if;

        -- Test 3: Read back data from Port A
        report "Test 3: PORTA_DATA readback";
        ahb_write(x"00000000", x"00000010");  -- set addr=16 again
        wait for CLK_PERIOD * 2;
        ahb_read(x"00000004");  -- read PORTA_DATA
        if HRDATA = x"DEADBEEF" then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Set Port B address
        report "Test 4: PORTB_ADDR write/read";
        ahb_write(x"00000008", x"00000020");  -- addr=32
        ahb_read(x"00000008");
        if HRDATA = x"00000020" then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Write data to Port B
        report "Test 5: PORTB_DATA write";
        ahb_write(x"0000000C", x"CAFEBABE");
        wait until rising_edge(HCLK);
        if we_b = '1' then
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL: we_b not asserted" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL FPGA_BRAM_CONTROLLER TESTS PASSED ===" severity note;
        else
            report "=== FPGA_BRAM_CONTROLLER TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;

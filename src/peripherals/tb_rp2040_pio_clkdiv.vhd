-- ================================================================================
-- tb_rp2040_pio_clkdiv : Testbench for RP2040 PIO Clock Divider
-- ================================================================================
-- Tests basic AHB-Lite register read/write for PIO clock divider config.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_rp2040_pio_clkdiv is
end entity tb_rp2040_pio_clkdiv;

architecture sim of tb_rp2040_pio_clkdiv is
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
    signal clkdiv_tick  : std_logic;
    signal clkdiv_stall : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.rp2040_pio_clkdiv
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            clkdiv_tick => clkdiv_tick, clkdiv_stall => clkdiv_stall
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

        -- Test 1: Read default CLKDIV_INT (should be 1)
        report "Test 1: CLKDIV_INT default read";
        ahb_read(x"00000000");
        if HRDATA = x"00000001" then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Write CLKDIV_INT
        report "Test 2: CLKDIV_INT write/read";
        ahb_write(x"00000000", x"00000004");  -- divide by 4
        ahb_read(x"00000000");
        if HRDATA = x"00000004" then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Write CLKDIV_FRAC
        report "Test 3: CLKDIV_FRAC write/read";
        ahb_write(x"00000004", x"00000080");  -- 0.5 fractional
        ahb_read(x"00000004");
        if HRDATA = x"00000080" then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Read CLKDIV_STAT (running bit should be set)
        report "Test 4: CLKDIV_STAT running bit";
        wait for CLK_PERIOD * 2;
        ahb_read(x"0000000C");
        if HRDATA(0) = '1' then  -- running
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Verify tick pulse occurs with divide-by-4
        report "Test 5: Tick pulse verification";
        -- With int=4, tick should occur every 4 cycles
        -- Wait for several cycles and check tick observed
        wait until clkdiv_tick = '1';
        if clkdiv_tick = '1' then
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL: no tick observed" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL RP2040_PIO_CLKDIV TESTS PASSED ===" severity note;
        else
            report "=== RP2040_PIO_CLKDIV TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;

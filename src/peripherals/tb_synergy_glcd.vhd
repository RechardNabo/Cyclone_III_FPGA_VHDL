-- ================================================================================
-- tb_synergy_glcd : Testbench for Synergy Graphics LCD Controller
-- ================================================================================
-- Tests basic AHB-Lite register read/write for GLCD configuration.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_synergy_glcd is
end entity tb_synergy_glcd;

architecture sim of tb_synergy_glcd is
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
    signal lcd_hsync : std_logic;
    signal lcd_vsync : std_logic;
    signal lcd_de    : std_logic;
    signal lcd_clk   : std_logic;
    signal lcd_r     : std_logic_vector(5 downto 0);
    signal lcd_g     : std_logic_vector(5 downto 0);
    signal lcd_b     : std_logic_vector(5 downto 0);

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.synergy_glcd
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            lcd_hsync => lcd_hsync, lcd_vsync => lcd_vsync, lcd_de => lcd_de,
            lcd_clk => lcd_clk, lcd_r => lcd_r, lcd_g => lcd_g, lcd_b => lcd_b
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

        -- Test 1: Write and read GLCD_CTRL
        report "Test 1: GLCD_CTRL write/read";
        ahb_write(x"00000000", x"00000003");  -- enable + irq_en
        ahb_read(x"00000000");
        if HRDATA = x"00000003" then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Write and read GLCD_FB_ADDR
        report "Test 2: GLCD_FB_ADDR write/read";
        ahb_write(x"00000008", x"10000000");
        ahb_read(x"00000008");
        if HRDATA = x"10000000" then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Write and read GLCD_HSYNC timing
        report "Test 3: GLCD_HSYNC write/read";
        ahb_write(x"0000000C", x"00401010");
        ahb_read(x"0000000C");
        if HRDATA = x"00401010" then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Write and read GLCD_WIDTH
        report "Test 4: GLCD_WIDTH write/read";
        ahb_write(x"00000014", x"000001E0");  -- 480
        ahb_read(x"00000014");
        if HRDATA = x"000001E0" then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Write and read GLCD_HEIGHT
        report "Test 5: GLCD_HEIGHT write/read";
        ahb_write(x"00000018", x"00000110");  -- 272
        ahb_read(x"00000018");
        if HRDATA = x"00000110" then
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL SYNERGY_GLCD TESTS PASSED ===" severity note;
        else
            report "=== SYNERGY_GLCD TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;

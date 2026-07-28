-- ================================================================================
-- tb_pic_config_fuses : Testbench for PIC Configuration Fuses
-- ================================================================================
-- Tests basic AHB-Lite register read/write and lock/unlock mechanism.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_pic_config_fuses is
end entity tb_pic_config_fuses;

architecture sim of tb_pic_config_fuses is
    signal HCLK      : std_logic := '0';
    signal HRESETn   : std_logic := '0';
    signal HSEL      : std_logic := '0';
    signal HWRITE    : std_logic := '0';
    signal HREADY    : std_logic := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "010";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.pic_config_fuses
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT
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

        -- Test 1: Read CONFIG1 default value
        report "Test 1: CONFIG1 default read";
        ahb_read(x"00000000");
        if HRDATA(7 downto 0) = x"B9" then  -- "10111001"
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Write CONFIG1 (unlocked at reset)
        report "Test 2: CONFIG1 write/read";
        ahb_write(x"00000000", x"000000FF");
        ahb_read(x"00000000");
        if HRDATA(7 downto 0) = x"FF" then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Write CONFIG2
        report "Test 3: CONFIG2 write/read";
        ahb_write(x"00000004", x"000000AA");
        ahb_read(x"00000004");
        if HRDATA(7 downto 0) = x"AA" then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Lock by setting CONFIG4 bit0
        report "Test 4: Lock config registers";
        ahb_write(x"0000000C", x"00000001");  -- set LOCK
        ahb_read(x"0000000C");
        if HRDATA(0) = '1' then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Write to CONFIG1 while locked (should be ignored)
        report "Test 5: Write blocked when locked";
        ahb_write(x"00000000", x"00000000");  -- try to clear
        ahb_read(x"00000000");
        if HRDATA(7 downto 0) = x"FF" then  -- still 0xFF from Test 2
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL PIC_CONFIG_FUSES TESTS PASSED ===" severity note;
        else
            report "=== PIC_CONFIG_FUSES TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;

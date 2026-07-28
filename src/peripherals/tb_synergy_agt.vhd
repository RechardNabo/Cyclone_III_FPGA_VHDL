-- ================================================================================
-- tb_synergy_agt : Testbench for Synergy AGT Timer
-- ================================================================================
-- Tests basic AHB-Lite register read/write for AGT timer configuration.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_synergy_agt is
end entity tb_synergy_agt;

architecture sim of tb_synergy_agt is
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
    signal agt_out   : std_logic;
    signal agt_irq   : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.synergy_agt
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            agt_out => agt_out, agt_irq => agt_irq
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

        -- Test 1: Write and read AGT_CTRL
        report "Test 1: AGT_CTRL write/read";
        ahb_write(x"00000000", x"00000003");  -- enable + irq_en
        ahb_read(x"00000000");
        if HRDATA = x"00000003" then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Write and read AGT_PER
        report "Test 2: AGT_PER write/read";
        ahb_write(x"0000000C", x"0000FFFF");
        ahb_read(x"0000000C");
        if HRDATA = x"0000FFFF" then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Write and read AGT_CC
        report "Test 3: AGT_CC write/read";
        ahb_write(x"00000010", x"00008000");
        ahb_read(x"00000010");
        if HRDATA = x"00008000" then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Read AGT_CNT (should be 0 after reset)
        report "Test 4: AGT_CNT reset value";
        ahb_read(x"00000008");
        if HRDATA = x"00000000" then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Read AGT_STAT (should be 0 after reset)
        report "Test 5: AGT_STAT reset value";
        ahb_read(x"00000004");
        if HRDATA = x"00000000" then
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL SYNERGY_AGT TESTS PASSED ===" severity note;
        else
            report "=== SYNERGY_AGT TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;

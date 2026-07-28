-- ================================================================================
-- tb_synergy_elc : Testbench for Synergy Event Link Controller
-- ================================================================================
-- Tests basic AHB-Lite register read/write for ELC event routing config.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_synergy_elc is
end entity tb_synergy_elc;

architecture sim of tb_synergy_elc is
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
    signal elc_event_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal elc_event_out : std_logic_vector(31 downto 0);

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.synergy_elc
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            elc_event_in => elc_event_in, elc_event_out => elc_event_out
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

        -- Test 1: Write and read ELC_CTRL
        report "Test 1: ELC_CTRL write/read";
        ahb_write(x"00000000", x"00000001");  -- enable
        ahb_read(x"00000000");
        if HRDATA = x"00000001" then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Configure ELSR0 (source=5, dest=10, enable)
        report "Test 2: ELSR0 write/read";
        ahb_write(x"00000008", x"00010A05");  -- bit16=1, dest=10, src=5
        ahb_read(x"00000008");
        if HRDATA = x"00010A05" then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Configure ELSR1
        report "Test 3: ELSR1 write/read";
        ahb_write(x"0000000C", x"00011803");  -- bit16=1, dest=24, src=3
        ahb_read(x"0000000C");
        if HRDATA = x"00011803" then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Read ELC_STAT (should be 0 after reset)
        report "Test 4: ELC_STAT reset value";
        ahb_read(x"00000004");
        if HRDATA = x"00000000" then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Configure ELSR2 and ELSR3
        report "Test 5: ELSR2/ELSR3 write/read";
        ahb_write(x"00000010", x"00010702");
        ahb_write(x"00000014", x"00011B0F");
        ahb_read(x"00000010");
        if HRDATA = x"00010702" then
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL SYNERGY_ELC TESTS PASSED ===" severity note;
        else
            report "=== SYNERGY_ELC TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;

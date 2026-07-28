-- ================================================================================
-- tb_synergy_sdhi : Testbench for Synergy SD Host Interface
-- ================================================================================
-- Tests basic AHB-Lite register read/write for SDHI configuration.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_synergy_sdhi is
end entity tb_synergy_sdhi;

architecture sim of tb_synergy_sdhi is
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
    signal sd_clk    : std_logic;
    signal sd_cmd    : std_logic;
    signal sd_dat    : std_logic_vector(3 downto 0);
    signal sd_cd     : std_logic := '1';  -- no card
    signal sd_irq    : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.synergy_sdhi
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            sd_clk => sd_clk, sd_cmd => sd_cmd, sd_dat => sd_dat,
            sd_cd => sd_cd, sd_irq => sd_irq
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

        -- Test 1: Write and read SDHI_CTRL
        report "Test 1: SDHI_CTRL write/read";
        ahb_write(x"00000000", x"00000007");  -- enable + irq_en + 4bit
        ahb_read(x"00000000");
        if HRDATA = x"00000007" then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Configure SDHI_BLKSIZE
        report "Test 2: SDHI_BLKSIZE write/read";
        ahb_write(x"00000024", x"00000200");  -- 512 bytes
        ahb_read(x"00000024");
        if HRDATA = x"00000200" then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Configure SDHI_BLKCNT
        report "Test 3: SDHI_BLKCNT write/read";
        ahb_write(x"00000028", x"00000004");  -- 4 blocks
        ahb_read(x"00000028");
        if HRDATA = x"00000004" then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Write SDHI_ARG
        report "Test 4: SDHI_ARG write/read";
        ahb_write(x"0000000C", x"12345678");
        ahb_read(x"0000000C");
        if HRDATA = x"12345678" then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Read SDHI_STAT (card_detected should reflect sd_cd)
        report "Test 5: SDHI_STAT read";
        ahb_read(x"00000004");
        if HRDATA(2) = '0' then  -- sd_cd=1 means no card -> bit2=0
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL SYNERGY_SDHI TESTS PASSED ===" severity note;
        else
            report "=== SYNERGY_SDHI TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;

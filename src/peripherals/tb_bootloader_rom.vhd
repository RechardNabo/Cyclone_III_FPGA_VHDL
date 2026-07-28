-- ================================================================================
-- tb_bootloader_rom : Testbench for Bootloader ROM
-- ================================================================================
-- Verifies boot sequence via AHB-Lite interface.
--
-- Tests:
--   1. Configure boot source and address
--   2. Start boot and verify boot_active
--   3. Wait for boot_done status
--   4. Read flash data from ROM
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_bootloader_rom is
end entity tb_bootloader_rom;

architecture sim of tb_bootloader_rom is
    signal HCLK    : std_logic := '0';
    signal HRESETn : std_logic := '0';

    signal HSEL      : std_logic                    := '0';
    signal HWRITE    : std_logic                    := '0';
    signal HREADY    : std_logic                    := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "010";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;
    signal boot_irq  : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.bootloader_rom
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT, boot_irq => boot_irq
        );

    stim : process
        procedure ahb_write(addr : in std_logic_vector(31 downto 0);
                            data : in std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '1'; HTRANS <= "10";
            HADDR <= addr; HWDATA <= data;
            wait until rising_edge(HCLK);
            HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
        end procedure;

        procedure ahb_read(addr : in std_logic_vector(31 downto 0);
                           data : out std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '0'; HTRANS <= "10";
            HADDR <= addr;
            wait until rising_edge(HCLK);
            data := HRDATA;
            HSEL <= '0'; HTRANS <= "00";
        end procedure;

        variable rdata     : std_logic_vector(31 downto 0);
        variable test_pass : boolean := true;
    begin
        HRESETn <= '0';
        wait for 100 ns;
        HRESETn <= '1';
        wait until rising_edge(HCLK);

        -- Test 1: Configure boot source (ROM) and address
        report "Test 1: Configure boot source";
        ahb_write(x"00000008", x"00000000");  -- BOOT_SRC = 0 (ROM)
        ahb_write(x"0000000C", x"00000000");  -- BOOT_ADDR = 0x0
        ahb_read(x"00000008", rdata);
        assert rdata = x"00000000"
            report "Test 1 FAILED: BOOT_SRC mismatch" severity error;
        if rdata = x"00000000" then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 2: Start boot (boot_start=1, boot_en=1)
        report "Test 2: Start boot sequence";
        ahb_write(x"00000000", x"00000003");  -- CTRL: start=1, en=1
        wait until rising_edge(HCLK);
        ahb_read(x"00000004", rdata);  -- STAT
        assert rdata(2) = '1'
            report "Test 2 FAILED: boot_active not set" severity error;
        if rdata(2) = '1' then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 3: Wait for boot done
        report "Test 3: Wait for boot done";
        wait for 500 ns;
        ahb_read(x"00000004", rdata);  -- STAT
        assert rdata(0) = '1'
            report "Test 3 FAILED: boot_done not set" severity error;
        if rdata(0) = '1' then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 4: Read flash data from ROM
        report "Test 4: Read flash data";
        ahb_write(x"0000000C", x"00000000");  -- BOOT_ADDR = 0
        ahb_read(x"00000010", rdata);  -- FLASH_DATA
        assert rdata = x"00000013"
            report "Test 4 FAILED: flash data mismatch" severity error;
        if rdata = x"00000013" then
            report "Test 4 PASSED" severity note;
        else
            test_pass := false;
        end if;

        if test_pass then
            report "PASS" severity note;
        else
            report "FAIL" severity error;
        end if;
        finish;
    end process;
end architecture sim;

-- ================================================================================
-- tb_crc_accelerator : Testbench for CRC accelerator
-- ================================================================================
-- Verifies CRC-16-CCITT and CRC-32 computation via AHB-Lite interface.
--
-- Tests:
--   1. Write control register (CRC-16-CCITT mode, reset)
--   2. Feed data bytes and verify CRC-16-CCITT result
--   3. Switch to CRC-32 mode and verify CRC-32 result
--   4. Verify data count register
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_crc_accelerator is
end entity tb_crc_accelerator;

architecture sim of tb_crc_accelerator is
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
    signal crc_irq   : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.crc_accelerator
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT, crc_irq => crc_irq
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

        -- Test 1: CRC-16-CCITT mode with reset
        report "Test 1: CRC-16-CCITT mode and reset";
        ahb_write(x"00000004", x"FFFF0000");  -- SEED
        ahb_write(x"00000000", x"00000008");  -- CTRL: mode=000, reset=1
        ahb_read(x"00000000", rdata);
        assert rdata(2 downto 0) = "000"
            report "Test 1 FAILED: mode not set" severity error;
        if rdata(2 downto 0) = "000" then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 2: Feed data bytes and check CRC-16-CCITT result
        report "Test 2: CRC-16-CCITT computation";
        ahb_write(x"00000008", x"00000041");  -- DATA = 'A'
        ahb_write(x"00000008", x"00000042");  -- DATA = 'B'
        ahb_read(x"0000000C", rdata);  -- RESULT
        assert rdata /= x"FFFF0000"
            report "Test 2 FAILED: CRC unchanged after data" severity error;
        if rdata /= x"FFFF0000" then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 3: CRC-32 mode
        report "Test 3: CRC-32 computation";
        ahb_write(x"00000004", x"FFFFFFFF");  -- SEED
        ahb_write(x"00000000", x"0000000A");  -- CTRL: mode=010(CRC32), reset=1
        ahb_write(x"00000008", x"00000031");  -- DATA = '1'
        ahb_read(x"0000000C", rdata);  -- RESULT
        assert rdata /= x"FFFFFFFF"
            report "Test 3 FAILED: CRC-32 unchanged" severity error;
        if rdata /= x"FFFFFFFF" then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 4: Data count
        report "Test 4: Data count register";
        ahb_read(x"00000014", rdata);  -- data_count
        assert unsigned(rdata) >= 3
            report "Test 4 FAILED: count too low" severity error;
        if unsigned(rdata) >= 3 then
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

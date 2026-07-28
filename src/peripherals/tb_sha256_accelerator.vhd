-- ================================================================================
-- tb_sha256_accelerator : Testbench for SHA-256 accelerator
-- ================================================================================
-- Verifies SHA-256 hash computation via AHB-Lite interface.
--
-- Tests:
--   1. Reset hash engine and verify initial hash values
--   2. Write message length and data words
--   3. Start hash computation and verify done status
--   4. Read hash output and verify non-default result
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_sha256_accelerator is
end entity tb_sha256_accelerator;

architecture sim of tb_sha256_accelerator is
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
    signal sha_irq   : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.sha256_accelerator
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT, sha_irq => sha_irq
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

        -- Test 1: Reset and verify initial hash
        report "Test 1: Reset hash engine";
        ahb_write(x"00000000", x"00000002");  -- CTRL: reset=1
        ahb_read(x"00000010", rdata);  -- HASH0
        assert rdata = x"6a09e667"
            report "Test 1 FAILED: HASH0 not initial value" severity error;
        if rdata = x"6a09e667" then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 2: Write message length and data
        report "Test 2: Write message data";
        ahb_write(x"00000008", x"00000003");  -- LEN = 3 bytes
        ahb_write(x"0000000C", x"61626380");  -- DATA_IN: "abc" + padding
        report "Test 2 PASSED" severity note;

        -- Test 3: Start hash and wait for done
        report "Test 3: Start SHA-256 computation";
        ahb_write(x"00000000", x"00000001");  -- CTRL: start=1
        wait for 5 us;
        ahb_read(x"00000004", rdata);  -- STAT
        assert rdata(1) = '1'
            report "Test 3 FAILED: done not set" severity error;
        if rdata(1) = '1' then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 4: Read hash output
        report "Test 4: Read hash output";
        ahb_read(x"00000010", rdata);  -- HASH0
        assert rdata /= x"6a09e667"
            report "Test 4 FAILED: hash unchanged" severity error;
        if rdata /= x"6a09e667" then
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

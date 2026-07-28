-- ================================================================================
-- tb_fuse_otp_controller : Testbench for Fuse/OTP Controller
-- ================================================================================
-- Verifies fuse programming via AHB-Lite interface.
--
-- Tests:
--   1. Enable fuse controller
--   2. Set fuse address and data
--   3. Program fuse with magic value and verify done
--   4. Read back programmed fuse data
--   5. Verify re-programming causes error
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_fuse_otp_controller is
end entity tb_fuse_otp_controller;

architecture sim of tb_fuse_otp_controller is
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
    signal fuse_irq  : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.fuse_otp_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT, fuse_irq => fuse_irq
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

        -- Test 1: Enable fuse controller
        report "Test 1: Enable fuse controller";
        ahb_write(x"00000000", x"00000001");  -- CTRL: prog_en=1
        ahb_read(x"00000000", rdata);
        assert rdata(0) = '1'
            report "Test 1 FAILED: CTRL not set" severity error;
        if rdata(0) = '1' then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 2: Set fuse address and data
        report "Test 2: Set fuse address and data";
        ahb_write(x"0000000C", x"00000003");  -- FUSE_ADDR = 3
        ahb_write(x"00000008", x"DEADBEEF");  -- FUSE_DATA
        ahb_read(x"0000000C", rdata);
        assert rdata = x"00000003"
            report "Test 2 FAILED: addr mismatch" severity error;
        if rdata = x"00000003" then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 3: Program fuse with magic
        report "Test 3: Program fuse";
        ahb_write(x"00000010", x"0000504F");  -- FUSE_PROG: magic
        wait for 100 ns;
        ahb_read(x"00000004", rdata);  -- STAT
        assert rdata(1) = '1'
            report "Test 3 FAILED: prog_done not set" severity error;
        if rdata(1) = '1' then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 4: Read back programmed fuse
        report "Test 4: Read back fuse data";
        ahb_write(x"0000000C", x"00000003");  -- FUSE_ADDR = 3
        ahb_read(x"00000008", rdata);  -- FUSE_DATA
        assert rdata = x"DEADBEEF"
            report "Test 4 FAILED: fuse data mismatch" severity error;
        if rdata = x"DEADBEEF" then
            report "Test 4 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 5: Re-programming should cause error
        report "Test 5: Re-program fuse (expect error)";
        ahb_write(x"00000008", x"CAFEBABE");
        ahb_write(x"00000010", x"0000504F");
        wait for 100 ns;
        ahb_read(x"00000004", rdata);  -- STAT
        assert rdata(2) = '1'
            report "Test 5 FAILED: fuse_error not set" severity error;
        if rdata(2) = '1' then
            report "Test 5 PASSED" severity note;
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

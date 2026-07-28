-- ================================================================================
-- tb_dap_controller : Testbench for Debug Access Port Controller
-- ================================================================================
-- Verifies DAP register access via AHB-Lite interface.
--
-- Tests:
--   1. Enable SWD mode and verify status
--   2. Write and read DP_CTRL register
--   3. Write and read AP_CTRL register
--   4. Write and read AP_DATA register
--   5. Enable JTAG mode and verify status
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_dap_controller is
end entity tb_dap_controller;

architecture sim of tb_dap_controller is
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

    signal swclk : std_logic := '0';
    signal swdio : std_logic;
    signal tck   : std_logic := '0';
    signal tms   : std_logic := '0';
    signal tdi   : std_logic := '0';
    signal tdo   : std_logic;
    signal ntrst : std_logic := '1';

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.dap_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            swclk => swclk, swdio => swdio, tck => tck, tms => tms,
            tdi => tdi, tdo => tdo, ntrst => ntrst
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

        -- Test 1: Enable SWD mode
        report "Test 1: Enable SWD mode";
        ahb_write(x"00000000", x"00000001");  -- CTRL: swd_en=1
        ahb_read(x"00000004", rdata);  -- STAT
        assert rdata(0) = '1'
            report "Test 1 FAILED: swd_active not set" severity error;
        if rdata(0) = '1' then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 2: Write and read DP_CTRL
        report "Test 2: DP_CTRL read/write";
        ahb_write(x"00000008", x"12345678");  -- DP_CTRL
        ahb_read(x"00000008", rdata);
        assert rdata = x"12345678"
            report "Test 2 FAILED: DP_CTRL mismatch" severity error;
        if rdata = x"12345678" then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 3: Write and read AP_CTRL
        report "Test 3: AP_CTRL read/write";
        ahb_write(x"0000000C", x"AABBCCDD");  -- AP_CTRL
        ahb_read(x"0000000C", rdata);
        assert rdata = x"AABBCCDD"
            report "Test 3 FAILED: AP_CTRL mismatch" severity error;
        if rdata = x"AABBCCDD" then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 4: Write and read AP_DATA
        report "Test 4: AP_DATA read/write";
        ahb_write(x"00000010", x"DEADBEEF");  -- AP_DATA
        ahb_read(x"00000010", rdata);
        assert rdata = x"DEADBEEF"
            report "Test 4 FAILED: AP_DATA mismatch" severity error;
        if rdata = x"DEADBEEF" then
            report "Test 4 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 5: Enable JTAG mode
        report "Test 5: Enable JTAG mode";
        ahb_write(x"00000000", x"00000002");  -- CTRL: jtag_en=1
        ahb_read(x"00000004", rdata);  -- STAT
        assert rdata(1) = '1'
            report "Test 5 FAILED: jtag_active not set" severity error;
        if rdata(1) = '1' then
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

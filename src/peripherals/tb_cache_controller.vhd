-- ================================================================================
-- tb_cache_controller : Testbench for Cache Controller
-- ================================================================================
-- Verifies cache hit/miss behavior via AHB-Lite interface.
--
-- Tests:
--   1. Enable cache and verify control register
--   2. Perform a read (miss) and verify miss counter increments
--   3. Perform same read (hit) and verify hit counter increments
--   4. Flush cache and verify counters can be cleared
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_cache_controller is
end entity tb_cache_controller;

architecture sim of tb_cache_controller is
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

    signal cpu_addr  : std_logic_vector(31 downto 0);
    signal cpu_wdata : std_logic_vector(31 downto 0);
    signal cpu_rdata : std_logic_vector(31 downto 0) := x"DEADBEEF";
    signal cpu_req   : std_logic;
    signal cpu_we    : std_logic;
    signal cpu_ack   : std_logic := '0';

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    -- Backing store model: acknowledge requests with data
    cpu_ack <= cpu_req after 20 ns;

    dut : entity work.cache_controller
        generic map (CACHE_LINES => 128, LINE_SIZE => 32)
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            cpu_addr => cpu_addr, cpu_wdata => cpu_wdata,
            cpu_rdata => cpu_rdata, cpu_req => cpu_req,
            cpu_we => cpu_we, cpu_ack => cpu_ack
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

        -- Test 1: Enable cache
        report "Test 1: Enable cache";
        ahb_write(x"00000000", x"00000001");  -- CTRL: enable=1
        ahb_read(x"00000000", rdata);
        assert rdata(0) = '1'
            report "Test 1 FAILED: cache not enabled" severity error;
        if rdata(0) = '1' then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 2: Read from cache (miss on first access)
        report "Test 2: Cache miss on first access";
        ahb_read(x"00001000", rdata);  -- arbitrary address
        wait until rising_edge(HCLK);
        ahb_read(x"0000000C", rdata);  -- MISS_COUNT
        assert unsigned(rdata) >= 1
            report "Test 2 FAILED: miss count not incremented" severity error;
        if unsigned(rdata) >= 1 then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 3: Read same address (hit)
        report "Test 3: Cache hit on second access";
        ahb_read(x"00001000", rdata);
        wait until rising_edge(HCLK);
        ahb_read(x"00000008", rdata);  -- HIT_COUNT
        assert unsigned(rdata) >= 1
            report "Test 3 FAILED: hit count not incremented" severity error;
        if unsigned(rdata) >= 1 then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 4: Clear counters
        report "Test 4: Clear counters";
        ahb_write(x"00000008", x"00000001");  -- clear hit count
        ahb_write(x"0000000C", x"00000001");  -- clear miss count
        ahb_read(x"00000008", rdata);
        assert unsigned(rdata) = 0
            report "Test 4 FAILED: hit count not cleared" severity error;
        if unsigned(rdata) = 0 then
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
